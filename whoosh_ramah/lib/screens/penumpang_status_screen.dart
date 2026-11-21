import 'package:material_ui/material_ui.dart';

import '../models/permintaan.dart';
import '../services/permintaan_service.dart';
import '../theme.dart';

/// Layar 3 — Status pendampingan (versi sementara untuk Langkah 4).
///
/// Menampilkan status MENTAH dari [PermintaanService.streamPermintaan] agar
/// alur "kirim permintaan -> lihat status" dapat diuji. Langkah 5 akan
/// mempercantiknya sesuai `design/Penumpang-Status.dc.html` (timeline, dsb.).
class PenumpangStatusScreen extends StatefulWidget {
  const PenumpangStatusScreen({super.key, required this.idPermintaan, this.service});

  /// Id dokumen `permintaan_pendampingan` yang dibuat di layar pesan.
  final String idPermintaan;

  /// Opsional: injeksi service (memudahkan pengujian).
  final PermintaanService? service;

  @override
  State<PenumpangStatusScreen> createState() => _PenumpangStatusScreenState();
}

class _PenumpangStatusScreenState extends State<PenumpangStatusScreen> {
  late final PermintaanService _service = widget.service ?? PermintaanService();
  late final Stream<Permintaan?> _stream = _service.streamPermintaan(widget.idPermintaan);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Status pendampingan')),
      body: StreamBuilder<Permintaan?>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final p = snapshot.data;
          if (p == null) {
            return const Center(child: Text('Permintaan tidak ditemukan.'));
          }
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _InfoBaris('ID', p.id),
              _InfoBaris('Status', '${p.status.label} (${p.status.value})'),
              _InfoBaris('Jenis bantuan', p.jenisBantuan.label),
              _InfoBaris('Titik jemput', p.titikJemput),
              _InfoBaris('Sumber', p.sumber),
              _InfoBaris('Petugas', p.petugas ?? '-'),
              _InfoBaris('Catatan', (p.catatan == null || p.catatan!.isEmpty) ? '-' : p.catatan!),
              _InfoBaris('Riwayat', p.riwayat.isEmpty ? '-' : p.riwayat.map((r) => r.status).join(' → ')),
            ],
          );
        },
      ),
    );
  }
}

/// Satu baris label + nilai pada tampilan status sementara.
class _InfoBaris extends StatelessWidget {
  const _InfoBaris(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
