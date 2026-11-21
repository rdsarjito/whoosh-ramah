import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Tombol sekunder: pil putih dengan garis 2px #E4E6EE, tinggi 46–54 (bagian 7).
///
/// Memakai [OutlinedButton] yang sudah aksesibel secara bawaan: label diambil
/// dari [label], tinggi sentuh >= 48dp, dan kondisi nonaktif ditangani otomatis.
class SecondaryPillButton extends StatelessWidget {
  const SecondaryPillButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.height = 54,
    this.borderColor = AppColors.outline,
    this.foregroundColor = AppColors.textPrimary,
  });

  final VoidCallback? onPressed;
  final String label;
  final double height;
  final Color borderColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: foregroundColor,
        minimumSize: Size(0, height),
        side: BorderSide(color: borderColor, width: 2),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    );
  }
}
