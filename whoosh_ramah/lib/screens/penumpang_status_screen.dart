import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

import '../data/dummy.dart';
import '../models/permintaan.dart';
import '../services/permintaan_service.dart';
import '../theme.dart';
import '../widgets/hero_back_button.dart';
import '../widgets/hero_header.dart';
import 'segera_hadir_screen.dart';

/// Layar 3 — Status pendampingan penumpang (design/Penumpang-Status.dc.html).
///
/// Mendengarkan [PermintaanService.streamPermintaan] secara real-time dan
/// menampilkan: pill status di hero, kartu petugas (muncul setelah `ditugaskan`,
/// sebelumnya "Mencari petugas…"), timeline 5 langkah (lewati = centang, aktif =
/// disorot, berikutnya = abu-abu, masing-masing berlabel teks + jam dari riwayat),
/// serta tombol aksi. Perubahan status diumumkan ke TalkBack lewat
/// [SemanticsService.announce]. Tombol kembali menuju layar tiket.
class PenumpangStatusScreen extends StatefulWidget {
  const PenumpangStatusScreen({
    super.key,
    required this.idPermintaan,
    this.service,
  });

  /// Id dokumen `permintaan_pendampingan` yang dibuat di layar pesan.
  final String idPermintaan;

  /// Opsional: injeksi service (memudahkan pengujian).
  final PermintaanService? service;

  @override
  State<PenumpangStatusScreen> createState() => _PenumpangStatusScreenState();
}

class _PenumpangStatusScreenState extends State<PenumpangStatusScreen> {
  late final PermintaanService _service = widget.service ?? PermintaanService();
  late final Stream<Permintaan?> _stream = _service.streamPermintaan(
    widget.idPermintaan,
  );

  /// Status terakhir yang sudah diumumkan, agar hanya mengumumkan saat berubah.
  StatusPermintaan? _statusTerakhir;

  /// Label tiap langkah timeline; langkah terakhir memakai `stasiunTujuan`.
  static String _labelLangkah(StatusPermintaan s, Permintaan p) {
    switch (s) {
      case StatusPermintaan.menunggu:
        return 'Permintaan diterima';
      case StatusPermintaan.ditugaskan:
        return 'Petugas ditugaskan';
      case StatusPermintaan.bertemu:
        return 'Bertemu petugas';
      case StatusPermintaan.diKursi:
        final g = (p.gerbong == null || p.gerbong!.isEmpty) ? '-' : p.gerbong;
        final k = (p.kursi == null || p.kursi!.isEmpty) ? '-' : p.kursi;
        return 'Duduk di Gerbong $g, Kursi $k';
      case StatusPermintaan.selesai:
        final tujuan = (p.stasiunTujuan == null || p.stasiunTujuan!.isEmpty)
            ? 'tujuan'
            : p.stasiunTujuan;
        return 'Dijemput petugas di $tujuan';
    }
  }

  /// Pesan yang diumumkan ke TalkBack saat status berubah.
  static String _pesanStatus(StatusPermintaan s) {
    switch (s) {
      case StatusPermintaan.menunggu:
        return 'Status: Permintaan diterima. Sedang mencari petugas.';
      case StatusPermintaan.ditugaskan:
        return 'Status: Petugas sudah ditugaskan.';
      case StatusPermintaan.bertemu:
        return 'Status: Petugas menuju Anda.';
      case StatusPermintaan.diKursi:
        return 'Status: Anda sudah duduk di kursi.';
      case StatusPermintaan.selesai:
        return 'Status: Pendampingan selesai.';
    }
  }

  /// Ringkasan status untuk pill di hero (label, warna, ikon).
  static ({String label, Color color, IconData icon}) _ringkasan(
    StatusPermintaan s,
  ) {
    switch (s) {
      case StatusPermintaan.menunggu:
        return (
          label: 'Mencari petugas…',
          color: AppColors.textSecondary,
          icon: Icons.hourglass_bottom,
        );
      case StatusPermintaan.ditugaskan:
        return (
          label: 'Petugas sudah ditugaskan',
          color: AppColors.greenFamily,
          icon: Icons.check,
        );
      case StatusPermintaan.bertemu:
        return (
          label: 'Petugas menuju Anda',
          color: AppColors.greenFamily,
          icon: Icons.check,
        );
      case StatusPermintaan.diKursi:
        return (
          label: 'Anda sudah di kursi',
          color: AppColors.greenFamily,
          icon: Icons.check,
        );
      case StatusPermintaan.selesai:
        return (
          label: 'Pendampingan selesai',
          color: AppColors.greenFamily,
          icon: Icons.check,
        );
    }
  }

