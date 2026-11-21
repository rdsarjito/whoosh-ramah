import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:whoosh_ramah/main.dart';
import 'package:whoosh_ramah/screens/penumpang_pesan_screen.dart';
import 'package:whoosh_ramah/screens/penumpang_tiket_screen.dart';
import 'package:whoosh_ramah/theme.dart';

void main() {
  Future<void> buka(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const PenumpangTiketScreen()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Layar tiket: kartu tiket, tombol, dan menu bawah tampil', (tester) async {
    // Font lokal terdaftar di tema (bukan google_fonts).
    expect(AppTheme.light.textTheme.bodyMedium?.fontFamily, 'Nunito');

    await buka(tester);

    expect(find.text('Selamat datang, Siti Aminah'), findsOneWidget);
    expect(find.text('TIKET CONTOH'), findsOneWidget);
    expect(find.text('Premium Economy'), findsOneWidget);

    // Jam & stasiun.
    expect(find.text('08.10'), findsOneWidget);
    expect(find.text('08.56'), findsOneWidget);
    expect(find.text('Halim'), findsOneWidget);
    expect(find.text('Tegalluar'), findsOneWidget);

    // Kisi info tiket.
    expect(find.text('KERETA'), findsOneWidget);
    expect(find.text('TANGGAL'), findsOneWidget);
    expect(find.text('GERBONG'), findsOneWidget);
    expect(find.text('KURSI'), findsOneWidget);
    expect(find.text('G1123'), findsOneWidget);
    expect(find.text('22 Nov'), findsOneWidget);

    // Tombol + menu bawah.
    expect(find.text('Butuh pendampingan'), findsOneWidget);
    expect(find.text('Lihat daftar tiket lain'), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Tiket'), findsOneWidget);
    expect(find.text('Bantuan'), findsOneWidget);
    expect(find.text('Akun'), findsOneWidget);
  });

  testWidgets('Layar tiket: "Butuh pendampingan" membuka layar pesan', (tester) async {
    await buka(tester);

    await tester.tap(find.text('Butuh pendampingan'));
    await tester.pumpAndSettle();

    expect(find.byType(PenumpangPesanScreen), findsOneWidget);
    expect(find.text('Pesan pendamping'), findsOneWidget);
  });

  testWidgets('Layar tiket dapat dibuka dari layar pilih peran', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const WhooshRamahApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Penumpang'));
    await tester.pumpAndSettle();

    expect(find.byType(PenumpangTiketScreen), findsOneWidget);
    expect(find.text('Butuh pendampingan'), findsOneWidget);
  });
}
