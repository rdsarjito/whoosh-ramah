#!/usr/bin/env python3
"""Mengisi Firestore dengan tiga permintaan demo (Tier 3 E6).

Berguna sebelum demo/presentasi: daftar petugas langsung berisi tugas dari
aplikasi maupun kamera AI, dan layar keluarga punya perjalanan yang selesai.
Skema dokumen mengikuti PROJECT.md bagian 4 persis (nama field & nilai enum).

Pakai Python yang punya firebase-admin (mis. venv detektor) dan kunci service
account `detector/firebase-key.json`:

    detector/venv/bin/python whoosh_ramah/tool/seed_demo.py
    detector/venv/bin/python whoosh_ramah/tool/seed_demo.py --bersih

Id dokumen tetap (`demo-seed-1..3`) supaya aman dijalankan ulang dan mudah
dibersihkan lagi. Skrip TIDAK menghapus dokumen lain.
"""

import argparse
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, firestore

ROOT = Path(__file__).resolve().parent.parent.parent
KUNCI = ROOT / "detector" / "firebase-key.json"
KOLEKSI = "permintaan_pendampingan"

SEKARANG = datetime.now(timezone.utc)


def jam(menit_lalu: int) -> datetime:
    return SEKARANG - timedelta(minutes=menit_lalu)


def riwayat(*tahap: tuple[str, int]) -> list[dict]:
    return [{"status": s, "waktu": jam(m)} for s, m in tahap]


DOKUMEN = {
    # 1. Permintaan aplikasi yang masih menunggu petugas.
    "demo-seed-1": {
        "jenisBantuan": "kursi_roda",
        "titikJemput": "Lobi utama",
        "status": "menunggu",
        "sumber": "aplikasi",
        "namaPenumpang": "Siti Aminah",
        "idPenumpang": "demo-siti",
        "kereta": "G1123",
        "jamBerangkat": "08.10",
        "stasiunAsal": "Halim",
        "stasiunTujuan": "Tegalluar",
        "gerbong": "5",
        "kursi": "7A",
        "catatan": "membawa satu koper besar",
        "petugas": None,
        "riwayat": riwayat(("menunggu", 2)),
        "dibuatPada": jam(2),
        "diperbaruiPada": jam(2),
    },
    # 2. Tugas kamera AI yang sedang berjalan (petugas sudah bertemu).
    "demo-seed-2": {
        "jenisBantuan": "kursi_roda",
        "titikJemput": "Stasiun Halim - Pintu Masuk Utara",
        "status": "bertemu",
        "sumber": "kamera_ai",
        "namaPenumpang": None,
        "idPenumpang": None,
        "kereta": None,
        "jamBerangkat": None,
        "stasiunAsal": None,
        "stasiunTujuan": None,
        "gerbong": None,
        "kursi": None,
        "catatan": None,
        "petugas": "Rina",
        "idKamera": "halim-utara-01",
        "keyakinan": 0.87,
        "riwayat": riwayat(("menunggu", 25), ("ditugaskan", 22), ("bertemu", 14)),
        "dibuatPada": jam(25),
        "diperbaruiPada": jam(14),
    },
    # 3. Perjalanan selesai — untuk daftar "selesai hari ini" & pantau keluarga.
    "demo-seed-3": {
        "jenisBantuan": "lansia",
        "titikJemput": "Area parkir",
        "status": "selesai",
        "sumber": "aplikasi",
        "namaPenumpang": "Siti Aminah",
        "idPenumpang": "demo-siti",
        "kereta": "G1123",
        "jamBerangkat": "08.10",
        "stasiunAsal": "Halim",
        "stasiunTujuan": "Tegalluar",
        "gerbong": "5",
        "kursi": "7A",
        "catatan": None,
        "petugas": "Rina",
        "riwayat": riwayat(
            ("menunggu", 90),
            ("ditugaskan", 86),
            ("bertemu", 78),
            ("di_kursi", 70),
            ("selesai", 62),
        ),
        "dibuatPada": jam(90),
        "diperbaruiPada": jam(62),
    },
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--bersih",
        action="store_true",
        help="hapus hanya dokumen demo-seed-1..3, lalu keluar",
    )
    parser.add_argument(
        "--kunci",
        type=Path,
        default=KUNCI,
        help="path kunci service account Firebase (default: detector/firebase-key.json)",
    )
    args = parser.parse_args()

    if not args.kunci.exists():
        print(f"kunci tidak ditemukan: {args.kunci}", file=sys.stderr)
        return 1

    firebase_admin.initialize_app(credentials.Certificate(str(args.kunci)))
    db = firestore.client()
    col = db.collection(KOLEKSI)

    if args.bersih:
        for doc_id in DOKUMEN:
            col.document(doc_id).delete()
            print(f"dihapus: {doc_id}")
        return 0

    for doc_id, data in DOKUMEN.items():
        col.document(doc_id).set(data)
        print(f"ditulis: {doc_id} ({data['status']}, {data['sumber']})")
    print(f"selesai: {len(DOKUMEN)} dokumen demo di koleksi {KOLEKSI}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())