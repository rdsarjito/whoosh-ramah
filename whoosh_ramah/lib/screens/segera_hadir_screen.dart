import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import '../widgets/ganti_peran_pill.dart';

/// Layar sementara untuk peran/tujuan yang belum dibangun.
///
/// Petugas & Keluarga diganti di Langkah 6 & 7; tombol "Butuh pendampingan"
/// di layar tiket diganti di Langkah 4. Menampilkan "Segera hadir" + tombol
/// "Ganti peran" yang kembali ke layar pilih peran (root).
class SegeraHadirScreen extends StatelessWidget {
  const SegeraHadirScreen({super.key, required this.title});

  /// Konteks singkat, mis. "Petugas stasiun" atau "Butuh pendampingan".
  final String title;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: text.titleMedium?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Text('Segera hadir', textAlign: TextAlign.center, style: text.displaySmall),
                const SizedBox(height: 28),
                GantiPeranPill(
                  // Kembali ke layar pilih peran (root), dari mana pun layar ini dibuka.
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
