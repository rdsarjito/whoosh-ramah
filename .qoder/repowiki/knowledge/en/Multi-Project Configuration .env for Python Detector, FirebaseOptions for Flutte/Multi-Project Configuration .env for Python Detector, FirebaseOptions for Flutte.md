---
kind: configuration_system
name: 'Multi-Project Configuration: .env for Python Detector, FirebaseOptions for Flutter App'
category: configuration_system
scope:
    - '**'
source_files:
    - detector/.env
    - detector/.env.example
    - detector/firebase-key.json
    - whoosh_ramah/lib/firebase_options.dart
    - whoosh_ramah/firebase.json
    - whoosh_ramah/android/app/google-services.json
    - whoosh_ramah/pubspec.yaml
    - whoosh_ramah/analysis_options.yaml
    - whoosh_ramah/android/local.properties
    - mise.toml
---

## Overview

This repository contains two independently configured subsystems — a Python wheelchair detector and a Flutter passenger-assistance app — each with its own configuration approach. There is no shared configuration layer; the two projects are wired together only by a shared Firestore collection name.

## Python Detector (`detector/`)

### Environment-file driven configuration

All runtime behavior of `detect_wheelchair.py` and `train_yolo.py` is controlled through environment variables loaded from `.env` (with `.env.example` as the template).

Key variables (from `.env.example`):

| Variable | Purpose |
|---|---|
| `MODE_MODEL` | Selects detection backend: `roboflow`, `yoloworld`, or `lokal` |
| `ROBOFLOW_API_KEY`, `ROBOFLOW_MODEL_ID` | Roboflow cloud model credentials and model id |
| `YOLOWORLD_MODEL`, `KELAS_YOLOWORLD` | YOLO World model file and target class list |
| `MODEL_LOKAL` | Path to a locally trained `.pt` model |
| `KELAS_TARGET` | Comma-separated list of classes considered "wheelchair" |
| `AMBANG_KEYAKINAN` | Detection confidence threshold |
| `FRAME_BERTURUT`, `JEDA_ANTAR_TUGAS_DETIK`, `DETEKSI_TIAP_DETIK` | Frame-skipping and timing controls |
| `LOKASI_KAMERA`, `ID_KAMERA` | Camera identity metadata attached to posted tasks |
| `FIREBASE_KEY` | Path to the Firebase service-account JSON (`firebase-key.json`) |
| `KOLEKSI_FIRESTORE` | Firestore collection name for assistance requests (`permintaan_pendampingan`) |

The `.env.example` header instructs users to copy it to `.env` and fill in values. The actual `.env` in the repo contains a committed API key and project secrets — this is a security concern but reflects current practice.

### Model selection convention

Three mutually exclusive modes are supported:

1. **Jalan A** (`MODE_MODEL=roboflow`): Uses Roboflow's hosted model via API.
2. **Jalan B** (`MODE_MODEL=lokal`): Uses a locally trained `.pt` model referenced by `MODEL_LOKAL`.
3. **YOLO World mode** (present in `.env` but not documented in `.env.example`): Uses prompt-based detection with `YOLOWORLD_MODEL` and `KELAS_YOLOWORLD`.

The presence of both `MODE_MODEL=yoloworld` in `.env` and the older three-mode comments in `.env.example` indicates the example file has not been updated to reflect the current code path.

### Secrets

- `firebase-key.json` — Firebase service account credentials, checked into the repo alongside `.env`.
- `yolov8s-worldv2.pt` — Pre-trained model weights (~tens of MB), checked into the repo.
- `.gitignore` at the repo root does NOT exclude these files, so they are tracked by version control.

## Flutter App (`whoosh_ramah/`)

### Firebase configuration

Firebase is configured via FlutterFire CLI-generated files:

- `lib/firebase_options.dart` — Generated Dart file exposing `DefaultFirebaseOptions.currentPlatform`, which returns platform-specific `FirebaseOptions`. Only Android is currently implemented; other platforms throw `UnsupportedError`.
- `firebase.json` — FlutterFire CLI manifest declaring the project ID (`whoosh-ramah`), Android app ID, and output location for generated options.
- `android/app/google-services.json` — Google Services config downloaded from the Firebase console.

The app initializes Firebase in `lib/main.dart` using `DefaultFirebaseOptions.currentPlatform`.

### Build & dependency configuration

- `pubspec.yaml` — Declares dependencies (`firebase_core`, `cloud_firestore`, `material_ui`, `cupertino_icons`, `intl`), SDK constraint (`^3.14.0`), and bundled Nunito fonts under `assets/fonts/`.
- `analysis_options.yaml` — Enables `flutter_lints/flutter.yaml` and excludes `build/**` and `android/**` from analysis.
- `android/local.properties` — Local machine paths (`flutter.sdk`, `sdk.dir`) and build metadata; this file is typically gitignored per standard Flutter conventions but appears present here.

### Runtime configuration

The Flutter app itself does not load any application-level config files at runtime. All Firebase connection details are baked into the generated `firebase_options.dart` and `google-services.json`. There is no feature-flag system, no runtime settings UI, and no env-var loading in the Dart code.

## Shared Convention

Both subsystems agree on the Firestore collection name used to exchange data:

- Python side: `KOLEKSI_FIRESTORE=permintaan_pendampingan` (in `.env`).
- Flutter side: hardcoded references to the same collection name in the domain models/services.

This is the only cross-project configuration coupling; there is no shared schema file or config registry.

## Toolchain Configuration

- `mise.toml` at the repo root pins `python = "3.12"` for the Python detector.
- No equivalent toolchain pinning exists for Flutter/Dart beyond the SDK constraint in `pubspec.yaml`.

## Conventions Observed

- Python configuration is exclusively `.env`-based; there is no typed config loader, validation, or defaults file separate from secrets.
- `.env.example` documents all expected variables with Indonesian-language comments (`Salin file ini menjadi .env lalu isi nilainya.`).
- Firebase configuration is managed entirely by FlutterFire CLI; developers should re-run the CLI rather than edit `firebase_options.dart` manually (the file header says `// File generated by FlutterFire CLI.`).
- Secrets (Firebase keys, Roboflow API key) are committed to the repository in both `.env` and `firebase-key.json`, which contradicts standard secret-management practices.
- The `detector/.gitignore` is absent (no `.gitignore` under `detector/`), so `.env` and `firebase-key.json` are tracked.