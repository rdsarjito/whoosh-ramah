# Anonymous Photo Verification System

<cite>
**Referenced Files in This Document**
- [PROJECT.md](file://PROJECT.md)
- [detect_wheelchair.py](file://detector/detect_wheelchair.py)
- [README.md (detector)](file://detector/README.md)
- [main.dart](file://whoosh_ramah/lib/main.dart)
- [permintaan.dart](file://whoosh_ramah/lib/models/permintaan.dart)
- [foto_permintaan.dart](file://whoosh_ramah/lib/models/foto_permintaan.dart)
- [permintaan_service.dart](file://whoosh_ramah/lib/services/permintaan_service.dart)
- [dummy.dart](file://whoosh_ramah/lib/data/dummy.dart)
- [theme.dart](file://whoosh_ramah/lib/theme.dart)
- [pilih_peran_screen.dart](file://whoosh_ramah/lib/screens/pilih_peran_screen.dart)
- [petugas_tugas_screen.dart](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart)
- [mise.toml](file://mise.toml)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [Project Structure](#project-structure)
3. [Core Components](#core-components)
4. [Architecture Overview](#architecture-overview)
5. [Detailed Component Analysis](#detailed-component-analysis)
6. [Dependency Analysis](#dependency-analysis)
7. [Performance Considerations](#performance-considerations)
8. [Troubleshooting Guide](#troubleshooting-guide)
9. [Conclusion](#conclusion)

## Introduction
This document explains the Anonymous Photo Verification System used by the Whoosh Ramah hackathon prototype. The system has two parts:
- A Python camera detector that detects wheelchair users and writes assistance tasks to Cloud Firestore.
- A Flutter application where passengers, station staff, and family members read and update those tasks in real time.

The verification photo feature is central: when a wheelchair user is detected, the detector creates an anonymous, blurred, pixelated JPEG snippet and stores it as base64 in a separate Firestore collection. Staff can view this snippet for verification, then accept or reject the task. Rejection does not change the task status; it only marks the task as rejected so it leaves the active list.

The project is intentionally scoped for a demo: no real login, no KCIC ticket integration, no push notifications, and no face-photo storage beyond the temporary anonymous snippet.

**Section sources**
- [PROJECT.md:8-20](file://PROJECT.md#L8-L20)
- [PROJECT.md:24-37](file://PROJECT.md#L24-L37)
- [PROJECT.md:102-114](file://PROJECT.md#L102-L114)
- [README.md (detector):1-8](file://detector/README.md#L1-L8)

## Project Structure
The repository contains three main areas:
- `detector/`: Python wheel-chair detector with Firebase integration and anonymous photo handling.
- `whoosh_ramah/`: Flutter app implementing passenger, staff, and family roles.
- `design/` and documentation files describing screens, data schema, and behavior.

```mermaid
graph TB
subgraph "Detector"
D1["detect_wheelchair.py"]
D2["requirements.txt"]
D3["README.md"]
end
subgraph "Flutter App"
F1["main.dart"]
F2["models/permintaan.dart"]
F3["models/foto_permintaan.dart"]
F4["services/permintaan_service.dart"]
F5["screens/pilih_peran_screen.dart"]
F6["screens/petugas_tugas_screen.dart"]
F7["data/dummy.dart"]
F8["theme.dart"]
end
subgraph "Cloud"
C1["Firestore<br/>permintaan_pendampingan"]
C2["Firestore<br/>permintaan_foto"]
end
D1 --> C1
D1 --> C2
F4 --> C1
F4 --> C2
F5 --> F6
F2 --> F4
F3 --> F4
```

**Diagram sources**
- [detect_wheelchair.py:381-451](file://detector/detect_wheelchair.py#L381-L451)
- [permintaan_service.dart:32-136](file://whoosh_ramah/lib/services/permintaan_service.dart#L32-L136)
- [permintaan.dart:77-150](file://whoosh_ramah/lib/models/permintaan.dart#L77-L150)
- [foto_permintaan.dart:6-31](file://whoosh_ramah/lib/models/foto_permintaan.dart#L6-L31)

**Section sources**
- [PROJECT.md:24-37](file://PROJECT.md#L24-L37)
- [PROJECT.md:201-225](file://PROJECT.md#L201-L225)
- [README.md (detector):10-18](file://detector/README.md#L10-L18)

## Core Components
The system revolves around four core components:

| Component | Responsibility | Key Behavior |
|---|---|---|
| Wheelchair Detector | Reads video, detects wheelchair users, writes tasks to Firestore | Supports Roboflow, YOLO-World, and local YOLO models; optional anonymous photo upload |
| Task Model | Represents one assistance request | Null-safe mapping from Firestore; enums for help type and status |
| Service Layer | Encapsulates Firestore reads/writes | Streams, transactional status updates, rejection handling, arrival marking |
| Photo Model | Represents verification snippet | Base64 JPEG decoding, TTL expiration check, null-safe UI state |

The detector writes tasks with `sumber = kamera_ai`, while passenger requests write `sumber = aplikasi`. Staff lists both, but treats them differently through badges, titles, and verification photos.

**Section sources**
- [detect_wheelchair.py:46-91](file://detector/detect_wheelchair.py#L46-L91)
- [permintaan.dart:7-57](file://whoosh_ramah/lib/models/permintaan.dart#L7-L57)
- [permintaan_service.dart:18-33](file://whoosh_ramah/lib/services/permintaan_service.dart#L18-L33)
- [foto_permintaan.dart:6-31](file://whoosh_ramah/lib/models/foto_permintaan.dart#L6-L31)

## Architecture Overview
At a high level, the system uses Firestore as the single source of truth. The detector writes tasks and optional verification photos. The Flutter app streams tasks and renders role-specific views.

```mermaid
sequenceDiagram
participant Camera as "Camera / Video Source"
participant Detector as "detect_wheelchair.py"
participant Firebase as "Cloud Firestore"
participant StaffApp as "Staff Flutter Screen"
Camera->>Detector : Frame stream
Detector->>Detector : Detect wheelchair + track ID
Detector->>Firebase : Create task in permintaan_pendampingan
alt Anonymous photo enabled
Detector->>Detector : Blur face + pixelate crop
Detector->>Firebase : Write base64 JPEG in permintaan_foto/{taskId}
Detector->>Firebase : Mark task adaFoto = true
end
StaffApp->>Firebase : Stream all tasks
Firebase-->>StaffApp : Active tasks with badges
StaffApp->>Firebase : Read permintaan_foto/{taskId}
Firebase-->>StaffApp : Verification snippet or expired state
```

**Diagram sources**
- [detect_wheelchair.py:573-707](file://detector/detect_wheelchair.py#L573-L707)
- [detect_wheelchair.py:381-451](file://detector/detect_wheelchair.py#L381-L451)
- [permintaan_service.dart:109-136](file://whoosh_ramah/lib/services/permintaan_service.dart#L109-L136)
- [petugas_tugas_screen.dart:24-28](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L24-L28)

## Detailed Component Analysis

### Anonymous Photo Pipeline
The anonymous photo pipeline ensures privacy while giving staff enough visual context to verify a detected wheelchair user.

```mermaid
flowchart TD
Start(["Detection Trigger"]) --> Crop["Crop detection box from raw frame"]
Crop --> FaceDetect["Detect faces using Haar cascade"]
FaceDetect --> BlurFaces["Blur detected faces"]
BlurFaces --> Resize["Resize longest side to max pixels"]
Resize --> Pixelate["Pixelate by block size"]
Pixelate --> Encode["Encode JPEG at quality 60"]
Encode --> Valid{"JPEG bytes valid?"}
Valid --> |No| SkipPhoto["Skip photo; task still created"]
Valid --> |Yes| WriteBase64["Write base64 to permintaan_foto/{taskId}"]
WriteBase64 --> ScheduleDelete["Schedule deletion after TTL"]
ScheduleDelete --> MarkTask["Mark task adaFoto = true"]
MarkTask --> End(["Task visible to staff"])
SkipPhoto --> End
```

**Diagram sources**
- [detect_wheelchair.py:230-279](file://detector/detect_wheelchair.py#L230-L279)
- [detect_wheelchair.py:282-295](file://detector/detect_wheelchair.py#L282-L295)
- [detect_wheelchair.py:425-451](file://detector/detect_wheelchair.py#L425-L451)
- [detect_wheelchair.py:298-357](file://detector/detect_wheelchair.py#L298-L357)

Key behaviors:
- Faces are blurred using OpenCV’s Haar cascade if available; otherwise, the whole crop is pixelated.
- The image is resized to a maximum side length, then pixelated to reduce detail.
- The result is encoded as a small JPEG and stored as base64 in Firestore.
- A background thread schedules deletion after the configured TTL.
- If any step fails, the task is still created without a photo.

**Section sources**
- [detect_wheelchair.py:207-279](file://detector/detect_wheelchair.py#L207-L279)
- [detect_wheelchair.py:298-357](file://detector/detect_wheelchair.py#L298-L357)
- [detect_wheelchair.py:425-451](file://detector/detect_wheelchair.py#L425-L451)

### Task Data Model
The task model maps Firestore documents into a null-safe Dart object. It includes enums for help type and status, plus derived properties for UI logic such as whether the task came from the camera, whether it is finished, and whether it can be rejected.

```mermaid
classDiagram
class JenisBantuan {
+string value
+string label
+dariValue(value) JenisBantuan
}
class StatusPermintaan {
+string value
+string label
+string tombolPetugas
+berikutnya StatusPermintaan?
+dariValue(value) StatusPermintaan
}
class RiwayatStatus {
+string status
+DateTime waktu
+fromMap(map) RiwayatStatus
+toFirestore() Map
}
class Permintaan {
+string id
+JenisBantuan jenisBantuan
+String titikJemput
+StatusPermintaan status
+String sumber
+bool dariKamera
+bool sudahSelesai
+bool sudahDitolak
+bool bisaDitolak
+RiwayatStatus[] riwayat
+fromFirestore(snap) Permintaan
+fromMap(data) Permintaan
+toFirestore() Map
}
Permintaan --> JenisBantuan : "uses"
Permintaan --> StatusPermintaan : "uses"
Permintaan --> RiwayatStatus : "contains"
```

**Diagram sources**
- [permintaan.dart:7-57](file://whoosh_ramah/lib/models/permintaan.dart#L7-L57)
- [permintaan.dart:59-75](file://whoosh_ramah/lib/models/permintaan.dart#L59-L75)
- [permintaan.dart:77-163](file://whoosh_ramah/lib/models/permintaan.dart#L77-L163)
- [permintaan.dart:183-253](file://whoosh_ramah/lib/models/permintaan.dart#L183-L253)

Important constraints:
- Enum values must match exactly between the detector and the Flutter app.
- Documents from the detector may lack fields like `riwayat`, `idPenumpang`, or `petugas`; the model handles missing fields safely.
- Rejection sets `ditolakPada` but does not change the status enum.

**Section sources**
- [PROJECT.md:54-100](file://PROJECT.md#L54-L100)
- [permintaan.dart:77-163](file://whoosh_ramah/lib/models/permintaan.dart#L77-L163)
- [permintaan.dart:183-253](file://whoosh_ramah/lib/models/permintaan.dart#L183-L253)

### Verification Photo Model
The verification photo model represents the anonymous snippet stored separately from the task. It decodes base64 JPEG data and exposes expiration logic.

```mermaid
classDiagram
class FotoPermintaan {
+string id
+Uint8List bytes
+DateTime dibuatPada
+DateTime kedaluwarsaPada
+kedaluwarsa(sekarang) bool
+fromFirestore(snap) FotoPermintaan
+fromMap(data) FotoPermintaan
}
```

**Diagram sources**
- [foto_permintaan.dart:6-31](file://whoosh_ramah/lib/models/foto_permintaan.dart#L6-L31)
- [foto_permintaan.dart:39-62](file://whoosh_ramah/lib/models/foto_permintaan.dart#L39-L62)

Behavior highlights:
- `bytes` is null when the snapshot is missing, the field is empty, or base64 decoding fails.
- UI should show “snippet expired” rather than erroring when `bytes` is null.
- Expiration is computed from `kedaluwarsaPada`, which the detector sets to creation time plus TTL.

**Section sources**
- [foto_permintaan.dart:6-31](file://whoosh_ramah/lib/models/foto_permintaan.dart#L6-L31)
- [foto_permintaan.dart:39-62](file://whoosh_ramah/lib/models/foto_permintaan.dart#L39-L62)

### Service Layer and Transactional Updates
The service layer centralizes Firestore access. It provides streams for tasks and verification photos, prevents duplicate passenger requests, advances status through transactions, supports task rejection, and marks passenger arrival.

```mermaid
sequenceDiagram
participant StaffUI as "Staff UI"
participant Service as "PermintaanService"
participant Firestore as "Firestore"
StaffUI->>Service : majukanStatus(taskId)
Service->>Service : Queue per taskId
Service->>Firestore : Read task in transaction
Firestore-->>Service : Current status
alt Next status exists and not rejected
Service->>Firestore : Update status + riwayat + petugas
Firestore-->>Service : Success
Service-->>StaffUI : Stream updates refresh UI
else Already finished or rejected
Service-->>StaffUI : No-op
end
```

**Diagram sources**
- [permintaan_service.dart:138-156](file://whoosh_ramah/lib/services/permintaan_service.dart#L138-L156)
- [permintaan_service.dart:158-213](file://whoosh_ramah/lib/services/permintaan_service.dart#L158-L213)

Key guarantees:
- `majukanStatus` runs in a Firestore transaction to prevent race conditions.
- An in-app per-id queue prevents double taps on the same device from racing.
- Rejection only affects `ditolakPada` and `alasanTolak`; it does not advance the status enum.
- Streams avoid composite index requirements by filtering and sorting locally.

**Section sources**
- [permintaan_service.dart:35-82](file://whoosh_ramah/lib/services/permintaan_service.dart#L35-L82)
- [permintaan_service.dart:98-136](file://whoosh_ramah/lib/services/permintaan_service.dart#L98-L136)
- [permintaan_service.dart:138-243](file://whoosh_ramah/lib/services/permintaan_service.dart#L138-L243)

### Staff Task List and Verification Thumbnail
The staff task screen streams all tasks, separates active and completed tasks, and shows verification thumbnails for camera-originated tasks that have a photo.

```mermaid
flowchart TD
Stream["Stream semua()"] --> Filter["Filter active: not selesai and not ditolak"]
Filter --> Summarize["Count Baru / Berjalan / Selesai / Ditolak"]
Summarize --> RenderCards["Render task cards"]
RenderCards --> CheckPhoto{"Camera task with adaFoto?"}
CheckPhoto --> |Yes| LoadPhoto["Stream permintaan_foto/{taskId}"]
LoadPhoto --> ShowThumb["Show thumbnail or expired state"]
CheckPhoto --> |No| ShowText["Show text-only card"]
```

**Diagram sources**
- [petugas_tugas_screen.dart:24-28](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L24-L28)
- [petugas_tugas_screen.dart:155-179](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L155-L179)
- [petugas_tugas_screen.dart:526-528](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L526-L528)
- [permintaan_service.dart:127-136](file://whoosh_ramah/lib/services/permintaan_service.dart#L127-L136)

**Section sources**
- [petugas_tugas_screen.dart:29-36](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L29-L36)
- [petugas_tugas_screen.dart:130-183](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L130-L183)
- [petugas_tugas_screen.dart:493-549](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L493-L549)

### Role Selection and App Entry
The app starts by initializing Firebase and showing the role selection screen. From there, users choose Passenger, Staff, or Family.

```mermaid
sequenceDiagram
participant Main as "main.dart"
participant App as "WhooshRamahApp"
participant RoleScreen as "PilihPeranScreen"
Main->>Main : Initialize Flutter binding
Main->>Main : Initialize Firebase
Main->>App : Run app
App->>RoleScreen : Show role selection
RoleScreen->>RoleScreen : Navigate to Penumpang / Petugas / Keluarga
```

**Diagram sources**
- [main.dart:9-28](file://whoosh_ramah/lib/main.dart#L9-L28)
- [main.dart:34-47](file://whoosh_ramah/lib/main.dart#L34-L47)
- [pilih_peran_screen.dart:16-158](file://whoosh_ramah/lib/screens/pilih_peran_screen.dart#L16-L158)

**Section sources**
- [main.dart:9-47](file://whoosh_ramah/lib/main.dart#L9-L47)
- [pilih_peran_screen.dart:10-16](file://whoosh_ramah/lib/screens/pilih_peran_screen.dart#L10-L16)
- [pilih_peran_screen.dart:16-158](file://whoosh_ramah/lib/screens/pilih_peran_screen.dart#L16-L158)

### Dummy Data and Theme
Dummy data provides hard-coded passenger, staff, ticket, and pickup location information for the demo. The theme defines colors, typography, radius, shadows, and button styles following the Brightline design system.

**Section sources**
- [dummy.dart:1-141](file://whoosh_ramah/lib/data/dummy.dart#L1-L141)
- [theme.dart:3-52](file://whoosh_ramah/lib/theme.dart#L3-L52)
- [theme.dart:81-182](file://whoosh_ramah/lib/theme.dart#L81-L182)

## Dependency Analysis
The detector depends on OpenCV, Firebase Admin, and optionally Roboflow or Ultralytics depending on the selected model. The Flutter app depends on Firebase Core, Cloud Firestore, and Material UI components.

```mermaid
graph LR
PyEnv["Python 3.12"] --> Detector["detect_wheelchair.py"]
Detector --> CV2["OpenCV"]
Detector --> FirebaseAdmin["Firebase Admin"]
Detector --> Roboflow["Roboflow SDK"]
Detector --> Ultralytics["Ultralytics / YOLO"]
FlutterApp["Flutter App"] --> FirebaseCore["firebase_core"]
FlutterApp --> Firestore["cloud_firestore"]
FlutterApp --> MaterialUI["material_ui"]
FlutterApp --> Models["models/*"]
FlutterApp --> Services["services/*"]
FlutterApp --> Screens["screens/*"]
```

**Diagram sources**
- [detect_wheelchair.py:40-43](file://detector/detect_wheelchair.py#L40-L43)
- [detect_wheelchair.py:97-190](file://detector/detect_wheelchair.py#L97-L190)
- [detect_wheelchair.py:362-379](file://detector/detect_wheelchair.py#L362-L379)
- [main.dart:1-7](file://whoosh_ramah/lib/main.dart#L1-L7)
- [permintaan_service.dart:1-5](file://whoosh_ramah/lib/services/permintaan_service.dart#L1-L5)
- [mise.toml:1-3](file://mise.toml#L1-L3)

**Section sources**
- [detect_wheelchair.py:40-91](file://detector/detect_wheelchair.py#L40-L91)
- [main.dart:1-7](file://whoosh_ramah/lib/main.dart#L1-L7)
- [permintaan_service.dart:1-5](file://whoosh_ramah/lib/services/permintaan_service.dart#L1-L5)
- [mise.toml:1-3](file://mise.toml#L1-L3)

## Performance Considerations
- Detection frequency is controlled by `DETEKSI_TIAP_DETIK` to limit API calls and CPU usage.
- Tracking mode reduces duplicate tasks per person by tracking IDs instead of relying only on global streaks.
- Anonymous photos are downsized, pixelated, and stored as small base64 strings to reduce Firestore payload size.
- Background deletion avoids keeping expired snippets indefinitely.
- Firestore queries avoid composite indexes by doing simple `where`/`orderBy` and filtering locally.
- Transactional status updates prevent duplicate history entries and inconsistent state under concurrent edits.

[No sources needed since this section provides general guidance]

## Troubleshooting Guide
Common issues and their likely causes:

| Symptom | Likely Cause | Resolution |
|---|---|---|
| Detector exits with missing Firebase key | `firebase-key.json` not found | Place the service account key in `detector/firebase-key.json` and keep it out of version control |
| Detector cannot open camera or video source | Invalid source path or webcam unavailable | Use a valid webcam index, video file, or RTSP URL |
| No tasks appear in staff list | Firestore rules, network issue, or wrong collection name | Verify Firestore rules, internet connection, and collection name |
| Verification photo never appears | Photo writing failed, TTL expired, or `adaFoto` not set | Check detector logs, TTL settings, and whether the photo document was deleted |
| Status jumps or duplicates | Concurrent edits or double taps | Rely on transactional `majukanStatus` and per-id queue; test with multiple devices |
| Duplicate passenger requests | Multiple rapid submissions before first completes | Service blocks new requests while an active request exists |

**Section sources**
- [detect_wheelchair.py:362-379](file://detector/detect_wheelchair.py#L362-L379)
- [detect_wheelchair.py:573-604](file://detector/detect_wheelchair.py#L573-L604)
- [detect_wheelchair.py:404-423](file://detector/detect_wheelchair.py#L404-L423)
- [permintaan_service.dart:35-82](file://whoosh_ramah/lib/services/permintaan_service.dart#L35-L82)
- [permintaan_service.dart:158-213](file://whoosh_ramah/lib/services/permintaan_service.dart#L158-L213)

## Conclusion
The Anonymous Photo Verification System combines a privacy-preserving camera detector with a real-time Flutter interface. The detector creates tasks and optional anonymous verification snippets, while the app lets passengers request help, staff manage tasks, and family monitor progress. The design emphasizes safety, accessibility, and clear state transitions, with Firestore serving as the shared backbone. For production use, security rules, authentication, and storage policies would need strengthening beyond the demo configuration.

[No sources needed since this section summarizes without analyzing specific files]