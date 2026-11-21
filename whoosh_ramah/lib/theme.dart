import 'package:material_ui/material_ui.dart';

/// Palet warna gaya "Cerah & ramah" (PROJECT.md bagian 7).
///
/// Nama warna mengikuti perannya di desain: merah untuk penumpang, biru untuk
/// petugas, hijau untuk keluarga/sukses.
class AppColors {
  AppColors._();

  // Dasar
  static const Color background = Color(0xFFF5F6FA); // Latar semua layar
  static const Color textPrimary = Color(0xFF1F2430); // Teks utama
  static const Color textSecondary = Color(0xFF5F6574); // Keterangan

  // Penumpang (merah)
  static const Color redPrimary = Color(0xFFE11D2E); // Tombol utama, badge Kamera AI
  static const Color redText = Color(0xFFB00E28); // Teks merah di atas merah muda
  static const Color pinkHero = Color(0xFFFFE4E8); // Header penumpang, chip terpilih

  // Petugas (biru)
  static const Color blueOfficer = Color(0xFF1E50C8); // Tombol & aksen petugas
  static const Color blueHero = Color(0xFFE3ECFF); // Header petugas

  // Keluarga / sukses (hijau)
  static const Color greenFamily = Color(0xFF17663F); // Tombol keluarga, status selesai
  static const Color greenHero = Color(0xFFE3F4EA); // Header keluarga

  // Pendukung
  static const Color innerGray = Color(0xFFF3F4F8); // Kotak info di dalam kartu
  static const Color noteYellow = Color(0xFFFFF3D6); // Latar catatan penumpang
  static const Color noteYellowText = Color(0xFF5C3D00); // Teks catatan penumpang
  static const Color outline = Color(0xFFE4E6EE); // Garis tombol sekunder
  static const Color outlineSoft = Color(0xFFE6E8EF); // Garis kotak pilihan
  static const Color connector = Color(0xFFE1E4EA); // Garis timeline yang belum aktif
}

/// Radius sudut yang dipakai di seluruh layar (PROJECT.md bagian 7).
class AppRadius {
  AppRadius._();

  static const double hero = 36; // 32–40: sudut bawah header berwarna
  static const double card = 24; // 24–28: kartu putih utama
  static const double cardLarge = 28;
  static const double inner = 16; // Kotak info di dalam kartu
  static const double choice = 20; // 20–22: kotak pilihan (bantuan / titik jemput)
  static const double bottomNav = 26; // Menu bawah melayang
  static const double pill = 999; // Tombol & badge berbentuk pil
}

/// Bayangan lembut untuk kartu (PROJECT.md bagian 7).
class AppShadows {
  AppShadows._();

  /// Kartu putih utama: blur 34, y 14, opacity 10%.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x1A1F2430), blurRadius: 34, offset: Offset(0, 14)),
  ];

  /// Kartu dalam / sekunder: blur 22, y 8, opacity ±6%.
  static const List<BoxShadow> cardSoft = [
    BoxShadow(color: Color(0x0F1F2430), blurRadius: 22, offset: Offset(0, 8)),
  ];
}

/// Tema aplikasi: warna, font Nunito (dibundel di assets/fonts), serta gaya
/// tombol & kartu (bagian 7).
class AppTheme {
  AppTheme._();

  /// Family font lokal (lihat bagian `fonts` di pubspec.yaml).
  static const String fontFamily = 'Nunito';

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.redPrimary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.redPrimary,
      secondary: AppColors.blueOfficer,
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

  /// Font Nunito dengan ukuran/berat sesuai panduan: minimum 13, teks utama
  /// 15–17, judul 25–30, berat 600–900. Family diisi otomatis oleh
  /// [ThemeData.fontFamily] ('Nunito').
  static TextTheme _textTheme() {
    const primary = AppColors.textPrimary;
    const secondary = AppColors.textSecondary;
    return const TextTheme(
      displayLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: primary, height: 1.15),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: primary, height: 1.15),
      displaySmall: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: primary, height: 1.2),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: primary),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primary),
      titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: primary),
      titleSmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: primary),
      bodyLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: primary, height: 1.4),
      bodyMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: primary, height: 1.45),
      bodySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: secondary, height: 1.4),
      labelLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: primary),
      labelMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: primary),
      labelSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: secondary),
    );
  }

  /// Tombol utama: bentuk pil, tinggi 60–68, teks 18 tebal 900.
  static ButtonStyle _primaryButton() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.redPrimary,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.redPrimary.withValues(alpha: 0.5),
      elevation: 0,
      minimumSize: const Size(0, 60),
      textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w900),
      shape: const StadiumBorder(),
      tapTargetSize: MaterialTapTargetSize.padded, // Area sentuh >= 48dp (aksesibilitas)
    );
  }

  /// Tombol sekunder: pil putih dengan garis 2px #E4E6EE, tinggi 46–54.
  static ButtonStyle _secondaryButton() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.textPrimary,
      minimumSize: const Size(0, 52),
      side: const BorderSide(color: AppColors.outline, width: 2),
      textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w800),
      shape: const StadiumBorder(),
      tapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}
