import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:whoosh_ramah/models/permintaan.dart';
import 'package:whoosh_ramah/screens/penumpang_pesan_screen.dart';
import 'package:whoosh_ramah/screens/penumpang_status_screen.dart';
import 'package:whoosh_ramah/services/permintaan_service.dart';
import 'package:whoosh_ramah/theme.dart';

/// Service palsu perekam `buatPermintaan` (Tier 3 E3). `streamPermintaan`
/// ikut dipalsukan karena layar status yang dibuka setelah kirim ikut
/// memakai service yang sama.
class _FakeKirimService extends PermintaanService {
  _FakeKirimService({this.sudahAda = false, this.gagal = false});

  final bool sudahAda;
  final bool gagal;
  final List<String> catatanTerkirim = <String>[];
  final List<JenisBantuan> jenisTerkirim = <JenisBantuan>[];
  int dipanggil = 0;

  @override
  Future<HasilPermintaan> buatPermintaan({
    required JenisBantuan jenisBantuan,
    required String titikJemput,
    String? catatan,
  }) async {
    dipanggil++;
    if (gagal) throw Exception('jaringan putus');
    jenisTerkirim.add(jenisBantuan);
    catatanTerkirim.add(catatan ?? '');
    return HasilPermintaan(
      id: sudahAda ? 'permintaan-lama' : 'permintaan-baru',
      sudahAda: sudahAda,
    );
  }

  @override
  Stream<Permintaan?> streamPermintaan(String id) =>
      Stream<Permintaan?>.value(Permintaan(
        id: id,
        jenisBantuan: JenisBantuan.kursiRoda,
        titikJemput: 'Lobi utama',
        status: StatusPermintaan.menunggu,
        sumber: 'aplikasi',
      ));
}

void main() {
  Future<void> bukaLayar(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const PenumpangPesanScreen()),
    );
    await tester.pump();
  }

  Future<void> bukaDengan(WidgetTester tester, PermintaanService service) async {
    await tester.binding.setSurfaceSize(const Size(420, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PenumpangPesanScreen(service: service),
      ),
    );
    await tester.pump();
  }

  /// Pilih bantuan + jemput, isi catatan, lalu tekan kirim.
  Future<void> isiDanKirim(WidgetTester tester, {String catatan = ''}) async {
    await tester.tap(find.text('Kursi roda'));
    await tester.pump();
    await tester.tap(find.text('Lobi utama'));
    await tester.pumpAndSettle();
    if (catatan.isNotEmpty) {
      await tester.enterText(find.byType(TextField), catatan);
      await tester.pump();
    }
    await tester.ensureVisible(find.byKey(const Key('tombol_kirim')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tombol_kirim')));
    await tester.pump(); // frame loading
    await tester.pumpAndSettle();
  }

  /// Habiskan timer SnackBar (4 dtk) agar tidak ada timer menggantung.
  Future<void> habiskanSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  // onTap null == tombol kirim sedang nonaktif (belum memilih jenis & jemput).
  VoidCallback? kirimOnTap(WidgetTester tester) =>
      tester.widget<GestureDetector>(find.byKey(const Key('tombol_kirim'))).onTap;

  testWidgets('Langkah 4: semua pilihan dirender & tombol kirim nonaktif awalnya', (tester) async {
    await bukaLayar(tester);

    // Judul bagian.
    expect(find.text('Bantuan apa yang Anda perlukan?'), findsOneWidget);
    expect(find.text('Di mana kami menjemput Anda?'), findsOneWidget);
    expect(find.text('Catatan untuk petugas (opsional)'), findsOneWidget);

    // Enam jenis bantuan.
    for (final label in const [
      'Kursi roda',
      'Tunanetra',
      'Tuli',
      'Lansia',
      'Ibu hamil',
      'Porter barang',
    ]) {
      expect(find.text(label), findsOneWidget, reason: 'jenis bantuan "$label" harus ada');
    }

    // Tiga titik jemput.
    for (final label in const ['Lobi utama', 'Area parkir', 'Kereta pengumpan']) {
      expect(find.text(label), findsOneWidget, reason: 'titik jemput "$label" harus ada');
    }

    // Belum ada yang terpilih -> tidak ada centang, tombol kirim nonaktif.
    expect(find.byIcon(Icons.check), findsNothing);
    expect(kirimOnTap(tester), isNull);
  });

  testWidgets('Langkah 4: memilih bantuan & jemput menampilkan centang dan mengaktifkan tombol', (tester) async {
    await bukaLayar(tester);

    await tester.tap(find.text('Kursi roda'));
    await tester.pump();
    await tester.tap(find.text('Lobi utama'));
    await tester.pumpAndSettle();

    // Dua kotak terpilih -> dua badge centang (indikator non-warna).
    expect(find.byIcon(Icons.check), findsNWidgets(2));
    expect(kirimOnTap(tester), isNotNull);
  });

  testWidgets('Tier 3 E3: kirim sukses membuka layar status dengan id baru', (tester) async {
    final svc = _FakeKirimService();
    await bukaDengan(tester, svc);
    await isiDanKirim(tester, catatan: '  membawa koper besar  ');

    expect(svc.dipanggil, 1);
    expect(svc.jenisTerkirim.single, JenisBantuan.kursiRoda);
    // Catatan dirapikan (trim) sebelum dikirim.
    expect(svc.catatanTerkirim.single, 'membawa koper besar');
    expect(find.byType(PenumpangPesanScreen), findsNothing);
    final status = tester.widget<PenumpangStatusScreen>(
      find.byType(PenumpangStatusScreen),
    );
    expect(status.idPermintaan, 'permintaan-baru');
    expect(find.text('Permintaan Anda masih aktif. Kami buka statusnya.'), findsNothing);
  });

  testWidgets('Tier 3 E3: permintaan ganda -> SnackBar + status permintaan lama', (tester) async {
    final svc = _FakeKirimService(sudahAda: true);
    await bukaDengan(tester, svc);
    await isiDanKirim(tester);

    expect(svc.dipanggil, 1);
    expect(
      find.text('Permintaan Anda masih aktif. Kami buka statusnya.'),
      findsOneWidget,
    );
    final status = tester.widget<PenumpangStatusScreen>(
      find.byType(PenumpangStatusScreen),
    );
    expect(status.idPermintaan, 'permintaan-lama');
    await habiskanSnackBar(tester);
  });

  testWidgets('Tier 3 E3: kirim gagal -> SnackBar, tetap di layar pesan, tombol hidup lagi', (tester) async {
    final svc = _FakeKirimService(gagal: true);
    await bukaDengan(tester, svc);
    await isiDanKirim(tester);

    expect(find.text('Gagal mengirim permintaan. Silakan coba lagi.'), findsOneWidget);
    expect(find.byType(PenumpangStatusScreen), findsNothing);
    expect(find.byType(PenumpangPesanScreen), findsOneWidget);
    expect(kirimOnTap(tester), isNotNull);
    await habiskanSnackBar(tester);
  });
}