  /// Jam (HH.mm) dari entri riwayat untuk status [s], atau null bila tidak ada.
  static String? _jamRiwayat(Permintaan p, StatusPermintaan s) {
    for (final r in p.riwayat.reversed) {
      if (r.status == s.value && r.waktu != null) {
        return DateFormat('HH.mm').format(r.waktu!);
      }
    }
    return null;
  }

  void _kembaliKeTiket() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop(); // kembali ke layar tiket (layar pesan sudah di-replace)
    } else {
      nav.pushReplacement(
        MaterialPageRoute(
          builder: (_) => const SegeraHadirScreen(title: 'Tiket'),
        ),
      );
    }
  }

  /// Umumkan perubahan status ke TalkBack (hanya saat berbeda dari sebelumnya).
  void _umumkanBilaBerubah(StatusPermintaan status) {
    if (_statusTerakhir == status) return;
    final pertama = _statusTerakhir == null;
    _statusTerakhir = status;
    if (pertama) return; // jangan umumkan saat pertama kali layar dibuka
    final view = View.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SemanticsService.sendAnnouncement(
        view,
        _pesanStatus(status),
        TextDirection.ltr,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: StreamBuilder<Permintaan?>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _layarPesan(
                _hero(null),
                'Gagal memuat status. Periksa koneksi Anda.',
              );
            }
            final p = snapshot.data;
            if (p == null) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _layarPesan(_hero(null), null, loading: true);
              }
              return _layarPesan(_hero(null), 'Permintaan tidak ditemukan.');
            }
            _umumkanBilaBerubah(p.status);
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _hero(p),
                  // Seluruh isi di bawah hero digeser naik 52px agar kartu petugas
                  // menumpuk hero (setara `margin: -52px 18px 0` di design; Flutter
                  // melarang margin/padding negatif pada Container/Padding).
                  Transform.translate(
                    offset: const Offset(0, -52),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _kartuPetugas(p),
                        _kartuTimeline(p),
                        const SizedBox(height: 16),
                        _tombolBawah(p),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Hero: tombol kembali + judul (+ pill status bila data tersedia).
  Widget _hero(Permintaan? p) {
    return HeroHeader(
      color: AppColors.pinkHero,
      borderRadius: 40,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 70),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HeroBackButton(label: 'Kembali ke tiket', onTap: _kembaliKeTiket),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Pendampingan Anda',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (p != null) ...[
            const SizedBox(height: 14),
            _StatusPill(ringkasan: _ringkasan(p.status)),
          ],
        ],
      ),
    );
  }

  /// Kerangka untuk state loading / error / tidak ditemukan: hero + pesan di tengah.
  Widget _layarPesan(Widget hero, String? pesan, {bool loading = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        hero,
        Expanded(
          child: Center(
            child: loading
                ? const CircularProgressIndicator()
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      pesan ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// Kartu petugas (menumpuk hero). Sebelum `ditugaskan`: "Mencari petugas…".
  Widget _kartuPetugas(Permintaan p) {
    final sudahDitugaskan = p.status != StatusPermintaan.menunggu;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.cardLarge),
        boxShadow: AppShadows.card,
      ),
      child: sudahDitugaskan ? _isiKartuPetugas(p) : _mencariPetugas(),
    );
  }

  Widget _mencariPetugas() {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            color: AppColors.innerGray,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_search,
            size: 30,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Mencari petugas…',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Kami sedang menghubungkan Anda dengan petugas layanan.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _isiKartuPetugas(Permintaan p) {
    final nama = (p.petugas == null || p.petugas!.isEmpty)
        ? DummyData.petugas.nama
        : p.petugas!;
    final lokasi = p.titikJemput.isEmpty
        ? DummyData.titikJemput.first
        : p.titikJemput;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: AppColors.pinkHero,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _inisial(nama),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.redText,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    nama,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DummyData.petugas.peranLengkap,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.innerGray,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Menunggu Anda di',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                lokasi,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _TombolGaris(
                label: 'Kirim pesan',
                icon: Icons.chat_bubble_outline,
                height: 48,
                onTap: () => _segeraHadir('Kirim pesan'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TombolGaris(
                label: 'Telepon',
                icon: Icons.call_outlined,
                height: 48,
                onTap: () => _segeraHadir('Telepon'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Timeline 5 langkah.
  Widget _kartuTimeline(Permintaan p) {
    final selesai = p.status == StatusPermintaan.selesai;
    final idxAktif = StatusPermintaan.values.indexOf(p.status);
    final langkah = StatusPermintaan.values;
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Column(
        children: [
          for (var i = 0; i < langkah.length; i++)
            _TimelineStep(
              label: _labelLangkah(langkah[i], p),
              waktu: _jamRiwayat(p, langkah[i]),
              state: selesai
                  ? _StepState.lewati
                  : (i < idxAktif
                        ? _StepState.lewati
                        : (i == idxAktif
                              ? _StepState.aktif
                              : _StepState.berikutnya)),
              isLast: i == langkah.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _tombolBawah(Permintaan p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CtaUtama(
            label: 'Saya sudah sampai di lobi',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Terima kasih, petugas sudah diberi tahu.'),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _TombolGaris(
            label: 'Bagikan ke keluarga',
            icon: Icons.share,
            height: 52,
            onTap: () => _segeraHadir('Bagikan ke keluarga'),
          ),
        ],
      ),
    );
  }

  void _segeraHadir(String judul) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SegeraHadirScreen(title: judul)));
  }

  /// Inisial untuk avatar: huruf pertama tiap kata (maks 2), atau 2 huruf pertama.
  static String _inisial(String nama) {
    final kata = nama
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (kata.isEmpty) return '';
    if (kata.length == 1) {
      final w = kata.first;
      return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
    }
    return (kata[0][0] + kata[1][0]).toUpperCase();
  }
}

enum _StepState { lewati, aktif, berikutnya }

/// Pill status di hero (ikon + label, warna mengikuti status).
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.ringkasan});

  final ({String label, Color color, IconData icon}) ringkasan;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: ringkasan.label,
      child: Container(
        height: 40,
        padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: ringkasan.color,
                shape: BoxShape.circle,
              ),
              child: Icon(ringkasan.icon, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(
              ringkasan.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: ringkasan.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu langkah pada timeline: penanda (centang/aktif/abu-abu) + label + jam.
class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.state,
    required this.isLast,
    this.waktu,
  });

  final String label;
  final _StepState state;
  final bool isLast;
  final String? waktu;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Column(
            children: [
              _penanda(),
              if (!isLast)
                Container(
                  width: 3,
                  height: 18,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: state == _StepState.lewati
                        ? AppColors.greenFamily
                        : AppColors.connector,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _label()),
                if (waktu != null && state == _StepState.lewati) ...[
                  const SizedBox(width: 8),
                  Text(
                    waktu!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _penanda() {
    switch (state) {
      case _StepState.lewati:
        return Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.greenFamily,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 16, color: Colors.white),
        );
      case _StepState.aktif:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.redPrimary, width: 4),
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.redPrimary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      case _StepState.berikutnya:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _abuLingkaran, width: 3),
          ),
        );
    }
  }

  Widget _label() {
    switch (state) {
      case _StepState.lewati:
        return Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        );
      case _StepState.aktif:
        return Text(
          '$label · sekarang',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: AppColors.redText,
          ),
        );
      case _StepState.berikutnya:
        return Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        );
    }
  }
}

/// Warna abu-abu lingkaran langkah berikutnya (#C9CDD6 pada design).
const Color _abuLingkaran = Color(0xFFC9CDD6);

/// Tombol garis (outline) dengan ikon + label.
class _TombolGaris extends StatelessWidget {
  const _TombolGaris({
    required this.label,
    required this.icon,
    required this.onTap,
    this.height = 48,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(color: AppColors.outline, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: AppColors.textPrimary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
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

/// Tombol utama merah dengan bayangan (CTA "Saya sudah sampai di lobi").
class _CtaUtama extends StatelessWidget {
  const _CtaUtama({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.redPrimary,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x47E11D2E),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
