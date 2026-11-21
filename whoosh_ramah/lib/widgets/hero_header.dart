import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Header "hero" berwarna dengan sudut bawah membulat (PROJECT.md bagian 7).
///
/// Membentang hingga ke area status bar (warna latar ikut), konten dijaga
/// [SafeArea]. Kartu putih di bawahnya biasanya menumpuk dengan margin atas
/// negatif (±48) — lihat `WhiteCard`.
class HeroHeader extends StatelessWidget {
  const HeroHeader({
    super.key,
    required this.color,
    required this.child,
    this.borderRadius = 40,
    this.padding = const EdgeInsets.fromLTRB(22, 20, 22, 26),
  });

  /// Warna latar hero (mis. merah muda penumpang, biru petugas, hijau keluarga).
  final Color color;
  final Widget child;

  /// Radius sudut bawah (32–40 sesuai bagian 7).
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        // Hero selalu berwarna muda, jadi ikon status bar dibuat gelap.
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          bottom: false,
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(borderRadius)),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
