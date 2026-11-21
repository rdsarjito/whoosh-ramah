import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Tombol kembali bulat putih di hero (chevron kiri). Dipakai layar pesan &
/// status penumpang. Ikon bersifat dekoratif; label aksesibilitas eksplisit
/// agar jelas untuk TalkBack (bagian 8). Area sentuh 48dp.
class HeroBackButton extends StatelessWidget {
  const HeroBackButton({super.key, required this.onTap, this.label = 'Kembali'});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.chevron_left, size: 28, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
