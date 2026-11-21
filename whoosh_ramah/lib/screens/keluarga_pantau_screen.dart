import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

import '../data/dummy.dart';
import '../models/permintaan.dart';
import '../services/permintaan_service.dart';
import '../theme.dart';
import '../widgets/ganti_peran_pill.dart';
import '../widgets/hero_header.dart';
import 'segera_hadir_screen.dart';

/// Layar 7 — Pantau perjalanan (design/Keluarga-Pantau.dc.html).
///
/// Mendengarkan permintaan TERBARU milik `idPenumpang` demo (default
/// `demo-siti`) lalu menampilkan kartu status saat ini, progres perjalanan, dan
/// riwayat berjam. Perubahan status diumumkan ke TalkBack lewat
/// [SemanticsService.sendAnnouncement] (pola sama dengan layar status penumpang).
class KeluargaPantauScreen extends StatefulWidget {
  const KeluargaPantauScreen({super.key, this.service, this.idPenumpang});

  /// Opsional: injeksi service (memudahkan pengujian).
  final PermintaanService? service;

  /// Opsional: id penumpang; default dari data dummy (`demo-siti`).
  final String? idPenumpang;

  @override
  State<KeluargaPantauScreen> createState() => _KeluargaPantauScreenState();
}

class _KeluargaPantauScreenState extends State<KeluargaPantauScreen> {
  late final PermintaanService _service = widget.service ?? PermintaanService();
  late final String _idPenumpang =
      widget.idPenumpang ?? DummyData.penumpang.idPenumpang;
  late final Stream<Permintaan?> _stream = _service.streamTerbaruPenumpang(
    _idPenumpang,
  );

  /// Status terakhir yang sudah diumumkan, agar hanya mengumumkan saat berubah.
  StatusPermintaan? _statusTerakhir;

  String get _nama => DummyData.penumpang.namaPenumpang;
  String get _namaDepan => _nama.trim().split(RegExp(r'\s+')).first;

