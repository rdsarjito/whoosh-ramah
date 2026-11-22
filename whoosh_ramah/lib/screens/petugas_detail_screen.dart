import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

import '../models/permintaan.dart';
import '../services/permintaan_service.dart';
import '../theme.dart';
import '../transisi.dart';
import '../widgets/foto_cuplikan.dart';
import '../widgets/hero_back_button.dart';
import '../widgets/hero_header.dart';
import '../widgets/secondary_pill_button.dart';
import '../widgets/skeleton.dart';
import 'segera_hadir_screen.dart';

/// Layar 6 — Detail tugas petugas, gaya Brightline (kanvas putih, kartu
/// radius 22, stepper merah, satu tombol aksi merah merek).
///
/// Mendengarkan satu dokumen. Menampilkan info penumpang (atau "Penumpang belum
/// diketahui" + lokasi & keyakinan untuk tugas kamera AI), stepper 5 status,
/// catatan, dan satu tombol besar yang teksnya mengikuti status saat ini.
class PetugasDetailScreen extends StatefulWidget {
  const PetugasDetailScreen({super.key, required this.idPermintaan, this.service});

  final String idPermintaan;

  /// Opsional: injeksi service (memudahkan pengujian).
  final PermintaanService? service;

  @override
  State<PetugasDetailScreen> createState() => _PetugasDetailScreenState();
}

class _PetugasDetailScreenState extends State<PetugasDetailScreen> {
  late final PermintaanService _service = widget.service ?? PermintaanService();
  late Stream<Permintaan?> _stream = _service.streamPermintaan(widget.idPermintaan);

  /// true selama `majukanStatus` berjalan (tombol dinonaktifkan + spinner).
  bool _loading = false;

  /// true selama `tolakTugas` berjalan (tombol tolak dinonaktifkan).
  bool _menolak = false;

  /// Berlangganan ulang dokumen setelah gagal memuat (tombol "Coba lagi").
  void _cobaLagi() {
    setState(() {
      _stream = _service.streamPermintaan(widget.idPermintaan);
    });
  }

