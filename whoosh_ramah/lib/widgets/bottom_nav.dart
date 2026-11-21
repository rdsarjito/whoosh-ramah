import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Satu item pada [BottomNav].
class BottomNavItem {
  const BottomNavItem({
    required this.label,
    required this.icon,
    this.active = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;
}

/// Menu bawah melayang: kotak putih radius 26, item aktif berlatar warna muda
/// peran (bagian 7). Tinggi tiap item >= 52dp (bagian 8: minimal 48dp).
class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.items, required this.activeColor, required this.activeBackground});

  final List<BottomNavItem> items;

  /// Warna teks/ikon item aktif (mis. merah penumpang).
  final Color activeColor;

  /// Latar muda item aktif (mis. merah muda hero penumpang).
  final Color activeBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.bottomNav),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(AppRadius.bottomNav),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            for (final item in items)
              Expanded(child: _NavItem(item: item, activeColor: activeColor, activeBackground: activeBackground)),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.item, required this.activeColor, required this.activeBackground});

  final BottomNavItem item;
  final Color activeColor;
  final Color activeBackground;

  @override
  Widget build(BuildContext context) {
    final color = item.active ? activeColor : AppColors.textSecondary;
    // Ikon dekoratif; label aksesibilitas diambil dari teks (MergeSemantics).
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: item.active,
        child: InkResponse(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 52,
            margin: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
            decoration: BoxDecoration(
              color: item.active ? activeBackground : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, size: 22, color: color),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: item.active ? FontWeight.w800 : FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
