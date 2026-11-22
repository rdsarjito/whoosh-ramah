// Uji unit model Permintaan.fromMap / fromFirestore (Langkah 2).
//
// Fokus: dokumen dari detektor banyak field-nya null / tidak ada, dan parsing
// harus tetap aman (null-safe) plus getter bantu menghasilkan nilai benar.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoosh_ramah/models/permintaan.dart';

void main() {
  group('Permintaan.fromMap — dokumen detektor (kamera AI)', () {
    // Meniru persis yang ditulis detector/detect_wheelchair.py: hanya ada
    // jenisBantuan, titikJemput, status, sumber, idKamera, keyakinan,
    // namaPenumpang(null), dibuatPada. Tanpa riwayat/diperbaruiPada/idPenumpang/
    // kereta/gerbong/kursi/catatan/petugas.
    final dibuatPada = Timestamp.fromDate(DateTime(2026, 11, 22, 7, 41));
    final data = <String, dynamic>{
      'jenisBantuan': 'kursi_roda',
      'titikJemput': 'Stasiun Halim - Pintu Masuk Utara',
      'status': 'menunggu',
      'sumber': 'kamera_ai',
      'idKamera': 'halim-utara-01',
      'keyakinan': 0.87,
      'namaPenumpang': null,
      'dibuatPada': dibuatPada,
    };

    final p = Permintaan.fromMap(data, id: 'cam-1');

    test('field wajib terisi', () {
      expect(p.id, 'cam-1');
      expect(p.jenisBantuan, JenisBantuan.kursiRoda);
      expect(p.status, StatusPermintaan.menunggu);
      expect(p.sumber, 'kamera_ai');
      expect(p.dariKamera, isTrue);
      expect(p.idKamera, 'halim-utara-01');
    });

    test('field yang tidak ada menjadi null / kosong (null-safe)', () {
      expect(p.namaPenumpang, isNull);
      expect(p.idPenumpang, isNull);
      expect(p.kereta, isNull);
      expect(p.jamBerangkat, isNull);
      expect(p.stasiunAsal, isNull);
      expect(p.stasiunTujuan, isNull);
      expect(p.gerbong, isNull);
      expect(p.kursi, isNull);
      expect(p.catatan, isNull);
      expect(p.petugas, isNull);
      expect(p.diperbaruiPada, isNull);
      expect(p.riwayat, isEmpty);
      expect(p.sudahSelesai, isFalse);
    });

    test('dibuatPada (Timestamp) menjadi DateTime', () {
      expect(p.dibuatPada, dibuatPada.toDate());
    });

    test('lokasiSingkat mengambil bagian setelah " - "', () {
      expect(p.lokasiSingkat, 'Pintu Masuk Utara');
    });

    test('persenKeyakinan = keyakinan x 100 dibulatkan', () {
      expect(p.persenKeyakinan, 87);
      expect(Permintaan.fromMap(<String, dynamic>{'keyakinan': 0.56}).persenKeyakinan, 56);
    });

    test('parsing tidak melempar exception', () {
      expect(() => Permintaan.fromMap(data, id: 'cam-1'), returnsNormally);
    });
  });

  group('Permintaan.fromMap — dokumen aplikasi (lengkap)', () {
    final dibuatPada = Timestamp.fromDate(DateTime(2026, 11, 22, 7, 32));
    final diperbaruiPada = Timestamp.fromDate(DateTime(2026, 11, 22, 7, 33));
    final data = <String, dynamic>{
      'jenisBantuan': 'kursi_roda',
      'titikJemput': 'Lobi utama',
      'status': 'ditugaskan',
      'sumber': 'aplikasi',
      'namaPenumpang': 'Siti Aminah',
      'idPenumpang': 'demo-siti',
      'kereta': 'G1123',
      'jamBerangkat': '08.10',
      'stasiunAsal': 'Halim',
      'stasiunTujuan': 'Tegalluar',
      'gerbong': '5',
      'kursi': '7A',
      'catatan': 'membawa satu koper besar',
      'petugas': 'Rina',
      'keyakinan': null,
      'riwayat': <Map<String, dynamic>>[
        <String, dynamic>{'status': 'menunggu', 'waktu': dibuatPada},
        <String, dynamic>{'status': 'ditugaskan', 'waktu': diperbaruiPada},
      ],
      'dibuatPada': dibuatPada,
      'diperbaruiPada': diperbaruiPada,
    };

    final p = Permintaan.fromMap(data, id: 'app-1');

    test('data penumpang & tiket terbaca', () {
      expect(p.namaPenumpang, 'Siti Aminah');
      expect(p.idPenumpang, 'demo-siti');
      expect(p.kereta, 'G1123');
      expect(p.stasiunTujuan, 'Tegalluar');
      expect(p.gerbong, '5');
      expect(p.kursi, '7A');
      expect(p.catatan, 'membawa satu koper besar');
      expect(p.petugas, 'Rina');
      expect(p.status, StatusPermintaan.ditugaskan);
      expect(p.dariKamera, isFalse);
    });

    test('riwayat terurai berurutan', () {
      expect(p.riwayat.length, 2);
      expect(p.riwayat[0].status, 'menunggu');
      expect(p.riwayat[1].status, 'ditugaskan');
      expect(p.riwayat[1].waktu, diperbaruiPada.toDate());
    });

    test('tanpa kamera: persenKeyakinan null, lokasiSingkat apa adanya', () {
      expect(p.persenKeyakinan, isNull);
      expect(p.lokasiSingkat, 'Lobi utama');
    });
  });

  group('Permintaan.tibaPada — kabar tiba dari penumpang (Tier 1 A1)', () {
    final waktu = DateTime(2026, 11, 22, 7, 50);

    Permintaan minimal({DateTime? tibaPada}) => Permintaan(
          id: 'app-1',
          jenisBantuan: JenisBantuan.kursiRoda,
          titikJemput: 'Lobi utama',
          status: StatusPermintaan.ditugaskan,
          sumber: 'aplikasi',
          tibaPada: tibaPada,
        );

    test('dokumen detektor tanpa tibaPada -> null, sudahTiba false', () {
      final p = Permintaan.fromMap(<String, dynamic>{'sumber': 'kamera_ai'});
      expect(p.tibaPada, isNull);
      expect(p.sudahTiba, isFalse);
    });

    test('Timestamp tibaPada menjadi DateTime, sudahTiba true', () {
      final p = Permintaan.fromMap(<String, dynamic>{
        'tibaPada': Timestamp.fromDate(waktu),
      });
      expect(p.tibaPada, waktu);
      expect(p.sudahTiba, isTrue);
    });

    test('toFirestore -> fromMap mempertahankan jam kedatangan', () {
      final hasil = Permintaan.fromMap(minimal(tibaPada: waktu).toFirestore(), id: 'app-1');
      expect(hasil.tibaPada, waktu);
      expect(hasil.sudahTiba, isTrue);
    });

    test('belum tiba tetap null setelah round-trip (tidak mengarang jam)', () {
      final hasil = Permintaan.fromMap(minimal().toFirestore(), id: 'app-1');
      expect(hasil.tibaPada, isNull);
      expect(hasil.sudahTiba, isFalse);
      expect(hasil.toFirestore()['tibaPada'], isNull);
    });
  });

  group('Permintaan.adaFoto & penolakan (O1 + A3)', () {
    final waktuTolak = DateTime(2026, 11, 22, 8, 5);

    Permintaan kamera({
      StatusPermintaan status = StatusPermintaan.menunggu,
      bool adaFoto = false,
      DateTime? ditolakPada,
      String? alasanTolak,
      String sumber = 'kamera_ai',
    }) =>
        Permintaan(
          id: 'cam-1',
          jenisBantuan: JenisBantuan.kursiRoda,
          titikJemput: 'Stasiun Halim - Pintu Masuk Utara',
          status: status,
          sumber: sumber,
          adaFoto: adaFoto,
          ditolakPada: ditolakPada,
          alasanTolak: alasanTolak,
        );

    test('dokumen detektor tanpa adaFoto -> false (null-safe)', () {
      final p = Permintaan.fromMap(<String, dynamic>{'sumber': 'kamera_ai'});
      expect(p.adaFoto, isFalse);
      expect(p.ditolakPada, isNull);
      expect(p.alasanTolak, isNull);
      expect(p.sudahDitolak, isFalse);
    });

    test('adaFoto true terbaca; round-trip mempertahankan flag', () {
      final p = Permintaan.fromMap(<String, dynamic>{'adaFoto': true});
      expect(p.adaFoto, isTrue);
      final hasil =
          Permintaan.fromMap(kamera(adaFoto: true).toFirestore(), id: 'cam-1');
      expect(hasil.adaFoto, isTrue);
    });

    test('ditolakPada & alasanTolak terurai; status TIDAK berubah', () {
      final p = Permintaan.fromMap(<String, dynamic>{
        'ditolakPada': Timestamp.fromDate(waktuTolak),
        'alasanTolak': 'Bukan pengguna kursi roda',
      });
      expect(p.ditolakPada, waktuTolak);
      expect(p.alasanTolak, 'Bukan pengguna kursi roda');
      expect(p.sudahDitolak, isTrue);
      // Penolakan tidak menambah nilai enum status (kontrak bagian 4).
      expect(p.status, StatusPermintaan.menunggu);
    });

    test('round-trip penolakan mempertahankan jam & alasan', () {
      final hasil = Permintaan.fromMap(
        kamera(ditolakPada: waktuTolak, alasanTolak: 'Bukan pengguna kursi roda')
            .toFirestore(),
        id: 'cam-1',
      );
      expect(hasil.ditolakPada, waktuTolak);
      expect(hasil.alasanTolak, 'Bukan pengguna kursi roda');
      expect(hasil.sudahDitolak, isTrue);
    });

    test('bisaDitolak: hanya kamera AI yang belum selesai & belum ditolak', () {
      expect(kamera().bisaDitolak, isTrue);
      expect(kamera(status: StatusPermintaan.ditugaskan).bisaDitolak, isTrue);
      expect(kamera(status: StatusPermintaan.selesai).bisaDitolak, isFalse);
      expect(kamera(ditolakPada: waktuTolak).bisaDitolak, isFalse);
      expect(kamera(sumber: 'aplikasi').bisaDitolak, isFalse);
    });
  });

  group('Enum & fallback', () {
    test('dariValue fallback untuk nilai tak dikenal / null', () {
      expect(StatusPermintaan.dariValue(null), StatusPermintaan.menunggu);
      expect(StatusPermintaan.dariValue('asing'), StatusPermintaan.menunggu);
      expect(JenisBantuan.dariValue('asing'), JenisBantuan.kursiRoda);
    });

    test('value enum cocok dengan skema Firestore', () {
      expect(StatusPermintaan.diKursi.value, 'di_kursi');
      expect(JenisBantuan.hamil.value, 'hamil');
      expect(JenisBantuan.hamil.label, 'Ibu hamil');
    });

    test('urutan status: berikutnya', () {
      expect(StatusPermintaan.menunggu.berikutnya, StatusPermintaan.ditugaskan);
      expect(StatusPermintaan.ditugaskan.berikutnya, StatusPermintaan.bertemu);
      expect(StatusPermintaan.bertemu.berikutnya, StatusPermintaan.diKursi);
      expect(StatusPermintaan.diKursi.berikutnya, StatusPermintaan.selesai);
      expect(StatusPermintaan.selesai.berikutnya, isNull);
    });
  });
}
