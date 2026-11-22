import 'package:material_ui/material_ui.dart';

/// Durasi animasi yang menghormati preferensi "kurangi gerak" pengguna.
///
/// Bila [MediaQuery.disableAnimationsOf] aktif, hasilnya [Duration.zero] sehingga
/// widget beranimasi (AnimatedSwitcher, AnimatedSize, AnimatedContainer) langsung
/// menampilkan keadaan akhir tanpa gerakan. Dipakai di seluruh layar agar satu
/// sakelar sistem mematikan semua motion aplikasi, bukan hanya transisi rute.
Duration durasiGerak(
  BuildContext context, [
  Duration normal = const Duration(milliseconds: 320),
]) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : normal;

/// Transisi antar layar yang dirancang, dipakai menggantikan [MaterialPageRoute]
/// polos di seluruh aplikasi.
///
/// Arah maju: halaman baru memudar masuk sambil naik sedikit (3.5% tinggi) dan
/// membesar dari 98% — terasa seperti kartu yang diletakkan, bukan jendela yang
/// digeser penuh. Arah kembali memakai kurva yang sama secara terbalik.
///
/// Durasi sengaja pendek (300ms maju / 240ms kembali) agar alur pemesanan
/// pendampingan tetap terasa cepat bagi pengguna yang terburu-buru.
///
/// Aksesibilitas: bila pengguna mematikan animasi
/// ([MediaQuery.disableAnimationsOf]), halaman langsung tampil tanpa gerakan
/// maupun fade — tidak ada motion yang bisa memicu vestibular disorder.
class TransisiHalaman {
  TransisiHalaman._();

  /// Durasi transisi maju.
  static const Duration maju = Duration(milliseconds: 300);

  /// Durasi transisi kembali (pop).
  static const Duration kembali = Duration(milliseconds: 240);

  /// Rute dengan transisi terancang untuk [halaman].
  static Route<T> masuk<T>({required Widget halaman, String? nama}) {
    return PageRouteBuilder<T>(
      settings: RouteSettings(name: nama),
      transitionDuration: maju,
      reverseTransitionDuration: kembali,
      pageBuilder: (context, animation, secondaryAnimation) => halaman,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        final melengkung = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: melengkung,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(melengkung),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.985, end: 1).animate(melengkung),
              child: child,
            ),
          ),
        );
      },
    );
  }
}