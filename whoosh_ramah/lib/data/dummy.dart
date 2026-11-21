/// Data dummy yang di-hard-code di aplikasi (PROJECT.md bagian 5).
///
/// Semua nama dan data tiket adalah contoh untuk demo hackathon. Nama field
/// sengaja disamakan dengan field dokumen Firestore agar mudah dipakai saat
/// membuat permintaan pendampingan pada langkah berikutnya.
library;

/// Penumpang demo yang dipakai di seluruh alur.
class PenumpangDummy {
  const PenumpangDummy({required this.namaPenumpang, required this.idPenumpang});

  final String namaPenumpang; // 'Siti Aminah'
  final String idPenumpang; // 'demo-siti'
}

/// Petugas layanan demo.
class PetugasDummy {
  const PetugasDummy({required this.nama, required this.peran, required this.stasiun});

  final String nama; // 'Rina' — nilai untuk field `petugas` di Firestore
  final String peran; // 'Petugas Layanan'
  final String stasiun; // 'Stasiun Halim'

  /// Label lengkap seperti pada desain: "Petugas Layanan · Stasiun Halim".
  String get peranLengkap => '$peran · $stasiun';
}

/// Tiket aktif dummy.
class TiketDummy {
  const TiketDummy({
    required this.kereta,
    required this.stasiunAsal,
    required this.jamBerangkat,
    required this.stasiunTujuan,
    required this.jamTiba,
    required this.tanggal,
    required this.gerbong,
    required this.kursi,
    required this.kelas,
    required this.label,
  });

  final String kereta; // 'G1123'
  final String stasiunAsal; // 'Halim'
  final String jamBerangkat; // '08.10'
  final String stasiunTujuan; // 'Tegalluar'
  final String jamTiba; // '08.56'
  final String tanggal; // '22 Nov' (Sabtu)
  final String gerbong; // '5'
  final String kursi; // '7A'
  final String kelas; // 'Premium Economy'
  final String label; // 'Tiket contoh'
}

/// Kumpulan data dummy untuk demo.
class DummyData {
  DummyData._();

  static const PenumpangDummy penumpang = PenumpangDummy(
    namaPenumpang: 'Siti Aminah',
    idPenumpang: 'demo-siti',
  );

  static const PetugasDummy petugas = PetugasDummy(
    nama: 'Rina',
    peran: 'Petugas Layanan',
    stasiun: 'Stasiun Halim',
  );

  static const TiketDummy tiket = TiketDummy(
    kereta: 'G1123',
    stasiunAsal: 'Halim',
    jamBerangkat: '08.10',
    stasiunTujuan: 'Tegalluar',
    jamTiba: '08.56',
    tanggal: '22 Nov',
    gerbong: '5',
    kursi: '7A',
    kelas: 'Premium Economy',
    label: 'Tiket contoh',
  );

  /// Pilihan titik jemput (dipakai di layar pesan pendamping).
  static const List<String> titikJemput = <String>[
    'Lobi utama',
    'Area parkir',
    'Kereta pengumpan',
  ];
}
