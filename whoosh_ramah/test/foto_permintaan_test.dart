// Uji unit model FotoPermintaan.fromMap (O1 — cuplikan verifikasi petugas).
//
// Fokus: dekode base64 `gambar`, null-safe saat field hilang/rusak (dokumen
// foto bisa sudah dihapus detektor setelah TTL), dan perhitungan kedaluwarsa.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoosh_ramah/models/foto_permintaan.dart';

void main() {
  final dibuat = DateTime(2026, 11, 22, 8, 0);
  final batas = DateTime(2026, 11, 22, 8, 10);
  // Byte JPEG mini (SOI + APP0 + EOI) — cukup untuk uji dekode base64.
  final jpegPalsu =
      Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 0xFF, 0xD9]);

  Map<String, dynamic> data(Object? gambar) => <String, dynamic>{
        'gambar': gambar,
        'dibuatPada': Timestamp.fromDate(dibuat),
        'kedaluwarsaPada': Timestamp.fromDate(batas),
      };

  test('base64 gambar didekode menjadi bytes; timestamp terurai', () {
    final f = FotoPermintaan.fromMap(data(base64Encode(jpegPalsu)), id: 'cam-1');
    expect(f.id, 'cam-1');
    expect(f.bytes, jpegPalsu);
    expect(f.dibuatPada, dibuat);
    expect(f.kedaluwarsaPada, batas);
  });

  test('gambar hilang / kosong / bukan string -> bytes null, tidak melempar', () {
    for (final raw in <Object?>[null, '', 123, <String>['x']]) {
      final f = FotoPermintaan.fromMap(data(raw), id: 'cam-1');
      expect(f.bytes, isNull);
    }
    // Dokumen sudah dihapus: fromMap({}) tetap aman.
    expect(() => FotoPermintaan.fromMap(<String, dynamic>{}), returnsNormally);
    expect(FotoPermintaan.fromMap(<String, dynamic>{}).bytes, isNull);
  });

  test('base64 rusak -> bytes null (FormatException ditelan)', () {
    final f = FotoPermintaan.fromMap(data('!!!bukan-base64!!!'), id: 'cam-1');
    expect(f.bytes, isNull);
  });

  test('kedaluwarsa: sebelum batas false, tepat/setelah batas true', () {
    final f = FotoPermintaan.fromMap(data(base64Encode(jpegPalsu)), id: 'cam-1');
    expect(f.kedaluwarsa(batas.subtract(const Duration(seconds: 1))), isFalse);
    expect(f.kedaluwarsa(batas), isTrue);
    expect(f.kedaluwarsa(batas.add(const Duration(seconds: 1))), isTrue);
  });

  test('tanpa kedaluwarsaPada -> belum kedaluwarsa (dokumen hilang diurus UI)', () {
    final f = FotoPermintaan.fromMap(
      <String, dynamic>{'gambar': base64Encode(jpegPalsu)},
      id: 'cam-1',
    );
    expect(f.kedaluwarsa(DateTime(2030)), isFalse);
  });
}