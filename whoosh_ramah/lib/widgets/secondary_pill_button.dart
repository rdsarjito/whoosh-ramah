import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Tombol sekunder gaya Brightline: pil putih dengan garis 2px, tinggi 52.
///
/// Garis bawaan memakai [AppColors.outlineControl] (4.8:1 di atas putih) agar
/// batas tombol tetap terlihat — WCAG 1.4.11.
///
/// Memakai [OutlinedButton] yang sudah aksesibel secara bawaan: label diambil
/// dari [label], tinggi sentuh >= 48dp, dan kondisi nonaktif ditangani otomatis.
class SecondaryPillButton extends StatelessWidget {
  const SecondaryPillButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.height = 52,
    this.borderColor = AppColors.outlineControl,
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
        // fontFamily wajib di sini: Material(textStyle:) milik tombol memakai
        // textStyle widget apa adanya (tanpa merge), sehingga family tema hilang
        // bila tidak disebut eksplisit.
        textStyle: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Text(label),
    );
  }
}
