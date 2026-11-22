import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../data/dummy.dart';
import '../models/permintaan.dart';
import '../services/permintaan_service.dart';
import '../theme.dart';
import '../transisi.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/ganti_peran_pill.dart';
import '../widgets/hero_header.dart';
import '../widgets/pill_button.dart';
import '../widgets/secondary_pill_button.dart';
import '../widgets/skeleton.dart';
import 'petugas_detail_screen.dart';

/// Layar 5 — Daftar tugas petugas, gaya Brightline (kanvas putih, satu aksen
/// merah; pembeda tugas adalah badge sumber + label status, bukan warna peran).
///
/// Mendengarkan [PermintaanService.streamSemua] lalu memisahkan tugas di sisi
/// aplikasi: aktif (status != selesai, terbaru di atas) dan selesai hari ini.
/// Saat dokumen BARU masuk setelah layar terbuka, petugas diberi tahu lewat
/// haptic, SnackBar, [SemanticsService.sendAnnouncement], dan sorotan kartu.
class PetugasTugasScreen extends StatefulWidget {
  const PetugasTugasScreen({super.key, this.service});

  /// Opsional: injeksi service (memudahkan pengujian).
  final PermintaanService? service;

  @override
  State<PetugasTugasScreen> createState() => _PetugasTugasScreenState();
}

class _PetugasTugasScreenState extends State<PetugasTugasScreen> {
  late final PermintaanService _service = widget.service ?? PermintaanService();
  late Stream<List<Permintaan>> _stream = _service.streamSemua();

  /// Pengendali gulir daftar tugas + penanda judul "SELESAI HARI INI", dipakai
  /// tombol nav "Riwayat" untuk melompat ke bagian tugas selesai.
  final ScrollController _gulir = ScrollController();
  final GlobalKey _judulSelesai = GlobalKey();

  /// Id yang sudah dikenal; null berarti snapshot pertama belum diproses
  /// (data awal tidak boleh memicu notifikasi "tugas baru").
  Set<String>? _dikenal;

  /// Id kartu yang sedang disorot (border tebal sementara).
  final Set<String> _disorot = <String>{};

  final List<Timer> _timerSorot = <Timer>[];

  /// Id tugas yang sedang ditulis statusnya lewat "Terima & datangi"; tombolnya
  /// nonaktif + berputar supaya tidak ada tulis ganda saat petugas menekan dua kali.
  final Set<String> _memuatTerima = <String>{};

  @override
  void dispose() {
    for (final t in _timerSorot) {
      t.cancel();
    }
    _gulir.dispose();
    super.dispose();
  }

  /// Berlangganan ulang daftar tugas setelah gagal memuat (tombol "Coba lagi").
  void _cobaLagi() {
    setState(() {
      _stream = _service.streamSemua();
    });
  }

