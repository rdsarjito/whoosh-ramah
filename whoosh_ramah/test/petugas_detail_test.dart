import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:whoosh_ramah/models/permintaan.dart';
import 'package:whoosh_ramah/screens/petugas_detail_screen.dart';
import 'package:whoosh_ramah/services/permintaan_service.dart';
import 'package:whoosh_ramah/theme.dart';

/// Service palsu: satu dokumen tetap + perekam `majukanStatus`.
class _FakeDetailService extends PermintaanService {
  _FakeDetailService({this.doc, this.gagal = false});

  final Permintaan? doc;
  final bool gagal;

  final List<String> dimajukan = <String>[];

  @override
  Stream<Permintaan?> streamPermintaan(String id) => Stream<Permintaan?>.value(doc);

  @override
  Future<void> majukanStatus(String id) async {
    dimajukan.add(id);
    if (gagal) throw Exception('jaringan gagal');
  }
}

Permintaan _aplikasi({
  String nama = 'Siti Aminah',
  StatusPermintaan status = StatusPermintaan.diKursi,
  String? catatan,
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
      dibuatPada: DateTime.now(),
      diperbaruiPada: DateTime.now(),
    );

Permintaan _kamera({StatusPermintaan status = StatusPermintaan.menunggu}) => Permintaan(
      id: 'cam1',
      jenisBantuan: JenisBantuan.kursiRoda,
      titikJemput: 'Stasiun Halim - Pintu Masuk Utara',
      status: status,
      sumber: 'kamera_ai',
      keyakinan: 0.87,
      dibuatPada: DateTime.now(),
      diperbaruiPada: DateTime.now(),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

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
}
