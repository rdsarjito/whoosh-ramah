import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/dummy.dart';
import '../models/foto_permintaan.dart';
import '../models/permintaan.dart';

/// Hasil [PermintaanService.buatPermintaan].
///
/// [sudahAda] true bila penumpang masih punya permintaan yang belum selesai:
/// tidak ada dokumen baru dibuat dan [id] menunjuk ke permintaan yang sudah ada.
class HasilPermintaan {
  const HasilPermintaan({required this.id, this.sudahAda = false});

  final String id;
  final bool sudahAda;
}

/// Semua akses Firestore untuk koleksi `permintaan_pendampingan` (bagian 4).
///
/// Nama koleksi & field harus sama persis dengan yang ditulis
/// `detector/detect_wheelchair.py` agar tugas dari kamera AI ikut terbaca.
class PermintaanService {
  /// [firestore] opsional (posisional) untuk pengujian; bila null pakai instance.
  PermintaanService([this._firestore]);

  final FirebaseFirestore? _firestore;

  /// `FirebaseFirestore` diakses malas agar konstruktor tidak menyentuh
  /// `FirebaseFirestore.instance` — memudahkan pengujian tanpa Firebase.
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('permintaan_pendampingan');

  /// Membuat permintaan pendampingan baru dari aplikasi penumpang.
  ///
  /// **Penjaga permintaan ganda:** bila penumpang masih punya permintaan yang
  /// belum `selesai`, tidak ada dokumen baru ditulis — id permintaan yang sudah
  /// ada dikembalikan dengan `sudahAda = true`, supaya UI bisa membuka statusnya
  /// alih-alih menumpuk tugas kembar di daftar petugas.
  ///
  /// Data penumpang & tiket diambil dari data dummy demo (bagian 5). `status` =
  /// menunggu, `sumber` = aplikasi, `riwayat` diisi entri awal,
  /// `dibuatPada`/`diperbaruiPada` pakai serverTimestamp.
  Future<HasilPermintaan> buatPermintaan({
    required JenisBantuan jenisBantuan,
    required String titikJemput,
    String? catatan,
  }) async {
    final tiket = DummyData.tiket;
    final penumpang = DummyData.penumpang;

    final aktif = await _permintaanAktif(penumpang.idPenumpang);
    if (aktif != null) return HasilPermintaan(id: aktif.id, sudahAda: true);

    final data = <String, dynamic>{
      'jenisBantuan': jenisBantuan.value,
      'titikJemput': titikJemput,
      'status': StatusPermintaan.menunggu.value,
      'sumber': 'aplikasi',
      'namaPenumpang': penumpang.namaPenumpang,
      'idPenumpang': penumpang.idPenumpang,
      'kereta': tiket.kereta,
      'jamBerangkat': tiket.jamBerangkat,
      'stasiunAsal': tiket.stasiunAsal,
      'stasiunTujuan': tiket.stasiunTujuan,
      'gerbong': tiket.gerbong,
      'kursi': tiket.kursi,
      'catatan': catatan,
      'petugas': null,
      'riwayat': <Map<String, dynamic>>[
        <String, dynamic>{
          'status': StatusPermintaan.menunggu.value,
          'waktu': Timestamp.now(),
        },
      ],
      'dibuatPada': FieldValue.serverTimestamp(),
      'diperbaruiPada': FieldValue.serverTimestamp(),
    };
    final ref = await _col.add(data);
    return HasilPermintaan(id: ref.id);
  }

  /// Permintaan terbaru milik penumpang yang belum `selesai`, atau null.
  ///
  /// Hanya `where` lalu disaring/diurutkan di sisi aplikasi — `where` +
  /// `orderBy` + `!=` akan menuntut composite index.
  Future<Permintaan?> _permintaanAktif(String idPenumpang) async {
    final snap = await _col.where('idPenumpang', isEqualTo: idPenumpang).get();
    final docs = snap.docs
        .where((d) => !Permintaan.fromFirestore(d).sudahSelesai)
        .toList();
    if (docs.isEmpty) return null;
    docs.sort(_urutDibuatPadaDesc);
    return Permintaan.fromFirestore(docs.first);
  }

  /// Mendengarkan satu dokumen permintaan (untuk layar status penumpang).
  /// Mengembalikan null bila dokumen tidak ada.
  Stream<Permintaan?> streamPermintaan(String id) => _col
      .doc(id)
      .snapshots()
      .map((snap) => snap.exists ? Permintaan.fromFirestore(snap) : null);