  /// Nav "Riwayat": gulir ke bagian tugas selesai hari ini. Bila belum ada,
  /// beri tahu lewat SnackBar (bukan tombol mati).
  void _bukaRiwayat() {
    final ctx = _judulSelesai.currentContext;
    if (ctx == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Belum ada tugas selesai hari ini.')),
        );
      return;
    }
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// Dipanggil setelah frame untuk setiap snapshot. Mendeteksi dokumen baru
  /// (bukan data awal) lalu memicu haptic, SnackBar, pengumuman TalkBack, dan
  /// sorotan kartu selama 3 detik.
  void _prosesSnapshot(List<Permintaan> data) {
    if (!mounted) return;
    final ids = data.map((e) => e.id).toSet();
    final dikenal = _dikenal;
    _dikenal = ids;
    if (dikenal == null) return; // data awal: tanpa notifikasi
    final baru = ids.difference(dikenal);
    if (baru.isEmpty) return;

    final contoh = data.firstWhere(
      (e) => baru.contains(e.id),
      orElse: () => data.first,
    );
    final pesan = contoh.dariKamera ? 'Tugas baru dari Kamera AI' : 'Tugas baru dari Aplikasi';

    HapticFeedback.mediumImpact();
    SemanticsService.sendAnnouncement(View.of(context), pesan, TextDirection.ltr);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pesan)));

    setState(() => _disorot.addAll(baru));
    _timerSorot.add(
      Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _disorot.removeAll(baru));
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: StreamBuilder<List<Permintaan>>(
          stream: _stream,
          builder: (context, snapshot) {
            final list = snapshot.data;
            if (list == null) {
              return _bingkai(
                baru: 0,
                berjalan: 0,
                selesai: 0,
                isi: snapshot.hasError
                    ? _PesanTengah(
                        text: 'Gagal memuat tugas. Periksa koneksi Anda.',
                        onRetry: _cobaLagi,
                      )
                    : const _SkeletonTugas(),
              );
            }
            WidgetsBinding.instance.addPostFrameCallback((_) => _prosesSnapshot(list));

            final aktif = list.where((e) => !e.sudahSelesai).toList();
            final selesaiHariIni = list
                .where((e) => e.sudahSelesai && _hariIni(e.diperbaruiPada))
                .toList();
            final baru = list.where((e) => e.status == StatusPermintaan.menunggu).length;
            final berjalan = list
                .where((e) => e.status != StatusPermintaan.menunggu && !e.sudahSelesai)
                .length;

            return _bingkai(
              baru: baru,
              berjalan: berjalan,
              selesai: selesaiHariIni.length,
              isi: _daftarTugas(aktif, selesaiHariIni),
            );
          },
        ),
      ),
    );
  }

  /// Kerangka layar: hero (dengan ringkasan angka) + isi + menu bawah.
  Widget _bingkai({
    required int baru,
    required int berjalan,
    required int selesai,
    required Widget isi,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _hero(baru: baru, berjalan: berjalan, selesai: selesai),
        Expanded(child: isi),
        BottomNav(
          activeColor: AppColors.redText,
          activeBackground: AppColors.redSoft,
          items: [
            const BottomNavItem(label: 'Tugas', icon: Icons.format_list_bulleted, active: true),
            BottomNavItem(label: 'Riwayat', icon: Icons.history, onTap: _bukaRiwayat),
            const BottomNavItem(label: 'Profil', icon: Icons.person_outline),
          ],
        ),
      ],
    );
  }

  Widget _hero({required int baru, required int berjalan, required int selesai}) {
    return HeroHeader(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GantiPeranPill(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Halo, ${DummyData.petugas.nama}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DummyData.petugas.peranLengkap,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const _BadgeBertugas(),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _StatCard(value: baru, label: 'Baru', color: AppColors.redPrimary)),
              const SizedBox(width: 8),
              Expanded(child: _StatCard(value: berjalan, label: 'Berjalan', color: AppColors.textPrimary)),
              const SizedBox(width: 8),
              Expanded(child: _StatCard(value: selesai, label: 'Selesai hari ini', color: AppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _daftarTugas(List<Permintaan> aktif, List<Permintaan> selesaiHariIni) {
    return SingleChildScrollView(
      controller: _gulir,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'TUGAS MASUK',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: AppColors.redText,
            ),
          ),
          const SizedBox(height: 12),
          if (aktif.isEmpty)
            const _KosongTugas()
          else
            for (final p in aktif) ...[
              _TaskCard(
                permintaan: p,
                disorot: _disorot.contains(p.id),
                onTap: () => _bukaDetail(p.id),
                onTerima: () => _terimaTugas(p.id),
                memuat: _memuatTerima.contains(p.id),
              ),
              const SizedBox(height: 12),
            ],
          if (selesaiHariIni.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'SELESAI HARI INI',
              key: _judulSelesai,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            for (final p in selesaiHariIni) ...[
              _TaskCard(
                permintaan: p,
                disorot: _disorot.contains(p.id),
                onTap: () => _bukaDetail(p.id),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }

  void _bukaDetail(String id) {
    Navigator.of(context).push(
      TransisiHalaman.masuk(
        halaman: PetugasDetailScreen(idPermintaan: id, service: widget.service),
      ),
    );
  }

  /// "Terima & datangi": majukan status tugas dari `menunggu` ke `ditugaskan`,
  /// lalu buka detailnya. Bila Firestore gagal, tugas tetap di daftar dan
  /// petugas diberi tahu lewat SnackBar — tidak ada status yang berubah diam-diam.
  Future<void> _terimaTugas(String id) async {
    if (_memuatTerima.contains(id)) return;
    setState(() => _memuatTerima.add(id));
    try {
      await _service.majukanStatus(id);
      if (!mounted) return;
      setState(() => _memuatTerima.remove(id));
      _bukaDetail(id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _memuatTerima.remove(id));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Gagal menerima tugas. Silakan coba lagi.'),
          ),
        );
    }
  }
}

/// Kerangka daftar tugas saat data pertama belum tiba: judul bagian + tiga
/// kartu bertombol, meniru bentuk daftar aslinya.
class _SkeletonTugas extends StatelessWidget {
  const _SkeletonTugas();

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      label: 'Memuat daftar tugas',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonLine(lebar: 120, tinggi: 13),
            const SizedBox(height: 12),
            for (var i = 0; i < 3; i++) ...[
              SkeletonCard(
                margin: EdgeInsets.zero,
                radius: AppRadius.card,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        SkeletonBox(width: 96, height: 28, radius: 14),
                        SizedBox(width: 8),
                        SkeletonLine(lebar: 72),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const SkeletonLine(tinggi: 18),
                    const SizedBox(height: 8),
                    const SkeletonLine(),
                    const SizedBox(height: 12),
                    const SkeletonBox(height: 50, radius: 25),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

/// Badge merah "Bertugas" pada header (putih di atas merah = 4.74:1).
class _BadgeBertugas extends StatelessWidget {
  const _BadgeBertugas();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.redPrimary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          const Text(
            'Bertugas',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Kotak ringkasan angka (Baru / Berjalan / Selesai hari ini).
class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label, required this.color});

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.block,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Kartu satu tugas. Bagian info dapat ditekan untuk membuka detail, dan di
/// bawahnya ada tombol: "Terima & datangi" (merah, tugas baru) atau
/// "Buka tugas" (pil garis, tugas yang sudah berjalan).
///
/// Tombol sengaja berada DI LUAR area tekan kartu agar tidak ada dua aksi yang
/// berebut satu ketukan, dan agar pembaca layar membacanya sebagai tombol
/// terpisah — bukan menyatu dengan label kartu.
class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.permintaan,
    required this.onTap,
    this.disorot = false,
    this.onTerima,
    this.memuat = false,
  });

  final Permintaan permintaan;
  final VoidCallback onTap;
  final bool disorot;

  /// Aksi "Terima & datangi"; null bila tugas tidak bisa diterima lagi.
  final VoidCallback? onTerima;

  /// true selama status tugas sedang ditulis.
  final bool memuat;

  @override
  Widget build(BuildContext context) {
    final p = permintaan;
    final status = _statusInfo(p);
    final waktu = _waktuRelatif(p.dibuatPada ?? p.diperbaruiPada);
    final judul = p.dariKamera ? 'Penumpang belum diketahui' : _judulAplikasi(p);
    final subjudul = p.dariKamera ? _subjudulKamera(p) : _subjudulAplikasi(p);
    final bisaDiterima = p.status == StatusPermintaan.menunggu;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: disorot
            ? Border.all(color: AppColors.redPrimary, width: 3)
            : Border.all(color: AppColors.outline),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: '$judul. $subjudul. ${status.label}. $waktu',
            child: ExcludeSemantics(
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _SumberBadge(dariKamera: p.dariKamera),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            status.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: status.color),
                          ),
                        ),
                        if (waktu.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              waktu,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      judul,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subjudul,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!p.sudahSelesai) ...[
            const SizedBox(height: 12),
            if (bisaDiterima && onTerima != null)
              PillButton(
                height: 50,
                onPressed: memuat ? null : onTerima,
                child: memuat
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text(
                        'Terima & datangi',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
              )
            else
              SecondaryPillButton(
                height: 50,
                onPressed: onTap,
                label: 'Buka tugas',
              ),
          ],
        ],
      ),
    );
  }
}

