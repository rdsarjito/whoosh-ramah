# Whoosh Ramah

Prototipe hackathon pendampingan **penumpang prioritas kereta cepat Whoosh (KCIC)** —
lansia, penyandang disabilitas, ibu hamil, penumpang sakit, dan anak tanpa pendamping.
Satu aplikasi Flutter berisi tiga peran (**Penumpang**, **Petugas**, **Keluarga**),
ditambah **kamera AI** Python yang mendeteksi pengguna kursi roda di pintu masuk
stasiun dan membuat tugas pendampingan secara otomatis.

Alur manual digantikan alur real-time: penumpang memesan pendamping dari HP,
petugas menerima dan memajukan tugas, keluarga memantau perjalanan — semuanya
tersinkron lewat Cloud Firestore tanpa server sendiri.

```
Kamera ──► detector/detect_wheelchair.py ──┐
                                           ▼
HP Penumpang ──► aplikasi Flutter ──► Cloud Firestore ──► HP Petugas (real-time)
                                           │
                                           └──────────► HP Keluarga (real-time)
```

> **Status:** prototipe demo hackathon (2–3 HP + 1 laptop). Bukan produk produksi:
> tanpa login sungguhan, integrasi tiket KCIC, pembayaran, penjadwalan otomatis,
> atau notifikasi push. Aturan Firestore terbuka khusus demo.

## Isi repo

