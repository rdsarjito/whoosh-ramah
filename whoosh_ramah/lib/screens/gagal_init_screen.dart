import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import '../widgets/pill_button.dart';

/// Layar darurat bila Firebase gagal diinisialisasi saat aplikasi dibuka
/// (mis. internet putus ketika demo). Tanpa layar ini, kegagalan init menjadi
/// exception tak tertangani dan aplikasi tidak terbuka sama sekali.
///
/// [onCobaLagi] mengulang inisialisasi; bila berhasil, `main` menjalankan ulang
/// aplikasi normal sehingga layar ini tergantikan oleh layar pilih peran.
class GagalInitScreen extends StatefulWidget {
  const GagalInitScreen({
    super.key,
    required this.pesan,
    required this.onCobaLagi,
  });

  /// Keterangan teknis singkat untuk ditampilkan di bawah penjelasan.
  final String pesan;

  /// Mengulang inisialisasi Firebase lalu menjalankan aplikasi normal.
  final Future<void> Function() onCobaLagi;

  @override
  State<GagalInitScreen> createState() => _GagalInitScreenState();
}

class _GagalInitScreenState extends State<GagalInitScreen> {
  bool _mencoba = false;

  Future<void> _coba() async {
    if (_mencoba) return;
    setState(() => _mencoba = true);
    await widget.onCobaLagi();
    // Bila berhasil, pohon widget sudah diganti oleh runApp; tidak perlu setState.
    if (mounted) setState(() => _mencoba = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.redSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_off,
                    size: 40,
                    color: AppColors.redText,
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: const Text(
                    'Tidak bisa terhubung',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Whoosh Ramah butuh internet untuk memuat permintaan pendampingan. '
                  'Periksa koneksi Anda, lalu coba lagi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                PillButton(
                  onPressed: _mencoba ? null : _coba,
                  child: _mencoba
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Coba lagi'),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.pesan,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: AppColors.textSecondary,
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

/// Pembungkus [GagalInitScreen] dengan tema aplikasi, dipakai `main` saat
/// inisialisasi Firebase gagal.
class AplikasiGagalInit extends StatelessWidget {
  const AplikasiGagalInit({
    super.key,
    required this.pesan,
    required this.onCobaLagi,
  });

  final String pesan;
  final Future<void> Function() onCobaLagi;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Whoosh Ramah',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      home: GagalInitScreen(pesan: pesan, onCobaLagi: onCobaLagi),
    );
  }
}