  Future<void> _majukan() async {
    setState(() => _loading = true);
    try {
      await _service.majukanStatus(widget.idPermintaan);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memperbarui status. Silakan coba lagi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// "Bukan penumpang / tolak" (O1 + A3): konfirmasi dulu lewat dialog, lalu
  /// tulis `ditolakPada` + `alasanTolak`. Status & riwayat tidak disentuh;
  /// tugas keluar dari daftar aktif. Setelah berhasil, kembali ke daftar.
  Future<void> _tolak() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tolak tugas ini?'),
        content: const Text(
          'Tugas akan ditandai bukan penumpang dan keluar dari daftar aktif. '
          'Gunakan bila kamera AI salah mendeteksi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;
    setState(() => _menolak = true);
    try {
      await _service.tolakTugas(
        widget.idPermintaan,
        alasan: 'Bukan pengguna kursi roda',
      );
      if (!mounted) return;
      setState(() => _menolak = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Tugas ditolak. Terima kasih sudah memeriksa.'),
          ),
        );
      Navigator.maybePop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _menolak = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Gagal menolak tugas. Silakan coba lagi.'),
          ),
        );
    }
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
            final p = snapshot.data;
            if (p == null) {
              final loading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasError;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _hero(null),
                  Expanded(
                    child: Center(
                      child: loading
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
                              child: Skeleton(
                                label: 'Memuat detail tugas',
                                child: const SkeletonRincian(jumlahBaris: 4),
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    snapshot.hasError
                                        ? 'Gagal memuat tugas. Periksa koneksi Anda.'
                                        : 'Tugas tidak ditemukan.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SecondaryPillButton(
                                    onPressed: _cobaLagi,
                                    label: 'Coba lagi',
                                    height: 52,
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _hero(p),
                        _kartuInfo(p),
                        if (p.dariKamera && p.adaFoto) _kartuFoto(p),
                        _kartuStatus(p),
                      ],
                    ),
                  ),
                ),
                _barBawah(p),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Header putih: tombol kembali + judul + badge sumber (bila data tersedia).
  Widget _hero(Permintaan? p) {
    return HeroHeader(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          HeroBackButton(
            label: 'Kembali ke daftar tugas',
            onTap: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              header: true,
              child: const Text(
                'Detail tugas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          if (p != null) ...[
            const SizedBox(width: 8),
            _BadgeSumber(dariKamera: p.dariKamera),
          ],
        ],
      ),
    );
  }

  Widget _kartuInfo(Permintaan p) {
    final nama = (p.namaPenumpang != null && p.namaPenumpang!.isNotEmpty)
        ? p.namaPenumpang!
        : 'Penumpang belum diketahui';
    final catatan = p.catatan;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.outline),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Avatar(nama: nama, dariKamera: p.dariKamera),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nama,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 26,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppColors.redSoft,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              p.jenisBantuan.label,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.redText),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _kisiInfo(_tiles(p)),
          // Kabar nyata dari penumpang: ia sudah tiba di titik jemput.
          if (p.sudahTiba) ...[
            const SizedBox(height: 14),
            _KabarTiba(waktu: p.tibaPada!),
          ],
          if (catatan != null && catatan.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.block,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Catatan: ', style: TextStyle(fontWeight: FontWeight.w800)),
                    TextSpan(text: catatan),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TombolGaris(
                  label: 'Kirim pesan',
                  onTap: () => _segeraHadir('Kirim pesan'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TombolGaris(
                  label: 'Telepon',
                  onTap: () => _segeraHadir('Telepon'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Daftar (label, nilai) untuk kotak info. Kamera AI: lokasi + keyakinan;
  /// aplikasi: titik jemput, kereta, kursi, tujuan.
  List<({String label, String value})> _tiles(Permintaan p) {
    if (p.dariKamera) {
      final list = <({String label, String value})>[
        (label: 'Lokasi', value: p.lokasiSingkat.isEmpty ? '—' : p.lokasiSingkat),
      ];
      final persen = p.persenKeyakinan;
      if (persen != null) list.add((label: 'Keyakinan', value: '$persen%'));
      return list;
    }
    final kereta = (p.kereta != null && p.kereta!.isNotEmpty)
        ? ((p.jamBerangkat != null && p.jamBerangkat!.isNotEmpty) ? '${p.kereta} · ${p.jamBerangkat}' : p.kereta!)
        : '—';
    final kursi = (p.gerbong != null && p.gerbong!.isNotEmpty && p.kursi != null && p.kursi!.isNotEmpty)
        ? 'Gerbong ${p.gerbong} · ${p.kursi}'
        : ((p.kursi != null && p.kursi!.isNotEmpty) ? p.kursi! : '—');
    return [
      (label: 'Titik jemput', value: p.titikJemput.isEmpty ? '—' : p.titikJemput),
      (label: 'Kereta', value: kereta),
      (label: 'Kursi', value: kursi),
      (label: 'Tujuan', value: (p.stasiunTujuan != null && p.stasiunTujuan!.isNotEmpty) ? p.stasiunTujuan! : '—'),
    ];
  }

  Widget _kisiInfo(List<({String label, String value})> tiles) {
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _InfoTile(label: tiles[i].label, value: tiles[i].value)),
              const SizedBox(width: 8),
              Expanded(
                child: i + 1 < tiles.length
                    ? _InfoTile(label: tiles[i + 1].label, value: tiles[i + 1].value)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Kartu cuplikan verifikasi anonim (O1, bagian 12): hanya untuk tugas
  /// Kamera AI dengan `adaFoto`. Foto dibaca dari koleksi `permintaan_foto`
  /// lewat [FotoCuplikan]; bila detektor sudah menghapusnya (TTL), widget
  /// menampilkan "Cuplikan sudah kedaluwarsa".
  Widget _kartuFoto(Permintaan p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.outline),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'CUPLIKAN KAMERA AI',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: AppColors.redText,
            ),
          ),
          const SizedBox(height: 10),
          FotoCuplikan(
            service: _service,
            idTugas: p.id,
            lokasi: p.lokasiSingkat,
          ),
          const SizedBox(height: 10),
          const Text(
            'Cuplikan anonim untuk verifikasi — otomatis terhapus setelah 10 menit.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu stepper 5 status.
  Widget _kartuStatus(Permintaan p) {
    final selesai = p.status == StatusPermintaan.selesai;
    final idx = StatusPermintaan.values.indexOf(p.status);
    final langkah = StatusPermintaan.values;
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.outline),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STATUS PENDAMPINGAN',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: AppColors.redText,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < langkah.length; i++)
            _StepRow(
              label: _labelLangkah(langkah[i], p),
              state: selesai
                  ? _StepState.done
                  : (i < idx ? _StepState.done : (i == idx ? _StepState.current : _StepState.todo)),
            ),
        ],
      ),
    );
  }

  /// Bar bawah tetap: tanda "Tugas ditolak" / "Tugas selesai", atau tombol
  /// aksi (+ tombol tolak untuk tugas Kamera AI yang masih berjalan).
  Widget _barBawah(Permintaan p) {
    final selesai = p.status == StatusPermintaan.selesai;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p.sudahDitolak)
            Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.redSoft,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Tugas ditolak · bukan penumpang',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.redText),
              ),
            )
          else if (selesai)
            Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.redSoft,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Tugas selesai · terima kasih!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.redText),
              ),
            )
          else ...[
            _TombolAksi(
              label: _labelTombol(p),
              loading: _loading,
              onPressed: _loading ? null : _majukan,
            ),
            if (p.bisaDitolak) ...[
              const SizedBox(height: 8),
              SecondaryPillButton(
                key: const Key('tombol_tolak'),
                onPressed: _menolak ? null : _tolak,
                label: _menolak ? 'Memproses…' : 'Bukan penumpang / tolak',
              ),
            ],
          ],
          const SizedBox(height: 8),
          const Text(
            'Setiap perubahan langsung terlihat oleh penumpang dan keluarga',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  void _segeraHadir(String judul) {
    Navigator.of(context).push(
      TransisiHalaman.masuk(halaman: SegeraHadirScreen(title: judul)),
    );
  }
}

