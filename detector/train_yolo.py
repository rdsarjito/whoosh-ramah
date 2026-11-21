"""
Whoosh Ramah - Latih Model Kursi Roda Sendiri (Jalan B)
=======================================================

Jalankan di Google Colab (Runtime > Change runtime type > GPU).

Langkah:
  1. Di Roboflow Universe, buka dataset kursi roda pilihan Anda
     (misalnya "Wheelchair Detection V.3"), klik Download Dataset,
     pilih format "YOLOv8", lalu salin kode unduhnya. Isi tiga
     variabel di bawah dari kode tersebut.
  2. Di Colab:  !pip install ultralytics roboflow
  3. Jalankan:  !python train_yolo.py
  4. Unduh file models/kursi_roda.pt ke laptop, taruh di folder detector/models/,
     lalu ubah MODE_MODEL=lokal di .env.
"""

import os
import shutil

from roboflow import Roboflow
from ultralytics import YOLO

# --- Isi dari halaman Download Dataset di Roboflow ---
ROBOFLOW_API_KEY = os.getenv("ROBOFLOW_API_KEY", "ISI_API_KEY_ANDA")
WORKSPACE = "wheelchair-detection"       # contoh, ganti sesuai dataset pilihan
PROJECT = "wheelchair-detection-v.3"     # contoh, ganti sesuai dataset pilihan
VERSI = 1

EPOCH = 50          # 50 sudah cukup untuk demo; naikkan kalau waktu ada
UKURAN_GAMBAR = 640


def main():
    # 1. Unduh dataset dalam format YOLOv8
    rf = Roboflow(api_key=ROBOFLOW_API_KEY)
    dataset = rf.workspace(WORKSPACE).project(PROJECT).version(VERSI).download("yolov8")

    # 2. Mulai dari YOLOv8 nano yang sudah pintar mengenali benda umum,
    #    lalu "ajari" khusus kursi roda (fine-tuning). Jauh lebih cepat dari nol.
    model = YOLO("yolov8n.pt")
    model.train(
        data=os.path.join(dataset.location, "data.yaml"),
        epochs=EPOCH,
        imgsz=UKURAN_GAMBAR,
        name="kursi_roda",
    )

    # 3. Evaluasi di data validasi. Angka mAP50 > 0.7 sudah bagus untuk demo.
    metrik = model.val()
    print(f"\nmAP50 = {metrik.box.map50:.3f}  |  mAP50-95 = {metrik.box.map:.3f}")

    # 4. Simpan model terbaik dengan nama yang dipakai detect_wheelchair.py
    os.makedirs("models", exist_ok=True)
    terbaik = os.path.join(model.trainer.save_dir, "weights", "best.pt")
    shutil.copy(terbaik, "models/kursi_roda.pt")
    print("\nSelesai! Model tersimpan di models/kursi_roda.pt")
    print("Nama kelas di model ini:", model.names)
    print("Pastikan nama kelas kursi roda ada di KELAS_TARGET pada .env")


if __name__ == "__main__":
    main()
