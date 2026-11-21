import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import '../widgets/hero_header.dart';
import '../widgets/train_illustration.dart';
import 'keluarga_pantau_screen.dart';
import 'penumpang_tiket_screen.dart';
import 'petugas_tugas_screen.dart';

/// Layar 0 — Pilih peran (design/Main.dc.html).
///
/// Penumpang -> layar tiket; Petugas -> daftar tugas; Keluarga -> pantau
/// perjalanan.
class PilihPeranScreen extends StatelessWidget {
  const PilihPeranScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HeroHeader(
              color: AppColors.pinkHero,
              borderRadius: 40,
              padding: const EdgeInsets.fromLTRB(22, 56, 22, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(color: AppColors.redPrimary, shape: BoxShape.circle),
                        child: Semantics(
                          label: 'Logo Whoosh Ramah',
                          child: const Icon(Icons.favorite, size: 22, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Whoosh Ramah',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Perjalanan nyaman untuk semua penumpang',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      letterSpacing: -0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Pendampingan lansia, penyandang disabilitas, dan penumpang '
                    'prioritas dari stasiun asal sampai tujuan.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: Color(0xFF5A4A50),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const TrainIllustration(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'MASUK SEBAGAI (MODE DEMO)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _RoleCard(
                    title: 'Penumpang',
                    subtitle: 'Pesan pendamping untuk perjalanan',
                    icon: Icons.accessible,
                    badgeColor: AppColors.pinkHero,
                    iconColor: AppColors.redPrimary,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PenumpangTiketScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _RoleCard(
                    title: 'Petugas stasiun',
                    subtitle: 'Terima dan selesaikan tugas',
                    icon: Icons.verified_user_outlined,
                    badgeColor: AppColors.blueHero,
                    iconColor: AppColors.blueOfficer,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PetugasTugasScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _RoleCard(
                    title: 'Keluarga',
                    subtitle: 'Pantau perjalanan orang tersayang',
                    icon: Icons.groups,
                    badgeColor: AppColors.greenHero,
                    iconColor: AppColors.greenFamily,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const KeluargaPantauScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 22),
              child: Text(
                'Prototipe hackathon · semua data adalah contoh',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu pilihan peran (putih, badge ikon berwarna, panah kanan).
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badgeColor,
    required this.iconColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color badgeColor;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // MergeSemantics: seluruh kartu jadi satu tombol berlabel "<title> <subtitle>".
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1F2430).withValues(alpha: 0.08),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                  child: Icon(icon, size: 28, color: iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_right, size: 22, color: AppColors.textPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