| Folder / file | Isi |
| --- | --- |
| [`whoosh_ramah/`](whoosh_ramah/README.md) | Aplikasi Flutter (penumpang, petugas, keluarga) + tes, golden, CI, seed demo |
| [`detector/`](detector/README.md) | Detektor kursi roda Python (YOLO-World / Roboflow / model lokal) + cuplikan verifikasi |
| [`design/`](design/README.md) | Acuan desain HTML layar (kanvas Gaya B) |
| `whoosh-ramah-gaya-baru/` | Acuan desain **Brightline** yang dipakai aplikasi saat ini |
| [`PROJECT.md`](PROJECT.md) | Spesifikasi lengkap & sumber kebenaran: skema data (§4), layar (§6), aksesibilitas (§8), privasi (§12) |
| `mise.toml` | Pin versi tool (Python 3.12 via [mise](https://mise.jdx.dev/)) |
| `.qoder/repowiki/` | Wiki repo terperinci (arsitektur, pipeline deteksi, alur layar, troubleshooting) |

## Tiga peran, satu koleksi

Semua peran membaca/menulis koleksi Firestore `permintaan_pendampingan`
(skema lengkap: [PROJECT.md §4](PROJECT.md)). Satu dokumen = satu permintaan
pendampingan, dengan enum status berurutan:

`menunggu → ditugaskan → bertemu → di_kursi → selesai`

| Peran | Alur utama |
| --- | --- |
| **Penumpang** | Lihat tiket contoh (G1123 Halim → Tegalluar) → pesan pendamping (6 jenis bantuan, 3 titik jemput) → pantau timeline status real-time → bagikan ke keluarga |
| **Petugas** | Daftar tugas real-time (badge **Kamera AI** / **Aplikasi**, ringkasan Baru/Berjalan/Selesai/Ditolak) → detail tugas → satu tombol besar memajukan status. Tugas kamera AI menampilkan **cuplikan verifikasi** + tombol **"Bukan penumpang / tolak"** bila AI salah mendeteksi |
| **Keluarga** | Pantau permintaan terbaru penumpang demo (`demo-siti`): status saat ini, progres perjalanan, riwayat berjam |

Penolakan tugas kamera tidak menambah enum status — dokumen diberi `ditolakPada`
dan keluar dari daftar aktif, dihitung terpisah di ringkasan "Ditolak".

Jenis bantuan: `kursi_roda`, `tunanetra`, `tuli`, `lansia`, `hamil`, `porter`.

## Kamera AI (detector)

Detektor berjalan di laptop, terpisah dari aplikasi; keduanya hanya bertemu di
Firestore. Mode bawaan **YOLO-World** (`yolov8s-worldv2.pt`) — cukup tulis nama
benda, jalan tanpa API key. Alternatif: model Roboflow (Jalan A) atau model YOLO
hasil latihan sendiri (Jalan B).

- **Satu tugas per orang**, bukan per jeda: tracking ByteTrack memberi id per
  kursi roda; tugas dibuat hanya untuk id yang belum pernah dikirim dan terlihat
  `FRAME_BERTURUT` kali berturut-turut. Cooldown `JEDA_ANTAR_TUGAS_DETIK` berlaku
  per id.
- **Cuplikan verifikasi** untuk petugas: disimpan sebagai base64 di koleksi
  terpisah `permintaan_foto/{idTugas}` (bukan Cloud Storage — project di paket
  Spark), lalu **dihapus otomatis setelah 10 menit** (`FOTO_TTL_DETIK=600`) oleh
  thread latar + sapuan saat start. Bila penulisan foto gagal, tugas tetap dibuat
  tanpa foto.
  - `FOTO_ANONIM=false` (bawaan demo, peserta yang setuju): cuplikan **asli**,
    maks 480 px, JPEG q80, tanpa blur/pikselasi.
  - `FOTO_ANONIM=true` (**wajib produksi**): wajah di-blur (Haar cascade) +
    pikselasi, maks 160 px, q60.
  - Panjang base64 dijaga jauh di bawah batas dokumen Firestore 1 MiB.

Panduan lengkap (setup venv, `.env`, uji tanpa Firebase, latih model):
[`detector/README.md`](detector/README.md).

## Menjalankan

Prasyarat: **Flutter 3.50.1 / stable** (Dart 3.14) + JDK 17 + perangkat/emulator
Android; **Python 3.10+** (disarankan 3.12) untuk detektor.

### 1. Aplikasi Flutter

Konfigurasi Firebase proyek demo sudah ikut di repo
(`lib/firebase_options.dart`, `android/app/google-services.json`) — tidak perlu
`flutterfire configure` lagi.

```bash
cd whoosh_ramah
flutter pub get
flutter run                 # pilih perangkat Android saat diminta
```

Deploy aturan Firestore (terbuka khusus demo) sebelum memakai aplikasi:

```bash
cd whoosh_ramah
firebase deploy --only firestore:rules,firestore:indexes
```

Tidak ada composite index: semua query hanya satu field, sisanya disaring di
sisi aplikasi.

### 2. Detektor kursi roda

```bash
cd detector
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env            # lalu isi sesuai kebutuhan
```

Uji deteksi dulu tanpa Firebase (webcam atau video):

```bash
python detect_wheelchair.py --tanpa-firebase
python detect_wheelchair.py --sumber contoh.mp4 --tanpa-firebase
```

Untuk menulis tugas ke Firestore, unduh kunci service account dari Firebase
console → simpan sebagai `detector/firebase-key.json` (**jangan di-commit**),
lalu jalankan `python detect_wheelchair.py`. Setiap kursi roda terdeteksi,
kartu "Kamera AI" muncul di HP petugas dalam beberapa detik.

### 3. Seed demo (opsional)

Daftar petugas langsung ramai dengan tiga dokumen demo (aman dijalankan ulang):

```bash
detector/venv/bin/python whoosh_ramah/tool/seed_demo.py
detector/venv/bin/python whoosh_ramah/tool/seed_demo.py --bersih
```

Alur demo lengkap ±3 menit ada di [`whoosh_ramah/README.md`](whoosh_ramah/README.md).

## Pengujian & CI

```bash
cd whoosh_ramah
flutter analyze
flutter test                         # seluruh suite, termasuk golden
flutter test --exclude-tags golden   # tanpa golden (Linux/CI)
```

Suite mencakup kontrak data & transaksi terhadap `fake_cloud_firestore`,
regresi kontras WCAG, semua layar pada skala teks 1.3/1.5, dan golden piksel
(direkam di macOS). CI (`.github/workflows/ci.yml`) menjalankan analyze + test
di Linux, golden di macOS, dan pemeriksaan sintaks detektor.

## Aksesibilitas (wajib)

Target sentuh ≥ 48 dp, `Semantics` pada kontrol ikon-saja, status tidak pernah
hanya warna, kontras lolos WCAG, tata letak utuh pada skala teks 130–150%,
animasi hormat pada *reduce motion*, dan alur penumpang bisa diselesaikan
dengan TalkBack/VoiceOver tanpa melihat layar.

## Privasi

- Untuk demo hackathon dengan peserta yang setuju, cuplikan asli boleh dipakai
  dan terhapus otomatis dalam 10 menit. Versi produksi wajib menyamarkan wajah.
- Semua nama dan data tiket adalah contoh.
- Aturan Firestore terbuka (`allow read, write: if true`) **hanya untuk demo**;
  jangan dipakai produksi.

## Desain & teknis

Tampilan mengikuti gaya **Brightline** (acuan: `whoosh-ramah-gaya-baru/design/`):
kanvas putih, satu aksen merah merek `#E11D2E`, font **Plus Jakarta Sans**
(500–800) dibundel lokal agar demo tidak butuh internet. UI memakai fork
`package:material_ui`; semua token terpusat di `whoosh_ramah/lib/theme.dart`.
Detail teknis (transisi, skeleton, antrean tulis per-id, penjaga permintaan
ganda): [`whoosh_ramah/README.md`](whoosh_ramah/README.md).

Dokumentasi lebih dalam — arsitektur sistem, pipeline deteksi, skema data,
alur tiap layar, troubleshooting — tersedia di wiki repo (`.qoder/repowiki/`).