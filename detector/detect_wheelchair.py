"""
Whoosh Ramah - Detektor Kursi Roda
==================================

Membaca kamera (webcam / CCTV / file video), mendeteksi pengguna kursi roda,
lalu membuat "permintaan pendampingan" otomatis di Firebase Firestore
sehingga muncul di aplikasi petugas.

Dua mode model:
  - roboflow : memakai model jadi di Roboflow lewat API (Jalan A, butuh internet)
  - lokal    : memakai model YOLO hasil latihan sendiri, file .pt (Jalan B)

Contoh menjalankan:
  python detect_wheelchair.py                      # webcam, mode dari .env
  python detect_wheelchair.py --sumber video.mp4   # dari file video
  python detect_wheelchair.py --tanpa-firebase     # uji deteksi saja

Semua pengaturan ada di file .env (lihat .env.example).
"""

import argparse
import os
import time

import cv2
from dotenv import load_dotenv

load_dotenv()

# ---------------------------------------------------------------------------
# Pengaturan (dibaca dari .env, ada nilai bawaan)
# ---------------------------------------------------------------------------
MODE_MODEL = os.getenv("MODE_MODEL", "roboflow")  # "roboflow", "yoloworld", atau "lokal"

ROBOFLOW_API_KEY = os.getenv("ROBOFLOW_API_KEY", "")
ROBOFLOW_MODEL_ID = os.getenv("ROBOFLOW_MODEL_ID", "accessibility_detection/1")

MODEL_LOKAL = os.getenv("MODEL_LOKAL", "models/kursi_roda.pt")

# Mode "yoloworld": cukup tulis nama benda dalam bahasa Inggris, pisah koma.
YOLOWORLD_MODEL = os.getenv("YOLOWORLD_MODEL", "yolov8s-worldv2.pt")
KELAS_YOLOWORLD = [
    k.strip()
    for k in os.getenv("KELAS_YOLOWORLD", "wheelchair,person in wheelchair").split(",")
    if k.strip()
]

# Nama kelas yang dianggap "kursi roda". Tiap model memberi nama berbeda,
# jadi tulis semua kemungkinan, dipisah koma, huruf kecil.
KELAS_TARGET = [
    k.strip().lower()
    for k in os.getenv(
        "KELAS_TARGET", "wheelchair,wheelchair-users,wheelchair user,person in wheelchair"
    ).split(",")
    if k.strip()
]

AMBANG_KEYAKINAN = float(os.getenv("AMBANG_KEYAKINAN", "0.5"))  # 0..1
FRAME_BERTURUT = int(os.getenv("FRAME_BERTURUT", "3"))  # harus terdeteksi N kali berturut
JEDA_ANTAR_TUGAS_DETIK = int(os.getenv("JEDA_ANTAR_TUGAS_DETIK", "60"))  # anti-spam
DETEKSI_TIAP_DETIK = float(os.getenv("DETEKSI_TIAP_DETIK", "1.0"))  # hemat API

LOKASI_KAMERA = os.getenv("LOKASI_KAMERA", "Stasiun Halim - Pintu Masuk Utara")
ID_KAMERA = os.getenv("ID_KAMERA", "halim-utara-01")

FIREBASE_KEY = os.getenv("FIREBASE_KEY", "firebase-key.json")
KOLEKSI_FIRESTORE = os.getenv("KOLEKSI_FIRESTORE", "permintaan_pendampingan")


# ---------------------------------------------------------------------------
# Model
# ---------------------------------------------------------------------------
class ModelRoboflow:
    """Jalan A: model jadi di server Roboflow."""

    def __init__(self):
        from inference_sdk import InferenceHTTPClient

        if not ROBOFLOW_API_KEY:
            raise SystemExit(
                "ROBOFLOW_API_KEY belum diisi di .env. "
                "Buat akun gratis di roboflow.com, lalu salin API key Anda."
            )
        self.client = InferenceHTTPClient(
            api_url="https://serverless.roboflow.com", api_key=ROBOFLOW_API_KEY
        )

    def deteksi(self, frame):
        """Mengembalikan list (nama_kelas, keyakinan, x1, y1, x2, y2)."""
        hasil = self.client.infer(frame, model_id=ROBOFLOW_MODEL_ID)
        kotak = []
        for p in hasil.get("predictions", []):
            # Roboflow memberi titik tengah (x, y) + lebar/tinggi
            x1 = int(p["x"] - p["width"] / 2)
            y1 = int(p["y"] - p["height"] / 2)
            x2 = int(p["x"] + p["width"] / 2)
            y2 = int(p["y"] + p["height"] / 2)
            kotak.append((p["class"], float(p["confidence"]), x1, y1, x2, y2))
        return kotak


