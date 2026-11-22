import 'package:flutter_test/flutter_test.dart';
import 'package:whoosh_ramah/main.dart';

void main() {
  testWidgets('Langkah 3: layar pilih peran tampil sebagai layar awal', (tester) async {
    await tester.pumpWidget(const WhooshRamahApp());

    // Judul hero + tiga kartu peran (copy contoh Brightline).
    expect(find.text('Perjalanan nyaman, untuk semua.'), findsOneWidget);
    expect(find.text('Penumpang'), findsOneWidget);
    expect(find.text('Petugas'), findsOneWidget);
    expect(find.text('Keluarga'), findsOneWidget);
  });
}
