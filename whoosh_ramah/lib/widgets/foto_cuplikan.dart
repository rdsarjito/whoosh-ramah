import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../models/foto_permintaan.dart';
import '../services/permintaan_service.dart';
import '../theme.dart';

/// Cuplikan verifikasi anonim dari kamera AI (O1, PROJECT.md bagian 4 & 12).
///
/// Mendengarkan [PermintaanService.streamFoto] lalu menampilkan gambar dari
/// base64 lewat [Image.memory] — hanya di RAM, tidak pernah ditulis ke disk.
/// Tiga state:
/// - gambar tersedia & belum lewat `kedaluwarsaPada` -> cuplikan ditampilkan;
/// - dokumen foto hilang (dihapus detektor setelah TTL) atau base64 rusak ->
///   "Cuplikan sudah kedaluwarsa" (teks + ikon, bukan hanya warna);
/// - snapshot pertama belum tiba / stream gagal -> placeholder netral.
///
/// [thumbnail] true untuk kartu daftar tugas (56x56); false untuk tampilan
/// penuh di detail tugas. Label Semantics menyebut lokasi agar pembaca layar
/// tahu cuplikan ini milik titik jemput mana.
class FotoCuplikan extends StatefulWidget {
  const FotoCuplikan({
    super.key,
    required this.service,
    required this.idTugas,
    required this.lokasi,
    this.thumbnail = false,
  });

  final PermintaanService service;
  final String idTugas;

  /// Lokasi singkat tugas (mis. "Pintu Masuk Utara") untuk label Semantics.
  final String lokasi;

  final bool thumbnail;

  @override
  State<FotoCuplikan> createState() => _FotoCuplikanState();
}

class _FotoCuplikanState extends State<FotoCuplikan> {
  late final Stream<FotoPermintaan?> _stream =
      widget.service.streamFoto(widget.idTugas);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FotoPermintaan?>(
      stream: _stream,
      builder: (context, snapshot) {
        final foto = snapshot.data;
        final bytes = foto?.bytes;
        if (bytes != null && !foto!.kedaluwarsa(DateTime.now())) {
          return _gambar(bytes);
        }
        final memuat =
            snapshot.connectionState == ConnectionState.waiting || snapshot.hasError;
        return memuat ? _placeholder() : _kedaluwarsa();
      },
    );
  }

  Widget _gambar(Uint8List bytes) {
    final radius = widget.thumbnail ? AppRadius.tile : AppRadius.inner;
    return Semantics(
      image: true,
      label: 'Cuplikan kamera AI: pengguna kursi roda di ${widget.lokasi}',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.memory(
            bytes,
            width: widget.thumbnail ? 56 : double.infinity,
            height: widget.thumbnail ? 56 : 200,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }

  /// Snapshot pertama belum tiba: kotak netral, bukan pesan kedaluwarsa
  /// (dokumen foto mungkin sedang dalam perjalanan).
  Widget _placeholder() {
    return Semantics(
      label: 'Memuat cuplikan kamera AI',
      child: ExcludeSemantics(
        child: _kotak(const Icon(Icons.photo_camera_outlined, size: 24, color: AppColors.outlineControl)),
      ),
    );
  }

  /// Dokumen foto sudah dihapus detektor (TTL) atau tidak bisa didekode.
  /// Thumbnail hanya ikon + label Semantics; tampilan penuh menambah teks
  /// yang terlihat supaya status tidak bergantung pada warna/ikon saja.
  Widget _kedaluwarsa() {
    const ikon = Icon(Icons.timer_off_outlined, size: 24, color: AppColors.outlineControl);
    if (widget.thumbnail) {
      return Semantics(
        label: 'Cuplikan sudah kedaluwarsa',
        child: ExcludeSemantics(child: _kotak(ikon)),
      );
    }
    return Semantics(
      label: 'Cuplikan sudah kedaluwarsa',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.block,
            borderRadius: BorderRadius.circular(AppRadius.inner),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ikon,
              SizedBox(height: 8),
              Text(
                'Cuplikan sudah kedaluwarsa',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kotak(Widget isi) {
    return Container(
      width: widget.thumbnail ? 56 : double.infinity,
      height: widget.thumbnail ? 56 : 200,
      decoration: BoxDecoration(
        color: AppColors.block,
        borderRadius: BorderRadius.circular(
          widget.thumbnail ? AppRadius.tile : AppRadius.inner,
        ),
      ),
      alignment: Alignment.center,
      child: isi,
    );
  }
}