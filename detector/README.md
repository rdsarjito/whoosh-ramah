# Whoosh Ramah – Detektor Kursi Roda

Kamera mendeteksi pengguna kursi roda, lalu otomatis membuat tugas pendampingan
di Firebase sehingga muncul di HP petugas.

```
Kamera ──► detect_wheelchair.py ──► Firestore "permintaan_pendampingan" ──► Aplikasi petugas (Flutter)
```

## 1. Persiapan (sekali saja)

1. Pasang Python 3.10 atau lebih baru.
2. Di folder `detector`, jalankan:
   ```bash
   python -m venv venv
   source venv/bin/activate        # Windows: venv\Scripts\activate
   pip install -r requirements.txt
   ```
3. Salin `.env.example` menjadi `.env`.

## 2. Jalan A – Pakai model jadi Roboflow (mulai dari sini)

1. Buat akun gratis di https://roboflow.com, lalu salin **API key** dari Settings.
2. Isi `ROBOFLOW_API_KEY` di `.env`.
3. Cari model kursi roda di https://universe.roboflow.com (ketik "wheelchair"),
   pilih yang punya tombol **"Try This Model"**, lalu salin **Model ID**-nya ke
   `ROBOFLOW_MODEL_ID`. Cek juga nama kelasnya dan pastikan ada di `KELAS_TARGET`.
4. Uji deteksi dulu tanpa Firebase:
   ```bash
   python detect_wheelchair.py --tanpa-firebase
   ```
   Arahkan webcam ke foto kursi roda di layar HP, atau pakai video:
   ```bash
   python detect_wheelchair.py --sumber contoh.mp4 --tanpa-firebase
   ```
   Kotak **merah** = kursi roda terdeteksi. Kalau sering salah, coba model lain
   atau naikkan `AMBANG_KEYAKINAN`.

## 3. Sambungkan ke Firebase

1. Buat proyek di https://console.firebase.google.com dan aktifkan **Cloud Firestore**.
2. Project settings → **Service accounts** → **Generate new private key**.
3. Simpan file itu sebagai `firebase-key.json` di folder `detector`.
   **Jangan pernah mengunggah file ini ke GitHub.**
4. Jalankan:
   ```bash
   python detect_wheelchair.py
   ```
   Setiap kursi roda terdeteksi, dokumen baru muncul di koleksi
   `permintaan_pendampingan` dengan isi seperti ini:

   | Field | Contoh | Arti |
   | --- | --- | --- |
   | `jenisBantuan` | `kursi_roda` | Jenis bantuan |
   | `titikJemput` | `Stasiun Halim - Pintu Masuk Utara` | Lokasi kamera |
   | `status` | `menunggu` | Alur: menunggu → ditugaskan → bertemu → di_kursi → selesai |
   | `sumber` | `kamera_ai` | Bedanya dengan pesanan dari aplikasi (`aplikasi`) |
   | `keyakinan` | `0.87` | Seberapa yakin AI |
   | `dibuatPada` | waktu server | Untuk mengurutkan tugas |

   Aplikasi Flutter cukup mendengarkan koleksi ini untuk menampilkan tugas baru.

## 4. Jalan B – Latih model sendiri (kalau ada waktu)

1. Buka Google Colab, aktifkan GPU (Runtime → Change runtime type → GPU).
2. Unggah `train_yolo.py`, isi nama workspace, project, dan versi dataset dari
   halaman **Download Dataset** di Roboflow (format **YOLOv8**).
3. Jalankan:
   ```
   !pip install ultralytics roboflow
   !python train_yolo.py
   ```
   Butuh sekitar 30–60 menit dengan GPU gratis Colab.
4. Unduh `models/kursi_roda.pt`, taruh di `detector/models/`, lalu ubah
   `MODE_MODEL=lokal` di `.env`. Sekarang deteksi jalan tanpa internet.

## Pengaturan penting di `.env`

| Pengaturan | Bawaan | Fungsi |
| --- | --- | --- |
| `AMBANG_KEYAKINAN` | 0.5 | Naikkan kalau banyak salah deteksi |
| `FRAME_BERTURUT` | 3 | Harus terlihat 3 kali berturut sebelum tugas dibuat |
| `JEDA_ANTAR_TUGAS_DETIK` | 60 | Mencegah satu orang menghasilkan banyak tugas |
| `DETEKSI_TIAP_DETIK` | 1.0 | Seberapa sering AI dipanggil (hemat kuota Roboflow) |
| `FOTO_AKTIF` | true | Kirim cuplikan verifikasi anonim ke petugas (mode yoloworld/lokal) |
| `FOTO_TTL_DETIK` | 600 | Cuplikan dihapus otomatis setelah 600 detik (10 menit) |
| `FOTO_MAKS_PIKSEL` | 160 | Sisi terpanjang cuplikan; wajah di-blur + dipikselkan |

## Tips demo

- Siapkan **video cadangan** berisi orang berkursi roda, untuk jaga-jaga kalau
  kursi roda sungguhan tidak tersedia.
- Jalankan detektor di laptop, dan buka aplikasi petugas di HP di sebelahnya
  supaya juri melihat notifikasi muncul.
- Wajah tidak disimpan; yang dikirim ke Firebase hanya jenis bantuan, lokasi, dan waktu.
