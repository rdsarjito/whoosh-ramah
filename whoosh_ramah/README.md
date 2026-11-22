# Whoosh Ramah — aplikasi Flutter

Prototipe hackathon pendampingan penumpang prioritas KCIC Whoosh (lansia,
penyandang disabilitas, ibu hamil, porter barang). Satu aplikasi berisi tiga
peran — **penumpang**, **petugas stasiun**, **keluarga** — plus tugas yang masuk
otomatis dari **kamera AI** pendeteksi kursi roda (`../detector/`).

Semua peran membaca/menulis satu koleksi Firestore: `permintaan_pendampingan`
(skema lengkap: `../PROJECT.md` bagian 4).

## Menjalankan

Prasyarat: Flutter **3.50.1 / stable** (Dart 3.14), JDK 17, dan perangkat atau
emulator Android. Konfigurasi Firebase proyek demo `whoosh-ramah` sudah ikut
di repo (`lib/firebase_options.dart`, `android/app/google-services.json`), jadi
tidak perlu `flutterfire configure` lagi.

```bash
cd whoosh_ramah
flutter pub get
flutter run                 # pilih perangkat Android saat diminta
```

Build APK demo: `flutter build apk --debug`.

### Alur demo (±3 menit)

1. **Pilih peran → Penumpang.** Layar tiket menampilkan kereta G1123 Halim →
   Tegalluar, kursi 5/7A. Tombol merah **Butuh pendampingan** membuka layar pesan.
2. Pilih jenis bantuan + titik jemput, tambah catatan, **Kirim permintaan**.
   Layar status terbuka real-time; tekan **Saya sudah sampai di lobi** untuk
   memberi tahu petugas. Lembar **QR tiket** dan **Ubah jadwal** ada di layar tiket.
3. **Pilih peran → Petugas stasiun.** Daftar tugas menampilkan permintaan tadi
   (dan tugas kamera AI bila detektor menyala). Tekan **Terima & datangi** pada
   kartu, lalu majukan status lewat tombol di layar detail sampai
   **Serahkan ke petugas tujuan**.
4. **Pilih peran → Keluarga.** Pantau perjalanan orang tersayang secara
   real-time dengan timeline yang sama.
5. Perubahan status terdengar di TalkBack dan terlihat sebagai animasi +
   kerangka skeleton saat memuat — coba dengan skala teks besar di setelan Android.

> Data penumpang & tiket demo bersifat hard-coded (`lib/data/dummy.dart`,
> PROJECT.md bagian 5), jadi alur penumpang tetap jalan tanpa seed apa pun.

### Seed data Firestore (opsional, untuk daftar petugas yang langsung ramai)

Menulis tiga dokumen demo dengan id tetap `demo-seed-1..3`: permintaan aplikasi
yang menunggu, tugas kamera AI yang sedang berjalan, dan perjalanan selesai.
Aman dijalankan ulang; `--bersih` hanya menghapus ketiga id itu.

```bash
# dari root repo; memakai venv detektor yang sudah punya firebase-admin
detector/venv/bin/python whoosh_ramah/tool/seed_demo.py
detector/venv/bin/python whoosh_ramah/tool/seed_demo.py --bersih
```

Butuh kunci service account `detector/firebase-key.json` (tidak ikut di repo;
lihat `../detector/README.md`). Alternatif tanpa skrip: jalankan detektor
(`../detector/detect_wheelchair.py`) agar tugas kamera AI masuk sendiri.

## Firestore rules & index

`firestore.rules` + `firestore.indexes.json` di-version-kan dan dirujuk oleh
`firebase.json`. Aturannya **terbuka khusus demo** (PROJECT.md bagian 4):
jangan dipakai produksi.

```bash
cd whoosh_ramah
firebase deploy --only firestore:rules,firestore:indexes
```

Tidak ada composite index: semua query hanya `where`/`orderBy` satu field,
sisanya disaring & diurutkan di sisi aplikasi.

## Pengujian

```bash
flutter analyze
flutter test                      # seluruh suite, termasuk golden
flutter test --exclude-tags golden   # tanpa golden (wajib di Linux; dipakai CI)
flutter test --tags golden           # hanya golden
flutter test --tags golden --update-goldens   # rekam ulang golden (macOS!)
```

- `test/permintaan_service_test.dart` — kontrak data, stream, transaksi
  `majukanStatus`, penjaga permintaan ganda, dan `tandaiTiba` terhadap
  `fake_cloud_firestore` (tanpa proyek Firebase sungguhan).
- `test/kontras_test.dart` — regresi WCAG 1.4.3 (teks ≥ 4.5:1) dan 1.4.11
  (batas komponen ≥ 3:1), termasuk kontrol negatif terhadap warna lama.
- `test/text_scale_test.dart` — semua layar + lembar pada skala teks 1.3/1.5.
- `test/golden_test.dart` — gambar piksel layar pilih peran, tiket, dan status.
  Golden direkam di **macOS**; CI menjalankannya di job macOS terpisah karena
  font fallback berbeda antar OS.
- CI: `../.github/workflows/ci.yml` (analyze + test di Linux, golden di macOS,
  pemeriksaan sintaks detektor).

## Aksesibilitas (wajib, bukan opsional)

Target sentuh ≥ 48 dp, `Semantics` pada kontrol ikon-saja, status tidak pernah
hanya warna (selalu ada label teks/ikon), kontras lolos WCAG, tata letak utuh
pada skala teks 130–150%, dan animasi dimatikan saat sistem meminta
*reduce motion* (`MediaQuery.disableAnimationsOf`).

## Desain (gaya Brightline)

Tampilan mengikuti acuan `../whoosh-ramah-gaya-baru/design/Contoh-Brightline-Pilih-Peran.dc.html`:
kanvas putih `#FFFFFF`, satu aksen merah merek `#E11D2E` (teks merah `#B00E28`
di atas putih), teks `#111318` / sekunder `#4B5260`, permukaan blok `#F2F3F5`,
garis `#E5E7EB`, kartu radius 22 dengan garis tipis, tombol pill 56. Semua token
terpusat di `lib/theme.dart`. Logo resmi (kereta tersenyum) dibundel di
`assets/logo/` dan ditampilkan lewat widget `LogoWhoosh`
(`lib/widgets/logo_whoosh.dart`).

## Ikon peluncur Android

Memakai aset resmi `assets/ikon/app-ikon-1024.png` + adaptive foreground
`assets/ikon/foreground-1024.png` di atas merah merek `#E11D2E`
(dikonfigurasi di `pubspec.yaml`, bagian `flutter_launcher_icons`):

```bash
cd whoosh_ramah && dart run flutter_launcher_icons
```

## Catatan teknis

- UI memakai fork `package:material_ui` (bukan `flutter/material`); tema tunggal
  di `lib/theme.dart`. Font **Plus Jakarta Sans** (500/600/700/800) dibundel
  lokal di `assets/fonts/` agar demo tidak butuh internet.
- `majukanStatus` berjalan dalam transaksi Firestore + antrean per-id di aplikasi,
  sehingga ketukan ganda tidak melompati tahap atau mendobel entri `riwayat`.
- `buatPermintaan` menolak permintaan ganda selama masih ada permintaan aktif
  milik penumpang yang sama; UI membuka status yang sudah ada.
- Transisi layar terpusat di `lib/transisi.dart` (fade + slide + scale halus,
  hormat pada *reduce motion*); kerangka memuat di `lib/widgets/skeleton.dart`.