import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:whoosh_ramah/models/foto_permintaan.dart';
import 'package:whoosh_ramah/models/permintaan.dart';
import 'package:whoosh_ramah/screens/petugas_detail_screen.dart';
import 'package:whoosh_ramah/services/permintaan_service.dart';
import 'package:whoosh_ramah/theme.dart';
import 'package:whoosh_ramah/widgets/secondary_pill_button.dart';

/// Service palsu: satu dokumen tetap + cuplikan foto + perekam
/// `majukanStatus`/`tolakTugas`.
class _FakeDetailService extends PermintaanService {
  _FakeDetailService({
    this.doc,
    this.gagal = false,
    this.foto,
    this.gagalTolak = false,
  });

  final Permintaan? doc;
  final bool gagal;
  final FotoPermintaan? foto;
  final bool gagalTolak;

  final List<String> dimajukan = <String>[];
  final List<String> ditolak = <String>[];
  String? alasanTerakhir;

  @override
  Stream<Permintaan?> streamPermintaan(String id) => Stream<Permintaan?>.value(doc);

  @override
  Stream<FotoPermintaan?> streamFoto(String idTugas) =>
      Stream<FotoPermintaan?>.value(foto);

  @override
  Future<void> majukanStatus(String id) async {
    dimajukan.add(id);
    if (gagal) throw Exception('jaringan gagal');
  }

  @override
  Future<void> tolakTugas(String id, {String? alasan}) async {
    ditolak.add(id);
    alasanTerakhir = alasan;
    if (gagalTolak) throw Exception('jaringan gagal');
  }
}

/// Langganan pertama gagal (atau kosong), berikutnya berhasil — menguji
/// tombol "Coba lagi" pada state error maupun "tidak ditemukan".
class _GagalLaluPulihService extends PermintaanService {
  _GagalLaluPulihService(this.doc, {this.gagalPertama = true});

  final Permintaan? doc;
  final bool gagalPertama;
  int langganan = 0;

  @override
  Stream<Permintaan?> streamPermintaan(String id) {
    langganan++;
    if (langganan > 1) return Stream<Permintaan?>.value(doc);
    if (gagalPertama) return Stream<Permintaan?>.error(Exception('offline'));
    return Stream<Permintaan?>.value(null);
  }
}

Permintaan _aplikasi({
  String nama = 'Siti Aminah',
  StatusPermintaan status = StatusPermintaan.diKursi,
  String? catatan,
  DateTime? tibaPada,
}) =>
    Permintaan(
      id: 'app1',
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
      catatan: catatan,
      tibaPada: tibaPada,
      dibuatPada: DateTime.now(),
      diperbaruiPada: DateTime.now(),
    );

