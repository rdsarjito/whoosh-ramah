import 'package:cloud_firestore/cloud_firestore.dart';

/// Jenis bantuan yang diminta penumpang (PROJECT.md bagian 4).
///
/// [value] adalah string yang disimpan di Firestore dan HARUS sama persis
/// dengan yang ditulis `detector/detect_wheelchair.py`; [label] untuk tampilan.
enum JenisBantuan {
  kursiRoda('kursi_roda', 'Kursi roda'),
  tunanetra('tunanetra', 'Tunanetra'),
  tuli('tuli', 'Tuli'),
  lansia('lansia', 'Lansia'),
  hamil('hamil', 'Ibu hamil'),
  porter('porter', 'Porter barang');

  const JenisBantuan(this.value, this.label);

  final String value;
  final String label;

  /// Mengubah string Firestore menjadi enum; fallback ke [kursiRoda].
  static JenisBantuan dariValue(String? value) => JenisBantuan.values.firstWhere(
        (e) => e.value == value,
        orElse: () => JenisBantuan.kursiRoda,
      );
}

/// Status pendampingan dengan urutan wajib (PROJECT.md bagian 4).
///
/// [label] untuk penumpang/keluarga; [tombolPetugas] adalah label tombol yang
/// dipakai petugas untuk memajukan status ke tahap ini (null untuk [menunggu]).
/// Teks khusus per layar (mis. "Serahkan ke petugas Tegalluar") disusun di UI.
enum StatusPermintaan {
  menunggu('menunggu', 'Permintaan diterima', null),
  ditugaskan('ditugaskan', 'Petugas ditugaskan', 'Terima tugas'),
  bertemu('bertemu', 'Bertemu petugas', 'Sudah bertemu penumpang'),
  diKursi('di_kursi', 'Sudah duduk di kursi', 'Penumpang sudah di kursi'),
  selesai('selesai', 'Diserahkan ke petugas tujuan', 'Serahkan ke petugas tujuan');

  const StatusPermintaan(this.value, this.label, this.tombolPetugas);

  final String value;
  final String label;
  final String? tombolPetugas;

  /// Status berikutnya sesuai urutan wajib, atau null jika sudah [selesai].
  StatusPermintaan? get berikutnya {
    final i = StatusPermintaan.values.indexOf(this);
    if (i < 0 || i >= StatusPermintaan.values.length - 1) return null;
    return StatusPermintaan.values[i + 1];
  }

  /// Mengubah string Firestore menjadi enum; fallback ke [menunggu].
  static StatusPermintaan dariValue(String? value) => StatusPermintaan.values.firstWhere(
        (e) => e.value == value,
        orElse: () => StatusPermintaan.menunggu,
      );
}

/// Satu entri pada array `riwayat`: status + waktu perubahannya.
class RiwayatStatus {
  const RiwayatStatus({required this.status, this.waktu});

  final String status; // nilai enum status, mis. 'menunggu'
  final DateTime? waktu;

