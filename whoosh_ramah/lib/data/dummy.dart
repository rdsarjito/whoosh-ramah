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

  /// Kode pemesanan yang ditampilkan sebagai QR dan bisa disalin.
  /// Diturunkan dari data tiket agar konsisten bila jadwal diubah.
  String get kodePesan => 'WR-$kereta-$gerbong$kursi';

  /// Ringkasan satu baris untuk QR / berbagi: "G1123 · Halim 08.10 → Tegalluar 08.56".
  String get ringkasanRute =>
      '$kereta · $stasiunAsal $jamBerangkat → $stasiunTujuan $jamTiba';
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

  /// Pilihan jadwal pada lembar "Ubah jadwal" (Tier 2). Entri pertama adalah
  /// jadwal saat ini; sisanya kereta lain di hari yang sama dengan rute dan
  /// kelas yang sama, agar perpindahan jadwal terasa nyata bagi demo.
  static const List<TiketDummy> jadwalAlternatif = <TiketDummy>[
    tiket,
    TiketDummy(
      kereta: 'G1127',
      stasiunAsal: 'Halim',
      jamBerangkat: '09.05',
      stasiunTujuan: 'Tegalluar',
      jamTiba: '09.51',
      tanggal: '22 Nov',
      gerbong: '3',
      kursi: '2C',
      kelas: 'Premium Economy',
      label: 'Tiket contoh',
    ),
    TiketDummy(
      kereta: 'G1131',
      stasiunAsal: 'Halim',
      jamBerangkat: '10.00',
      stasiunTujuan: 'Tegalluar',
      jamTiba: '10.46',
      tanggal: '22 Nov',
      gerbong: '6',
      kursi: '11A',
      kelas: 'Premium Economy',
      label: 'Tiket contoh',
    ),
    TiketDummy(
      kereta: 'G1135',
      stasiunAsal: 'Halim',
      jamBerangkat: '11.15',
      stasiunTujuan: 'Tegalluar',
      jamTiba: '12.01',
      tanggal: '22 Nov',
      gerbong: '2',
      kursi: '4D',
      kelas: 'Premium Economy',
      label: 'Tiket contoh',
    ),
  ];

  /// Pilihan titik jemput (dipakai di layar pesan pendamping).
  static const List<String> titikJemput = <String>[
    'Lobi utama',
    'Area parkir',
    'Kereta pengumpan',
  ];
}
