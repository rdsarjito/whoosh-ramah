import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Kartu putih utama: radius 24–28, bayangan lembut (blur 34, y 14, 10%).
///
/// [margin] harus non-negatif — `Container` menolak margin/padding negatif.
/// Untuk menumpuk kartu di atas hero, geser seluruh isi di bawah hero dengan
/// `Transform.translate(offset: Offset(0, -N))` di layar pemanggil (setara
/// `margin-top` negatif pada design).
class WhiteCard extends StatelessWidget {
  const WhiteCard({
    super.key,
    required this.child,
    this.margin,
    this.padding = const EdgeInsets.all(20),
    this.radius = AppRadius.cardLarge,
    this.shadow = AppShadows.card,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;
  final double radius;
  final List<BoxShadow> shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow,
      ),
      // Material agar teks/ink punya kanvas; transparan supaya dekorasi Container terlihat.
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(radius),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
