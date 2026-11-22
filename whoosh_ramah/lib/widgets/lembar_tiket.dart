/// Lembar bawah (modal bottom sheet) untuk dua aksi tiket pada layar 1:
/// "QR tiket" dan "Ubah jadwal". Keduanya aksi nyata — bukan tombol kosong.
///
/// Bentuk lembar mengikuti bahasa desain Brightline: sudut atas 24, kartu
/// putih, pegangan tarik, tombol pil merah/putih, dan tinggi sentuh >= 48dp.
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/dummy.dart';
import '../theme.dart';
import 'pill_button.dart';
import 'secondary_pill_button.dart';

/// Tampilkan QR tiket yang benar-benar bisa dipindai, berisi kode pemesanan +
/// rute + tempat duduk. Kode juga bisa disalin untuk ditempel ke chat.
Future<void> tampilkanQrTiket(
  BuildContext context, {
  required TiketDummy tiket,
  required String namaPenumpang,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x99111318),
    builder: (_) => _LembarQr(tiket: tiket, namaPenumpang: namaPenumpang),
  );
}

/// Tampilkan pilihan jadwal lain. Mengembalikan tiket terpilih, atau null bila
/// pengguna batal / menutup lembar.
Future<TiketDummy?> tampilkanUbahJadwal(
  BuildContext context, {
  required TiketDummy sekarang,
}) {
  return showModalBottomSheet<TiketDummy>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x99111318),
    builder: (_) => _LembarJadwal(sekarang: sekarang),
  );
}

/// Isi QR: padat agar modul QR tetap besar dan mudah dipindai dari layar ponsel.
String _isiQr(TiketDummy t, String nama) =>
    'WHOOSH-RAMAH|${t.kodePesan}|$nama|${t.kereta}|'
    '${t.stasiunAsal} ${t.jamBerangkat}>${t.stasiunTujuan} ${t.jamTiba}|'
    '${t.tanggal}|G${t.gerbong} K${t.kursi}|${t.kelas}';

/// Pembungkus lembar: sudut atas membulat, tinggi maksimum 88% layar, isi
/// yang bisa digulir, dan [aksi] yang **selalu terlihat** di dasar lembar.
///
/// Tombol utama sengaja tidak ikut digulir: pada layar ponsel pendek (atau
/// skala teks besar) pengguna lansia tidak boleh perlu mencari-cari "Simpan".
class _BungkusLembar extends StatelessWidget {
  const _BungkusLembar({required this.child, this.aksi});

  final Widget child;

