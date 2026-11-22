"""
Whoosh Ramah - Detektor Kursi Roda
==================================

Membaca kamera (webcam / CCTV / file video), mendeteksi pengguna kursi roda,
lalu membuat "permintaan pendampingan" otomatis di Firebase Firestore
sehingga muncul di aplikasi petugas.

Tiga mode model:
  - roboflow : memakai model jadi di Roboflow lewat API (Jalan A, butuh internet)
  - yoloworld: deteksi dengan menulis nama benda, tanpa melatih (Jalan C)
  - lokal    : memakai model YOLO hasil latihan sendiri, file .pt (Jalan B)

Mode yoloworld & lokal memakai ByteTrack (model.track persist=True) sehingga
 tiap kursi roda punya track ID: satu tugas per ORANG, bukan satu tugas per
 jeda. ID yang hilang > 30 detik dianggap orang baru bila muncul kembali.
 Mode roboflow tetap memakai cara lama (streak + jeda global, tanpa tracking).

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
JEDA_COBA_LAGI_DETIK = float(os.getenv("JEDA_COBA_LAGI_DETIK", "2.0"))  # retry kirim
PERCOBAAN_KIRIM = int(os.getenv("PERCOBAAN_KIRIM", "3"))  # jumlah percobaan kirim

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
            kotak.append((p["class"], float(p["confidence"]), x1, y1, x2, y2, None))
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
        # persist=True: tracker menyimpan state antar frame, jadi tiap kursi
        # roda memegang track ID yang sama selama masih terlihat.
        hasil = self.model.track(
            frame, persist=True, tracker="bytetrack.yaml", verbose=False
        )[0]
        kotak = []
        for b in hasil.boxes:
            nama = hasil.names[int(b.cls)]
            x1, y1, x2, y2 = (int(v) for v in b.xyxy[0].tolist())
            id_lacak = int(b.id) if b.id is not None else None
            kotak.append((nama, float(b.conf), x1, y1, x2, y2, id_lacak))
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
        hasil = self.model.track(
            frame, persist=True, tracker="bytetrack.yaml", conf=0.1, verbose=False
        )[0]
        kotak = []
        for b in hasil.boxes:
            nama = hasil.names[int(b.cls)]
            x1, y1, x2, y2 = (int(v) for v in b.xyxy[0].tolist())
            id_lacak = int(b.id) if b.id is not None else None
            kotak.append((nama, float(b.conf), x1, y1, x2, y2, id_lacak))
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

    def kirim_tugas(self, keyakinan, jumlah_terdeteksi=1, id_lacak=None):
        """Membuat permintaan pendampingan baru yang langsung muncul di HP petugas.

        [jumlah_terdeteksi] = banyaknya kursi roda di layar saat tugas dibuat;
        [id_lacak] = track ID ByteTrack (None untuk mode roboflow tanpa tracking).
        Mencoba ulang beberapa kali bila jaringan/Firestore sedang bermasalah.
        Mengembalikan True bila terkirim, False bila semua percobaan gagal —
        kegagalan TIDAK menghentikan loop deteksi.
        """
        data = {
            "jenisBantuan": "kursi_roda",
            "titikJemput": LOKASI_KAMERA,
            "status": "menunggu",  # menunggu -> ditugaskan -> bertemu -> di_kursi -> selesai
            "sumber": "kamera_ai",
            "idKamera": ID_KAMERA,
            "keyakinan": round(keyakinan, 2),
            "jumlahTerdeteksi": int(jumlah_terdeteksi),
            "idLacak": id_lacak,
            "namaPenumpang": None,  # tidak diketahui, karena tidak memesan lewat aplikasi
            "dibuatPada": self.SERVER_TIMESTAMP,
        }
        galat_terakhir = None
        for percobaan in range(1, PERCOBAAN_KIRIM + 1):
            try:
                ref = self.db.collection(KOLEKSI_FIRESTORE).add(data)[1]
                print(f"[firebase] Tugas dibuat: {ref.id} ({LOKASI_KAMERA})")
                return True
            except Exception as e:  # koneksi putus, kuota, dsb.
                galat_terakhir = e
                print(
                    f"[peringatan] Gagal mengirim tugas "
                    f"(percobaan {percobaan}/{PERCOBAAN_KIRIM}): {e}"
                )
                if percobaan < PERCOBAAN_KIRIM:
                    time.sleep(JEDA_COBA_LAGI_DETIK * percobaan)
        print(
            f"[galat] Tugas tidak terkirim setelah {PERCOBAAN_KIRIM} percobaan: "
            f"{galat_terakhir}. Deteksi tetap berjalan."
        )
        return False


# ---------------------------------------------------------------------------
# Pelacak tugas per orang (track ID)
# ---------------------------------------------------------------------------
BATAS_HILANG_DETIK = 30.0  # ID hilang lebih lama dari ini = orang baru


class PelacakTugas:
    """State per track ID untuk mode yoloworld/lokal: satu tugas per orang.

    - streak berturut-turut per ID (reset bila ID tidak terlihat satu siklus);
    - daftar ID yang sudah dibuatkan tugas (tidak dikirim dobel);
    - jeda antar tugas berlaku PER ID, bukan global;
    - ID yang hilang > BATAS_HILANG_DETIK dihapus dari daftar, sehingga orang
      yang pergi lalu kembali boleh mendapat tugas baru.
    """

    def __init__(
        self,
        frame_berturut=FRAME_BERTURUT,
        jeda_detik=JEDA_ANTAR_TUGAS_DETIK,
        batas_hilang_detik=BATAS_HILANG_DETIK,
    ):
        self.frame_berturut = frame_berturut
        self.jeda_detik = jeda_detik
        self.batas_hilang_detik = batas_hilang_detik
        self.berturut_id = {}  # id -> jumlah siklus deteksi berturut terlihat
        self.terakhir_terlihat = {}  # id -> waktu terakhir terlihat
        self.id_terkirim = set()  # id yang sudah dibuatkan tugas
        self.waktu_kirim_id = {}  # id -> waktu percobaan kirim terakhir

    def proses(self, terlihat, sekarang):
        """[terlihat]: list kotak target (7-tuple) dari satu siklus deteksi.

        Memperbarui streak/daftar hilang, lalu mengembalikan list
        (id_lacak, keyakinan) yang layak dibuatkan tugas BARU saat ini.
        """
        ids_sekarang = set()
        for k in terlihat:
            id_lacak = k[6]
            if id_lacak is None:  # tracker belum memberi ID: lewati siklus ini
                continue
            ids_sekarang.add(id_lacak)
            self.terakhir_terlihat[id_lacak] = sekarang
            self.berturut_id[id_lacak] = self.berturut_id.get(id_lacak, 0) + 1
        for id_lacak in self.berturut_id:
            if id_lacak not in ids_sekarang:
                self.berturut_id[id_lacak] = 0  # putus streak: tidak berturut

        # ID hilang > 30 detik: hapus dari daftar tugas & streak.
        for id_lacak in list(self.terakhir_terlihat):
            if sekarang - self.terakhir_terlihat[id_lacak] > self.batas_hilang_detik:
                del self.terakhir_terlihat[id_lacak]
                self.berturut_id.pop(id_lacak, None)
                self.id_terkirim.discard(id_lacak)
        # Entri jeda yang sudah kedaluwarsa tidak membatasi apa pun: buang.
        for id_lacak in list(self.waktu_kirim_id):
            if sekarang - self.waktu_kirim_id[id_lacak] >= self.jeda_detik:
                del self.waktu_kirim_id[id_lacak]

        layak = []
        for k in terlihat:
            id_lacak = k[6]
            if id_lacak is None or id_lacak in self.id_terkirim:
                continue
            if self.berturut_id.get(id_lacak, 0) < self.frame_berturut:
                continue
            kirim_terakhir = self.waktu_kirim_id.get(id_lacak)
            if kirim_terakhir is not None and sekarang - kirim_terakhir < self.jeda_detik:
                continue
            layak.append((id_lacak, k[1]))
        return layak

    def catat_kirim(self, id_lacak, sekarang, berhasil):
        """Mencatat percobaan kirim: jeda per ID mulai sekarang; bila berhasil
        (atau tanpa Firebase saat uji), ID masuk daftar sudah-dikirim."""
        self.waktu_kirim_id[id_lacak] = sekarang
        if berhasil:
            self.id_terkirim.add(id_lacak)
            self.berturut_id[id_lacak] = 0


# ---------------------------------------------------------------------------
# Program utama
# ---------------------------------------------------------------------------
def gambar_kotak(frame, kotak_list):
    for nama, keyakinan, x1, y1, x2, y2, id_lacak in kotak_list:
        target = nama.lower() in KELAS_TARGET and keyakinan >= AMBANG_KEYAKINAN
        warna = (0, 0, 255) if target else (180, 180, 180)  # merah = kursi roda
        cv2.rectangle(frame, (x1, y1), (x2, y2), warna, 2)
        if target and id_lacak is not None:
            label = f"Kursi roda #{id_lacak}"
        else:
            label = f"{nama} {keyakinan:.0%}"
        cv2.putText(
            frame,
            label,
            (x1, max(y1 - 8, 16)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.6,
            warna,
            2,
        )


def gambar_jumlah(frame, jumlah):
    """Tulisan 'Terdeteksi: N' di pojok kanan atas jendela kamera."""
    teks = f"Terdeteksi: {jumlah}"
    (lebar, _), _ = cv2.getTextSize(teks, cv2.FONT_HERSHEY_SIMPLEX, 0.7, 2)
    cv2.putText(
        frame,
        teks,
        (max(frame.shape[1] - lebar - 10, 10), 28),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.7,
        (255, 255, 255),
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
    firebase = None
    if not args.tanpa_firebase:
        try:
            firebase = PengirimFirebase()
        except SystemExit:
            raise  # pesan konfigurasi yang sudah jelas
        except Exception as e:
            raise SystemExit(
                f"Gagal menyiapkan Firebase: {e}. "
                "Periksa FIREBASE_KEY dan koneksi internet, "
                "atau jalankan dengan --tanpa-firebase untuk uji deteksi saja."
            )

    hitung_berturut = 0  # cara lama (global): hanya mode roboflow
    waktu_tugas_terakhir = 0.0  # cara lama (global): hanya mode roboflow
    waktu_deteksi_terakhir = 0.0
    kotak_terakhir = []
    pakai_tracking = MODE_MODEL in ("yoloworld", "lokal")
    pelacak = PelacakTugas() if pakai_tracking else None

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

            if pakai_tracking:
                # Satu tugas per orang: hanya ID baru yang sudah terlihat
                # FRAME_BERTURUT siklus berturut dan lolos jeda per ID.
                for id_lacak, keyakinan in pelacak.proses(terlihat, sekarang):
                    print(
                        f"[deteksi] Kursi roda #{id_lacak} terdeteksi "
                        f"({keyakinan:.0%}), terdeteksi {len(terlihat)} kursi roda"
                    )
                    berhasil = firebase is None  # --tanpa-firebase: anggap terkirim
                    if firebase:
                        # Kegagalan kirim tidak boleh mematikan loop deteksi.
                        try:
                            berhasil = firebase.kirim_tugas(
                                keyakinan,
                                jumlah_terdeteksi=len(terlihat),
                                id_lacak=id_lacak,
                            )
                        except Exception as e:
                            print(f"[galat] Pengiriman tugas gagal: {e}")
                    pelacak.catat_kirim(id_lacak, sekarang, berhasil)
            else:
                # Cara lama (roboflow, tanpa tracking): streak + jeda global.
                hitung_berturut = hitung_berturut + 1 if terlihat else 0
                if (
                    hitung_berturut >= FRAME_BERTURUT
                    and sekarang - waktu_tugas_terakhir >= JEDA_ANTAR_TUGAS_DETIK
                ):
                    keyakinan_maks = max(k[1] for k in terlihat)
                    print(f"[deteksi] Kursi roda terdeteksi ({keyakinan_maks:.0%})")
                    if firebase:
                        # Kegagalan kirim tidak boleh mematikan loop deteksi.
                        try:
                            firebase.kirim_tugas(
                                keyakinan_maks,
                                jumlah_terdeteksi=len(terlihat),
                            )
                        except Exception as e:
                            print(f"[galat] Pengiriman tugas gagal: {e}")
                    waktu_tugas_terakhir = sekarang
                    hitung_berturut = 0

        gambar_kotak(frame, kotak_terakhir)
        jumlah_sekarang = sum(
            1 for k in kotak_terakhir
            if k[0].lower() in KELAS_TARGET and k[1] >= AMBANG_KEYAKINAN
        )
        if pakai_tracking:
            status = "KURSI RODA TERDETEKSI" if jumlah_sekarang > 0 else "Memantau..."
        else:
            status = "KURSI RODA TERDETEKSI" if hitung_berturut > 0 else "Memantau..."
        cv2.putText(frame, f"{LOKASI_KAMERA} | {status}", (10, 28),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
        gambar_jumlah(frame, jumlah_sekarang)
        cv2.imshow("Whoosh Ramah - Detektor Kursi Roda", frame)

        if cv2.waitKey(1) & 0xFF == ord("q"):
            break

    kamera.release()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
