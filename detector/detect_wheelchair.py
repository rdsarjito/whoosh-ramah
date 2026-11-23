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

Mode yoloworld & lokal juga mengirim cuplikan verifikasi (O1): crop kotak
deteksi disimpan base64 di koleksi permintaan_foto/{idTugas} maksimal
FOTO_TTL_DETIK (default 600 detik), lalu dihapus thread latar. Bawaan demo
(FOTO_ANONIM=false): cuplikan ASLI maks 480 px JPEG q80, hanya untuk peserta
yang setuju. FOTO_ANONIM=true: cara lama — wajah di-blur (Haar) + pikselasi,
maks 160 px JPEG q60 (wajib untuk produksi). Gagal menulis foto -> tugas
tetap dibuat tanpa foto.

Contoh menjalankan:
  python detect_wheelchair.py                      # webcam, mode dari .env
  python detect_wheelchair.py --sumber video.mp4   # dari file video
  python detect_wheelchair.py --tanpa-firebase     # uji deteksi saja

Semua pengaturan ada di file .env (lihat .env.example).
"""

import argparse
import base64
import os
import queue
import threading
import time
from datetime import datetime, timedelta, timezone

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

# --- Foto verifikasi petugas (O1) ---
# Cuplikan disimpan base64 di koleksi permintaan_foto/{idTugas}, dihapus
# otomatis setelah TTL. FOTO_ANONIM=false (bawaan demo): cuplikan asli,
# hanya untuk peserta yang setuju; true: blur wajah + pikselasi (produksi).
FOTO_AKTIF = os.getenv("FOTO_AKTIF", "true").strip().lower() in ("1", "true", "ya", "yes")
FOTO_ANONIM = os.getenv("FOTO_ANONIM", "false").strip().lower() in ("1", "true", "ya", "yes")
FOTO_TTL_DETIK = int(os.getenv("FOTO_TTL_DETIK", "600"))  # 600 = 10 menit
FOTO_MAKS_PIKSEL = int(os.getenv("FOTO_MAKS_PIKSEL", "480"))  # sisi terpanjang


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
# Foto verifikasi petugas (O1): cuplikan base64 di Firestore
# ---------------------------------------------------------------------------
# Kontrak PROJECT.md bagian 4/12: demo dengan peserta yang setuju boleh memakai
# cuplikan asli (maks FOTO_MAKS_PIKSEL px, JPEG q80); FOTO_ANONIM=true memakai
# cara lama (blur wajah Haar + pikselasi, maks 160 px, JPEG q60) — wajib untuk
# produksi. Disimpan maksimal FOTO_TTL_DETIK lalu dihapus otomatis. Tidak ada
# file foto ditulis ke disk — semua di RAM.

KOLEKSI_FOTO = "permintaan_foto"  # id dokumen = id dokumen tugas
FOTO_KUALITAS_JPEG = 80  # cuplikan asli (demo)
FOTO_KUALITAS_ANONIM = 60  # cara lama: cuplikan anonim
FOTO_MAKS_PIKSEL_ANONIM = 160  # cara lama membatasi sisi terpanjang ke 160 px
PIKSEL_BLOK = 8  # perkecil 8x lalu perbesar nearest = efek pikselasi
# Batas aman panjang string base64: dokumen Firestore maks 1 MiB, jadi base64
# dijaga jauh di bawahnya (700 ribu karakter ~ 525 KB biner).
FOTO_BATAS_BASE64 = 700_000

_CASCADE_WAJAH = None  # None = belum dimuat; False = tidak tersedia


def deteksi_wajah(gray):
    """Deteksi wajah pada crop grayscale; list (x, y, w, h), [] bila gagal.

    Cascade Haar bawaan opencv-python (cv2.data), dimuat sekali. Bila tidak
    tersedia, kembalikan [] — pikselasi tetap menyamarkan seluruh cuplikan.
    """
    global _CASCADE_WAJAH
    if _CASCADE_WAJAH is None:
        try:
            path = os.path.join(
                cv2.data.haarcascades, "haarcascade_frontalface_default.xml"
            )
            c = cv2.CascadeClassifier(path)
            _CASCADE_WAJAH = c if not c.empty() else False
        except Exception:
            _CASCADE_WAJAH = False
    if _CASCADE_WAJAH is False:
        return []
    return _CASCADE_WAJAH.detectMultiScale(
        gray, scaleFactor=1.1, minNeighbors=4, minSize=(20, 20)
    )


def anonimkan_crop(crop, maks_piks=FOTO_MAKS_PIKSEL):
    """Cuplikan BGR -> bytes JPEG anonim (cara lama), atau None bila gagal.

    Urutan: blur wajah (Haar) -> perkecil sisi terpanjang <= min(maks_piks,
    160) -> pikselkan -> encode JPEG q60. Dipakai saat FOTO_ANONIM=true
    (wajib untuk produksi). Kegagalan apa pun tidak boleh melempar: tugas
    tetap dibuat tanpa foto.
    """
    try:
        if crop is None or crop.size == 0:
            return None
        maks_piks = min(maks_piks, FOTO_MAKS_PIKSEL_ANONIM)
        hasil = crop.copy()
        gray = cv2.cvtColor(hasil, cv2.COLOR_BGR2GRAY)
        for (x, y, w, h) in deteksi_wajah(gray):
            # Perlebar 20% agar rambut/dagu ikut tersamar, clamp ke crop.
            mx, my = int(w * 0.2), int(h * 0.2)
            x1, y1 = max(0, x - mx), max(0, y - my)
            x2 = min(hasil.shape[1], x + w + mx)
            y2 = min(hasil.shape[0], y + h + my)
            if x2 <= x1 or y2 <= y1:
                continue
            area = hasil[y1:y2, x1:x2]
            k = (max(3, (x2 - x1) | 1), max(3, (y2 - y1) | 1))
            hasil[y1:y2, x1:x2] = cv2.GaussianBlur(area, k, 0)
        tinggi, lebar = hasil.shape[:2]
        skala = maks_piks / max(tinggi, lebar)
        if skala < 1:
            hasil = cv2.resize(
                hasil,
                (max(1, int(lebar * skala)), max(1, int(tinggi * skala))),
                interpolation=cv2.INTER_AREA,
            )
        kecil = cv2.resize(
            hasil,
            (
                max(1, hasil.shape[1] // PIKSEL_BLOK),
                max(1, hasil.shape[0] // PIKSEL_BLOK),
            ),
            interpolation=cv2.INTER_AREA,
        )
        hasil = cv2.resize(
            kecil, (hasil.shape[1], hasil.shape[0]),
            interpolation=cv2.INTER_NEAREST,
        )
        ok, buf = cv2.imencode(
            ".jpg", hasil, [int(cv2.IMWRITE_JPEG_QUALITY), FOTO_KUALITAS_ANONIM]
        )
        return buf.tobytes() if ok else None
    except Exception as e:
        print(f"[peringatan] Anonimisasi cuplikan gagal: {e}")
        return None


def crop_asli(crop, maks_piks=FOTO_MAKS_PIKSEL):
    """Cuplikan BGR -> bytes JPEG ASLI (tanpa blur/pikselasi), atau None.

    Untuk demo hackathon dengan peserta yang setuju (FOTO_ANONIM=false).
    Hanya diperkecil bila sisi terpanjang > maks_piks, lalu encode JPEG q80.
    Bila hasil base64 masih melebihi FOTO_BATAS_BASE64 (foto sangat ramai/
    noise), ukuran & kualitas diturunkan bertahap sampai muat — dokumen
    Firestore tidak boleh mendekati batas 1 MiB.
    """
    try:
        if crop is None or crop.size == 0:
            return None
        sisi = maks_piks
        kualitas = FOTO_KUALITAS_JPEG
        while True:
            hasil = crop
            tinggi, lebar = hasil.shape[:2]
            skala = sisi / max(tinggi, lebar)
            if skala < 1:
                hasil = cv2.resize(
                    hasil,
                    (max(1, int(lebar * skala)), max(1, int(tinggi * skala))),
                    interpolation=cv2.INTER_AREA,
                )
            ok, buf = cv2.imencode(
                ".jpg", hasil, [int(cv2.IMWRITE_JPEG_QUALITY), kualitas]
            )
            if not ok:
                return None
            data = buf.tobytes()
            # Panjang base64 = 4/3 ukuran biner (dibulatkan ke kelipatan 4).
            if (len(data) + 2) // 3 * 4 <= FOTO_BATAS_BASE64 or sisi <= 160:
                return data
            sisi = max(160, int(sisi * 0.8))
            kualitas = max(50, kualitas - 10)
    except Exception as e:
        print(f"[peringatan] Cuplikan asli gagal diproses: {e}")
        return None


def siapkan_foto(crop):
    """Pilih jalur cuplikan sesuai FOTO_ANONIM; None bila gagal/di luar mode.

    false (bawaan demo): cuplikan asli maks 480 px q80. true: cara lama,
    blur wajah + pikselasi maks 160 px q60 (produksi).
    """
    if FOTO_ANONIM:
        return anonimkan_crop(crop)
    return crop_asli(crop)


def crop_dari_kotak(frame, kotak, margin=0.1):
    """Cuplikan BGR dari kotak deteksi (7-tuple) + margin, clamp ke frame.

    Dipanggil pada frame MENTAH sebelum kotak/label digambar, agar cuplikan
    tidak ikut memuat coretan overlay. None bila kotak di luar frame.
    """
    _, _, x1, y1, x2, y2, _ = kotak
    tinggi, lebar = frame.shape[:2]
    mx, my = int((x2 - x1) * margin), int((y2 - y1) * margin)
    x1, y1 = max(0, x1 - mx), max(0, y1 - my)
    x2, y2 = min(lebar, x2 + mx), min(tinggi, y2 + my)
    if x2 <= x1 or y2 <= y1:
        return None
    return frame[y1:y2, x1:x2].copy()


class PenghapusFoto:
    """Thread latar penghapus dokumen permintaan_foto setelah TTL.

    Antrean prioritas (waktu_hapus, id_dokumen); satu thread daemon memproses.
    Gagal hapus (offline) dicoba lagi tiap 30 detik. Saat startup,
    sapu_kedaluwarsa() membuang foto sisa proses sebelumnya yang sudah lewat
    kedaluwarsaPada — backstop bila laptop mati sebelum thread sempat hapus.
    """

    def __init__(self, db, koleksi=KOLEKSI_FOTO, jeda_retry=30.0):
        self.db = db
        self.koleksi = koleksi
        self.jeda_retry = jeda_retry  # jarak coba ulang saat hapus gagal
        self.antrean = queue.PriorityQueue()
        self.thread = threading.Thread(
            target=self._jalan, daemon=True, name="penghapus-foto"
        )
        self.thread.start()

    def jadwalkan(self, id_dokumen, waktu_hapus):
        self.antrean.put((waktu_hapus, id_dokumen))

    def _jalan(self):
        while True:
            waktu_hapus, id_dokumen = self.antrean.get()
            while True:
                jeda = waktu_hapus - time.time()
                if jeda <= 0:
                    break
                time.sleep(min(jeda, 1.0))
            try:
                self.db.collection(self.koleksi).document(id_dokumen).delete()
                print(f"[foto] Cuplikan {id_dokumen} dihapus (TTL habis).")
            except Exception as e:
                print(
                    f"[peringatan] Gagal menghapus cuplikan {id_dokumen}: {e}; "
                    f"coba lagi {self.jeda_retry:.0f} detik."
                )
                self.antrean.put((time.time() + self.jeda_retry, id_dokumen))

    def sapu_kedaluwarsa(self):
        """Hapus foto yang kedaluwarsaPada-nya sudah lewat (sisa proses lama).

        Hanya where satu field sehingga tidak butuh composite index.
        Kegagalan sapuan tidak boleh menghentikan startup detektor.
        """
        try:
            sekarang = datetime.now(timezone.utc)
            docs = self.db.collection(self.koleksi).where(
                "kedaluwarsaPada", "<", sekarang
            ).stream()
            n = 0
            for d in docs:
                d.reference.delete()
                n += 1
            if n:
                print(f"[foto] {n} cuplikan kedaluwarsa sisa proses lama dibersihkan.")
        except Exception as e:
            print(f"[peringatan] Sapuan cuplikan kedaluwarsa gagal: {e}")


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
        # Foto verifikasi (O1): thread penghapus TTL + sapuan sisa proses lama.
        self.penghapus = PenghapusFoto(self.db) if FOTO_AKTIF else None
        if self.penghapus:
            self.penghapus.sapu_kedaluwarsa()

    def kirim_tugas(self, keyakinan, jumlah_terdeteksi=1, id_lacak=None, cuplikan=None):
        """Membuat permintaan pendampingan baru yang langsung muncul di HP petugas.

        [jumlah_terdeteksi] = banyaknya kursi roda di layar saat tugas dibuat;
        [id_lacak] = track ID ByteTrack (None untuk mode roboflow tanpa tracking);
        [cuplikan] = crop BGR mentah orang ini untuk foto verifikasi
        (None = tanpa foto; mode roboflow selalu None).
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
                self._kirim_foto(ref, cuplikan)
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

    def _kirim_foto(self, ref, cuplikan):
        """Menulis cuplikan verifikasi ke permintaan_foto/{idTugas}, lalu
        menandai tugas dengan adaFoto: true. Jalur asli/anonim mengikuti
        FOTO_ANONIM. Gagal di langkah mana pun: tugas TETAP dibuat tanpa foto
        (PROJECT.md bagian 4). Foto yang sudah tertulis selalu dijadwalkan
        hapus, walau penandaan adaFoto kemudian gagal.
        """
        if not FOTO_AKTIF or cuplikan is None or self.penghapus is None:
            return
        try:
            jpeg = siapkan_foto(cuplikan)
            if jpeg is None:
                print("[peringatan] Cuplikan gagal diproses; tugas tanpa foto.")
                return
            sekarang = datetime.now(timezone.utc)
            self.db.collection(KOLEKSI_FOTO).document(ref.id).set({
                "gambar": base64.b64encode(jpeg).decode("ascii"),
                "dibuatPada": self.SERVER_TIMESTAMP,
                "kedaluwarsaPada": sekarang + timedelta(seconds=FOTO_TTL_DETIK),
            })
            self.penghapus.jadwalkan(ref.id, time.time() + FOTO_TTL_DETIK)
            ref.update({"adaFoto": True})
            jenis = "anonim" if FOTO_ANONIM else "asli"
            print(
                f"[firebase] Cuplikan {jenis} {ref.id} ditulis "
                f"(TTL {FOTO_TTL_DETIK} detik)"
            )
        except Exception as e:
            print(f"[peringatan] Gagal menulis cuplikan ({e}); tugas tetap tanpa foto.")


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
                    # Cuplikan verifikasi (O1): crop kotak orang ini dari frame
                    # MENTAH (sebelum overlay digambar), hanya untuk kirim nyata.
                    cuplikan = None
                    if firebase and FOTO_AKTIF:
                        kotak_id = next(
                            (k for k in terlihat if k[6] == id_lacak), None
                        )
                        if kotak_id is not None:
                            cuplikan = crop_dari_kotak(frame, kotak_id)
                    berhasil = firebase is None  # --tanpa-firebase: anggap terkirim
                    if firebase:
                        # Kegagalan kirim tidak boleh mematikan loop deteksi.
                        try:
                            berhasil = firebase.kirim_tugas(
                                keyakinan,
                                jumlah_terdeteksi=len(terlihat),
                                id_lacak=id_lacak,
                                cuplikan=cuplikan,
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
