import 'package:material_ui/material_ui.dart';

import '../data/dummy.dart';
import '../services/permintaan_service.dart';
import '../theme.dart';
import '../transisi.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/ganti_peran_pill.dart';
import '../widgets/hero_header.dart';
import '../widgets/lembar_tiket.dart';
import '../widgets/logo_whoosh.dart';
import '../widgets/pill_button.dart';
import '../widgets/secondary_pill_button.dart';
import '../widgets/white_card.dart';
import 'penumpang_pesan_screen.dart';
import 'penumpang_status_screen.dart';

/// Layar 1 — Detail tiket penumpang, gaya Brightline (kanvas putih, satu
/// aksen merah, kartu radius 22 dengan garis rambut).
///
/// Informasi tetap seperti desain awal: sapaan "Halo, Bu Siti" + subjudul,
/// tombol bundar merah untuk memesan pendamping, badge "Whoosh G1123", tiga
/// kotak info (Tanggal/Gerbong/Kursi), catatan gratis, serta dua tombol
/// sekunder "QR tiket" dan "Ubah jadwal".
///
/// Semua tombol adalah aksi nyata (Tier 1 A2/A4):
/// - "QR tiket" membuka lembar berisi QR yang benar-benar bisa dipindai;
/// - "Ubah jadwal" membuka lembar pilihan kereta dan memperbarui kartu tiket;
/// - "Lihat status pendampingan" membuka status permintaan terakhir penumpang.
class PenumpangTiketScreen extends StatefulWidget {
  const PenumpangTiketScreen({super.key, this.service});

  /// Opsional: injeksi service (memudahkan pengujian).
  final PermintaanService? service;

  @override
  State<PenumpangTiketScreen> createState() => _PenumpangTiketScreenState();
}

class _PenumpangTiketScreenState extends State<PenumpangTiketScreen> {
  PermintaanService? _lazy;
  PermintaanService get _svc => widget.service ?? (_lazy ??= PermintaanService());

  /// Tiket yang sedang ditampilkan. Mulai dari data dummy, lalu berubah bila
  /// pengguna memilih jadwal lain lewat lembar "Ubah jadwal".
  TiketDummy _tiket = DummyData.tiket;

  /// true selama mencari permintaan terakhir (tombol sekunder nonaktif).
  bool _memuatStatus = false;

  String get _namaDepan => DummyData.penumpang.namaPenumpang.split(' ').first;

