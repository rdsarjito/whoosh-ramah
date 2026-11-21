import 'package:material_ui/material_ui.dart';

import '../models/permintaan.dart';
import '../services/permintaan_service.dart';
import '../theme.dart';
import '../widgets/hero_back_button.dart';
import '../widgets/hero_header.dart';
import 'segera_hadir_screen.dart';

/// Warna cincin abu-abu langkah yang belum dikerjakan (design: #C9CDD6).
const Color _abuLingkaran = Color(0xFFC9CDD6);

/// Layar 6 — Detail tugas petugas (design/Petugas-Detail.dc.html).
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
  late final Stream<Permintaan?> _stream = _service.streamPermintaan(widget.idPermintaan);

  /// true selama `majukanStatus` berjalan (tombol dinonaktifkan + spinner).
  bool _loading = false;

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
                          ? const CircularProgressIndicator()
                          : Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
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
                        // Kartu menumpuk hero 44px (setara `margin: -44px 18px 0`
                        // di design; Flutter melarang margin negatif).
                        Transform.translate(
                          offset: const Offset(0, -44),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _kartuInfo(p),
                              _kartuStatus(p),
                            ],
                          ),
                        ),
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

  /// Hero biru: tombol kembali + judul + badge sumber (bila data tersedia).
  Widget _hero(Permintaan? p) {
    return HeroHeader(
      color: AppColors.blueHero,
      borderRadius: 36,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 64),
      child: Row(
        children: [
          HeroBackButton(
            label: 'Kembali ke daftar tugas',
            onTap: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Detail tugas',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                color: AppColors.textPrimary,
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
        borderRadius: BorderRadius.circular(AppRadius.cardLarge),
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
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 26,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppColors.pinkHero,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              p.jenisBantuan.label,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.redText),
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
          if (catatan != null && catatan.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.noteYellow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Catatan: ', style: TextStyle(fontWeight: FontWeight.w900)),
                    TextSpan(text: catatan),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                  color: AppColors.noteYellowText,
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
        boxShadow: AppShadows.cardSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STATUS PENDAMPINGAN',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
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

  /// Bar bawah tetap: tombol aksi atau tanda "Tugas selesai".
  Widget _barBawah(Permintaan p) {
    final selesai = p.status == StatusPermintaan.selesai;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selesai)
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.greenHero,
                borderRadius: BorderRadius.circular(30),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Tugas selesai · terima kasih!',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.greenFamily),
              ),
            )
          else
            _TombolAksi(
              label: _labelTombol(p),
              loading: _loading,
              onPressed: _loading ? null : _majukan,
            ),
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
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SegeraHadirScreen(title: judul)));
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
          decoration: const BoxDecoration(color: AppColors.greenFamily, shape: BoxShape.circle),
          child: const Icon(Icons.check, size: 16, color: Colors.white),
        );
      case _StepState.current:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.blueOfficer, width: 4),
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: AppColors.blueOfficer, shape: BoxShape.circle),
            ),
          ),
        );
      case _StepState.todo:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _abuLingkaran, width: 3),
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
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.blueOfficer),
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
      decoration: const BoxDecoration(color: AppColors.pinkHero, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: dariKamera
          ? const Icon(Icons.photo_camera, size: 26, color: AppColors.redText)
          : Text(
              _inisial(nama),
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.redText),
            ),
    );
  }
}

/// Badge sumber di hero: "Aplikasi" (biru) / "Kamera AI" (merah).
class _BadgeSumber extends StatelessWidget {
  const _BadgeSumber({required this.dariKamera});

  final bool dariKamera;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      alignment: Alignment.center,
      child: Text(
        dariKamera ? 'Kamera AI' : 'Aplikasi',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: dariKamera ? AppColors.redText : AppColors.blueOfficer,
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
      decoration: BoxDecoration(color: AppColors.innerGray, borderRadius: BorderRadius.circular(16)),
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
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
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
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(23),
              border: Border.all(color: AppColors.outline, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol aksi utama biru (memajukan status).
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
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.blueOfficer.withValues(alpha: loading ? 0.6 : 1),
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(color: Color(0x401E50C8), blurRadius: 22, offset: Offset(0, 10)),
              ],
            ),
            alignment: Alignment.center,
            child: loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
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
