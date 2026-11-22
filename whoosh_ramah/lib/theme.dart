import 'package:material_ui/material_ui.dart';

/// Palet gaya Brightline (paket `whoosh-ramah-gaya-baru`): kanvas putih, satu
/// aksen merah merek, tinta hampir hitam, dan abu blok untuk kartu sekunder.
///
/// Tidak ada lagi hero berwarna per peran: pembeda peran adalah eyebrow +
/// ikon, bukan warna latar. Status tidak pernah hanya warna (selalu ada teks
/// dan/atau ikon centang).
class AppColors {
  AppColors._();

  // Dasar
  static const Color background = Color(0xFFFFFFFF); // Kanvas semua layar
  static const Color textPrimary = Color(0xFF111318); // Tinta utama (18.7:1)
  static const Color textSecondary = Color(0xFF4B5260); // Keterangan (7.9:1)

  /// Abu netral untuk footer/eyebrow sekunder (4.8:1 di atas putih — cukup
  /// untuk teks 13px sekaligus batas komponen WCAG 1.4.11).
  static const Color textMuted = Color(0xFF6B7280);

  // Merek (merah)
  static const Color redPrimary = Color(0xFFE11D2E); // Tombol utama, kartu peran
  static const Color redText = Color(0xFFB00E28); // Teks merah di atas putih (7.1:1)

  /// Merah sangat muda untuk latar kotak terpilih / chip aktif. Dipakai bersama
  /// garis merah 2px + badge centang, jadi terpilih tidak hanya lewat warna.
  static const Color redSoft = Color(0xFFFDEDEE);

  /// Abu blok: kartu sekunder, kotak info, latar ikon, kerangka skeleton.
  static const Color block = Color(0xFFF2F3F5);

  /// Garis pemisah dekoratif (kartu, header, lembar). Bukan batas komponen.
  static const Color outline = Color(0xFFE5E7EB);

  /// Garis komponen interaktif (tombol sekunder, kotak pilihan, lingkaran
  /// timeline yang belum aktif). WCAG 1.4.11 meminta >= 3:1 terhadap latar;
  /// #6B7280 = 4.8:1 di atas putih maupun di atas [block] terang.
  /// [outline] tetap untuk pemisah dekoratif yang tidak menandai batas komponen.
  static const Color outlineControl = Color(0xFF6B7280);

  /// Garis penghubung timeline yang belum aktif — sama dengan batas komponen.
  static const Color connector = outlineControl;

  /// Latar tombol utama saat nonaktif: nada merah diredam ke abu gelap supaya
  /// teks putih tetap >= 4.5:1 (WCAG 1.4.3). Hasil #8E394A = 7.4:1.
  static final Color redDisabled = redam(redPrimary);

  /// Warna tombol nonaktif: nada [bg] diredam ke arah abu gelap (#4A5060)
  /// sehingga tetap satu keluarga warna dengan tombol aktif, tetapi teks putih
  /// di atasnya >= 4.5:1. Dipakai untuk merah maupun tinta.
  static Color redam(Color bg) => Color.lerp(bg, const Color(0xFF4A5060), 0.55)!;
}

/// Radius sudut gaya Brightline: kartu 22, kotak dalam 16, ubin logo 12.
class AppRadius {
  AppRadius._();

  static const double card = 22; // Kartu utama & kartu peran
  static const double cardLarge = 24; // Lembar / kartu besar
  static const double inner = 16; // Kotak info di dalam kartu
  static const double choice = 18; // Kotak pilihan (bantuan / titik jemput)
  static const double tile = 12; // Ubin logo & ikon persegi membulat
  static const double pill = 999; // Tombol & badge berbentuk pil
}

/// Bayangan sangat lembut (gaya Brightline: 0 10px 26px rgba tinta 6%).
class AppShadows {
  AppShadows._();

  /// Kartu putih utama / lembar melayang.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0F111318), blurRadius: 26, offset: Offset(0, 10)),
  ];

  /// Kartu dalam / sekunder: lebih tipis lagi.
  static const List<BoxShadow> cardSoft = [
    BoxShadow(color: Color(0x0A111318), blurRadius: 18, offset: Offset(0, 6)),
  ];
}

/// Tema aplikasi: putih + merah merek, font Plus Jakarta Sans (dibundel di
/// assets/fonts), serta gaya tombol & kartu gaya Brightline.
class AppTheme {
  AppTheme._();

  /// Family font lokal (lihat bagian `fonts` di pubspec.yaml).
  static const String fontFamily = 'Plus Jakarta Sans';

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.redPrimary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.redPrimary,
      secondary: AppColors.textPrimary,
      surface: Colors.white,
      error: AppColors.redPrimary,
    );

    final textTheme = _textTheme();

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.redPrimary,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _primaryButton()),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _secondaryButton()),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  /// Plus Jakarta Sans sesuai contoh Brightline: judul 42/800/-1.4, eyebrow
  /// 12/800/+1.4, isi 17/500/1.5, judul kartu 24/800/-0.5, footer 13/600.
  static TextTheme _textTheme() {
    const primary = AppColors.textPrimary;
    const secondary = AppColors.textSecondary;
    return const TextTheme(
      displayLarge: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: primary, height: 1.04, letterSpacing: -1.4),
      displayMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: primary, height: 1.08, letterSpacing: -1.0),
      displaySmall: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: primary, height: 1.15, letterSpacing: -0.6),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: primary, letterSpacing: -0.5),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: primary, letterSpacing: -0.3),
      titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: primary),
      titleSmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: primary),
      bodyLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: primary, height: 1.5),
      bodyMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: primary, height: 1.45),
      bodySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: secondary, height: 1.4),
      labelLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: primary),
      labelMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: primary),
      labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.redText, letterSpacing: 1.4),
    );
  }

  /// Tombol utama: pil merah, tinggi 56, teks 17 tebal 800.
  static ButtonStyle _primaryButton() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.redPrimary,
      foregroundColor: Colors.white,
      // Teks putih harus tetap >= 4.5:1 saat tombol nonaktif (WCAG 1.4.3).
      disabledBackgroundColor: AppColors.redDisabled,
      disabledForegroundColor: Colors.white,
      elevation: 0,
      minimumSize: const Size(0, 56),
      textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 17, fontWeight: FontWeight.w800),
      shape: const StadiumBorder(),
      tapTargetSize: MaterialTapTargetSize.padded, // Area sentuh >= 48dp (aksesibilitas)
    );
  }

  /// Tombol sekunder: pil putih dengan garis 2px, tinggi 52. Garis memakai
  /// [AppColors.outlineControl] agar batas tombol terlihat (WCAG 1.4.11).
  static ButtonStyle _secondaryButton() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.textPrimary,
      backgroundColor: Colors.white,
      minimumSize: const Size(0, 52),
      side: const BorderSide(color: AppColors.outlineControl, width: 2),
      textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w700),
      shape: const StadiumBorder(),
      tapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}