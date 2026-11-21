import 'package:material_ui/material_ui.dart';

import '../data/dummy.dart';
import '../theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/ganti_peran_pill.dart';
import '../widgets/hero_header.dart';
import '../widgets/pill_button.dart';
import '../widgets/secondary_pill_button.dart';
import '../widgets/train_illustration.dart';
import '../widgets/white_card.dart';
import 'penumpang_pesan_screen.dart';

/// Layar 1 — Detail tiket penumpang (design/Penumpang-Tiket.dc.html).
///
/// Data tiket dari [DummyData]. Tombol "Butuh pendampingan" dan nav "Bantuan"
/// membuka layar pesan pendampingan (Langkah 4).
class PenumpangTiketScreen extends StatelessWidget {
  const PenumpangTiketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = DummyData.tiket;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HeroHeader(
                color: AppColors.pinkHero,
                borderRadius: 36,
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 64),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const GantiPeranPill(),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              'Selamat datang, ${DummyData.penumpang.namaPenumpang}',
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                                letterSpacing: -0.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 30,
                            color: Color(0xFF5A6473),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const TrainIllustration(),
                  ],
                ),
              ),
              // Kartu putih menumpuk hero: seluruh isi di bawah hero digeser naik
              // 48px (setara `margin-top: -48px` di design; Flutter melarang
              // margin/padding negatif pada Container/Padding).
              Transform.translate(
                offset: const Offset(0, -48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    WhiteCard(
                      radius: AppRadius.card,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.redPrimary,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                                child: Text(
                                  t.label.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  t.kelas,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _TimePoint(
                                  time: t.jamBerangkat,
                                  station: t.stasiunAsal,
                                ),
                              ),
                              const _Connector(),
                              Expanded(
                                child: _TimePoint(
                                  time: t.jamTiba,
                                  station: t.stasiunTujuan,
                                  alignEnd: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.outlineSoft,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _TicketInfo(label: 'KERETA', value: t.kereta),
                              _TicketInfo(label: 'TANGGAL', value: t.tanggal),
                              _TicketInfo(label: 'GERBONG', value: t.gerbong),
                              _TicketInfo(
                                label: 'KURSI',
                                value: t.kursi,
                                alignEnd: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PillButton(
                            height: 72,
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PenumpangPesanScreen(),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.accessible,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Flexible(
                                  child: Text(
                                    'Butuh pendampingan',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Icon(
                                  Icons.arrow_forward,
                                  size: 22,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SecondaryPillButton(
                            height: 54,
                            onPressed: () {},
                            label: 'Lihat daftar tiket lain',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    BottomNav(
                      activeColor: AppColors.redPrimary,
                      activeBackground: AppColors.pinkHero,
                      items: [
                        const BottomNavItem(
                          label: 'Beranda',
                          icon: Icons.home_outlined,
                          active: true,
                        ),
                        const BottomNavItem(
                          label: 'Tiket',
                          icon: Icons.confirmation_number_outlined,
                        ),
                        BottomNavItem(
                          label: 'Bantuan',
                          icon: Icons.favorite_outline,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PenumpangPesanScreen(),
                            ),
                          ),
                        ),
                        const BottomNavItem(
                          label: 'Akun',
                          icon: Icons.person_outline,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Titik waktu keberangkatan/kedatangan (jam besar + nama stasiun).
class _TimePoint extends StatelessWidget {
  const _TimePoint({
    required this.time,
    required this.station,
    this.alignEnd = false,
  });

  final String time;
  final String station;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            time,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          station,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Garis penghubung + panah di antara dua titik waktu.
class _Connector extends StatelessWidget {
  const _Connector();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            child: Divider(height: 2, thickness: 2, color: AppColors.connector),
          ),
          Icon(Icons.arrow_forward, size: 16, color: AppColors.redPrimary),
        ],
      ),
    );
  }
}

/// Satu kolom info tiket (label kecil + nilai tebal).
class _TicketInfo extends StatelessWidget {
  const _TicketInfo({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
