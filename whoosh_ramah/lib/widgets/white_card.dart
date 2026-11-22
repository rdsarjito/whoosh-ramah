import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Kartu putih utama gaya Brightline: radius 22, garis rambut 1px
/// [AppColors.outline], bayangan sangat lembut (blur 26, y 10, 6%).
///
/// [margin] harus non-negatif — `Container` menolak margin/padding negatif.
class WhiteCard extends StatelessWidget {
  const WhiteCard({
    super.key,
    required this.child,
    this.margin,
    this.padding = const EdgeInsets.all(20),
    this.radius = AppRadius.card,
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
        border: Border.all(color: AppColors.outline),
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
