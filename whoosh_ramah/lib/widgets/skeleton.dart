import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Kerangka loading (skeleton) dengan kilau lembut, pengganti spinner polos.
///
/// Bentuknya meniru tata letak layar sungguhan (hero + kartu + baris teks)
/// sehingga pengguna tahu *apa* yang sedang dimuat, bukan sekadar "tunggu".
///
/// Satu [Skeleton] membungkus seluruh kerangka dan memegang satu
/// [AnimationController]; [SkeletonBox] di dalamnya hanya kotak abu-abu statis.
/// Sapuan gradien dihitung terhadap bounds seluruh kerangka agar kilau terlihat
/// menyapu layar, bukan berkedip per kotak.
///
/// Aksesibilitas:
/// - seluruh kerangka dibungkus `Semantics(label: 'Memuat …')` +
///   `ExcludeSemantics`, jadi TalkBack membaca satu pengumuman, bukan puluhan
///   kotak kosong;
/// - bila pengguna mematikan animasi ([MediaQuery.disableAnimationsOf]), kilau
///   berhenti dan kerangka tampil statis — informasi loading tetap tersampaikan.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    required this.child,
    this.label = 'Memuat data',
  });

  /// Tata letak kerangka, disusun dari [SkeletonBox].
  final Widget child;

  /// Pengumuman untuk pembaca layar.
  final String label;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kilau = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bolehBergerak = !MediaQuery.disableAnimationsOf(context);
    if (bolehBergerak && !_kilau.isAnimating) {
      _kilau.repeat();
    } else if (!bolehBergerak && _kilau.isAnimating) {
      _kilau.stop();
    }
  }

  @override
  void dispose() {
    _kilau.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      container: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _kilau,
          builder: (context, child) {
            // Tanpa animasi: gradien diam di tengah (tetap terbaca sebagai
            // kerangka, bukan layar kosong).
            final t = _kilau.isAnimating ? _kilau.value : 0.5;
            final geser = -1.6 + 3.2 * t;
            return ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment(geser, -0.4),
                end: Alignment(geser + 0.9, 0.4),
                colors: const [
                  AppColors.block,
                  Color(0xFFFAFBFC),
                  AppColors.block,
                ],
                stops: const [0.0, 0.5, 1.0],
              ).createShader(bounds),
              child: child,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// Satu blok kerangka: kotak abu-abu bersudut [radius].
///
/// [width] null berarti melebar mengikuti induk (mis. dalam Column stretch).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 10,
    this.shape = BoxShape.rectangle,
  });

  /// Lingkaran (mis. avatar petugas atau penanda timeline).
  const SkeletonBox.bulat({super.key, required double size})
      : width = size,
        height = size,
        radius = 0,
        shape = BoxShape.circle;

  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.block,
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular(radius),
      ),
    );
  }
}

/// Baris teks kerangka: tinggi 12, sudut 6, lebar [lebar] (null = melebar).
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({super.key, this.lebar, this.tinggi = 12});

  final double? lebar;
  final double tinggi;

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(width: lebar, height: tinggi, radius: tinggi / 2);
  }
}

/// Kartu putih tempat kerangka disusun, memakai bayangan kartu aplikasi.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 18),
    this.padding = const EdgeInsets.all(18),
    this.radius = AppRadius.card,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.outline),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}

/// Kerangka kartu rincian yang dipakai bersama oleh layar status penumpang,
/// detail tugas petugas, dan pantau keluarga: avatar bundar + judul + subjudul,
/// [jumlahBaris] baris info, lalu satu tombol.
///
/// Bentuknya sengaja mirip kartu aslinya supaya perpindahan dari kerangka ke
/// data tidak terasa seperti layar yang berganti total.
class SkeletonRincian extends StatelessWidget {
  const SkeletonRincian({
    super.key,
    this.jumlahBaris = 3,
    this.adaTombol = true,
  });

  final int jumlahBaris;
  final bool adaTombol;

  @override
  Widget build(BuildContext context) {
    return SkeletonCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SkeletonBox.bulat(size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonLine(tinggi: 18),
                    const SizedBox(height: 8),
                    SkeletonLine(lebar: MediaQuery.sizeOf(context).width * 0.36),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < jumlahBaris; i++) ...[
            SkeletonLine(
              lebar: i.isEven ? double.infinity : MediaQuery.sizeOf(context).width * 0.5,
            ),
            const SizedBox(height: 10),
          ],
          if (adaTombol) ...[
            const SizedBox(height: 8),
            const SkeletonBox(height: 56, radius: 28),
          ],
        ],
      ),
    );
  }
}