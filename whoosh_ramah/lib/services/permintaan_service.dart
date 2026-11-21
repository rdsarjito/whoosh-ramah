import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/dummy.dart';
import '../models/permintaan.dart';

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
  /// Mengembalikan id dokumen baru. Data penumpang & tiket diambil dari data
  /// dummy demo (bagian 5). `status` = menunggu, `sumber` = aplikasi, `riwayat`
  /// diisi entri awal, `dibuatPada`/`diperbaruiPada` pakai serverTimestamp.
  Future<String> buatPermintaan({
    required JenisBantuan jenisBantuan,
    required String titikJemput,
    String? catatan,
  }) async {
    final tiket = DummyData.tiket;
    final penumpang = DummyData.penumpang;
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
    return ref.id;
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

  /// Memajukan status ke tahap berikutnya (menunggu -> ... -> selesai).
  ///
  /// Memperbarui `status` & `diperbaruiPada` (serverTimestamp), menambah entri
  /// `riwayat` lewat `FieldValue.arrayUnion` (waktu pakai `Timestamp.now()`,
  /// BUKAN serverTimestamp), dan mengisi `petugas` = "Rina" saat jadi `ditugaskan`.
  /// Tidak melakukan apa-apa bila dokumen tidak ada atau status sudah `selesai`.
  Future<void> majukanStatus(String id) async {
    final ref = _col.doc(id);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null) return;

    final sekarang = StatusPermintaan.dariValue(data['status'] as String?);
    final berikutnya = sekarang.berikutnya;
    if (berikutnya == null) return; // sudah selesai

    final update = <String, dynamic>{
      'status': berikutnya.value,
      'diperbaruiPada': FieldValue.serverTimestamp(),
      'riwayat': FieldValue.arrayUnion(<Map<String, dynamic>>[
        <String, dynamic>{'status': berikutnya.value, 'waktu': Timestamp.now()},
      ]),
    };
    if (berikutnya == StatusPermintaan.ditugaskan) {
      update['petugas'] = DummyData.petugas.nama; // 'Rina'
    }
    await ref.update(update);
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
