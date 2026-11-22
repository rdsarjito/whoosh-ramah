import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Header atas gaya Brightline: kanvas putih polos tanpa hero berwarna.
///
/// Membentang hingga area status bar (latar putih, ikon status bar gelap),
/// konten dijaga [SafeArea]. Pembeda peran kini eyebrow + ikon, bukan warna
/// latar — lihat [AppColors]. Isi header biasanya baris logo/wordmark atau
/// tombol kembali + judul.
class HeroHeader extends StatelessWidget {
  const HeroHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 12, 22, 10),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        // Latar selalu putih, jadi ikon status bar dibuat gelap.
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          bottom: false,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}