# Whoosh Ramah – Spesifikasi Project (untuk AI coding)

> Dokumen ini adalah sumber kebenaran project. Baca seluruhnya sebelum menulis kode.
> Kerjakan **satu langkah per perintah** (lihat bagian 10). Jangan menambah fitur di luar dokumen ini.

---

## 1. Konteks bisnis (ringkasan BRD)

**Masalah.** Penumpang prioritas kereta cepat Whoosh (lansia, penyandang disabilitas, ibu hamil, penumpang sakit, anak tanpa pendamping) bisa mendapat pendampingan dari petugas KCIC, tetapi permintaannya masih manual: datang ke petugas di stasiun atau menelepon Contact Center. Petugas sering baru tahu saat penumpang tiba, data kursi diteruskan manual ke stasiun tujuan, dan keluarga tidak bisa memantau.

**Data pendukung (publik).**
- KCIC melayani sekitar 9.000 penumpang prioritas pada Januari–Agustus 2026.
- Permintaan pendampingan lansia sekitar 60/hari (hari biasa) dan 100/hari (akhir pekan); 64 petugas pelayanan terlatih (data Mei 2025).

**Solusi.** Whoosh Ramah: aplikasi untuk memesan pendamping, menugaskan petugas, meneruskan data ke stasiun tujuan, dan memberi pantauan ke keluarga. Ditambah **kamera AI** yang mendeteksi pengguna kursi roda di pintu masuk dan membuat tugas otomatis.

**Tujuan hackathon.** Prototipe yang bisa didemokan langsung di 2–3 HP + 1 laptop dalam 1 minggu, dikerjakan 1 orang.

**Di luar cakupan (JANGAN dibuat).** Login/akun sungguhan, integrasi sistem tiket KCIC, pembayaran, penjadwalan petugas otomatis, notifikasi push, penyimpanan foto wajah.

---

## 2. Arsitektur

```
[Laptop: detector/detect_wheelchair.py]  --menulis-->  [Firebase Cloud Firestore]
                                                              ^        |
[HP Penumpang] --menulis permintaan------------------------- |        | (real-time)
[HP Petugas]   <--membaca tugas / mengubah status----------- +        v
[HP Keluarga]  <--membaca status---------------------------------------
```

- **Satu aplikasi Flutter** (Android/iOS) dengan layar pilih peran: Penumpang, Petugas, Keluarga.
- **Database:** Cloud Firestore (real-time, tanpa server sendiri).
- **Detektor kursi roda:** Python + YOLO-World (sudah jadi, folder `detector/`). Aplikasi Flutter TIDAK menjalankan AI; ia hanya membaca tugas yang ditulis detektor.

---

## 3. Paket Flutter

```yaml
dependencies:
  firebase_core: ^3.0.0      # pakai versi terbaru yang kompatibel
  cloud_firestore: ^5.0.0
  google_fonts: ^6.0.0       # font Nunito
  intl: ^0.19.0              # format jam "08.10"
```

Setup Firebase: `dart pub global activate flutterfire_cli` lalu `flutterfire configure`.

---

## 4. Struktur data Firestore

### Koleksi `permintaan_pendampingan`

Nama koleksi dan field **harus sama persis** dengan yang ditulis `detector/detect_wheelchair.py`.

| Field | Tipe | Contoh | Diisi oleh |
| --- | --- | --- | --- |
| `jenisBantuan` | string (enum) | `kursi_roda` | penumpang / detektor |
| `titikJemput` | string | `Lobi utama` | penumpang / detektor |
| `status` | string (enum) | `menunggu` | semua |
| `sumber` | string | `aplikasi` atau `kamera_ai` | otomatis |
| `namaPenumpang` | string \| null | `Siti Aminah` (null dari kamera) | penumpang |
| `idPenumpang` | string \| null | `demo-siti` | penumpang |
| `kereta` | string \| null | `G1123` | penumpang |
| `jamBerangkat` | string \| null | `08.10` | penumpang |
| `stasiunAsal` | string \| null | `Halim` | penumpang |
| `stasiunTujuan` | string \| null | `Tegalluar` | penumpang |
| `gerbong` | string \| null | `5` | penumpang |
| `kursi` | string \| null | `7A` | penumpang |
| `catatan` | string \| null | `membawa satu koper besar` | penumpang |
| `petugas` | string \| null | `Rina` | petugas |
| `idKamera` | string \| null | `halim-utara-01` | detektor |
| `keyakinan` | number \| null | `0.87` | detektor |
| `adaFoto` | bool | `true` | detektor (hanya bila cuplikan anonim berhasil ditulis; tanpa field = tidak ada foto) |
| `ditolakPada` | Timestamp \| null | – | petugas (tombol "Bukan penumpang / tolak", khusus tugas kamera AI) |
| `alasanTolak` | string \| null | `Bukan pengguna kursi roda` | petugas |
| `riwayat` | array of map | `[{status: "menunggu", waktu: Timestamp}]` | semua (tambah setiap ubah status) |
| `dibuatPada` | Timestamp (server) | – | otomatis |
| `diperbaruiPada` | Timestamp (server) | – | otomatis |