  /// Mendengarkan seluruh koleksi, terbaru di atas, maksimal 100.
  ///
  /// Hanya `orderBy` satu field sehingga TIDAK butuh composite index.
  /// Pemisahan "aktif" vs "selesai hari ini" dilakukan di sisi UI.
  Stream<List<Permintaan>> streamSemua() => _col
      .orderBy('dibuatPada', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) => snap.docs.map(Permintaan.fromFirestore).toList());

  /// Mendengarkan permintaan TERBARU milik satu penumpang (untuk layar keluarga).
  ///
  /// Sengaja tanpa `orderBy` (where + orderBy butuh composite index): dokumen
  /// diurutkan di sisi aplikasi berdasarkan `dibuatPada`, lalu ambil yang terbaru.
  Stream<Permintaan?> streamTerbaruPenumpang(String idPenumpang) =>
      _col.where('idPenumpang', isEqualTo: idPenumpang).snapshots().map((snap) {
        final docs = snap.docs.toList();
        if (docs.isEmpty) return null;
        docs.sort(_urutDibuatPadaDesc);
        return Permintaan.fromFirestore(docs.first);
      });

  /// Mendengarkan cuplikan verifikasi anonim satu tugas (koleksi
  /// `permintaan_foto/{idTugas}`, PROJECT.md bagian 4). Mengembalikan null
  /// bila dokumen foto tidak ada — sudah dihapus detektor setelah TTL —
  /// sehingga UI menampilkan state "Cuplikan sudah kedaluwarsa".
  /// Hanya layar petugas yang memakai ini (need-to-know).
  Stream<FotoPermintaan?> streamFoto(String idTugas) => _db
      .collection('permintaan_foto')
      .doc(idTugas)
      .snapshots()
      .map((snap) => snap.exists ? FotoPermintaan.fromFirestore(snap) : null);

  /// Antrean per-id untuk [majukanStatus] dan [tolakTugas]. Ketukan ganda pada
  /// perangkat yang sama diurutkan supaya panggilan kedua membaca status yang
  /// sudah dimajukan panggilan pertama; antar perangkat, transaksi Firestore
  /// yang menjaga.
  final Map<String, Future<void>> _antreanMaju = <String, Future<void>>{};

  /// Menjalankan [aksi] dalam antrean per-id: tulisan pada satu dokumen tidak
  /// berpacu. Ekor antrean tidak boleh ikut gagal — panggilan berikutnya harus
  /// tetap berjalan walau panggilan ini melempar (mis. jaringan putus).
  Future<void> _antrePerId(String id, Future<void> Function() aksi) {
    final ekor = _antreanMaju[id] ?? Future<void>.value();
    final hasil = ekor.then((_) => aksi());
    final ekorBaru = hasil.then<void>((_) {}, onError: (Object _) {});
    _antreanMaju[id] = ekorBaru;
    ekorBaru.whenComplete(() {
      if (identical(_antreanMaju[id], ekorBaru)) _antreanMaju.remove(id);
    });
    return hasil;
  }

  /// Memajukan status ke tahap berikutnya (menunggu -> ... -> selesai).
  ///
  /// Dijalankan dalam **transaksi** supaya dua petugas yang menekan tombol pada
  /// saat bersamaan tidak melompati satu tahap: pembacaan status dan penulisannya
  /// terjadi atomik, dan Firestore mengulang transaksi bila dokumen berubah di
  /// tengah jalan.
  ///
  /// Memperbarui `status` & `diperbaruiPada` (serverTimestamp), menambah entri
  /// `riwayat` lewat `FieldValue.arrayUnion` (waktu pakai `Timestamp.now()`,
  /// BUKAN serverTimestamp — arrayUnion tidak menerima sentinel), dan mengisi
  /// `petugas` = "Rina" saat jadi `ditugaskan`.
  /// Tidak melakukan apa-apa bila dokumen tidak ada, status sudah `selesai`,
  /// tugas sudah ditolak, atau tahap berikutnya sudah tercatat di `riwayat`
  /// (transaksi kembar).
  Future<void> majukanStatus(String id) =>
      _antrePerId(id, () => _majukanDalamTransaksi(id));

  Future<void> _majukanDalamTransaksi(String id) async {
    final ref = _col.doc(id);
    await _db.runTransaction<void>((tx) async {
      // Semua pembacaan harus mendahului semua penulisan dalam transaksi.
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) return;
      // Tugas yang sudah ditolak (false-positive kamera) tidak boleh dimajukan.
      if (data['ditolakPada'] != null) return;

      final sekarang = StatusPermintaan.dariValue(data['status'] as String?);
      final berikutnya = sekarang.berikutnya;
      if (berikutnya == null) return; // sudah selesai

      // Penjaga tambahan di sisi aplikasi: bila tahap berikutnya sudah ada di
      // riwayat, permintaan ini sudah dimajukan pihak lain — jangan menambah
      // entri kembar walau transaksi tidak diulang (mis. saat pengujian).
      final riwayat = data['riwayat'];
      if (riwayat is List &&
          riwayat.any((e) => e is Map && e['status'] == berikutnya.value)) {
        return;
      }

      final update = <String, dynamic>{
        'status': berikutnya.value,
        'diperbaruiPada': FieldValue.serverTimestamp(),
        'riwayat': FieldValue.arrayUnion(<Map<String, dynamic>>[
          <String, dynamic>{
            'status': berikutnya.value,
            'waktu': Timestamp.now(),
          },
        ]),
      };
      if (berikutnya == StatusPermintaan.ditugaskan) {
        update['petugas'] = DummyData.petugas.nama; // 'Rina'
      }
      tx.update(ref, update);
    });
  }

  /// Menolak tugas kamera AI (tombol "Bukan penumpang / tolak", O1 + A3).
  ///
  /// Menulis `ditolakPada` (serverTimestamp) + `alasanTolak` dan memperbarui
  /// `diperbaruiPada`; enum `status` dan `riwayat` TIDAK disentuh (kontrak
  /// bagian 4). Tugas keluar dari daftar aktif lewat `ditolakPada`.
  ///
  /// Hanya berlaku untuk tugas `kamera_ai` yang belum selesai dan belum
  /// ditolak; idempoten terhadap ketukan ganda. memakai antrean per-id yang
  /// sama dengan [majukanStatus] agar tolak dan majukan tidak berpacu.
  Future<void> tolakTugas(String id, {String? alasan}) =>
      _antrePerId(id, () => _tolakDalamTransaksi(id, alasan));

  Future<void> _tolakDalamTransaksi(String id, String? alasan) async {
    final ref = _col.doc(id);
    await _db.runTransaction<void>((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) return;
      if (data['sumber'] != 'kamera_ai') return; // hanya tugas kamera AI
      if (data['ditolakPada'] != null) return; // sudah ditolak: idempoten
      final status = StatusPermintaan.dariValue(data['status'] as String?);
      if (status == StatusPermintaan.selesai) return;
      tx.update(ref, <String, dynamic>{
        'ditolakPada': FieldValue.serverTimestamp(),
        'alasanTolak': alasan,
        'diperbaruiPada': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Menandai penumpang sudah tiba di titik jemput (tombol "Saya sudah sampai
  /// di lobi"). Menyimpan `tibaPada` (serverTimestamp) supaya petugas melihat
  /// kabar ini di detail tugas, dan memperbarui `diperbaruiPada`.
  ///
  /// Idempoten: bila `tibaPada` sudah terisi, tidak menulis ulang sehingga
  /// ketukan ganda tidak menggeser jam kedatangan.
  Future<void> tandaiTiba(String id) async {
    final ref = _col.doc(id);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null) return;
    if (data['tibaPada'] != null) return;
    await ref.update(<String, dynamic>{
      'tibaPada': FieldValue.serverTimestamp(),
      'diperbaruiPada': FieldValue.serverTimestamp(),
    });
  }

  /// Pembanding untuk mengurutkan dokumen berdasar `dibuatPada` menurun
  /// (terbaru dulu). Dokumen tanpa `dibuatPada` (serverTimestamp belum terisi)
  /// dianggap paling lama.
  static int _urutDibuatPadaDesc(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final ta = a.data()['dibuatPada'] as Timestamp?;
    final tb = b.data()['dibuatPada'] as Timestamp?;
    if (ta == null && tb == null) return 0;
    if (ta == null) return 1;
    if (tb == null) return -1;
    return tb.compareTo(ta);
  }
}
