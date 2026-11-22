import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Tombol utama berbentuk pil gaya Brightline: tinggi 56, teks 17 tebal 800.
///
/// [child] biasanya `Text('Label')` atau `Row` ikon+teks; teks di dalamnya
/// menyatu menjadi label aksesibilitas tombol (MergeSemantics). Seluruh area
/// punya tinggi sentuh >= 56dp (bagian 8: minimal 48dp).
///
/// Saat nonaktif, latar diredam lewat [AppColors.redam] (bukan alpha 50%) agar
/// teks putih tetap >= 4.5:1 — WCAG 1.4.3. Semua peran memakai merah merek
/// yang sama, jadi tidak ada lagi warna tombol per peran.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.backgroundColor = AppColors.redPrimary,
    this.foregroundColor = Colors.white,
    this.height = 56,
    this.disabledBackgroundColor,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Color backgroundColor;
  final Color foregroundColor;
  final double height;

  /// Opsional: timpa warna latar saat nonaktif. Bawaan: [AppColors.redam].
  final Color? disabledBackgroundColor;

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
              color: onPressed == null
                  ? (disabledBackgroundColor ?? AppColors.redam(backgroundColor))
                  : backgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Center(
              // merge (bukan timpa) agar family Plus Jakarta Sans dari tema tetap terpakai.
              child: DefaultTextStyle.merge(
                style: TextStyle(color: foregroundColor, fontSize: 17, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
                child: IconTheme(
                  data: IconThemeData(color: foregroundColor, size: 22),
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
