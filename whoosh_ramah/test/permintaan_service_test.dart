/// Tier 3 E1 — pengujian [PermintaanService] terhadap Firestore palsu.
///
/// `fake_cloud_firestore` menjalankan koleksi, stream, transaksi, dan
/// `FieldValue` (serverTimestamp/arrayUnion) in-memory, jadi kontrak data
/// PROJECT.md bagian 4 bisa diverifikasi tanpa proyek Firebase sungguhan.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoosh_ramah/data/dummy.dart';
import 'package:whoosh_ramah/models/permintaan.dart';
import 'package:whoosh_ramah/services/permintaan_service.dart';

const String _koleksi = 'permintaan_pendampingan';

/// Waktu tetap supaya urutan `dibuatPada` deterministik.
Timestamp _jam(int menit) =>
    Timestamp.fromDate(DateTime(2026, 11, 22, 8, menit));

void main() {
  late FakeFirebaseFirestore db;
  late PermintaanService svc;

  setUp(() {
    db = FakeFirebaseFirestore();
    svc = PermintaanService(db);
  });

  /// Menulis dokumen mentah langsung ke koleksi (meniru detektor/penumpang lain).
  Future<String> seed(
    Map<String, dynamic> data, {
    String? id,
  }) async {
    final col = db.collection(_koleksi);
    final ref = id == null ? await col.add(data) : col.doc(id);
    if (id != null) await ref.set(data);
    return ref.id;
  }

  /// Dokumen minimal milik penumpang demo dengan status & waktu tertentu.
  Map<String, dynamic> dok({
    String status = 'menunggu',
    String idPenumpang = 'demo-siti',
    int menit = 0,
    List<Map<String, dynamic>>? riwayat,
  }) =>
      <String, dynamic>{
        'jenisBantuan': 'kursi_roda',
        'titikJemput': 'Lobi utama',
        'status': status,
        'sumber': 'aplikasi',
        'namaPenumpang': 'Siti Aminah',
        'idPenumpang': idPenumpang,
        'petugas': null,
        'riwayat': riwayat ??
            <Map<String, dynamic>>[
              <String, dynamic>{'status': 'menunggu', 'waktu': _jam(menit)},
            ],
        'dibuatPada': _jam(menit),
        'diperbaruiPada': _jam(menit),
      };

  Future<Map<String, dynamic>> baca(String id) async =>
      (await db.collection(_koleksi).doc(id).get()).data()!;

  Future<int> jumlah() async =>
      (await db.collection(_koleksi).get()).docs.length;

  group('buatPermintaan — kontrak data (bagian 4)', () {
    test('menulis seluruh field dengan nilai enum yang tepat', () async {
      final hasil = await svc.buatPermintaan(
        jenisBantuan: JenisBantuan.kursiRoda,
        titikJemput: 'Lobi utama',
        catatan: 'membawa satu koper besar',
      );

      expect(hasil.sudahAda, isFalse);
      expect(await jumlah(), 1);

      final data = await baca(hasil.id);
      expect(data['jenisBantuan'], 'kursi_roda');
      expect(data['titikJemput'], 'Lobi utama');
      expect(data['status'], 'menunggu');
      expect(data['sumber'], 'aplikasi');
      expect(data['namaPenumpang'], DummyData.penumpang.namaPenumpang);
      expect(data['idPenumpang'], DummyData.penumpang.idPenumpang);
      expect(data['kereta'], DummyData.tiket.kereta);
      expect(data['jamBerangkat'], DummyData.tiket.jamBerangkat);
      expect(data['stasiunAsal'], DummyData.tiket.stasiunAsal);
      expect(data['stasiunTujuan'], DummyData.tiket.stasiunTujuan);
      expect(data['gerbong'], DummyData.tiket.gerbong);
      expect(data['kursi'], DummyData.tiket.kursi);
      expect(data['catatan'], 'membawa satu koper besar');
      expect(data['petugas'], isNull);
      // serverTimestamp harus sudah terisi, bukan sentinel yang tertinggal.
      expect(data['dibuatPada'], isA<Timestamp>());
      expect(data['diperbaruiPada'], isA<Timestamp>());

      final riwayat = data['riwayat'] as List;
      expect(riwayat, hasLength(1));
      expect((riwayat.first as Map)['status'], 'menunggu');
      expect((riwayat.first as Map)['waktu'], isA<Timestamp>());
    });

    test('catatan kosong disimpan sebagai null, bukan string kosong', () async {
      final hasil = await svc.buatPermintaan(
        jenisBantuan: JenisBantuan.lansia,
        titikJemput: 'Area parkir',
      );
      final data = await baca(hasil.id);
      expect(data['catatan'], isNull);
      expect(data['jenisBantuan'], 'lansia');
    });

    test('model yang dibaca kembali cocok dengan yang ditulis', () async {
      final hasil = await svc.buatPermintaan(
        jenisBantuan: JenisBantuan.porter,
        titikJemput: 'Kereta pengumpan',
      );
      final p = await svc.streamPermintaan(hasil.id).first;
      expect(p, isNotNull);
      expect(p!.id, hasil.id);
      expect(p.jenisBantuan, JenisBantuan.porter);
      expect(p.status, StatusPermintaan.menunggu);
      expect(p.dariKamera, isFalse);
      expect(p.sudahSelesai, isFalse);
      expect(p.sudahTiba, isFalse);
      expect(p.riwayat.single.status, 'menunggu');
    });
  });

  group('buatPermintaan — penjaga permintaan ganda (E3)', () {
    test('permintaan aktif kedua tidak menulis dokumen baru', () async {
      final pertama = await svc.buatPermintaan(
        jenisBantuan: JenisBantuan.kursiRoda,
        titikJemput: 'Lobi utama',
      );
      final kedua = await svc.buatPermintaan(
        jenisBantuan: JenisBantuan.porter,
        titikJemput: 'Area parkir',
        catatan: 'coba lagi',
      );

      expect(kedua.sudahAda, isTrue);
      expect(kedua.id, pertama.id);
      expect(await jumlah(), 1);
      // Data permintaan pertama tidak boleh tertimpa pilihan kedua.
      final data = await baca(pertama.id);
      expect(data['jenisBantuan'], 'kursi_roda');
      expect(data['titikJemput'], 'Lobi utama');
      expect(data['catatan'], isNull);
    });

    test('permintaan yang sudah selesai tidak menghalangi permintaan baru',
        () async {
      await seed(dok(status: 'selesai', menit: 0));
      final hasil = await svc.buatPermintaan(
        jenisBantuan: JenisBantuan.tuli,
        titikJemput: 'Lobi utama',
      );
      expect(hasil.sudahAda, isFalse);
      expect(await jumlah(), 2);
    });

    test('permintaan penumpang lain tidak ikut dihitung', () async {
      await seed(dok(idPenumpang: 'demo-budi', menit: 5));
      final hasil = await svc.buatPermintaan(
        jenisBantuan: JenisBantuan.hamil,
        titikJemput: 'Lobi utama',
      );
      expect(hasil.sudahAda, isFalse);
      expect(await jumlah(), 2);
    });

    test('bila ada beberapa yang aktif, id terbaru yang dikembalikan',
        () async {
      await seed(dok(menit: 0), id: 'lama');
      await seed(dok(status: 'ditugaskan', menit: 9), id: 'baru');
      final hasil = await svc.buatPermintaan(
        jenisBantuan: JenisBantuan.kursiRoda,
        titikJemput: 'Lobi utama',
      );
      expect(hasil.sudahAda, isTrue);
      expect(hasil.id, 'baru');
      expect(await jumlah(), 2);
    });

    test('dokumen tanpa dibuatPada tetap dianggap aktif', () async {
      final data = dok()..remove('dibuatPada');
      await seed(data, id: 'tanpa-jam');
      final hasil = await svc.buatPermintaan(
        jenisBantuan: JenisBantuan.kursiRoda,
        titikJemput: 'Lobi utama',
      );
      expect(hasil.sudahAda, isTrue);
      expect(hasil.id, 'tanpa-jam');
    });
  });

  group('stream', () {
    test('streamPermintaan mengirim null untuk dokumen yang tidak ada',
        () async {
      expect(await svc.streamPermintaan('tidak-ada').first, isNull);
    });

    test('streamPermintaan mengikuti perubahan dokumen', () async {
      final id = await seed(dok());
      final perubahan = svc.streamPermintaan(id).take(2).toList();
      await svc.majukanStatus(id);
      final hasil = await perubahan;
      expect(hasil.first!.status, StatusPermintaan.menunggu);
      expect(hasil.last!.status, StatusPermintaan.ditugaskan);
    });

    test('streamSemua mengurutkan terbaru dulu dan membatasi 100 dokumen',
        () async {
      for (var i = 0; i < 101; i++) {
        await seed(dok(menit: i), id: 'd$i');
      }
      final list = await svc.streamSemua().first;
      expect(list, hasLength(100));
      expect(list.first.id, 'd100');
      expect(list.last.id, 'd1');
      for (var i = 1; i < list.length; i++) {
        expect(
          list[i - 1].dibuatPada!.isAfter(list[i].dibuatPada!),
          isTrue,
          reason: 'urutan harus menurun berdasarkan dibuatPada',
        );
      }
    });

    test('streamTerbaruPenumpang memilih milik penumpang itu yang terbaru',
        () async {
      await seed(dok(menit: 0), id: 'siti-lama');
      await seed(dok(idPenumpang: 'demo-budi', menit: 30), id: 'budi');
      await seed(dok(status: 'bertemu', menit: 12), id: 'siti-baru');
      final p = await svc.streamTerbaruPenumpang('demo-siti').first;
      expect(p!.id, 'siti-baru');
      expect(p.status, StatusPermintaan.bertemu);
    });

    test('streamTerbaruPenumpang null bila penumpang belum punya permintaan',
        () async {
      await seed(dok(idPenumpang: 'demo-budi'));
      expect(await svc.streamTerbaruPenumpang('demo-siti').first, isNull);
    });

    test('dokumen kamera AI tanpa riwayat/nama tetap terbaca (null-safe)',
        () async {
      await seed(<String, dynamic>{
        'jenisBantuan': 'kursi_roda',
        'titikJemput': 'Stasiun Halim - Pintu Masuk Utara',
        'status': 'menunggu',
        'sumber': 'kamera_ai',
        'idKamera': 'halim-utara-01',
        'keyakinan': 0.87,
        'dibuatPada': _jam(3),
      }, id: 'kamera');

      final p = (await svc.streamSemua().first).single;
      expect(p.dariKamera, isTrue);
      expect(p.namaPenumpang, isNull);
      expect(p.idPenumpang, isNull);
      expect(p.riwayat, isEmpty);
      expect(p.persenKeyakinan, 87);
      expect(p.lokasiSingkat, 'Pintu Masuk Utara');
    });
  });

  group('majukanStatus — transaksi (E2)', () {
    test('menunggu -> ditugaskan mengisi petugas Rina & menambah riwayat',
        () async {
      final id = await seed(dok());
      await svc.majukanStatus(id);

      final data = await baca(id);
      expect(data['status'], 'ditugaskan');
      expect(data['petugas'], 'Rina');
      final riwayat = (data['riwayat'] as List).cast<Map>();
      expect(riwayat.map((e) => e['status']), <String>[
        'menunggu',
        'ditugaskan',
      ]);
      expect(riwayat.last['waktu'], isA<Timestamp>());
      expect(data['diperbaruiPada'], isA<Timestamp>());
    });

    test('urutan wajib dilalui satu per satu sampai selesai', () async {
      final id = await seed(dok());
      const urutan = <String>[
        'ditugaskan',
        'bertemu',
        'di_kursi',
        'selesai',
      ];
      for (final tujuan in urutan) {
        await svc.majukanStatus(id);
        expect((await baca(id))['status'], tujuan);
      }
      final riwayat = ((await baca(id))['riwayat'] as List).cast<Map>();
      expect(riwayat.map((e) => e['status']), <String>[
        'menunggu',
        ...urutan,
      ]);
    });

    test('panggilan setelah selesai tidak menulis apa-apa', () async {
      final id = await seed(dok(status: 'selesai', riwayat: <Map<String, dynamic>>[
        <String, dynamic>{'status': 'menunggu', 'waktu': _jam(0)},
        <String, dynamic>{'status': 'selesai', 'waktu': _jam(4)},
      ]));
      final sebelum = await baca(id);
      await svc.majukanStatus(id);
      expect(await baca(id), sebelum);
    });

    test('dokumen tidak ada -> tidak melempar dan tidak membuat dokumen',
        () async {
      await svc.majukanStatus('tidak-ada');
      expect(await jumlah(), 0);
    });

    test('dua panggilan bersamaan diurutkan: dua tahap, tanpa riwayat kembar',
        () async {
      final id = await seed(dok());
      await Future.wait<void>(<Future<void>>[
        svc.majukanStatus(id),
        svc.majukanStatus(id),
      ]);

      // Antrean per-id membuat panggilan kedua membaca hasil panggilan pertama,
      // jadi tiap panggilan memajukan tepat satu tahap (bukan melompati tahap).
      final data = await baca(id);
      expect(data['status'], 'bertemu');
      final riwayat = (data['riwayat'] as List).cast<Map>();
      expect(riwayat.map((e) => e['status']), <String>[
        'menunggu',
        'ditugaskan',
        'bertemu',
      ]);
    });

    test('tahap berikutnya yang sudah tercatat di riwayat tidak ditulis ulang',
        () async {
      // Meniru transaksi lain yang sudah mendahului: status masih menunggu,
      // tetapi riwayat sudah memuat ditugaskan.
      final id = await seed(dok(riwayat: <Map<String, dynamic>>[
        <String, dynamic>{'status': 'menunggu', 'waktu': _jam(0)},
        <String, dynamic>{'status': 'ditugaskan', 'waktu': _jam(1)},
      ]));
      final sebelum = await baca(id);
      await svc.majukanStatus(id);
      expect(await baca(id), sebelum);
    });

    test('dua ketukan berurutan tetap memajukan dua tahap', () async {
      final id = await seed(dok());
      await svc.majukanStatus(id);
      await svc.majukanStatus(id);
      final data = await baca(id);
      expect(data['status'], 'bertemu');
      expect((data['riwayat'] as List), hasLength(3));
    });

    test('dokumen kamera tanpa riwayat mendapat entri pertama saat dimajukan',
        () async {
      final id = await seed(<String, dynamic>{
        'jenisBantuan': 'kursi_roda',
        'titikJemput': 'Stasiun Halim - Pintu Masuk Utara',
        'status': 'menunggu',
        'sumber': 'kamera_ai',
        'dibuatPada': _jam(1),
      });
      await svc.majukanStatus(id);
      final data = await baca(id);
      expect(data['status'], 'ditugaskan');
      expect((data['riwayat'] as List).cast<Map>().single['status'],
          'ditugaskan');
    });

    test('riwayat lama tidak hilang saat tahap baru ditambahkan', () async {
      final id = await seed(dok(status: 'bertemu', riwayat: <Map<String, dynamic>>[
        <String, dynamic>{'status': 'menunggu', 'waktu': _jam(0)},
        <String, dynamic>{'status': 'ditugaskan', 'waktu': _jam(1)},
        <String, dynamic>{'status': 'bertemu', 'waktu': _jam(2)},
      ]));
      await svc.majukanStatus(id);
      final riwayat = ((await baca(id))['riwayat'] as List).cast<Map>();
      expect(riwayat.map((e) => e['status']), <String>[
        'menunggu',
        'ditugaskan',
        'bertemu',
        'di_kursi',
      ]);
      expect(riwayat.first['waktu'], _jam(0));
    });
  });

  group('tandaiTiba', () {
    test('mengisi tibaPada & memperbarui diperbaruiPada', () async {
      final id = await seed(dok());
      await svc.tandaiTiba(id);
      final data = await baca(id);
      expect(data['tibaPada'], isA<Timestamp>());
      expect(data['diperbaruiPada'], isA<Timestamp>());
      expect((await svc.streamPermintaan(id).first)!.sudahTiba, isTrue);
    });

    test('idempoten: ketukan ganda tidak menggeser jam kedatangan', () async {
      final id = await seed(dok());
      await svc.tandaiTiba(id);
      final pertama = (await baca(id))['tibaPada'] as Timestamp;
      await svc.tandaiTiba(id);
      expect((await baca(id))['tibaPada'], pertama);
    });

    test('dokumen tidak ada -> tidak melempar', () async {
      await svc.tandaiTiba('tidak-ada');
      expect(await jumlah(), 0);
    });
  });

  group('tolakTugas & streamFoto — O1 + A3', () {
    /// Dokumen kamera AI minimal, meniru tulisan detektor (tanpa riwayat).
    Map<String, dynamic> dokKamera({
      String status = 'menunggu',
      int menit = 0,
    }) =>
        <String, dynamic>{
          'jenisBantuan': 'kursi_roda',
          'titikJemput': 'Stasiun Halim - Pintu Masuk Utara',
          'status': status,
          'sumber': 'kamera_ai',
          'idKamera': 'halim-utara-01',
          'keyakinan': 0.87,
          'dibuatPada': _jam(menit),
        };

    test('menulis ditolakPada + alasanTolak; status & riwayat tidak disentuh',
        () async {
      final id = await seed(dokKamera());
      await svc.tolakTugas(id, alasan: 'Bukan pengguna kursi roda');

      final data = await baca(id);
      expect(data['ditolakPada'], isA<Timestamp>());
      expect(data['alasanTolak'], 'Bukan pengguna kursi roda');
      expect(data['diperbaruiPada'], isA<Timestamp>());
      // Kontrak bagian 4: enum status tetap, tidak ada nilai "ditolak".
      expect(data['status'], 'menunggu');
      expect(data['riwayat'], isNull);

      final p = (await svc.streamPermintaan(id).first)!;
      expect(p.sudahDitolak, isTrue);
      expect(p.bisaDitolak, isFalse);
    });

    test('idempoten: tolak kedua tidak menggeser waktu maupun alasan',
        () async {
      final id = await seed(dokKamera());
      await svc.tolakTugas(id, alasan: 'Bukan pengguna kursi roda');
      final pertama = await baca(id);
      await svc.tolakTugas(id, alasan: 'coba lagi');
      expect(await baca(id), pertama);
    });

    test('penjaga: tugas aplikasi, selesai, dan tidak ada tidak ditolak',
        () async {
      final aplikasi = await seed(dok());
      final sebelumAplikasi = await baca(aplikasi);
      await svc.tolakTugas(aplikasi);
      expect(await baca(aplikasi), sebelumAplikasi);

      final selesai = await seed(dokKamera(status: 'selesai', menit: 5));
      final sebelumSelesai = await baca(selesai);
      await svc.tolakTugas(selesai);
      expect(await baca(selesai), sebelumSelesai);

      await svc.tolakTugas('tidak-ada');
      expect(await jumlah(), 2);
    });

    test('majukanStatus pada tugas yang sudah ditolak tidak menulis apa-apa',
        () async {
      final id = await seed(dokKamera());
      await svc.tolakTugas(id);
      final sebelum = await baca(id);
      await svc.majukanStatus(id);
      expect(await baca(id), sebelum);
    });

    test('tolak & majukan bersamaan diurutkan: ditolak menang, status tetap',
        () async {
      final id = await seed(dokKamera());
      await Future.wait<void>(<Future<void>>[
        svc.tolakTugas(id),
        svc.majukanStatus(id),
      ]);
      final data = await baca(id);
      expect(data['ditolakPada'], isA<Timestamp>());
      expect(data['status'], 'menunggu');
    });

    test('streamFoto: null -> cuplikan hadir -> null lagi setelah dihapus',
        () async {
      final id = await seed(dokKamera());
      final fotoRef = db.collection('permintaan_foto').doc(id);
      final perubahan = svc.streamFoto(id).take(3).toList();

      await fotoRef.set(<String, dynamic>{
        'gambar': 'aGVsbw==', // base64 "hello" — cukup untuk uji dekode
        'dibuatPada': _jam(0),
        'kedaluwarsaPada':
            Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 10))),
      });
      await fotoRef.delete(); // detektor menghapus setelah TTL

      final hasil = await perubahan;
      expect(hasil[0], isNull);
      expect(hasil[1], isNotNull);
      expect(hasil[1]!.bytes, isNotNull);
      expect(hasil[1]!.kedaluwarsa(DateTime.now()), isFalse);
      expect(hasil[2], isNull);
    });

    test('streamFoto: kedaluwarsaPada yang sudah lewat ditandai kedaluwarsa',
        () async {
      final id = await seed(dokKamera());
      await db.collection('permintaan_foto').doc(id).set(<String, dynamic>{
        'gambar': 'aGVsbw==',
        'kedaluwarsaPada':
            Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 1))),
      });
      final foto = await svc.streamFoto(id).first;
      expect(foto!.kedaluwarsa(DateTime.now()), isTrue);
    });
  });
}