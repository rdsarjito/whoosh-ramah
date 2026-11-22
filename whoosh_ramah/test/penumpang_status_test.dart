import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:whoosh_ramah/models/permintaan.dart';
import 'package:whoosh_ramah/screens/penumpang_status_screen.dart';
import 'package:whoosh_ramah/screens/penumpang_tiket_screen.dart';
import 'package:whoosh_ramah/services/permintaan_service.dart';
import 'package:whoosh_ramah/theme.dart';
import 'package:whoosh_ramah/widgets/hero_back_button.dart';
import 'package:whoosh_ramah/widgets/skeleton.dart';

/// Service palsu: hanya `streamPermintaan` yang dipakai layar status, jadi
/// konstruktor super tidak menyentuh Firestore (init `_db` bersifat malas).
class _FakeService extends PermintaanService {
  _FakeService(this._data);

  final Permintaan? _data;

  @override
  Stream<Permintaan?> streamPermintaan(String id) => Stream<Permintaan?>.value(_data);
}

/// Service yang stream-nya tidak pernah emit, untuk menguji state loading.
class _LoadingService extends PermintaanService {
  final StreamController<Permintaan?> _controller = StreamController<Permintaan?>();

  @override
  Stream<Permintaan?> streamPermintaan(String id) => _controller.stream;
}

/// Service dengan aliran yang bisa dikendalikan tes, untuk menguji animasi
/// perubahan status (Tier 2 D4).
class _StreamService extends PermintaanService {
  _StreamService(this._aliran);

  final Stream<Permintaan?> _aliran;

  @override
  Stream<Permintaan?> streamPermintaan(String id) => _aliran;
}

/// Service palsu yang merekam panggilan `tandaiTiba` (Tier 1 A1).
class _FakeTibaService extends PermintaanService {
  _FakeTibaService(this._data, {this.gagal = false});

  final Permintaan? _data;
  final bool gagal;
  final List<String> ditandai = <String>[];

  @override
  Stream<Permintaan?> streamPermintaan(String id) => Stream<Permintaan?>.value(_data);

  @override
  Future<void> tandaiTiba(String id) async {
    ditandai.add(id);
    if (gagal) throw Exception('jaringan putus');
  }
}

/// Langganan pertama gagal (atau kosong), berikutnya berhasil — menguji
/// tombol "Coba lagi" pada state error maupun "tidak ditemukan".
class _GagalLaluPulihService extends PermintaanService {
  _GagalLaluPulihService(this._pulih, {this.gagalPertama = true});

  final Permintaan? _pulih;
  final bool gagalPertama;
  int langganan = 0;

  @override
  Stream<Permintaan?> streamPermintaan(String id) {
    langganan++;
    if (langganan > 1) return Stream<Permintaan?>.value(_pulih);
    if (gagalPertama) return Stream<Permintaan?>.error(Exception('offline'));
    return Stream<Permintaan?>.value(null);
  }
}

Permintaan _bertemu({DateTime? tibaPada, StatusPermintaan status = StatusPermintaan.bertemu}) =>
    Permintaan(
      id: 'abc',
      jenisBantuan: JenisBantuan.kursiRoda,
      titikJemput: 'Lobi utama',
      status: status,
      sumber: 'aplikasi',
      petugas: 'Rina',
      gerbong: '5',
      kursi: '7A',
      stasiunTujuan: 'Tegalluar',
      tibaPada: tibaPada,
    );

