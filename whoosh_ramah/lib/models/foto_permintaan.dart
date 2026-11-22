import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Model satu dokumen pada koleksi `permintaan_foto/{idTugas}`
/// (PROJECT.md bagian 4 — cuplikan verifikasi petugas).
///
/// Read-only di aplikasi: detektor yang menulis dan menghapus (TTL).
/// `gambar` adalah string base64 JPEG cuplikan anonim (maks 160 px,
/// dipikselkan, wajah di-blur). Null-safe: dokumen bisa sudah dihapus atau
/// `gambar` tidak ada/tidak sah — [bytes] null berarti UI menampilkan state
/// "Cuplikan sudah kedaluwarsa", bukan error.
class FotoPermintaan {
  const FotoPermintaan({
    required this.id,
    this.bytes,
    this.dibuatPada,
    this.kedaluwarsaPada,
  });

  /// Id dokumen = id dokumen tugas pada `permintaan_pendampingan`.
  final String id;

  /// Hasil dekode base64 `gambar`; null bila field hilang/kosong/rusak.
  final Uint8List? bytes;

  final DateTime? dibuatPada;

  /// Batas berlaku cuplikan (`dibuatPada` + FOTO_TTL_DETIK di detektor).
  final DateTime? kedaluwarsaPada;

  /// true bila cuplikan sudah lewat masa berlakunya pada [sekarang].
  /// Tanpa `kedaluwarsaPada` dianggap belum kedaluwarsa (dokumen hilang
  /// ditangani terpisah lewat bytes/null snapshot di UI).
  bool kedaluwarsa(DateTime sekarang) =>
      kedaluwarsaPada != null && !sekarang.isBefore(kedaluwarsaPada!);

  /// Membangun dari snapshot Firestore; dokumen tidak ada -> map kosong.
  factory FotoPermintaan.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) =>
      FotoPermintaan.fromMap(snap.data() ?? <String, dynamic>{}, id: snap.id);

  /// Membangun dari map mentah agar bisa diuji tanpa instance Firestore.
  factory FotoPermintaan.fromMap(Map<String, dynamic> data, {String id = ''}) {
    return FotoPermintaan(
      id: id,
      bytes: _decodeGambar(data['gambar']),
      dibuatPada: (data['dibuatPada'] as Timestamp?)?.toDate(),
      kedaluwarsaPada: (data['kedaluwarsaPada'] as Timestamp?)?.toDate(),
    );
  }

  static Uint8List? _decodeGambar(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } on FormatException {
      return null; // base64 rusak: perlakukan seperti cuplikan tidak tersedia
    }
  }
}