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

/// Menu bawah gaya Brightline: bar putih rata dengan garis rambut di atas,
/// item aktif berchip muda ([activeBackground]). Tinggi tiap item >= 56dp
/// (bagian 8: minimal 48dp).
///
/// Tidak ada kontrol mati: item aktif adalah halaman saat ini, item dengan
/// [BottomNavItem.onTap] menjalankan aksinya, dan item tanpa tujuan memberi
/// umpan balik "segera hadir" plus label TalkBack yang jujur.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.items, required this.activeColor, required this.activeBackground});

  final List<BottomNavItem> items;

  /// Warna teks/ikon item aktif (merah teks merek untuk semua peran).
  final Color activeColor;

  /// Latar chip item aktif (mis. [AppColors.redSoft]).
  final Color activeBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: Material(
        type: MaterialType.transparency,
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
    final adaAksi = item.onTap != null;
    // Label eksplisit: item tanpa tujuan tidak boleh terdengar seperti tombol
    // yang berfungsi penuh bagi pengguna TalkBack.
    final label = item.active
        ? '${item.label}, halaman saat ini'
        : (adaAksi ? item.label : '${item.label}, segera hadir');
    return Semantics(
      button: !item.active,
      selected: item.active,
      label: label,
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: item.active
              ? null
              : (item.onTap ?? () => _segeraHadir(context, item.label)),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            decoration: BoxDecoration(
              color: item.active ? activeBackground : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, size: 22, color: color),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
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

  /// Umpan balik untuk item yang belum punya layar sungguhan.
  void _segeraHadir(BuildContext context, String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label segera hadir.')));
  }
}
