import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import '../transisi.dart';
import '../widgets/logo_whoosh.dart';
import 'keluarga_pantau_screen.dart';
import 'penumpang_tiket_screen.dart';
import 'petugas_tugas_screen.dart';

/// Layar 0 — Pilih peran, persis contoh Brightline
/// (whoosh-ramah-gaya-baru/design/Contoh-Brightline-Pilih-Peran.dc.html).
///
/// Kanvas putih, satu aksen merah: kartu Penumpang merah, kartu Petugas &
/// Keluarga abu blok, chip panah bundar 48. Navigasi tetap: Penumpang ->
/// layar tiket; Petugas -> daftar tugas; Keluarga -> pantau perjalanan.
class PilihPeranScreen extends StatelessWidget {
  const PilihPeranScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        // LayoutBuilder + IntrinsicHeight: footer menempel di dasar layar
        // saat muat, dan seluruh halaman bisa digulir saat teks diperbesar
        // (text scale 1.3–1.5) tanpa overflow.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Baris merek: ubin logo 40 + wordmark 18/800.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                      child: Row(
                        children: [
                          const LogoWhoosh(size: 40),
                          const SizedBox(width: 10),
                          const Text(
                            'Whoosh Ramah',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Hero: eyebrow merah, judul 42 dengan span merah, isi 17.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 36, 22, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MODE DEMO · HACKATHON KCIC',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              color: AppColors.redText,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Semantics(
                            header: true,
                            child: Text.rich(
                              TextSpan(
                                text: 'Perjalanan nyaman, ',
                                children: [
                                  TextSpan(
                                    text: 'untuk semua.',
                                    style: TextStyle(color: AppColors.redPrimary),
                                  ),
                                ],
                              ),
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                height: 1.04,
                                letterSpacing: -1.4,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Pilih peran untuk mencoba alur pendampingan penumpang prioritas.',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Tiga kartu peran, gap 12.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _KartuPeran(
                            judul: 'Penumpang',
                            subjudul: 'Pesan pendamping untuk perjalanan Anda',
                            utama: true,
                            onTap: () => Navigator.of(context).push(
                              TransisiHalaman.masuk(halaman: const PenumpangTiketScreen()),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _KartuPeran(
                            judul: 'Petugas',
                            subjudul: 'Terima tugas dari aplikasi dan Kamera AI',
                            onTap: () => Navigator.of(context).push(
                              TransisiHalaman.masuk(halaman: const PetugasTugasScreen()),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _KartuPeran(
                            judul: 'Keluarga',
                            subjudul: 'Pantau perjalanan orang tersayang',
                            onTap: () => Navigator.of(context).push(
                              TransisiHalaman.masuk(halaman: const KeluargaPantauScreen()),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(22, 24, 22, 28),
                      child: Text(
                        'Prototipe hackathon · semua data adalah contoh',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu peran gaya Brightline: radius 22, padding 22×20, tinggi minimum 104,
/// judul 24/800 + subjudul 15/600, chip panah bundar 48 di kanan.
///
/// [utama] = kartu merah merek (Penumpang); lainnya abu blok dengan chip
/// tinta. MergeSemantics: seluruh kartu jadi satu tombol berlabel
/// `<judul> <subjudul>` untuk TalkBack.
class _KartuPeran extends StatelessWidget {
  const _KartuPeran({
    required this.judul,
    required this.subjudul,
    required this.onTap,
    this.utama = false,
  });

  final String judul;
  final String subjudul;
  final VoidCallback onTap;
  final bool utama;

  @override
  Widget build(BuildContext context) {
    final warnaTeks = utama ? Colors.white : AppColors.textPrimary;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            constraints: const BoxConstraints(minHeight: 104),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(
              color: utama ? AppColors.redPrimary : AppColors.block,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        judul,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: warnaTeks,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subjudul,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: utama ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Chip panah 48×48: putih di kartu merah, tinta di kartu blok.
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: utama ? Colors.white : AppColors.textPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 22,
                    color: utama ? AppColors.redPrimary : Colors.white,
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