/// Badge sumber tugas: "Kamera AI" (merah muda) atau "Aplikasi" (abu blok).
class _SumberBadge extends StatelessWidget {
  const _SumberBadge({required this.dariKamera});

  final bool dariKamera;

  @override
  Widget build(BuildContext context) {
    final bg = dariKamera ? AppColors.redSoft : AppColors.block;
    final fg = dariKamera ? AppColors.redText : AppColors.textPrimary;
    final ikon = dariKamera ? Icons.photo_camera_outlined : Icons.smartphone;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 15, color: fg),
          const SizedBox(width: 6),
          Text(
            dariKamera ? 'Kamera AI' : 'Aplikasi',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: fg),
          ),
        ],
      ),
    );
  }
}

/// Tampilan saat tidak ada tugas aktif.
class _KosongTugas extends StatelessWidget {
  const _KosongTugas();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.outline),
        boxShadow: AppShadows.cardSoft,
      ),
      child: const Text(
        'Belum ada tugas aktif. Tugas baru akan muncul di sini secara otomatis.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
      ),
    );
  }
}

/// Pesan di tengah layar (loading error).
class _PesanTengah extends StatelessWidget {
  const _PesanTengah({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              SecondaryPillButton(onPressed: onRetry, label: 'Coba lagi', height: 52),
            ],
          ],
        ),
      ),
    );
  }
}

