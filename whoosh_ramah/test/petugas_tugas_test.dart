import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:whoosh_ramah/models/foto_permintaan.dart';
import 'package:whoosh_ramah/models/permintaan.dart';
import 'package:whoosh_ramah/screens/petugas_detail_screen.dart';
import 'package:whoosh_ramah/screens/petugas_tugas_screen.dart';
import 'package:whoosh_ramah/services/permintaan_service.dart';
import 'package:whoosh_ramah/theme.dart';
import 'package:whoosh_ramah/widgets/foto_cuplikan.dart';
import 'package:whoosh_ramah/widgets/pill_button.dart';
import 'package:whoosh_ramah/widgets/secondary_pill_button.dart';
import 'package:whoosh_ramah/widgets/skeleton.dart';

class _FakeListService extends PermintaanService {
  _FakeListService(this._list);
  final List<Permintaan> _list;

  @override
  Stream<List<Permintaan>> streamSemua() => Stream<List<Permintaan>>.value(_list);
}

class _StreamListService extends PermintaanService {
  _StreamListService(this._stream);
  final Stream<List<Permintaan>> _stream;

  @override
  Stream<List<Permintaan>> streamSemua() => _stream;
}

/// Langganan pertama gagal, berikutnya berhasil — menguji tombol "Coba lagi".
class _GagalLaluPulihService extends PermintaanService {
  _GagalLaluPulihService(this._list);

  final List<Permintaan> _list;
  int langganan = 0;

  @override
  Stream<List<Permintaan>> streamSemua() {
    langganan++;
    if (langganan == 1) return Stream<List<Permintaan>>.error(Exception('offline'));
    return Stream<List<Permintaan>>.value(_list);
  }
}

/// Daftar tetap + perekam `majukanStatus` untuk tombol "Terima & datangi".
/// `streamPermintaan` ikut dipalsukan karena layar detail membukanya lagi.
/// [tunda] menahan tulisan agar keadaan "sedang menulis" bisa diamati.
class _FakeTerimaService extends PermintaanService {
  _FakeTerimaService(this._list, {this.gagal = false, this.tunda});

  final List<Permintaan> _list;
  final bool gagal;
  final Completer<void>? tunda;

  final List<String> dimajukan = <String>[];

  @override
  Stream<List<Permintaan>> streamSemua() => Stream<List<Permintaan>>.value(_list);

  @override
  Stream<Permintaan?> streamPermintaan(String id) {
    final cocok = _list.where((e) => e.id == id);
    return Stream<Permintaan?>.value(cocok.isEmpty ? null : cocok.first);
  }

  @override
  Future<void> majukanStatus(String id) async {
    dimajukan.add(id);
    final penunda = tunda;
    if (penunda != null) await penunda.future;
    if (gagal) throw Exception('jaringan gagal');
  }
}

/// Daftar tetap + cuplikan foto per id tugas (thumbnail kartu Kamera AI).
class _FakeFotoListService extends PermintaanService {
  _FakeFotoListService(this._list, this._foto);

  final List<Permintaan> _list;
  final Map<String, FotoPermintaan?> _foto;

  @override
  Stream<List<Permintaan>> streamSemua() => Stream<List<Permintaan>>.value(_list);

  @override
  Stream<FotoPermintaan?> streamFoto(String idTugas) =>
      Stream<FotoPermintaan?>.value(_foto[idTugas]);
}

/// PNG 1x1 yang sah untuk Image.memory; tes hanya memastikan widget &
/// Semantics-nya ada (dekode piksel berjalan di waktu async sungguhan).
final Uint8List _pngKecil = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

Permintaan _kamera(
  String id, {
  StatusPermintaan status = StatusPermintaan.menunggu,
  bool adaFoto = false,
  bool ditolak = false,
}) =>
    Permintaan(
      id: id,
      jenisBantuan: JenisBantuan.kursiRoda,
      titikJemput: 'Stasiun Halim - Pintu Masuk Utara',
      status: status,
      sumber: 'kamera_ai',
      keyakinan: 0.87,
      adaFoto: adaFoto,
      ditolakPada: ditolak ? DateTime.now() : null,
      dibuatPada: DateTime.now(),
      diperbaruiPada: DateTime.now(),
    );