  /// Membuka status pendampingan terakhir milik penumpang demo. Bila belum ada
  /// permintaan atau jaringan gagal, beri tahu lewat SnackBar.
  Future<void> _bukaStatusTerakhir() async {
    if (_memuatStatus) return;
    setState(() => _memuatStatus = true);
    try {
      final p = await _svc
          .streamTerbaruPenumpang(DummyData.penumpang.idPenumpang)
          .first
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() => _memuatStatus = false);
      if (p == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Belum ada permintaan pendampingan. Tekan "Butuh pendampingan" untuk memesan.',
              ),
            ),
          );
        return;
      }
      Navigator.of(context).push(
        TransisiHalaman.masuk(
          halaman: PenumpangStatusScreen(
            idPermintaan: p.id,
            service: widget.service,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _memuatStatus = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Gagal memuat status. Periksa koneksi Anda.'),
          ),
        );
    }
  }

  void _pesanPendamping() {
    Navigator.of(context).push(
      TransisiHalaman.masuk(halaman: const PenumpangPesanScreen()),
    );
  }

  Future<void> _bukaQr() async {
    await tampilkanQrTiket(
      context,
      tiket: _tiket,
      namaPenumpang: DummyData.penumpang.namaPenumpang,
    );
  }

  Future<void> _ubahJadwal() async {
    final dipilih = await tampilkanUbahJadwal(context, sekarang: _tiket);
    if (!mounted || dipilih == null) return;
    setState(() => _tiket = dipilih);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Jadwal diperbarui: ${dipilih.kereta}, berangkat ${dipilih.jamBerangkat}.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final t = _tiket;
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: BottomNav(
        activeColor: AppColors.redText,
        activeBackground: AppColors.redSoft,
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
            onTap: _pesanPendamping,
          ),
          const BottomNavItem(
            label: 'Akun',
            icon: Icons.person_outline,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header putih: pill ganti peran + ubin logo merek di kanan.
          HeroHeader(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
            child: Row(
              children: [
                const GantiPeranPill(),
                const Spacer(),
                const LogoWhoosh(size: 32),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sapaan + jalan pintas pesan pendamping.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                'Halo, Bu $_namaDepan',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  height: 1.08,
                                  letterSpacing: -1.0,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Siap berangkat hari ini?',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      _TombolPesanHero(onTap: _pesanPendamping),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Kartu tiket: badge kereta, jam keberangkatan/tiba, info.
                  WhiteCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.redSoft,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: Text(
                                'Whoosh ${t.kereta}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.redText,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                t.label,
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        MergeSemantics(
                          child: Row(
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
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _TicketInfo(label: 'Tanggal', value: t.tanggal),
                            const SizedBox(width: 8),
                            _TicketInfo(label: 'Gerbong', value: t.gerbong),
                            const SizedBox(width: 8),
                            _TicketInfo(label: 'Kursi', value: t.kursi),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  PillButton(
                    onPressed: _pesanPendamping,
                    child: Row(
                      children: [
                        // Lingkaran putih solid dengan ikon merah — chip
                        // panah gaya Brightline.
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.accessible,
                            size: 24,
                            color: AppColors.redPrimary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
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
                  const _CatatanGratis(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryPillButton(
                          onPressed: _bukaQr,
                          label: 'QR tiket',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SecondaryPillButton(
                          onPressed: _ubahJadwal,
                          label: 'Ubah jadwal',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SecondaryPillButton(
                    onPressed: _memuatStatus ? null : _bukaStatusTerakhir,
                    label: _memuatStatus
                        ? 'Memuat status…'
                        : 'Lihat status pendampingan',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol bundar merah 52dp di header: jalan pintas memesan pendamping.
///
/// Ikon kursi roda putih di atas merah (4.74:1) — penanda visual utama layar
/// ini, jadi diberi label eksplisit "Pesan pendamping" untuk pembaca layar.
class _TombolPesanHero extends StatelessWidget {
  const _TombolPesanHero({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Pesan pendamping',
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.redPrimary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.accessible,
              size: 28,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Catatan di bawah tombol utama: "Gratis untuk lansia, difabel & ibu hamil".
/// Gaya Brightline: satu aksen merah, centang + teks merah teks (7.1:1).
class _CatatanGratis extends StatelessWidget {
  const _CatatanGratis();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const ExcludeSemantics(
          child: Icon(Icons.check_rounded, size: 20, color: AppColors.redText),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Gratis untuk lansia, difabel & ibu hamil',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.35,
              color: AppColors.redText,
            ),
          ),
        ),
      ],
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
    final alignment = alignEnd ? Alignment.centerRight : Alignment.centerLeft;
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // FittedBox menjaga jam & nama stasiun tetap satu baris dan tidak
        // meluber saat skala teks dinaikkan (bagian 8: utuh pada 130%).
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: Text(
            time,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              height: 1.05,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: Text(
            station,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Penghubung dua titik waktu: lingkaran kosong → garis titik-titik → lingkaran
/// penuh. Garis memakai [AppColors.connector] (4.8:1) agar arah perjalanan
/// tetap terbaca, bukan sekadar dekorasi.
class _Connector extends StatelessWidget {
  const _Connector();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'menuju',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.redPrimary, width: 3),
                ),
              ),
              const SizedBox(width: 4),
              const _GarisTitik(),
              const SizedBox(width: 4),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.redPrimary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Garis titik-titik 3px (design: `border-top: 3px dotted`).
class _GarisTitik extends StatelessWidget {
  const _GarisTitik();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(40, 3),
      painter: _PelukisTitik(),
    );
  }
}

class _PelukisTitik extends CustomPainter {
  const _PelukisTitik();

  @override
  void paint(Canvas canvas, Size size) {
    final cat = Paint()
      ..color = AppColors.connector
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const jarak = 7.0;
    for (var x = 1.5; x < size.width; x += jarak) {
      canvas.drawCircle(Offset(x, size.height / 2), 1.5, cat);
    }
  }

  @override
  bool shouldRepaint(covariant _PelukisTitik oldDelegate) => false;
}

/// Satu kotak info tiket (label kecil + nilai tebal) di dalam kartu.
class _TicketInfo extends StatelessWidget {
  const _TicketInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MergeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.block,
            borderRadius: BorderRadius.circular(AppRadius.inner),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}