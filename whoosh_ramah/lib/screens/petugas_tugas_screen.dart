import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../data/dummy.dart';
import '../models/permintaan.dart';
import '../services/permintaan_service.dart';
import '../theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/ganti_peran_pill.dart';
import '../widgets/hero_header.dart';
import 'petugas_detail_screen.dart';

/// Warna teks kuning-cokelat status "Menunggu petugas" (design Petugas-Tugas).
const Color _cokelatMenunggu = Color(0xFF8A5A00);

/// Warna teks keterangan pada hero petugas (design: #3E4A66).
const Color _teksHeroPetugas = Color(0xFF3E4A66);

/// Layar 5 — Daftar tugas petugas (design/Petugas-Tugas.dc.html).
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
  late final Stream<List<Permintaan>> _stream = _service.streamSemua();

  /// Id yang sudah dikenal; null berarti snapshot pertama belum diproses
  /// (data awal tidak boleh memicu notifikasi "tugas baru").
  Set<String>? _dikenal;

  /// Id kartu yang sedang disorot (border tebal sementara).
  final Set<String> _disorot = <String>{};

  final List<Timer> _timerSorot = <Timer>[];

  @override
  void dispose() {
    for (final t in _timerSorot) {
      t.cancel();
    }
    super.dispose();
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
                    ? const _PesanTengah(text: 'Gagal memuat tugas. Periksa koneksi Anda.')
                    : const Center(child: CircularProgressIndicator()),
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
          activeColor: AppColors.blueOfficer,
          activeBackground: AppColors.blueHero,
          items: const [
            BottomNavItem(label: 'Tugas', icon: Icons.format_list_bulleted, active: true),
            BottomNavItem(label: 'Riwayat', icon: Icons.history),
            BottomNavItem(label: 'Profil', icon: Icons.person_outline),
          ],
        ),
      ],
    );
  }

  Widget _hero({required int baru, required int berjalan, required int selesai}) {
    return HeroHeader(
      color: AppColors.blueHero,
      borderRadius: 36,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
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
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DummyData.petugas.peranLengkap,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _teksHeroPetugas,
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
              Expanded(child: _StatCard(value: berjalan, label: 'Berjalan', color: AppColors.blueOfficer)),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'TUGAS MASUK',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
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
              ),
              const SizedBox(height: 12),
            ],
          if (selesaiHariIni.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Text(
              'SELESAI HARI INI',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: AppColors.textSecondary,
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
      MaterialPageRoute(
        builder: (_) => PetugasDetailScreen(idPermintaan: id, service: widget.service),
      ),
    );
  }
}

/// Badge hijau "Bertugas" pada hero.
class _BadgeBertugas extends StatelessWidget {
  const _BadgeBertugas();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.greenFamily,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color),
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

/// Kartu satu tugas. Seluruh kartu dapat ditekan untuk membuka detail.
class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.permintaan, required this.onTap, this.disorot = false});

  final Permintaan permintaan;
  final VoidCallback onTap;
  final bool disorot;

  @override
  Widget build(BuildContext context) {
    final p = permintaan;
    final status = _statusInfo(p);
    final waktu = _waktuRelatif(p.dibuatPada ?? p.diperbaruiPada);
    final judul = p.dariKamera ? 'Penumpang belum diketahui' : _judulAplikasi(p);
    final subjudul = p.dariKamera ? _subjudulKamera(p) : _subjudulAplikasi(p);

    return MergeSemantics(
      child: Semantics(
        button: true,
        label: '$judul. $subjudul. ${status.label}. $waktu',
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: disorot ? Border.all(color: AppColors.blueOfficer, width: 3) : null,
              boxShadow: AppShadows.card,
            ),
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
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: status.color),
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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
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
    );
  }
}

/// Badge sumber tugas: "Kamera AI" (merah muda) atau "Aplikasi" (biru).
class _SumberBadge extends StatelessWidget {
  const _SumberBadge({required this.dariKamera});

  final bool dariKamera;

  @override
  Widget build(BuildContext context) {
    final bg = dariKamera ? AppColors.pinkHero : AppColors.blueHero;
    final fg = dariKamera ? AppColors.redText : AppColors.blueOfficer;
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
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: fg),
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
  const _PesanTengah({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

/// Label + warna status untuk badge kecil di kartu.
({String label, Color color}) _statusInfo(Permintaan p) {
  switch (p.status) {
    case StatusPermintaan.menunggu:
      return p.dariKamera
          ? (label: 'Baru', color: AppColors.redText)
          : (label: 'Menunggu petugas', color: _cokelatMenunggu);
    case StatusPermintaan.ditugaskan:
      return (label: 'Ditugaskan ke Anda', color: AppColors.blueOfficer);
    case StatusPermintaan.bertemu:
      return (label: 'Bertemu penumpang', color: AppColors.blueOfficer);
    case StatusPermintaan.diKursi:
      return (label: 'Penumpang di kursi', color: AppColors.blueOfficer);
    case StatusPermintaan.selesai:
      return (label: 'Selesai', color: AppColors.greenFamily);
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