/// Label + warna status untuk badge kecil di kartu. Status selalu berupa
/// teks (tidak pernah hanya warna); nada mengikuti palet Brightline.
({String label, Color color}) _statusInfo(Permintaan p) {
  switch (p.status) {
    case StatusPermintaan.menunggu:
      return p.dariKamera
          ? (label: 'Baru', color: AppColors.redText)
          : (label: 'Menunggu petugas', color: AppColors.textSecondary);
    case StatusPermintaan.ditugaskan:
      return (label: 'Ditugaskan ke Anda', color: AppColors.textPrimary);
    case StatusPermintaan.bertemu:
      return (label: 'Bertemu penumpang', color: AppColors.textPrimary);
    case StatusPermintaan.diKursi:
      return (label: 'Penumpang di kursi', color: AppColors.textPrimary);
    case StatusPermintaan.selesai:
      return (label: 'Selesai', color: AppColors.textMuted);
  }
}

String _judulAplikasi(Permintaan p) {
  final nama = (p.namaPenumpang == null || p.namaPenumpang!.isEmpty) ? 'Penumpang' : p.namaPenumpang!;
  return '$nama · ${p.jenisBantuan.label}';
}

String _subjudulAplikasi(Permintaan p) {
  final bagian = <String>[];
  if (p.titikJemput.isNotEmpty) bagian.add(p.titikJemput);
  if (p.kereta != null && p.kereta!.isNotEmpty && p.jamBerangkat != null && p.jamBerangkat!.isNotEmpty) {
    bagian.add('${p.kereta} ${p.jamBerangkat}');
  } else if (p.kereta != null && p.kereta!.isNotEmpty) {
    bagian.add(p.kereta!);
  }
  if (p.gerbong != null && p.gerbong!.isNotEmpty && p.kursi != null && p.kursi!.isNotEmpty) {
    bagian.add('Gerbong ${p.gerbong}, Kursi ${p.kursi}');
  }
  return bagian.join(' · ');
}

String _subjudulKamera(Permintaan p) {
  final bagian = <String>[p.lokasiSingkat];
  final persen = p.persenKeyakinan;
  if (persen != null) bagian.add('keyakinan $persen%');
  return bagian.where((e) => e.isNotEmpty).join(' · ');
}

/// Waktu relatif singkat dari sebuah timestamp, mis. "baru saja", "3 menit lalu".
String _waktuRelatif(DateTime? waktu) {
  if (waktu == null) return '';
  final beda = DateTime.now().difference(waktu);
  if (beda.inMinutes < 1) return 'baru saja';
  if (beda.inMinutes < 60) return '${beda.inMinutes} menit lalu';
  if (beda.inHours < 24) return '${beda.inHours} jam lalu';
  return '${beda.inDays} hari lalu';
}

/// true bila [waktu] jatuh pada hari ini (null dianggap bukan hari ini).
bool _hariIni(DateTime? waktu) {
  if (waktu == null) return false;
  final now = DateTime.now();
  return waktu.year == now.year && waktu.month == now.month && waktu.day == now.day;
}