Permintaan _kamera({
  StatusPermintaan status = StatusPermintaan.menunggu,
  bool adaFoto = false,
  bool ditolak = false,
}) =>
    Permintaan(
      id: 'cam1',
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

/// PNG 1x1 yang sah untuk Image.memory; tes hanya memastikan widget &
/// Semantics-nya ada (dekode piksel berjalan di waktu async sungguhan).
final Uint8List _pngKecil = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  Future<void> buka(WidgetTester tester, PermintaanService service, String id) async {
    await tester.binding.setSurfaceSize(const Size(700, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PetugasDetailScreen(idPermintaan: id, service: service),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Habiskan timer SnackBar (4 dtk) agar tidak ada timer menggantung di akhir tes.
  Future<void> habiskanSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets('Langkah 6: detail aplikasi — info, stepper, catatan, tombol tujuan', (tester) async {
    await buka(
      tester,
      _FakeDetailService(doc: _aplikasi(catatan: 'Tolong bawa kursi roda lipat')),
      'app1',
    );

    // Info penumpang.
    expect(find.text('Siti Aminah'), findsOneWidget);
    expect(find.text('Kursi roda'), findsOneWidget);
    expect(find.text('Detail tugas'), findsOneWidget);
    expect(find.text('Aplikasi'), findsOneWidget);

    // Kisi info 2 kolom.
    expect(find.text('Titik jemput'), findsOneWidget);
    expect(find.text('Lobi utama'), findsOneWidget);
    expect(find.text('Kereta'), findsOneWidget);
    expect(find.text('G1123 · 08.10'), findsOneWidget);
    expect(find.text('Kursi'), findsOneWidget);
    expect(find.text('Gerbong 5 · 7A'), findsOneWidget);
    expect(find.text('Tujuan'), findsOneWidget);

    // Catatan.
    expect(find.textContaining('Tolong bawa kursi roda lipat', findRichText: true), findsOneWidget);

    // Stepper: 5 langkah, tahap sekarang = di kursi.
    expect(find.text('STATUS PENDAMPINGAN'), findsOneWidget);
    expect(find.text('Tugas masuk'), findsOneWidget);
    expect(find.text('Tugas diterima'), findsOneWidget);
    expect(find.text('Bertemu penumpang'), findsOneWidget);
    expect(find.text('Penumpang di kursi 7A · sekarang'), findsOneWidget);
    expect(find.text('Diserahkan ke petugas Tegalluar'), findsOneWidget);

    // Tombol aksi langkah terakhir memakai nama stasiun tujuan.
    expect(find.text('Serahkan ke petugas Tegalluar'), findsOneWidget);
    expect(find.byKey(const Key('tombol_aksi')), findsOneWidget);
  });

  testWidgets('Langkah 6: status selesai — tombol berganti tanda tidak bisa ditekan', (tester) async {
    await buka(
      tester,
      _FakeDetailService(doc: _aplikasi(status: StatusPermintaan.selesai)),
      'app1',
    );

    expect(find.text('Tugas selesai · terima kasih!'), findsOneWidget);
    expect(find.byKey(const Key('tombol_aksi')), findsNothing);
  });

  testWidgets('Langkah 6: tugas kamera — penumpang belum diketahui + lokasi & keyakinan', (tester) async {
    await buka(tester, _FakeDetailService(doc: _kamera()), 'cam1');

    expect(find.text('Penumpang belum diketahui'), findsOneWidget);
    expect(find.text('Kamera AI'), findsOneWidget);
    expect(find.text('Lokasi'), findsOneWidget);
    expect(find.text('Pintu Masuk Utara'), findsOneWidget);
    expect(find.text('Keyakinan'), findsOneWidget);
    expect(find.text('87%'), findsOneWidget);

    // Langkah pertama: tombol memakai label status berikutnya.
    expect(find.text('Terima tugas'), findsOneWidget);
    expect(find.byKey(const Key('tombol_aksi')), findsOneWidget);

    // Tanpa adaFoto: tidak ada kartu cuplikan (O1).
    expect(find.text('CUPLIKAN KAMERA AI'), findsNothing);
  });

  testWidgets('Langkah 6: tekan tombol memanggil majukanStatus(id)', (tester) async {
    final service = _FakeDetailService(doc: _aplikasi(status: StatusPermintaan.menunggu));
    await buka(tester, service, 'app1');

    expect(find.text('Terima tugas'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tombol_aksi')));
    await tester.pumpAndSettle();

    expect(service.dimajukan, <String>['app1']);
  });

  testWidgets('Langkah 6: majukanStatus gagal menampilkan SnackBar', (tester) async {
    final service = _FakeDetailService(
      doc: _aplikasi(status: StatusPermintaan.menunggu),
      gagal: true,
    );
    await buka(tester, service, 'app1');

    await tester.tap(find.byKey(const Key('tombol_aksi')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Gagal memperbarui status. Silakan coba lagi.'), findsOneWidget);
  });

  testWidgets('Tier 1 A1: petugas melihat kabar penumpang sudah tiba + jamnya', (tester) async {
    await buka(
      tester,
      _FakeDetailService(
        doc: _aplikasi(
          status: StatusPermintaan.ditugaskan,
          tibaPada: DateTime(2026, 11, 22, 7, 50),
        ),
      ),
      'app1',
    );

    expect(find.text('Penumpang sudah tiba di titik jemput · 07.50'), findsOneWidget);
  });

  testWidgets('Tier 1 A1: tanpa tibaPada, kabar tiba tidak muncul', (tester) async {
    await buka(tester, _FakeDetailService(doc: _aplikasi()), 'app1');

    expect(find.textContaining('Penumpang sudah tiba di titik jemput'), findsNothing);
  });

  testWidgets('Tier 1 B2: gagal memuat -> "Coba lagi" berlangganan ulang lalu pulih', (tester) async {
    final service = _GagalLaluPulihService(_aplikasi());
    await buka(tester, service, 'app1');

    expect(find.text('Gagal memuat tugas. Periksa koneksi Anda.'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(service.langganan, 1);

    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(service.langganan, 2);
    expect(find.text('Gagal memuat tugas. Periksa koneksi Anda.'), findsNothing);
    expect(find.text('Siti Aminah'), findsOneWidget);
  });

  testWidgets('Tier 1 B2: tugas tidak ditemukan juga punya "Coba lagi"', (tester) async {
    final service = _GagalLaluPulihService(_aplikasi(), gagalPertama: false);
    await buka(tester, service, 'app1');

    expect(find.text('Tugas tidak ditemukan.'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);

    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(service.langganan, 2);
    expect(find.text('Tugas tidak ditemukan.'), findsNothing);
    expect(find.text('Siti Aminah'), findsOneWidget);
  });

  testWidgets('O1: detail kamera dengan adaFoto menampilkan cuplikan + keterangan', (tester) async {
    await buka(
      tester,
      _FakeDetailService(
        doc: _kamera(adaFoto: true),
        foto: FotoPermintaan(
          id: 'cam1',
          bytes: _pngKecil,
          kedaluwarsaPada: DateTime.now().add(const Duration(minutes: 10)),
        ),
      ),
      'cam1',
    );

    expect(find.text('CUPLIKAN KAMERA AI'), findsOneWidget);
    expect(
      find.text('Cuplikan anonim untuk verifikasi — otomatis terhapus setelah 10 menit.'),
      findsOneWidget,
    );
    expect(find.byType(Image), findsOneWidget);

    final handle = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel('Cuplikan kamera AI: pengguna kursi roda di Pintu Masuk Utara'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('O1: dokumen foto hilang -> "Cuplikan sudah kedaluwarsa"', (tester) async {
    await buka(
      tester,
      _FakeDetailService(doc: _kamera(adaFoto: true)), // foto null: sudah dihapus TTL
      'cam1',
    );

    expect(find.text('CUPLIKAN KAMERA AI'), findsOneWidget);
    expect(find.text('Cuplikan sudah kedaluwarsa'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('A3: tugas kamera menunggu punya tombol tolak', (tester) async {
    await buka(tester, _FakeDetailService(doc: _kamera()), 'cam1');
    expect(find.byKey(const Key('tombol_tolak')), findsOneWidget);
    expect(find.text('Bukan penumpang / tolak'), findsOneWidget);
  });

  testWidgets('A3: tugas aplikasi tidak pernah punya tombol tolak', (tester) async {
    await buka(tester, _FakeDetailService(doc: _aplikasi()), 'app1');
    expect(find.byKey(const Key('tombol_tolak')), findsNothing);
  });

  testWidgets('A3: tugas kamera selesai tidak bisa ditolak lagi', (tester) async {
    await buka(
      tester,
      _FakeDetailService(doc: _kamera(status: StatusPermintaan.selesai)),
      'cam1',
    );
    expect(find.byKey(const Key('tombol_tolak')), findsNothing);
  });

  testWidgets('A3: tugas sudah ditolak menampilkan pil, tanpa tombol aksi/tolak', (tester) async {
    await buka(
      tester,
      _FakeDetailService(doc: _kamera(ditolak: true)),
      'cam1',
    );
    expect(find.text('Tugas ditolak · bukan penumpang'), findsOneWidget);
    expect(find.byKey(const Key('tombol_aksi')), findsNothing);
    expect(find.byKey(const Key('tombol_tolak')), findsNothing);
  });

  testWidgets('A3: dialog konfirmasi — Batal tidak menulis apa-apa', (tester) async {
    final service = _FakeDetailService(doc: _kamera());
    await buka(tester, service, 'cam1');

    await tester.tap(find.byKey(const Key('tombol_tolak')));
    await tester.pumpAndSettle();
    expect(find.text('Tolak tugas ini?'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(service.ditolak, isEmpty);
    expect(find.text('Tolak tugas ini?'), findsNothing);
    expect(find.byKey(const Key('tombol_tolak')), findsOneWidget);
  });

  testWidgets('A3: dialog Tolak menulis alasan + SnackBar konfirmasi', (tester) async {
    final service = _FakeDetailService(doc: _kamera());
    await buka(tester, service, 'cam1');

    await tester.tap(find.byKey(const Key('tombol_tolak')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tolak'));
    await tester.pumpAndSettle();

    expect(service.ditolak, <String>['cam1']);
    expect(service.alasanTerakhir, 'Bukan pengguna kursi roda');
    expect(find.text('Tugas ditolak. Terima kasih sudah memeriksa.'), findsOneWidget);
    await habiskanSnackBar(tester);
  });

  testWidgets('A3: tolak gagal -> SnackBar, tombol pulih, tidak ada penolakan tertulis', (tester) async {
    final service = _FakeDetailService(doc: _kamera(), gagalTolak: true);
    await buka(tester, service, 'cam1');

    await tester.tap(find.byKey(const Key('tombol_tolak')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tolak'));
    await tester.pumpAndSettle();

    expect(service.ditolak, <String>['cam1']);
    expect(find.text('Gagal menolak tugas. Silakan coba lagi.'), findsOneWidget);
    expect(find.text('Bukan penumpang / tolak'), findsOneWidget);
    expect(
      tester.widget<SecondaryPillButton>(find.byKey(const Key('tombol_tolak'))).onPressed,
      isNotNull,
    );
    await habiskanSnackBar(tester);
  });
}