/// Label tombol aksi untuk memajukan status. Mengikuti `tombolPetugas` status
/// tujuan; langkah terakhir memakai nama stasiun tujuan (fallback "tujuan").
String _labelTombol(Permintaan p) {
  final berikutnya = p.status.berikutnya;
  if (berikutnya == null) return ''; // sudah selesai (tak dipakai)
  if (berikutnya == StatusPermintaan.selesai) {
    final tujuan = (p.stasiunTujuan != null && p.stasiunTujuan!.isNotEmpty) ? p.stasiunTujuan! : 'tujuan';
    return 'Serahkan ke petugas $tujuan';
  }
  return berikutnya.tombolPetugas ?? berikutnya.label;
}

/// Label langkah pada stepper 5 status.
String _labelLangkah(StatusPermintaan s, Permintaan p) {
  switch (s) {
    case StatusPermintaan.menunggu:
      return 'Tugas masuk';
    case StatusPermintaan.ditugaskan:
      return 'Tugas diterima';
    case StatusPermintaan.bertemu:
      return 'Bertemu penumpang';
    case StatusPermintaan.diKursi:
      final k = p.kursi;
      return (k != null && k.isNotEmpty) ? 'Penumpang di kursi $k' : 'Penumpang di kursi';
    case StatusPermintaan.selesai:
      final tujuan = (p.stasiunTujuan != null && p.stasiunTujuan!.isNotEmpty) ? p.stasiunTujuan! : 'tujuan';
      return 'Diserahkan ke petugas $tujuan';
  }
}

