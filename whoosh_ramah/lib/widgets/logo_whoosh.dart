import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Logo Whoosh Ramah: kereta cepat tersenyum di ubin merah membulat
/// (lembar desain "Logo C · Kereta senyum", paket whoosh-ramah-gaya-baru).
///
/// Radius ubin mengikuti lembar logo: ±30% ukuran (40 → 12, 84 → 25).
/// [inverted] memakai ubin putih untuk header berlatar merah. Gambar PNG
/// transparan resmi dibundel di `assets/logo/`; Semantics gambar eksplisit
/// agar pembaca layar menyebut merek, bukan "gambar tanpa label".
class LogoWhoosh extends StatelessWidget {
  const LogoWhoosh({super.key, this.size = 40, this.inverted = false});

  /// Sisi ubin logo (32–84 sesuai lembar logo).
  final double size;

  /// true = ubin putih (versi terbalik di atas latar merah).
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Logo Whoosh Ramah',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.3),
          child: ColoredBox(
            color: inverted ? Colors.white : AppColors.redPrimary,
            child: Image.asset(
              'assets/logo/logo_kereta_512.png',
              width: size,
              height: size,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}