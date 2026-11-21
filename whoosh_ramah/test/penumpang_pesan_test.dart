import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:whoosh_ramah/screens/penumpang_pesan_screen.dart';
import 'package:whoosh_ramah/theme.dart';

void main() {
  Future<void> bukaLayar(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const PenumpangPesanScreen()),
    );
    await tester.pump();
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
}
