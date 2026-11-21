import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whoosh_ramah/main.dart';

void main() {
  setUpAll(() {
    // Cegah google_fonts mengambil font lewat jaringan saat test (hindari
    // timer menggantung); teks tetap dirender dengan font fallback.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Langkah 3: layar pilih peran tampil sebagai layar awal', (tester) async {
    await tester.pumpWidget(const WhooshRamahApp());

    // Judul hero + tiga kartu peran.
    expect(find.text('Perjalanan nyaman untuk semua penumpang'), findsOneWidget);
    expect(find.text('Penumpang'), findsOneWidget);
    expect(find.text('Petugas stasiun'), findsOneWidget);
    expect(find.text('Keluarga'), findsOneWidget);
  });
}