  /// Tombol-tombol lembar, dipaku di bawah area gulir.
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    final tinggi = MediaQuery.sizeOf(context).height;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: tinggi * 0.88),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              // Pegangan tarik: dekoratif, pembaca layar memakai tombol "Tutup".
              ExcludeSemantics(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: child,
                ),
              ),
              if (aksi != null) ...[
                // Garis pemisah dekoratif antara isi yang digulir dan tombol.
                Container(height: 1, color: AppColors.outline),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  child: aksi,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Judul + subjudul lembar.
class _JudulLembar extends StatelessWidget {
  const _JudulLembar({required this.judul, required this.subjudul});

  final String judul;
  final String subjudul;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            judul,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subjudul,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _LembarQr extends StatelessWidget {
  const _LembarQr({required this.tiket, required this.namaPenumpang});

  final TiketDummy tiket;
  final String namaPenumpang;

  @override
  Widget build(BuildContext context) {
    final isi = _isiQr(tiket, namaPenumpang);
    return _BungkusLembar(
      aksi: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          PillButton(
            height: 56,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: tiket.kodePesan));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(content: Text('Kode ${tiket.kodePesan} disalin.')),
                );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.copy_rounded, size: 20),
                SizedBox(width: 10),
                Flexible(child: Text('Salin kode tiket')),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SecondaryPillButton(
            height: 52,
            onPressed: () => Navigator.of(context).pop(),
            label: 'Tutup',
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _JudulLembar(
            judul: 'QR tiket',
            subjudul:
                'Tunjukkan kode ini ke petugas di gerbang keberangkatan. '
                'Tidak perlu dicetak.',
          ),
          const SizedBox(height: 18),
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.outlineControl, width: 2),
              ),
              child: QrImageView(
                data: isi,
                size: 208,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                // Pembaca layar mendapat isi kode, bukan sekadar "gambar QR".
                semanticsLabel: 'Kode QR tiket ${tiket.kodePesan}, $namaPenumpang, '
                    '${tiket.ringkasanRute}',
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.textPrimary,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.textPrimary,
                ),
                // Bila data terlalu panjang untuk QR, tampilkan kode teksnya
                // saja — lembar tetap berguna, tidak error.
                errorStateBuilder: (context, error) => SizedBox(
                  width: 208,
                  height: 208,
                  child: Center(
                    child: Text(
                      tiket.kodePesan,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.block,
              borderRadius: BorderRadius.circular(AppRadius.inner),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kode pemesanan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tiket.kodePesan,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${tiket.ringkasanRute}\n'
                  '${tiket.tanggal} · Gerbong ${tiket.gerbong} · Kursi ${tiket.kursi}',
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
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _LembarJadwal extends StatefulWidget {
  const _LembarJadwal({required this.sekarang});

  final TiketDummy sekarang;

  @override
  State<_LembarJadwal> createState() => _LembarJadwalState();
}

class _LembarJadwalState extends State<_LembarJadwal> {
  late TiketDummy _pilih = widget.sekarang;

  bool get _berubah => _pilih.kereta != widget.sekarang.kereta;

  @override
  Widget build(BuildContext context) {
    return _BungkusLembar(
      aksi: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          PillButton(
            height: 56,
            onPressed: _berubah ? () => Navigator.of(context).pop(_pilih) : null,
            child: Text(_berubah ? 'Simpan jadwal' : 'Pilih jadwal lain'),
          ),
          const SizedBox(height: 10),
          SecondaryPillButton(
            height: 52,
            onPressed: () => Navigator.of(context).pop(),
            label: 'Batal',
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _JudulLembar(
            judul: 'Ubah jadwal',
            subjudul:
                'Pilih kereta lain di hari yang sama. Gerbong dan kursi '
                'menyesuaikan ketersediaan.',
          ),
          const SizedBox(height: 16),
          for (final t in DummyData.jadwalAlternatif) ...[
            _PilihanJadwal(
              tiket: t,
              terpilih: t.kereta == _pilih.kereta,
              saatIni: t.kereta == widget.sekarang.kereta,
              onTap: () => setState(() => _pilih = t),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// Satu pilihan jadwal: kartu putih yang bisa ditekan, terpilih = garis merah.
class _PilihanJadwal extends StatelessWidget {
  const _PilihanJadwal({
    required this.tiket,
    required this.terpilih,
    required this.saatIni,
    required this.onTap,
  });

  final TiketDummy tiket;
  final bool terpilih;
  final bool saatIni;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = '${tiket.kereta}, berangkat ${tiket.jamBerangkat} dari '
        '${tiket.stasiunAsal}, tiba ${tiket.jamTiba} di ${tiket.stasiunTujuan}, '
        'gerbong ${tiket.gerbong} kursi ${tiket.kursi}'
        '${saatIni ? ', jadwal saat ini' : ''}';
    return Semantics(
      button: true,
      selected: terpilih,
      label: label,
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.choice),
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: terpilih ? AppColors.redSoft : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.choice),
              border: Border.all(
                color: terpilih
                    ? AppColors.redPrimary
                    : AppColors.outlineControl,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              tiket.kereta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (saatIni) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Saat ini',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.redText,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${tiket.jamBerangkat} → ${tiket.jamTiba} · '
                        'Gerbong ${tiket.gerbong}, Kursi ${tiket.kursi}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  terpilih
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 24,
                  color: terpilih
                      ? AppColors.redPrimary
                      : AppColors.outlineControl,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}