  factory RiwayatStatus.fromMap(Map<dynamic, dynamic> map) => RiwayatStatus(
        status: map['status'] as String? ?? '',
        waktu: (map['waktu'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'status': status,
        'waktu': waktu == null ? null : Timestamp.fromDate(waktu!),
      };
}

/// Model satu dokumen pada koleksi `permintaan_pendampingan`.
///
/// Null-safe: dokumen dari detektor tidak punya `riwayat`, `diperbaruiPada`,
/// `idPenumpang`, `kereta`, `gerbong`, `kursi`, `catatan`, dan `petugas`.
class Permintaan {
  const Permintaan({
    required this.id,
    required this.jenisBantuan,
    required this.titikJemput,
    required this.status,
    required this.sumber,
    this.namaPenumpang,
    this.idPenumpang,
    this.kereta,
    this.jamBerangkat,
    this.stasiunAsal,
    this.stasiunTujuan,
    this.gerbong,
    this.kursi,
    this.catatan,
    this.petugas,
    this.idKamera,
    this.keyakinan,
    this.riwayat = const <RiwayatStatus>[],
    this.dibuatPada,
    this.diperbaruiPada,
  });

  final String id;
  final JenisBantuan jenisBantuan;
  final String titikJemput;
  final StatusPermintaan status;
  final String sumber; // 'aplikasi' | 'kamera_ai'
  final String? namaPenumpang;
  final String? idPenumpang;
  final String? kereta;
  final String? jamBerangkat;
  final String? stasiunAsal;
  final String? stasiunTujuan;
  final String? gerbong;
  final String? kursi;
  final String? catatan;
  final String? petugas;
  final String? idKamera;
  final double? keyakinan;
  final List<RiwayatStatus> riwayat;
  final DateTime? dibuatPada;
  final DateTime? diperbaruiPada;

  /// true bila tugas dibuat otomatis oleh kamera AI (bukan lewat aplikasi).
  bool get dariKamera => sumber == 'kamera_ai';

  /// true bila pendampingan sudah selesai.
  bool get sudahSelesai => status == StatusPermintaan.selesai;

  /// Bagian setelah " - " pada [titikJemput]. Contoh tugas kamera:
  /// "Stasiun Halim - Pintu Masuk Utara" -> "Pintu Masuk Utara".
  /// Bila tidak ada " - ", kembalikan [titikJemput] apa adanya.
  String get lokasiSingkat {
    const pemisah = ' - ';
    final i = titikJemput.indexOf(pemisah);
    if (i < 0) return titikJemput;
    return titikJemput.substring(i + pemisah.length).trim();
  }

  /// [keyakinan] x 100 dibulatkan (0.56 -> 56). Null bila tidak ada keyakinan
  /// (permintaan dari aplikasi tidak menyimpan `keyakinan`).
  int? get persenKeyakinan {
    final k = keyakinan;
    if (k == null) return null;
    return (k * 100).round();
  }

  /// Membangun [Permintaan] dari snapshot Firestore (null-safe).
  factory Permintaan.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snap) {
    return Permintaan.fromMap(snap.data() ?? <String, dynamic>{}, id: snap.id);
  }

  /// Membangun [Permintaan] dari map mentah. Dipisah dari [fromFirestore] agar
  /// bisa diuji tanpa instance Firestore.
  factory Permintaan.fromMap(Map<String, dynamic> data, {String id = ''}) {
    return Permintaan(
      id: id,
      jenisBantuan: JenisBantuan.dariValue(data['jenisBantuan'] as String?),
      titikJemput: data['titikJemput'] as String? ?? '',
      status: StatusPermintaan.dariValue(data['status'] as String?),
      sumber: data['sumber'] as String? ?? 'aplikasi',
      namaPenumpang: data['namaPenumpang'] as String?,
      idPenumpang: data['idPenumpang'] as String?,
      kereta: data['kereta'] as String?,
      jamBerangkat: data['jamBerangkat'] as String?,
      stasiunAsal: data['stasiunAsal'] as String?,
      stasiunTujuan: data['stasiunTujuan'] as String?,
      gerbong: data['gerbong'] as String?,
      kursi: data['kursi'] as String?,
      catatan: data['catatan'] as String?,
      petugas: data['petugas'] as String?,
      idKamera: data['idKamera'] as String?,
      keyakinan: (data['keyakinan'] as num?)?.toDouble(),
      riwayat: _riwayatDari(data['riwayat']),
      dibuatPada: (data['dibuatPada'] as Timestamp?)?.toDate(),
      diperbaruiPada: (data['diperbaruiPada'] as Timestamp?)?.toDate(),
    );
  }

  static List<RiwayatStatus> _riwayatDari(dynamic raw) {
    if (raw is! List) return const <RiwayatStatus>[];
    final hasil = <RiwayatStatus>[];
    for (final e in raw) {
      if (e is Map) hasil.add(RiwayatStatus.fromMap(e));
    }
    return hasil;
  }

  /// Serialisasi ke map Firestore (bagian 9: toFirestore).
  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'jenisBantuan': jenisBantuan.value,
        'titikJemput': titikJemput,
        'status': status.value,
        'sumber': sumber,
        'namaPenumpang': namaPenumpang,
        'idPenumpang': idPenumpang,
        'kereta': kereta,
        'jamBerangkat': jamBerangkat,
        'stasiunAsal': stasiunAsal,
        'stasiunTujuan': stasiunTujuan,
        'gerbong': gerbong,
        'kursi': kursi,
        'catatan': catatan,
        'petugas': petugas,
        'idKamera': idKamera,
        'keyakinan': keyakinan,
        'riwayat': riwayat.map((r) => r.toFirestore()).toList(),
        'dibuatPada': dibuatPada == null ? null : Timestamp.fromDate(dibuatPada!),
        'diperbaruiPada': diperbaruiPada == null ? null : Timestamp.fromDate(diperbaruiPada!),
      };
}
