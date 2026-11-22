---
kind: external_dependency
name: YOLO-World wheel-chair detector (Python)
slug: yolo-world-ultralytics
category: external_dependency
category_hints:
    - framework_behavior
    - sdk_real_api
scope:
    - '**'
source_files:
    - detector/requirements.txt
    - detector/yolov8s-worldv2.pt
    - detector/detect_wheelchair.py
---

### Identity
Ultralytics YOLO-World object-detection runtime, with the pre-trained `yolov8s-worldv2.pt` model shipped under `detector/yolov8s-worldv2.pt`. Optional inference path via `inference-sdk>=0.20` (Roboflow) or local model via `ultralytics>=8.2`.

### Role in this repo
The detector runs on a laptop, watches the camera feed with `opencv-python>=4.8`, detects wheelchair users at station entrances, and writes a Firestore task document (`sumber='kamera_ai'`). The Flutter app never runs AI — it only consumes the resulting documents.

### Stable integration shape
- Detector output fields: `jenisBantuan='kursi_roda'`, `titikJemput` (full location string), `status='menunggu'`, `sumber='kamera_ai'`, `idKamera`, `keyakinan`, `namaPenumpang=null`, `dibuatPada`.
- Confidence is stored as a float 0–1; the app converts to percentage via `persenKeyakinan = keyakinan * 100` rounded.
- Environment variables (e.g. Firebase credentials) come from `detector/.env` loaded via `python-dotenv`.
- Verify exact API against the current `detect_wheelchair.py` before modifying the detection pipeline.