void main() {
  Future<void> bukaDengan(WidgetTester tester, PermintaanService service) async {
    await tester.binding.setSurfaceSize(const Size(420, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PenumpangStatusScreen(idPermintaan: 'x', service: service),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> buka(WidgetTester tester, Permintaan? data) async {
    await bukaDengan(tester, _FakeService(data));
  }

  /// Habiskan timer SnackBar (4 dtk) agar tidak ada timer menggantung.
  Future<void> habiskanSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets('Langkah 5: state loading saat data belum tiba', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PenumpangStatusScreen(idPermintaan: 'x', service: _LoadingService()),
      ),
    );
    await tester.pump(); // satu frame; jangan settle (kilau skeleton beranimasi terus)

    expect(find.text('Pendampingan Anda'), findsOneWidget);
    // Tier 2 D4: spinner polos diganti kerangka yang meniru kartu petugas.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(Skeleton), findsOneWidget);
    expect(find.byType(SkeletonRincian), findsOneWidget);
  });

  testWidgets('Langkah 5: status bertemu -> kartu petugas, timeline aktif, tombol bawah', (tester) async {
    const p = Permintaan(
      id: 'abc',
      jenisBantuan: JenisBantuan.kursiRoda,
      titikJemput: 'Lobi utama',
      status: StatusPermintaan.bertemu,
      sumber: 'aplikasi',
      petugas: 'Rina',
      gerbong: '5',
      kursi: '7A',
      stasiunTujuan: 'Tegalluar',
      riwayat: [
        RiwayatStatus(status: 'menunggu'),
        RiwayatStatus(status: 'ditugaskan'),
        RiwayatStatus(status: 'bertemu'),
      ],
    );
    await buka(tester, p);

    // Judul + pill status (contoh pesan yang juga diumumkan ke TalkBack).
    expect(find.text('Pendampingan Anda'), findsOneWidget);
    expect(find.text('Petugas menuju Anda'), findsOneWidget);

    // Kartu petugas muncul setelah status >= ditugaskan.
    expect(find.text('Rina'), findsOneWidget);
    expect(find.text('Petugas Layanan · Stasiun Halim'), findsOneWidget);
    expect(find.text('Lobi utama'), findsOneWidget);

    // Langkah aktif disorot + "· sekarang"; langkah terakhir dinamis.
    expect(find.text('Bertemu petugas · sekarang'), findsOneWidget);
    expect(find.text('Dijemput petugas di Tegalluar'), findsOneWidget);

    // Tombol bawah.
    expect(find.text('Saya sudah sampai di lobi'), findsOneWidget);
    expect(find.text('Bagikan ke keluarga'), findsOneWidget);
  });

  testWidgets('Langkah 5: status menunggu -> "Mencari petugas…", tanpa kartu petugas', (tester) async {
    const p = Permintaan(
      id: 'def',
      jenisBantuan: JenisBantuan.kursiRoda,
      titikJemput: 'Lobi utama',
      status: StatusPermintaan.menunggu,
      sumber: 'aplikasi',
    );
    await buka(tester, p);

    // "Mencari petugas…" muncul di pill hero dan di kartu (pengganti kartu petugas).
    expect(find.text('Mencari petugas…'), findsWidgets);
    expect(find.text('Rina'), findsNothing);
    // Langkah pertama aktif.
    expect(find.text('Permintaan diterima · sekarang'), findsOneWidget);
  });

  testWidgets('Langkah 5: dokumen tidak ditemukan ditangani rapi', (tester) async {
    await buka(tester, null);
    expect(find.text('Permintaan tidak ditemukan.'), findsOneWidget);
  });

  testWidgets('Tier 1 A1: CTA tiba menulis lewat tandaiTiba(id) + SnackBar sukses', (tester) async {
    final service = _FakeTibaService(_bertemu());
    await bukaDengan(tester, service);

    await tester.tap(find.text('Saya sudah sampai di lobi'));
    await tester.pumpAndSettle();

    // Aksi nyata: menulis ke Firestore lewat service, bukan sekadar SnackBar.
    expect(service.ditandai, <String>['x']);
    expect(find.text('Petugas sudah diberi tahu Anda tiba.'), findsOneWidget);
    await habiskanSnackBar(tester);
  });

  testWidgets('Tier 1 A1: tandaiTiba gagal -> SnackBar gagal, CTA tetap bisa ditekan', (tester) async {
    final service = _FakeTibaService(_bertemu(), gagal: true);
    await bukaDengan(tester, service);

    await tester.tap(find.text('Saya sudah sampai di lobi'));
    await tester.pumpAndSettle();

    expect(service.ditandai, <String>['x']);
    expect(find.text('Gagal memberi tahu petugas. Silakan coba lagi.'), findsOneWidget);
    expect(find.text('Saya sudah sampai di lobi'), findsOneWidget);
    await habiskanSnackBar(tester);

    // Ketukan kedua mencoba lagi (tidak terkunci permanen).
    await tester.tap(find.text('Saya sudah sampai di lobi'));
    await tester.pumpAndSettle();
    expect(service.ditandai, <String>['x', 'x']);
    await habiskanSnackBar(tester);
  });

  testWidgets('Tier 1 A1: sudahTiba -> kabar hijau menggantikan CTA', (tester) async {
    await bukaDengan(tester, _FakeTibaService(_bertemu(tibaPada: DateTime(2026, 11, 22, 7, 50))));

    expect(find.text('Petugas sudah diberi tahu · 07.50'), findsOneWidget);
    expect(find.text('Saya sudah sampai di lobi'), findsNothing);
    expect(find.text('Bagikan ke keluarga'), findsOneWidget);
  });

  testWidgets('Tier 1 A1: status selesai -> CTA tiba tidak relevan, disembunyikan', (tester) async {
    await bukaDengan(
      tester,
      _FakeTibaService(_bertemu(status: StatusPermintaan.selesai)),
    );

    expect(find.text('Saya sudah sampai di lobi'), findsNothing);
    expect(find.text('Bagikan ke keluarga'), findsOneWidget);
  });

  testWidgets('Tier 1 B2: gagal memuat -> "Coba lagi" berlangganan ulang lalu pulih', (tester) async {
    final service = _GagalLaluPulihService(_bertemu());
    await bukaDengan(tester, service);

    expect(find.text('Gagal memuat status. Periksa koneksi Anda.'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(service.langganan, 1);

    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(service.langganan, 2);
    expect(find.text('Gagal memuat status. Periksa koneksi Anda.'), findsNothing);
    expect(find.text('Petugas menuju Anda'), findsOneWidget);
  });

  testWidgets('Tier 1 B2: dokumen tidak ditemukan juga punya "Coba lagi"', (tester) async {
    final service = _GagalLaluPulihService(_bertemu(), gagalPertama: false);
    await bukaDengan(tester, service);

    expect(find.text('Permintaan tidak ditemukan.'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);

    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(service.langganan, 2);
    expect(find.text('Permintaan tidak ditemukan.'), findsNothing);
    expect(find.text('Petugas menuju Anda'), findsOneWidget);
  });

  testWidgets('Tier 1 A3: tombol kembali membuka layar tiket sungguhan', (tester) async {
    await bukaDengan(tester, _FakeTibaService(_bertemu()));

    await tester.tap(find.byType(HeroBackButton));
    await tester.pumpAndSettle();

    expect(find.byType(PenumpangTiketScreen), findsOneWidget);
    expect(find.text('Butuh pendampingan'), findsOneWidget);
    expect(find.text('Segera hadir'), findsNothing);
  });

  testWidgets('Tier 2 D4: skeleton mengumumkan "Memuat" ke pembaca layar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PenumpangStatusScreen(idPermintaan: 'x', service: _LoadingService()),
      ),
    );
    await tester.pump();

    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Memuat status pendampingan'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Tier 2 D4: "kurangi gerak" membuat skeleton statis (bisa di-settle)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: PenumpangStatusScreen(idPermintaan: 'x', service: _LoadingService()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Skeleton), findsOneWidget);

    // Kilau berhenti, jadi pumpAndSettle kembali (tidak menggantung).
    await tester.pumpAndSettle();
    expect(find.byType(Skeleton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tier 2 D4: status maju dianimasikan, kartu lama tidak hilang seketika', (tester) async {
    final ctrl = StreamController<Permintaan?>();
    addTearDown(ctrl.close);
    await tester.binding.setSurfaceSize(const Size(420, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PenumpangStatusScreen(idPermintaan: 'x', service: _StreamService(ctrl.stream)),
      ),
    );
    await tester.pump();

    ctrl.add(_bertemu(status: StatusPermintaan.menunggu));
    await tester.pump();
    await tester.pump();
    const mencari = 'Kami sedang menghubungkan Anda dengan petugas layanan.';
    expect(find.text(mencari), findsOneWidget);
    expect(find.text('Rina'), findsNothing);

    ctrl.add(_bertemu(status: StatusPermintaan.ditugaskan));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    // Di tengah transisi kedua kartu sama-sama ada (fade + slide).
    expect(find.text(mencari), findsOneWidget);
    expect(find.text('Rina'), findsOneWidget);
    expect(find.byType(AnimatedSwitcher), findsWidgets);

    await tester.pumpAndSettle();
    expect(find.text(mencari), findsNothing);
    expect(find.text('Petugas sudah ditugaskan'), findsOneWidget);
  });
}