**Enum `jenisBantuan`:** `kursi_roda`, `tunanetra`, `tuli`, `lansia`, `hamil`, `porter`
Label tampilan: Kursi roda, Tunanetra, Tuli, Lansia, Ibu hamil, Porter barang.

**Enum `status` (urutan wajib):**

| Nilai | Label untuk penumpang/keluarga | Tombol petugas untuk ke status ini |
| --- | --- | --- |
| `menunggu` | Permintaan diterima | – |
| `ditugaskan` | Petugas ditugaskan | "Terima tugas" |
| `bertemu` | Bertemu petugas | "Sudah bertemu penumpang" |
| `di_kursi` | Sudah duduk di kursi | "Penumpang sudah di kursi" |
| `selesai` | Diserahkan ke petugas tujuan | "Serahkan ke petugas tujuan" |

Catatan: dokumen dari detektor tidak punya `riwayat`. Aplikasi harus menangani field yang tidak ada (null-safe).

Penolakan tugas kamera (tombol "Bukan penumpang / tolak") TIDAK menambah nilai enum `status`: dokumen tetap pada statusnya, tetapi `ditolakPada` terisi sehingga keluar dari daftar aktif petugas dan dihitung terpisah di ringkasan.

### Koleksi `permintaan_foto` (cuplikan verifikasi petugas)

Cuplikan disimpan sebagai base64 di Firestore, **bukan Cloud Storage** — project di paket Spark dan Storage sekarang mewajibkan paket Blaze. Satu dokumen per tugas; id dokumen = id dokumen tugas (`permintaan_foto/{idTugas}`).

| Field | Tipe | Keterangan |
| --- | --- | --- |
| `gambar` | string (base64) | JPEG cuplikan anonim: maks 160 px, dipikselkan, wajah di-blur dengan Haar cascade, kualitas 60 |
| `dibuatPada` | Timestamp (server) | waktu cuplikan ditulis |
| `kedaluwarsaPada` | Timestamp | `dibuatPada` + `FOTO_TTL_DETIK` (default 600 detik / 10 menit) |

- Detektor menulis dokumen foto setelah dokumen tugas dibuat, lalu menandai tugas dengan `adaFoto: true`. Bila penulisan foto gagal, tugas tetap dibuat tanpa foto.
- Detektor menghapus dokumen foto setelah `FOTO_TTL_DETIK` lewat thread latar. Aplikasi harus menangani dokumen yang sudah hilang: tampilkan state "Cuplikan sudah kedaluwarsa".
- Hanya layar petugas yang membaca koleksi ini (need-to-know). Penumpang dan keluarga tidak pernah menerima cuplikan.

