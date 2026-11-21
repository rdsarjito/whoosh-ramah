import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Pill "Ganti peran" di pojok kiri atas hero (kembali ke layar pilih peran).
///
/// Tanpa [onPressed], default-nya `Navigator.maybePop()`. Ikon panah bersifat
/// dekoratif; label aksesibilitas diambil dari teks (MergeSemantics).
class GantiPeranPill extends StatelessWidget {
  const GantiPeranPill({super.key, this.onPressed, this.label = 'Ganti peran'});

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final handler = onPressed ?? () => Navigator.maybePop(context);
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkResponse(
          onTap: handler,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            height: 44,
            padding: const EdgeInsets.fromLTRB(10, 0, 16, 0),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back, size: 18, color: AppColors.textPrimary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