class ModelLokal:
    """Jalan B: model YOLO hasil latihan sendiri (file .pt)."""

    def __init__(self):
        from ultralytics import YOLO

        if not os.path.exists(MODEL_LOKAL):
            raise SystemExit(
                f"File model '{MODEL_LOKAL}' tidak ditemukan. "
                "Latih dulu dengan train_yolo.py (lihat README), "
                "atau pakai MODE_MODEL=roboflow."
            )
        self.model = YOLO(MODEL_LOKAL)

    def deteksi(self, frame):
        hasil = self.model(frame, verbose=False)[0]
        kotak = []
        for b in hasil.boxes:
            nama = hasil.names[int(b.cls)]
            x1, y1, x2, y2 = (int(v) for v in b.xyxy[0].tolist())
            kotak.append((nama, float(b.conf), x1, y1, x2, y2))
        return kotak


class ModelYoloWorld:
    """Mode 'yoloworld': deteksi cukup dengan menulis nama benda, tanpa melatih.

    Model diunduh otomatis sekali (sekitar 25-100 MB), setelah itu jalan
    tanpa internet di laptop.
    """

    def __init__(self):
        from ultralytics import YOLOWorld

        print(f"[model] Memuat YOLO-World: {YOLOWORLD_MODEL} (pertama kali akan mengunduh)")
        self.model = YOLOWorld(YOLOWORLD_MODEL)
        self.model.set_classes(KELAS_YOLOWORLD)
        print(f"[model] Mencari: {KELAS_YOLOWORLD}")

    def deteksi(self, frame):
        hasil = self.model.predict(frame, conf=0.1, verbose=False)[0]
        kotak = []
        for b in hasil.boxes:
            nama = hasil.names[int(b.cls)]
            x1, y1, x2, y2 = (int(v) for v in b.xyxy[0].tolist())
            kotak.append((nama, float(b.conf), x1, y1, x2, y2))
        return kotak


def buat_model():
    if MODE_MODEL == "yoloworld":
        return ModelYoloWorld()
    if MODE_MODEL == "lokal":
        print(f"[model] Memakai model lokal: {MODEL_LOKAL}")
        return ModelLokal()
    print(f"[model] Memakai model Roboflow: {ROBOFLOW_MODEL_ID}")
    return ModelRoboflow()


# ---------------------------------------------------------------------------
# Firebase
# ---------------------------------------------------------------------------
class PengirimFirebase:
    def __init__(self):
        import firebase_admin
        from firebase_admin import credentials, firestore

        if not os.path.exists(FIREBASE_KEY):
            raise SystemExit(
                f"File kunci Firebase '{FIREBASE_KEY}' tidak ditemukan. "
                "Unduh dari Firebase Console > Project settings > Service accounts, "
                "atau jalankan dengan --tanpa-firebase untuk uji deteksi saja."
            )
        firebase_admin.initialize_app(credentials.Certificate(FIREBASE_KEY))
        self.db = firestore.client()
        self.SERVER_TIMESTAMP = firestore.SERVER_TIMESTAMP

    def kirim_tugas(self, keyakinan):
        """Membuat permintaan pendampingan baru yang langsung muncul di HP petugas."""
        data = {
            "jenisBantuan": "kursi_roda",
            "titikJemput": LOKASI_KAMERA,
            "status": "menunggu",  # menunggu -> ditugaskan -> bertemu -> di_kursi -> selesai
            "sumber": "kamera_ai",
            "idKamera": ID_KAMERA,
            "keyakinan": round(keyakinan, 2),
            "namaPenumpang": None,  # tidak diketahui, karena tidak memesan lewat aplikasi
            "dibuatPada": self.SERVER_TIMESTAMP,
        }
        ref = self.db.collection(KOLEKSI_FIRESTORE).add(data)[1]
        print(f"[firebase] Tugas dibuat: {ref.id} ({LOKASI_KAMERA})")