### Aturan keamanan (KHUSUS DEMO)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /permintaan_pendampingan/{doc} {
      allow read, write: if true;   // HANYA untuk demo hackathon. Jangan dipakai produksi.
    }
    match /permintaan_foto/{doc} {
      allow read, write: if true;   // HANYA untuk demo hackathon. Jangan dipakai produksi.
    }
  }
}
```

---

## 5. Data dummy (hard-coded di aplikasi)

- **Penumpang demo:** Siti Aminah, `idPenumpang = demo-siti`.
- **Tiket aktif:** Whoosh G1123, Halim 08.10 → Tegalluar 08.56, Sabtu 22 Nov, Gerbong 5, Kursi 7A, Premium Economy. Tampilkan label "Tiket contoh".
- **Petugas demo:** Rina, Petugas Layanan Stasiun Halim.
- **Titik jemput:** Lobi utama, Area parkir, Kereta pengumpan.

---

## 6. Layar & perilaku

Desain visual setiap layar ada di folder `design/` (file HTML, buka di browser atau baca CSS-nya). Tiru tata letak, warna, ukuran huruf, dan sudut membulatnya.

| # | Layar | File desain | Isi & perilaku |
| --- | --- | --- | --- |
| 0 | Pilih peran | `Main.dc.html` | Judul, ilustrasi kereta, 3 kartu: Penumpang, Petugas, Keluarga |
| 1 | Penumpang – Tiket aktif | `Penumpang-Tiket.dc.html` | Kartu tiket dummy, tombol besar "Butuh pendampingan" → layar 2, tombol "Ganti peran" → layar 0 |
| 2 | Penumpang – Pesan pendamping | `Penumpang-Pesan.dc.html` | Pilih 1 dari 6 jenis bantuan, pilih 1 dari 3 titik jemput, catatan opsional. "Kirim permintaan" → buat dokumen Firestore (`status: menunggu`, `sumber: aplikasi`, data tiket dummy) → layar 3 |
| 3 | Penumpang – Status | `Penumpang-Status.dc.html` | Mendengarkan dokumen yang baru dibuat secara real-time. Timeline 5 status. Nama petugas muncul setelah `ditugaskan`. Tombol "Bagikan ke keluarga" → layar 7 |
| 4 | Kamera AI | `Kamera-AI.dc.html` | **Tidak dibuat di Flutter.** Ini jendela detektor Python. Desain hanya acuan |
| 5 | Petugas – Daftar tugas | `Petugas-Tugas.dc.html` | Daftar real-time semua dokumen dengan `status != selesai` dan belum ditolak (`ditolakPada` null), terbaru di atas. Badge merah "Kamera AI" (sumber `kamera_ai`) atau biru "Aplikasi". Ringkasan jumlah Baru/Berjalan/Selesai/Ditolak. Kartu Kamera AI ber-`adaFoto` menampilkan thumbnail cuplikan anonim (state "Cuplikan sudah kedaluwarsa" bila dokumen foto hilang). Ketuk kartu → layar 6 |
| 6 | Petugas – Detail tugas | `Petugas-Detail.dc.html` | Info penumpang (atau "Penumpang belum diketahui" untuk kamera AI), stepper status, satu tombol besar yang memajukan status ke tahap berikutnya (update Firestore + tambah `riwayat` + isi `petugas: "Rina"` saat `ditugaskan`). Bila `adaFoto`: cuplikan verifikasi penuh (`Image.memory` dari base64 `permintaan_foto/{idTugas}`) + tombol sekunder "Bukan penumpang / tolak" khusus tugas kamera AI yang belum selesai/ditolak — menulis `ditolakPada` + `alasanTolak` tanpa mengubah enum `status` |
| 7 | Keluarga – Pantau | `Keluarga-Pantau.dc.html` | Mendengarkan permintaan terbaru milik `idPenumpang = demo-siti`. Kartu status saat ini, progres perjalanan, riwayat dengan jam |

---

## 7. Panduan desain (Gaya B "Cerah & ramah")

**Font:** Nunito (lewat `google_fonts`), berat 600–900. Ukuran minimum 13; teks utama 15–17; judul 25–30.

**Warna**

| Nama | Hex | Dipakai untuk |
| --- | --- | --- |
| Latar | `#F5F6FA` | Latar semua layar |
| Teks utama | `#1F2430` | Teks |
| Teks sekunder | `#5F6574` | Keterangan |
| Merah utama | `#E11D2E` | Tombol utama penumpang, badge Kamera AI |
| Merah teks | `#B00E28` | Teks merah di atas merah muda |
| Merah muda (hero penumpang) | `#FFE4E8` | Header penumpang, chip terpilih |
| Biru petugas | `#1E50C8` | Tombol & aksen petugas |
| Biru muda (hero petugas) | `#E3ECFF` | Header petugas |
| Hijau keluarga/sukses | `#17663F` | Tombol keluarga, status selesai |
| Hijau muda (hero keluarga) | `#E3F4EA` | Header keluarga |
| Abu kartu dalam | `#F3F4F8` | Kotak info di dalam kartu |
| Kuning catatan | `#FFF3D6` + teks `#5C3D00` | Catatan penumpang |

**Bentuk & komponen**
- Header ("hero") berwarna dengan sudut bawah membulat 32–40, kartu putih utama menumpuk di atasnya (margin atas negatif ±48).
- Kartu putih: radius 24–28, bayangan lembut (`blur 34, y 14, opacity 10%`).
- Tombol utama: bentuk pil, tinggi 60–68, teks 18–19 tebal 900.
- Tombol sekunder: pil putih dengan garis 2 px `#E4E6EE`, tinggi 46–54.
- Menu bawah: kotak putih melayang, radius 26, item aktif berlatar warna muda peran.
- Pilihan (jenis bantuan, titik jemput): kotak radius 20–22; terpilih = latar merah muda + garis merah 2 px.

---

## 8. Aksesibilitas (wajib)