  /// Pesan yang diumumkan ke TalkBack saat status berubah.
  static String _pesanStatus(StatusPermintaan s) {
    switch (s) {
      case StatusPermintaan.menunggu:
        return 'Status: Permintaan diterima. Sedang mencari petugas.';
      case StatusPermintaan.ditugaskan:
        return 'Status: Petugas sudah ditugaskan.';
      case StatusPermintaan.bertemu:
        return 'Status: Petugas menuju penumpang.';
      case StatusPermintaan.diKursi:
        return 'Status: Penumpang sudah duduk di kursi.';
      case StatusPermintaan.selesai:
        return 'Status: Pendampingan selesai.';
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
              return _kerangkaPesan('Gagal memuat pantauan. Periksa koneksi Anda.');
            }
            final p = snapshot.data;
            if (p == null) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _kerangkaPesan(null, loading: true);
              }
              return _kerangkaKosong();
            }
            _umumkanBilaBerubah(p.status);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _hero(),
                        // Kartu status menumpuk hero 52px (setara `margin: -52px
                        // 18px 0` di design; Flutter melarang margin negatif).
                        Transform.translate(
                          offset: const Offset(0, -52),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _kartuStatus(p),
                              _kartuPerjalanan(p),
                              _kartuRiwayat(p),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _barBawah(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _hero() {
    return HeroHeader(
      color: AppColors.greenHero,
      borderRadius: 36,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 70),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GantiPeranPill(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(
              'Perjalanan Ibu $_namaDepan',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Dibagikan oleh $_nama · diperbarui otomatis',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3F5A4B),
            ),
          ),
        ],
      ),
    );
  }

  /// Kerangka loading / error: hero + pesan di tengah.
  Widget _kerangkaPesan(String? pesan, {bool loading = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _hero(),
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

  /// Empty state: penumpang belum pernah meminta pendampingan.
  Widget _kerangkaKosong() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _hero(),
        Expanded(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.card),
                boxShadow: AppShadows.cardSoft,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: AppColors.greenHero,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.groups_outlined,
                      size: 28,
                      color: AppColors.greenFamily,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$_namaDepan belum memesan pendampingan',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Minta $_namaDepan memesan lewat aplikasi, lalu halaman ini '
                    'akan terisi otomatis.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Kartu status saat ini: jam, label status besar, dan petugas (bila ada).
  Widget _kartuStatus(Permintaan p) {
    final jam = _jamStatus(p);
    final petugas = _teksPetugas(p);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.cardLarge),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.greenFamily,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 26, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  jam == null ? 'STATUS SAAT INI' : 'STATUS SAAT INI · $jam',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: AppColors.greenFamily,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _teksStatusBesar(p),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isi(p.namaPenumpang, _nama),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (petugas != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    petugas,
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
        ],
      ),
    );
  }

  /// Kartu progres perjalanan: rute, bar, jam, dan kereta/gerbong/kursi.
  Widget _kartuPerjalanan(Permintaan p) {
    final asal = _isi(p.stasiunAsal, DummyData.tiket.stasiunAsal);
    final tujuan = _isi(p.stasiunTujuan, DummyData.tiket.stasiunTujuan);
    final kereta = _isi(p.kereta, DummyData.tiket.kereta);
    final gerbong = _isi(p.gerbong, DummyData.tiket.gerbong);
    final kursi = _isi(p.kursi, DummyData.tiket.kursi);
    final berangkat = _isi(p.jamBerangkat, DummyData.tiket.jamBerangkat);
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: _teksStasiun(asal)),
              const SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _teksStasiun(tujuan),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _barPerjalanan(p.status),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text('Berangkat $berangkat', style: _gayaKecil)),
              const SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text('Tiba ± ${DummyData.tiket.jamTiba}', style: _gayaKecil),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.train, size: 16, color: AppColors.greenFamily),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$kereta · Gerbong $gerbong, Kursi $kursi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const TextStyle _gayaKecil = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
  );

  Widget _teksStasiun(String nama) {
    return Text(
      nama,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
      ),
    );
  }

  /// Bar progres + penanda kereta. Fraksi mengikuti urutan 5 status.
  Widget _barPerjalanan(StatusPermintaan status) {
    final idx = StatusPermintaan.values.indexOf(status);
    final fraksi = idx / (StatusPermintaan.values.length - 1);
    return LayoutBuilder(
      builder: (context, constraints) {
        const sisi = 30.0;
        final lebar = constraints.maxWidth;
        final kiri = (lebar - sisi) * fraksi;
        return SizedBox(
          height: sisi,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 11,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1E7E3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 11,
                width: kiri + sisi / 2,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.greenFamily,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Positioned(
                left: kiri,
                top: 0,
                child: Container(
                  width: sisi,
                  height: sisi,
                  decoration: BoxDecoration(
                    color: AppColors.greenFamily,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(Icons.train, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Kartu riwayat: entri `riwayat` terbaru di atas + baris "Berikutnya".
  Widget _kartuRiwayat(Permintaan p) {
    final terbaruDulu = p.riwayat.reversed.toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'RIWAYAT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          for (final r in terbaruDulu) ...[
            _BarisRiwayat(
              label: _labelRiwayat(StatusPermintaan.dariValue(r.status), p),
              waktu: r.waktu == null ? null : DateFormat('HH.mm').format(r.waktu!),
              selesai: true,
            ),
            const SizedBox(height: 10),
          ],
          if (p.status != StatusPermintaan.selesai)
            _BarisRiwayat(label: 'Berikutnya: ${_teksBerikutnya(p)}'),
        ],
      ),
    );
  }

  Widget _barBawah() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TombolHijau(
            label: 'Hubungi petugas',
            onTap: () => _segeraHadir('Hubungi petugas'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Anda mendapat notifikasi setiap status berubah',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _segeraHadir(String judul) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SegeraHadirScreen(title: judul)),
    );
  }

  /// Jam (HH.mm) status saat ini: `diperbaruiPada`, fallback entri riwayat terakhir.
  static String? _jamStatus(Permintaan p) {
    final waktu = p.diperbaruiPada ??
        (p.riwayat.isEmpty ? null : p.riwayat.last.waktu);
    if (waktu == null) return null;
    return DateFormat('HH.mm').format(waktu);
  }

  /// Label status besar (selalu berupa teks, bukan hanya warna).
  static String _teksStatusBesar(Permintaan p) {
    switch (p.status) {
      case StatusPermintaan.menunggu:
        return 'Menunggu petugas';
      case StatusPermintaan.ditugaskan:
        return 'Petugas sudah ditugaskan';
      case StatusPermintaan.bertemu:
        return 'Petugas bertemu penumpang';
      case StatusPermintaan.diKursi:
        final g = _isi(p.gerbong, DummyData.tiket.gerbong);
        final k = _isi(p.kursi, DummyData.tiket.kursi);
        return 'Sudah duduk di Gerbong $g, Kursi $k';
      case StatusPermintaan.selesai:
        final tujuan = _isi(p.stasiunTujuan, DummyData.tiket.stasiunTujuan);
        return 'Tiba di $tujuan · pendampingan selesai';
    }
  }

  /// Baris petugas: hanya tampil bila `petugas` sudah terisi dokumen.
  static String? _teksPetugas(Permintaan p) {
    final nama = p.petugas;
    if (nama == null || nama.isEmpty) return null;
    return 'Didampingi $nama, ${DummyData.petugas.peranLengkap}';
  }

  /// Label satu entri riwayat.
  static String _labelRiwayat(StatusPermintaan s, Permintaan p) {
    switch (s) {
      case StatusPermintaan.menunggu:
        return 'Permintaan dibuat';
      case StatusPermintaan.ditugaskan:
        return 'Petugas ditugaskan';
      case StatusPermintaan.bertemu:
        return 'Bertemu petugas';
      case StatusPermintaan.diKursi:
        final k = _isi(p.kursi, DummyData.tiket.kursi);
        return 'Sudah di kursi $k';
      case StatusPermintaan.selesai:
        final tujuan = _isi(p.stasiunTujuan, DummyData.tiket.stasiunTujuan);
        return 'Dijemput petugas di $tujuan';
    }
  }

  /// Teks langkah berikutnya pada baris abu-abu riwayat.
  static String _teksBerikutnya(Permintaan p) {
    switch (p.status) {
      case StatusPermintaan.menunggu:
        return 'petugas ditugaskan';
      case StatusPermintaan.ditugaskan:
        return 'bertemu petugas';
      case StatusPermintaan.bertemu:
        final k = _isi(p.kursi, DummyData.tiket.kursi);
        return 'duduk di kursi $k';
      case StatusPermintaan.diKursi:
        final tujuan = _isi(p.stasiunTujuan, DummyData.tiket.stasiunTujuan);
        return 'dijemput di $tujuan';
      case StatusPermintaan.selesai:
        return 'selesai';
    }
  }

  static String _isi(String? nilai, String fallback) =>
      (nilai == null || nilai.isEmpty) ? fallback : nilai;
}

/// Satu baris riwayat: centang hijau (selesai) / lingkaran abu (berikutnya).
class _BarisRiwayat extends StatelessWidget {
  const _BarisRiwayat({required this.label, this.waktu, this.selesai = false});

  final String label;
  final String? waktu;
  final bool selesai;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          selesai ? Icons.check : Icons.circle_outlined,
          size: 20,
          color: selesai ? AppColors.greenFamily : const Color(0xFF9AA0AC),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selesai ? FontWeight.w800 : FontWeight.w700,
              color: selesai ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
        if (waktu != null) ...[
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
    );
  }
}

/// Tombol utama hijau "Hubungi petugas".
class _TombolHijau extends StatelessWidget {
  const _TombolHijau({required this.label, required this.onTap});

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
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.greenFamily,
              borderRadius: BorderRadius.circular(29),
              boxShadow: const [
                BoxShadow(color: Color(0x4017663F), blurRadius: 22, offset: Offset(0, 10)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.call, size: 20, color: Colors.white),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
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
