// Tier 1 A4 — menu bawah tidak boleh punya kontrol mati.
//
// Item aktif = halaman saat ini (tidak melakukan apa-apa), item dengan aksi
// menjalankan aksinya, dan item tanpa tujuan memberi umpan balik "segera hadir"
// plus label TalkBack yang jujur (bukan terdengar seperti tombol berfungsi).

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:whoosh_ramah/theme.dart';
import 'package:whoosh_ramah/widgets/bottom_nav.dart';

void main() {
  Future<void> pumpNav(WidgetTester tester, List<BottomNavItem> items) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: const SizedBox.shrink(),
          bottomNavigationBar: BottomNav(
            items: items,
            activeColor: AppColors.redText,
            activeBackground: AppColors.redSoft,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Habiskan timer SnackBar (4 dtk) agar tidak ada timer menggantung.
  Future<void> habiskanSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets('item dengan onTap menjalankan aksinya', (tester) async {
    var ditekan = 0;
    await pumpNav(tester, [
      const BottomNavItem(label: 'Beranda', icon: Icons.home_outlined, active: true),
      BottomNavItem(label: 'Bantuan', icon: Icons.favorite_outline, onTap: () => ditekan++),
    ]);

    await tester.tap(find.text('Bantuan'));
    await tester.pumpAndSettle();

    expect(ditekan, 1);
    expect(find.text('Bantuan segera hadir.'), findsNothing);
  });

  testWidgets('item tanpa tujuan memberi SnackBar "segera hadir", bukan diam', (tester) async {
    await pumpNav(tester, [
      const BottomNavItem(label: 'Beranda', icon: Icons.home_outlined, active: true),
      const BottomNavItem(label: 'Akun', icon: Icons.person_outline),
    ]);

    await tester.tap(find.text('Akun'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Akun segera hadir.'), findsOneWidget);
    await habiskanSnackBar(tester);
  });

  testWidgets('item aktif tidak memicu aksi apa pun (halaman saat ini)', (tester) async {
    var ditekan = 0;
    await pumpNav(tester, [
      BottomNavItem(
        label: 'Beranda',
        icon: Icons.home_outlined,
        active: true,
        onTap: () => ditekan++,
      ),
      const BottomNavItem(label: 'Akun', icon: Icons.person_outline),
    ]);

    await tester.tap(find.text('Beranda'), warnIfMissed: false);
    await tester.pump();
    await tester.pump();

    expect(ditekan, 0);
    expect(find.text('Beranda segera hadir.'), findsNothing);
  });

  testWidgets('label TalkBack jujur: halaman saat ini / aksi / segera hadir', (tester) async {
    await pumpNav(tester, [
      const BottomNavItem(label: 'Beranda', icon: Icons.home_outlined, active: true),
      BottomNavItem(label: 'Bantuan', icon: Icons.favorite_outline, onTap: () {}),
      const BottomNavItem(label: 'Akun', icon: Icons.person_outline),
    ]);

    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.text('Beranda')),
      isSemantics(label: 'Beranda, halaman saat ini', isSelected: true, isButton: false),
    );
    expect(
      tester.getSemantics(find.text('Bantuan')),
      isSemantics(label: 'Bantuan', isButton: true),
    );
    expect(
      tester.getSemantics(find.text('Akun')),
      isSemantics(label: 'Akun, segera hadir', isButton: true),
    );
    handle.dispose();
  });

  testWidgets('tiap item punya area sentuh >= 48dp', (tester) async {
    await pumpNav(tester, [
      const BottomNavItem(label: 'Beranda', icon: Icons.home_outlined, active: true),
      const BottomNavItem(label: 'Tiket', icon: Icons.confirmation_number_outlined),
      const BottomNavItem(label: 'Bantuan', icon: Icons.favorite_outline),
      const BottomNavItem(label: 'Akun', icon: Icons.person_outline),
    ]);

    final jumlah = find.byType(InkResponse).evaluate().length;
    expect(jumlah, 4);
    for (var i = 0; i < jumlah; i++) {
      final ukuran = tester.getSize(find.byType(InkResponse).at(i));
      expect(ukuran.height, greaterThanOrEqualTo(48));
      expect(ukuran.width, greaterThanOrEqualTo(48));
    }
  });
}