- Semua tombol minimal 48×48 dp.
- Ikon tanpa teks harus punya `Semantics(label: ...)` atau `tooltip`.
- Uji dengan TalkBack (Android) atau VoiceOver (iOS): semua langkah dari layar 1 sampai 3 harus bisa dilakukan tanpa melihat layar.
- Ikuti pengaturan ukuran huruf HP (jangan kunci `textScaler`), pastikan tata letak tidak pecah di ukuran huruf 130%.
- Status tidak boleh hanya dibedakan warna; selalu ada teks.

---

## 9. Struktur folder Flutter

```
whoosh_ramah/
  lib/
    main.dart                     # inisialisasi Firebase, MaterialApp, rute
    theme.dart                    # warna, font, gaya tombol & kartu (bagian 7)
    models/
      permintaan.dart             # model + fromFirestore/toFirestore, enum status & jenis
    services/
      permintaan_service.dart     # semua akses Firestore (buat, stream, majukan status)
    data/
      dummy.dart                  # tiket, penumpang, petugas dummy (bagian 5)
    widgets/                      # HeroHeader, PillButton, InfoCard, StatusTimeline, BottomNav
    screens/
      pilih_peran_screen.dart
      penumpang_tiket_screen.dart
      penumpang_pesan_screen.dart
      penumpang_status_screen.dart
      petugas_tugas_screen.dart
      petugas_detail_screen.dart
      keluarga_pantau_screen.dart
detector/                         # sudah jadi (Python)
design/                           # acuan desain HTML
```

---

## 10. Urutan pengerjaan + perintah siap salin

Setelah setiap langkah: jalankan aplikasi, tes, lalu `git commit`.

**Langkah 1 – Fondasi**
> Baca PROJECT.md. Buat proyek Flutter `whoosh_ramah` sesuai struktur folder bagian 9. Tambahkan paket di bagian 3. Buat `theme.dart` dari bagian 7 dan `dummy.dart` dari bagian 5. Buat `main.dart` yang menginisialisasi Firebase (anggap `flutterfire configure` sudah dijalankan dan `firebase_options.dart` ada). Belum perlu layar apa pun selain layar kosong.

**Langkah 2 – Model & service**
> Buat `models/permintaan.dart` dan `services/permintaan_service.dart` sesuai bagian 4: buat permintaan baru, stream satu dokumen, stream daftar tugas aktif, stream permintaan terbaru per `idPenumpang`, dan fungsi `majukanStatus` yang memperbarui `status`, `diperbaruiPada`, menambah `riwayat`, dan mengisi `petugas` saat `ditugaskan`. Tangani field null dari detektor.

**Langkah 3 – Pilih peran & tiket**
> Buat layar 0 dan 1 (bagian 6) persis seperti `design/Main.dc.html` dan `design/Penumpang-Tiket.dc.html`, memakai komponen di `widgets/`.

**Langkah 4 – Pesan pendamping**
> Buat layar 2 seperti `design/Penumpang-Pesan.dc.html`. Tombol "Kirim permintaan" membuat dokumen lewat service, lalu membuka layar 3 dengan id dokumen tersebut.

**Langkah 5 – Status penumpang**
> Buat layar 3 seperti `design/Penumpang-Status.dc.html`, mendengarkan dokumen secara real-time dan menampilkan timeline 5 status.

**Langkah 6 – Petugas**
> Buat layar 5 dan 6 seperti `design/Petugas-Tugas.dc.html` dan `design/Petugas-Detail.dc.html`. Daftar real-time, badge sumber, dan tombol yang memajukan status.

**Langkah 7 – Keluarga**
> Buat layar 7 seperti `design/Keluarga-Pantau.dc.html`, mendengarkan permintaan terbaru `idPenumpang = demo-siti`.

**Langkah 8 – Aksesibilitas & rapikan**
> Periksa semua layar terhadap bagian 8. Tambahkan Semantics, pastikan ukuran sentuh, uji ukuran huruf 130%.

---

## 11. Checklist demo (definition of done)

- [ ] Detektor (laptop) melihat kursi roda → kartu "Kamera AI" muncul di HP petugas dalam beberapa detik.
- [ ] Penumpang memesan pendamping → muncul di HP petugas.
- [ ] Petugas menekan tombol status → HP penumpang dan HP keluarga ikut berubah.
- [ ] Alur penumpang bisa dilakukan dengan TalkBack/VoiceOver.
- [ ] Ada video cadangan demo kalau internet bermasalah.

## 12. Privasi

- Kamera tidak menyimpan foto wajah. Cuplikan anonim (wajah disamarkan) disimpan maksimal 10 menit hanya untuk verifikasi petugas, lalu dihapus otomatis.
- Semua nama dan data tiket adalah contoh.
