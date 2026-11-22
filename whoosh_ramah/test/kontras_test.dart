/// Regresi kontras WCAG (Tier 2 D3) — palet gaya Brightline.
///
/// Dua aturan diuji terpisah karena ambangnya berbeda:
/// - **1.4.3** teks normal >= 4.5:1 terhadap latarnya;
/// - **1.4.11** batas komponen & penanda keadaan >= 3:1 (bukan pemisah dekoratif).
///
/// Nilai dihitung dari token [AppColors] yang benar-benar dipakai layar, jadi
/// mengubah warna tema tanpa memikirkan kontras akan langsung menggagalkan tes.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:whoosh_ramah/theme.dart';
import 'package:whoosh_ramah/widgets/pill_button.dart';
import 'package:whoosh_ramah/widgets/secondary_pill_button.dart';

/// Rasio kontras WCAG 2.x: (L terang + 0.05) / (L gelap + 0.05).
double rasio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final terang = la > lb ? la : lb;
  final gelap = la > lb ? lb : la;
  return (terang + 0.05) / (gelap + 0.05);
}

void main() {
  group('WCAG 1.4.3 — teks di atas latar', () {
    test('teks utama, sekunder & muted di atas kanvas putih', () {
      for (final latar in <Color>[Colors.white, AppColors.background]) {
        expect(rasio(AppColors.textPrimary, latar), greaterThanOrEqualTo(4.5));
        expect(rasio(AppColors.textSecondary, latar), greaterThanOrEqualTo(4.5));
        expect(rasio(AppColors.textMuted, latar), greaterThanOrEqualTo(4.5));
      }
    });

    test('teks putih di atas tombol merah merek / tinta', () {
      for (final bg in <Color>[AppColors.redPrimary, AppColors.textPrimary]) {
        expect(rasio(Colors.white, bg), greaterThanOrEqualTo(4.5));
      }
    });

    test('teks putih tetap terbaca saat tombol nonaktif (bukan alpha 50%)', () {
      // Inilah alasan `redam()` ada: merah 50% di atas putih hanya 2.33:1.
      final pudar = Color.lerp(AppColors.redPrimary, Colors.white, 0.5)!;
      expect(rasio(Colors.white, pudar), lessThan(4.5));

      for (final bg in <Color>[AppColors.redPrimary, AppColors.textPrimary]) {
        expect(
          rasio(Colors.white, AppColors.redam(bg)),
          greaterThanOrEqualTo(4.5),
          reason: 'tombol nonaktif $bg harus tetap >= 4.5:1',
        );
      }
      expect(AppColors.redDisabled, AppColors.redam(AppColors.redPrimary));
    });

    test('badge & eyebrow merah: redText di atas putih dan redSoft', () {
      expect(rasio(AppColors.redText, Colors.white), greaterThanOrEqualTo(4.5));
      expect(rasio(AppColors.redText, AppColors.redSoft), greaterThanOrEqualTo(4.5));
      // redText selalu lebih kontras daripada merah merek terang untuk teks.
      expect(
        rasio(AppColors.redText, Colors.white),
        greaterThan(rasio(AppColors.redPrimary, Colors.white)),
      );
    });

    test('teks di atas permukaan blok (kotak info, catatan, chip nonaktif)', () {
      expect(rasio(AppColors.textPrimary, AppColors.block), greaterThanOrEqualTo(4.5));
      expect(rasio(AppColors.textSecondary, AppColors.block), greaterThanOrEqualTo(4.5));
      // Catatan "Gratis untuk lansia, difabel & ibu hamil" kini redText di putih.
      expect(rasio(AppColors.redText, Colors.white), greaterThanOrEqualTo(4.5));
    });
  });

  group('WCAG 1.4.11 — batas komponen & penanda keadaan', () {
    test('garis tombol sekunder dan kotak pilihan >= 3:1 di atas putih & blok', () {
      expect(rasio(AppColors.outlineControl, Colors.white), greaterThanOrEqualTo(3.0));
      expect(rasio(AppColors.outlineControl, AppColors.background), greaterThanOrEqualTo(3.0));
      expect(rasio(AppColors.outlineControl, AppColors.block), greaterThanOrEqualTo(3.0));
      // Garis dekoratif kartu memang di bawah 3:1 — jangan dipakai untuk
      // menandai batas komponen interaktif.
      expect(rasio(AppColors.outline, Colors.white), lessThan(3.0));
    });

    test('penanda merah (timeline, bar progres, stepper) >= 3:1 di atas putih', () {
      expect(rasio(AppColors.redPrimary, Colors.white), greaterThanOrEqualTo(3.0));
      expect(rasio(AppColors.redPrimary, AppColors.block), greaterThanOrEqualTo(3.0));
    });

    test('lingkaran timeline belum aktif memakai nada yang sama', () {
      expect(AppColors.connector, AppColors.outlineControl);
      expect(rasio(AppColors.connector, Colors.white), greaterThanOrEqualTo(3.0));
    });
  });

  group('Token kontras benar-benar terpakai saat render', () {
    testWidgets('PillButton nonaktif meredam latar, bukan memudarkan teks', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PillButton(
              onPressed: null,
              backgroundColor: AppColors.textPrimary,
              child: const Text('Nonaktif'),
            ),
          ),
        ),
      );

      final kotak = tester.widget<Container>(
        find.descendant(of: find.byType(PillButton), matching: find.byType(Container)),
      );
      final warna = (kotak.decoration! as BoxDecoration).color!;
      expect(warna, AppColors.redam(AppColors.textPrimary));
      expect(rasio(Colors.white, warna), greaterThanOrEqualTo(4.5));
    });

    testWidgets('SecondaryPillButton memakai garis outlineControl', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SecondaryPillButton(onPressed: () {}, label: 'QR tiket'),
          ),
        ),
      );

      final tombol = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      final sisi = tombol.style!.side!.resolve(<WidgetState>{})!;
      expect(sisi.color, AppColors.outlineControl);
      expect(sisi.width, 2);
      expect(rasio(sisi.color, Colors.white), greaterThanOrEqualTo(3.0));
    });
  });
}