Permintaan _aplikasi(
  String id, {
  StatusPermintaan status = StatusPermintaan.menunggu,
  String nama = 'Siti Aminah',
}) =>
    Permintaan(
      id: id,
      jenisBantuan: JenisBantuan.kursiRoda,
      titikJemput: 'Lobi utama',
      status: status,
      sumber: 'aplikasi',
      namaPenumpang: nama,
      kereta: 'G1123',
      jamBerangkat: '08.10',
      gerbong: '5',
      kursi: '7A',
      stasiunTujuan: 'Tegalluar',
      dibuatPada: DateTime.now(),
      diperbaruiPada: DateTime.now(),
    );

void main() {
  Future<void> buka(WidgetTester tester, PermintaanService service) async {
    await tester.binding.setSurfaceSize(const Size(700, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: PetugasTugasScreen(service: service)),
    );
    // Dua pump: cukup untuk stream statis, tanpa menggantung bila stream
    // belum mengirim data (spinner animasi terus).
    await tester.pump();
    await tester.pump();
  }

  /// Habiskan timer SnackBar (4 dtk) agar tidak ada timer menggantung di akhir tes.
  Future<void> habiskanSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets('Langkah 6: ringkasan angka + kartu kamera & aplikasi', (tester) async {
    final list = <Permintaan>[
      _kamera('cam1'),
      _aplikasi('app1', status: StatusPermintaan.ditugaskan),
      _aplikasi('app2', nama: 'Budi Hartono'),
    ];
    await buka(tester, _FakeListService(list));

    // Ringkasan: Baru 2, Berjalan 1, Selesai 0, Ditolak 0. "Baru" juga muncul
    // sebagai badge status pada kartu kamera yang masih menunggu.
    expect(find.text('Baru'), findsNWidgets(2));
    expect(find.text('Berjalan'), findsOneWidget);
    expect(find.text('Selesai hari ini'), findsOneWidget);
    expect(find.text('Ditolak'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));

    // Badge sumber selalu bertext.
    expect(find.text('Kamera AI'), findsOneWidget);
    expect(find.text('Aplikasi'), findsNWidgets(2));

    // Kartu kamera.
    expect(find.text('Penumpang belum diketahui'), findsOneWidget);
    expect(find.text('Pintu Masuk Utara · keyakinan 87%'), findsOneWidget);

    // Kartu aplikasi.
    expect(find.text('Siti Aminah · Kursi roda'), findsOneWidget);
    // Dua kartu aplikasi memakai detail perjalanan yang sama.
    expect(find.text('Lobi utama · G1123 08.10 · Gerbong 5, Kursi 7A'), findsNWidgets(2));
    expect(find.text('Budi Hartono · Kursi roda'), findsOneWidget);

    // Status badge + waktu relatif.
    expect(find.text('Ditugaskan ke Anda'), findsOneWidget);
    expect(find.text('Menunggu petugas'), findsOneWidget);
    expect(find.text('baru saja'), findsWidgets);
  });

  testWidgets('Langkah 6: tanpa tugas menampilkan pesan kosong', (tester) async {
    await buka(tester, _FakeListService(const <Permintaan>[]));

    expect(find.text('TUGAS MASUK'), findsOneWidget);
    expect(
      find.text('Belum ada tugas aktif. Tugas baru akan muncul di sini secara otomatis.'),
      findsOneWidget,
    );
  });

  testWidgets('Langkah 6: dokumen baru memicu SnackBar tugas baru', (tester) async {
    final ctrl = StreamController<List<Permintaan>>();
    addTearDown(ctrl.close);
    await buka(tester, _StreamListService(ctrl.stream));

    ctrl.add(<Permintaan>[_aplikasi('app1')]);
    await tester.pumpAndSettle();
    expect(find.text('Tugas baru dari Aplikasi'), findsNothing);

    ctrl.add(<Permintaan>[_aplikasi('app1'), _kamera('cam1')]);
    await tester.pumpAndSettle();
    expect(find.text('Tugas baru dari Kamera AI'), findsOneWidget);

    // Habiskan timer sorotan (3 dtk) + SnackBar agar tak ada timer menggantung.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('Tier 1 B2: gagal memuat -> "Coba lagi" berlangganan ulang lalu pulih', (tester) async {
    final service = _GagalLaluPulihService(<Permintaan>[_aplikasi('app1')]);
    await buka(tester, service);

    expect(find.text('Gagal memuat tugas. Periksa koneksi Anda.'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(service.langganan, 1);

    await tester.tap(find.text('Coba lagi'));
    await tester.pump();
    await tester.pump();

    expect(service.langganan, 2);
    expect(find.text('Gagal memuat tugas. Periksa koneksi Anda.'), findsNothing);
    expect(find.text('Siti Aminah · Kursi roda'), findsOneWidget);
  });

  testWidgets('Tier 1 A4: nav "Riwayat" tanpa tugas selesai -> SnackBar, bukan tombol mati', (tester) async {
    await buka(tester, _FakeListService(<Permintaan>[_aplikasi('app1')]));

    expect(find.text('SELESAI HARI INI'), findsNothing);
    await tester.tap(find.text('Riwayat'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Belum ada tugas selesai hari ini.'), findsOneWidget);
  });

  testWidgets('Tier 1 A4: nav "Riwayat" menggulir ke bagian tugas selesai', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final list = <Permintaan>[
      for (var i = 0; i < 6; i++) _aplikasi('app$i'),
      _aplikasi('done1', status: StatusPermintaan.selesai),
    ];
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: PetugasTugasScreen(service: _FakeListService(list))),
    );
    await tester.pump();
    await tester.pump();

    final judul = find.text('SELESAI HARI INI');
    expect(judul, findsOneWidget);
    // Awalnya di bawah lipatan layar.
    expect(tester.getTopLeft(judul).dy, greaterThan(800));

    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(judul).dy, lessThan(800));
  });

  testWidgets('Tier 1 A4: nav "Profil" memberi umpan balik "segera hadir"', (tester) async {
    await buka(tester, _FakeListService(<Permintaan>[_aplikasi('app1')]));

    await tester.tap(find.text('Profil'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Profil segera hadir.'), findsOneWidget);
  });

  testWidgets('Tier 2 D2: tombol per kartu — menunggu "Terima & datangi", berjalan "Buka tugas", selesai tanpa tombol', (tester) async {
    final list = <Permintaan>[
      _aplikasi('app1'),
      _aplikasi('app2', status: StatusPermintaan.ditugaskan, nama: 'Budi Hartono'),
      _aplikasi('done1', status: StatusPermintaan.selesai, nama: 'Rina Wati'),
    ];
    await buka(tester, _FakeListService(list));

    // Tiga kartu, dua tombol: kartu selesai tidak punya aksi lagi.
    expect(find.text('Terima & datangi'), findsOneWidget);
    expect(find.text('Buka tugas'), findsOneWidget);
    expect(find.byType(PillButton), findsOneWidget);
    expect(find.byType(SecondaryPillButton), findsOneWidget);

    // Area info kartu tetap bisa ditekan terpisah dari tombolnya.
    final handle = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel(
        'Siti Aminah · Kursi roda. Lobi utama · G1123 08.10 · Gerbong 5, Kursi 7A. Menunggu petugas. baru saja',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('Tier 2 D2: "Terima & datangi" menulis status lalu membuka detail tugas', (tester) async {
    final service = _FakeTerimaService(<Permintaan>[_aplikasi('app1')]);
    await buka(tester, service);

    await tester.tap(find.text('Terima & datangi'));
    await tester.pumpAndSettle();

    expect(service.dimajukan, <String>['app1']);
    expect(find.byType(PetugasDetailScreen), findsOneWidget);
    await habiskanSnackBar(tester);
  });

  testWidgets('Tier 2 D2: gagal menerima -> SnackBar, tugas tetap di daftar, tombol pulih', (tester) async {
    final service = _FakeTerimaService(<Permintaan>[_aplikasi('app1')], gagal: true);
    await buka(tester, service);

    await tester.tap(find.text('Terima & datangi'));
    await tester.pumpAndSettle();

    expect(service.dimajukan, <String>['app1']);
    expect(find.text('Gagal menerima tugas. Silakan coba lagi.'), findsOneWidget);
    expect(find.byType(PetugasDetailScreen), findsNothing);
    expect(find.text('Siti Aminah · Kursi roda'), findsOneWidget);
    expect(tester.widget<PillButton>(find.byType(PillButton)).onPressed, isNotNull);
    await habiskanSnackBar(tester);
  });

  testWidgets('Tier 2 D2: saat menulis, tombol nonaktif + spinner dan ketukan kedua diabaikan', (tester) async {
    final tunda = Completer<void>();
    final service = _FakeTerimaService(<Permintaan>[_aplikasi('app1')], tunda: tunda);
    await buka(tester, service);

    await tester.tap(find.text('Terima & datangi'));
    await tester.pump();

    expect(find.text('Terima & datangi'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<PillButton>(find.byType(PillButton)).onPressed, isNull);

    // Ketukan kedua tidak menulis ulang status.
    await tester.tap(find.byType(PillButton), warnIfMissed: false);
    await tester.pump();
    expect(service.dimajukan, <String>['app1']);

    tunda.complete();
    await tester.pumpAndSettle();
    expect(find.byType(PetugasDetailScreen), findsOneWidget);
    await habiskanSnackBar(tester);
  });

  testWidgets('Tier 2 D2: "Buka tugas" pada kartu berjalan membuka detail tanpa menulis status', (tester) async {
    final service = _FakeTerimaService(
      <Permintaan>[_aplikasi('app1', status: StatusPermintaan.bertemu)],
    );
    await buka(tester, service);

    expect(find.text('Terima & datangi'), findsNothing);
    await tester.tap(find.text('Buka tugas'));
    await tester.pumpAndSettle();

    expect(service.dimajukan, isEmpty);
    expect(find.byType(PetugasDetailScreen), findsOneWidget);
    await habiskanSnackBar(tester);
  });

  testWidgets('Tier 2 D4: daftar tugas memakai skeleton, bukan spinner polos', (tester) async {
    final ctrl = StreamController<List<Permintaan>>();
    addTearDown(ctrl.close);
    await buka(tester, _StreamListService(ctrl.stream));

    expect(find.byType(Skeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Terima & datangi'), findsNothing);

    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Memuat daftar tugas'), findsOneWidget);
    handle.dispose();

    ctrl.add(<Permintaan>[_aplikasi('app1')]);
    await tester.pump();
    await tester.pump();

    expect(find.byType(Skeleton), findsNothing);
    expect(find.text('Terima & datangi'), findsOneWidget);
  });

  testWidgets('Tier 2 D4: animasi dimatikan -> skeleton statis, pumpAndSettle selesai', (tester) async {
    final ctrl = StreamController<List<Permintaan>>();
    addTearDown(ctrl.close);
    await tester.binding.setSurfaceSize(const Size(700, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: PetugasTugasScreen(service: _StreamListService(ctrl.stream)),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(Skeleton), findsOneWidget);
    // Kilau berhenti, jadi tidak ada frame yang dijadwalkan terus-menerus.
    await tester.pumpAndSettle();
    expect(find.byType(Skeleton), findsOneWidget);
  });

  testWidgets('O1: thumbnail cuplikan hanya pada kartu Kamera AI dengan adaFoto', (tester) async {
    final service = _FakeFotoListService(
      <Permintaan>[
        _kamera('cam1', adaFoto: true),
        _kamera('cam2'), // tanpa foto: tanpa thumbnail
        _aplikasi('app1'), // tugas aplikasi: tidak pernah punya cuplikan
      ],
      <String, FotoPermintaan?>{
        'cam1': FotoPermintaan(
          id: 'cam1',
          bytes: _pngKecil,
          kedaluwarsaPada: DateTime.now().add(const Duration(minutes: 10)),
        ),
      },
    );
    await buka(tester, service);

    expect(find.byType(FotoCuplikan), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    final handle = tester.ensureSemantics();
    // Label cuplikan menyebut lokasi; label gabungan kartu tetap utuh
    // (thumbnail berada di luar ExcludeSemantics area tekan kartu).
    expect(
      find.bySemanticsLabel('Cuplikan kamera AI: pengguna kursi roda di Pintu Masuk Utara'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Penumpang belum diketahui. Pintu Masuk Utara · keyakinan 87%. Baru. baru saja',
      ),
      // cam1 & cam2 sama-sama menunggu dengan lokasi/keyakinan identik.
      findsNWidgets(2),
    );
    handle.dispose();
  });

  testWidgets('O1: dokumen foto hilang -> thumbnail "Cuplikan sudah kedaluwarsa"', (tester) async {
    final service = _FakeFotoListService(
      <Permintaan>[_kamera('cam1', adaFoto: true)],
      <String, FotoPermintaan?>{'cam1': null}, // sudah dihapus detektor (TTL)
    );
    await buka(tester, service);

    expect(find.byType(Image), findsNothing);
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Cuplikan sudah kedaluwarsa'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('A3: tugas ditolak keluar dari daftar aktif, dihitung di "Ditolak"', (tester) async {
    await buka(
      tester,
      _FakeListService(<Permintaan>[_kamera('cam1', ditolak: true)]),
    );

    // Tidak ada kartu aktif; ringkasan Baru/Berjalan/Selesai 0, Ditolak 1.
    expect(find.text('Penumpang belum diketahui'), findsNothing);
    expect(
      find.text('Belum ada tugas aktif. Tugas baru akan muncul di sini secara otomatis.'),
      findsOneWidget,
    );
    expect(find.text('Ditolak'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(3));
  });
}