enum _StepState { done, current, todo }

/// Satu baris langkah stepper (penanda + label).
class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 30),
      child: Row(
        children: [
          _penanda(),
          const SizedBox(width: 12),
          Expanded(child: _teks()),
        ],
      ),
    );
  }

  Widget _penanda() {
    switch (state) {
      case _StepState.done:
        return Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(color: AppColors.redPrimary, shape: BoxShape.circle),
          child: const Icon(Icons.check, size: 16, color: Colors.white),
        );
      case _StepState.current:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.redPrimary, width: 4),
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: AppColors.redPrimary, shape: BoxShape.circle),
            ),
          ),
        );
      case _StepState.todo:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.outlineControl, width: 3),
          ),
        );
    }
  }

  Widget _teks() {
    switch (state) {
      case _StepState.done:
        return Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        );
      case _StepState.current:
        return Text(
          '$label · sekarang',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.redText),
        );
      case _StepState.todo:
        return Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        );
    }
  }
}

/// Avatar penumpang: inisial (aplikasi) atau ikon kamera (kamera AI).
class _Avatar extends StatelessWidget {
  const _Avatar({required this.nama, required this.dariKamera});

  final String nama;
  final bool dariKamera;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(color: AppColors.redSoft, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: dariKamera
          ? const Icon(Icons.photo_camera, size: 26, color: AppColors.redText)
          : Text(
              _inisial(nama),
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.redText),
            ),
    );
  }
}

/// Badge sumber di header: "Aplikasi" (tinta) / "Kamera AI" (merah teks),
/// keduanya di atas chip abu blok.
class _BadgeSumber extends StatelessWidget {
  const _BadgeSumber({required this.dariKamera});

  final bool dariKamera;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.block, borderRadius: BorderRadius.circular(15)),
      alignment: Alignment.center,
      child: Text(
        dariKamera ? 'Kamera AI' : 'Aplikasi',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: dariKamera ? AppColors.redText : AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Kabar kedatangan penumpang: merah muda + ikon centang + teks (tidak hanya warna).
class _KabarTiba extends StatelessWidget {
  const _KabarTiba({required this.waktu});

  final DateTime waktu;

  @override
  Widget build(BuildContext context) {
    final jam = DateFormat('HH.mm').format(waktu);
    return Semantics(
      label: 'Penumpang sudah tiba di titik jemput pukul $jam',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.redSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.redPrimary, width: 2),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, size: 22, color: AppColors.redText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Penumpang sudah tiba di titik jemput · $jam',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                    color: AppColors.redText,
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

/// Kotak info kecil (label + nilai) untuk kisi 2 kolom.
class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.block, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Tombol garis (outline) untuk "Kirim pesan" / "Telepon".
class _TombolGaris extends StatelessWidget {
  const _TombolGaris({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.outlineControl, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol aksi utama merah merek (memajukan status), pil 56 gaya Brightline.
class _TombolAksi extends StatelessWidget {
  const _TombolAksi({required this.label, required this.loading, required this.onPressed});

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final aktif = onPressed != null && !loading;
    return Semantics(
      button: true,
      enabled: aktif,
      label: loading ? 'Memproses' : label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: GestureDetector(
          key: const Key('tombol_aksi'),
          onTap: onPressed,
          behavior: HitTestBehavior.opaque,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              // Saat memuat, nada diredam (bukan alpha) agar spinner putih
              // tetap terlihat jelas — WCAG 1.4.11.
              color: loading ? AppColors.redDisabled : AppColors.redPrimary,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            alignment: Alignment.center,
            child: loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Inisial nama: huruf pertama tiap kata (maks 2), atau 2 huruf pertama.
String _inisial(String nama) {
  final kata = nama.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (kata.isEmpty) return '';
  if (kata.length == 1) {
    final w = kata.first;
    return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
  }
  return (kata[0][0] + kata[1][0]).toUpperCase();
}