# ---------------------------------------------------------------------------
# Program utama
# ---------------------------------------------------------------------------
def gambar_kotak(frame, kotak_list):
    for nama, keyakinan, x1, y1, x2, y2 in kotak_list:
        target = nama.lower() in KELAS_TARGET and keyakinan >= AMBANG_KEYAKINAN
        warna = (0, 0, 255) if target else (180, 180, 180)  # merah = kursi roda
        cv2.rectangle(frame, (x1, y1), (x2, y2), warna, 2)
        cv2.putText(
            frame,
            f"{nama} {keyakinan:.0%}",
            (x1, max(y1 - 8, 16)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.6,
            warna,
            2,
        )


def main():
    parser = argparse.ArgumentParser(description="Detektor kursi roda Whoosh Ramah")
    parser.add_argument(
        "--sumber",
        default="0",
        help="0 untuk webcam, atau path/URL video (mp4, rtsp://...)",
    )
    parser.add_argument(
        "--tanpa-firebase",
        action="store_true",
        help="Hanya uji deteksi, tidak mengirim apa pun ke Firebase",
    )
    args = parser.parse_args()

    sumber = int(args.sumber) if args.sumber.isdigit() else args.sumber
    kamera = cv2.VideoCapture(sumber)
    if not kamera.isOpened():
        raise SystemExit(f"Tidak bisa membuka sumber video: {args.sumber}")

    model = buat_model()
    firebase = None if args.tanpa_firebase else PengirimFirebase()

    hitung_berturut = 0
    waktu_tugas_terakhir = 0.0
    waktu_deteksi_terakhir = 0.0
    kotak_terakhir = []

    print("[info] Tekan 'q' di jendela video untuk berhenti.")
    while True:
        ok, frame = kamera.read()
        if not ok:
            print("[info] Video selesai atau kamera terputus.")
            break

        sekarang = time.time()
        if sekarang - waktu_deteksi_terakhir >= DETEKSI_TIAP_DETIK:
            waktu_deteksi_terakhir = sekarang
            try:
                kotak_terakhir = model.deteksi(frame)
            except Exception as e:  # koneksi putus, dsb.
                print(f"[peringatan] Deteksi gagal: {e}")
                kotak_terakhir = []

            terlihat = [
                k for k in kotak_terakhir
                if k[0].lower() in KELAS_TARGET and k[1] >= AMBANG_KEYAKINAN
            ]
            hitung_berturut = hitung_berturut + 1 if terlihat else 0

            # Kirim tugas hanya kalau terlihat beberapa kali berturut-turut
            # dan sudah lewat jeda sejak tugas terakhir (mencegah tugas dobel).
            if (
                hitung_berturut >= FRAME_BERTURUT
                and sekarang - waktu_tugas_terakhir >= JEDA_ANTAR_TUGAS_DETIK
            ):
                keyakinan_maks = max(k[1] for k in terlihat)
                print(f"[deteksi] Kursi roda terdeteksi ({keyakinan_maks:.0%})")
                if firebase:
                    firebase.kirim_tugas(keyakinan_maks)
                waktu_tugas_terakhir = sekarang
                hitung_berturut = 0

        gambar_kotak(frame, kotak_terakhir)
        status = "KURSI RODA TERDETEKSI" if hitung_berturut > 0 else "Memantau..."
        cv2.putText(frame, f"{LOKASI_KAMERA} | {status}", (10, 28),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
        cv2.imshow("Whoosh Ramah - Detektor Kursi Roda", frame)

        if cv2.waitKey(1) & 0xFF == ord("q"):
            break

    kamera.release()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
