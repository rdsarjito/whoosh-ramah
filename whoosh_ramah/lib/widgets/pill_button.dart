import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Tombol utama berbentuk pil (bagian 7): tinggi 60–68, teks 18 tebal 900.
///
/// [child] biasanya `Text('Label')` atau `Row` ikon+teks; teks di dalamnya
/// menyatu menjadi label aksesibilitas tombol (MergeSemantics). Seluruh area
/// punya tinggi sentuh >= 68dp (bagian 8: minimal 48dp).
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.backgroundColor = AppColors.redPrimary,
    this.foregroundColor = Colors.white,
    this.height = 68,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Color backgroundColor;
  final Color foregroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        child: InkResponse(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            constraints: BoxConstraints(minHeight: height),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: onPressed == null ? backgroundColor.withValues(alpha: 0.5) : backgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Center(
              child: DefaultTextStyle(
                style: TextStyle(color: foregroundColor, fontSize: 19, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
                child: IconTheme(
                  data: IconThemeData(color: foregroundColor, size: 26),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
