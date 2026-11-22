Based on my analysis of the codebase, I can see that the Firebase integration has been significantly enhanced with new features. Let me now create the updated documentation that reflects these changes:

# Firebase Integration

<cite>
**Referenced Files in This Document**
- [detect_wheelchair.py](file://detector/detect_wheelchair.py)
- [permintaan.dart](file://whoosh_ramah/lib/models/permintaan.dart)
- [permintaan_service.dart](file://whoosh_ramah/lib/services/permintaan_service.dart)
- [PROJECT.md](file://PROJECT.md)
</cite>

## Update Summary
**Changes Made**
- Enhanced `PengirimFirebase` class with retry logic and exponential backoff
- Added new data fields `jumlahTerdeteksi` and `idLacak` to Firestore documents
- Improved error handling for robust operation
- Updated data schema documentation to reflect new fields
- Enhanced troubleshooting section with retry mechanism details

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
This document explains how the AI detection system integrates with Firebase Firestore to automatically create assistance tasks when wheelchair users are detected by the camera detector. It covers:

- The Python `PengirimFirebase` class that writes new assistance requests into Firestore with enhanced retry logic and exponential backoff.
- The Firestore data schema for assistance requests, including fields such as `jenisBantuan`, `titikJemput`, status progression, metadata, and new fields like `jumlahTerdeteksi` and `idLacak`.
- Firebase authentication using a service account key file.
- Security rules configuration for demo use.
- Example Firestore document structure created by the detector.
- How the Flutter mobile application consumes these documents through real-time streams.
- Error handling, retry mechanisms with exponential backoff, and monitoring of detection-to-task conversion rates.

## Project Structure
The integration spans two main parts:

- **Detector (Python):** Runs on a laptop or edge device, reads video from a webcam or CCTV, detects wheelchair users, and writes assistance requests to Firestore with enhanced reliability.
- **Mobile App (Flutter):** Reads and updates assistance requests in real time for passengers, staff, and family members.

```mermaid
graph TB
subgraph "Edge Device"
DET["Detector<br/>detect_wheelchair.py"]
end
subgraph "Cloud"
FIRESTORE["Firestore<br/>Collection: permintaan_pendampingan"]
end
subgraph "Mobile Devices"
PASSENGER["Passenger App"]
STAFF["Staff App"]
FAMILY["Family App"]
end
DET --> FIRESTORE
PASSENGER --> FIRESTORE
STAFF --> FIRESTORE
FAMILY --> FIRESTORE
```

**Diagram sources**
- [detect_wheelchair.py:362-452](file://detector/detect_wheelchair.py#L362-L452)
- [PROJECT.md:24-36](file://PROJECT.md#L24-L36)

**Section sources**
- [PROJECT.md:24-36](file://PROJECT.md#L24-L36)

## Core Components
The Firebase integration relies on three core components:

1. **`PengirimFirebase` (Python)**  
   Initializes Firebase Admin SDK with a service account key and creates new assistance request documents in Firestore when wheelchairs are detected, featuring enhanced retry logic with exponential backoff.

2. **`Permintaan` model (Flutter)**  
   Defines the Firestore document schema, including enums for `jenisBantuan` and `status`, helper methods for null-safe parsing, and serialization to/from Firestore maps.

3. **`PermintaanService` (Flutter)**  
   Encapsulates all Firestore operations: creating requests, streaming single documents, streaming lists, filtering by passenger, and advancing status with history tracking.

**Section sources**
- [detect_wheelchair.py:362-452](file://detector/detect_wheelchair.py#L362-L452)
- [permintaan.dart:1-255](file://whoosh_ramah/lib/models/permintaan.dart#L1-L255)
- [permintaan_service.dart:1-228](file://whoosh_ramah/lib/services/permintaan_service.dart#L1-L228)

## Architecture Overview
The end-to-end flow is:

1. The detector runs continuously, sampling frames at a controlled rate.
2. When a wheelchair is detected with sufficient confidence for consecutive frames, it calls `PengirimFirebase.kirim_tugas`.
3. `PengirimFirebase` initializes Firebase Admin SDK using a service account JSON file and writes a new document to the `permintaan_pendampingan` collection with enhanced retry logic.
4. Flutter apps subscribe to Firestore streams and update UIs in real time.

```mermaid
sequenceDiagram
participant Camera as "Camera / Video Source"
participant Detector as "Detector<br/>detect_wheelchair.py"
participant Firebase as "Firebase Admin SDK"
participant Firestore as "Firestore<br/>permintaan_pendampingan"
participant PassengerApp as "Passenger App"
participant StaffApp as "Staff App"
participant FamilyApp as "Family App"
Camera->>Detector : Frame stream
Detector->>Detector : Detect wheelchair + confidence
Detector->>Firebase : Initialize app with service account
Detector->>Firestore : Add assistance request document (with retry)
Firestore-->>PassengerApp : Real-time stream update
Firestore-->>StaffApp : Real-time stream update
Firestore-->>FamilyApp : Real-time stream update
```

**Diagram sources**
- [detect_wheelchair.py:573-708](file://detector/detect_wheelchair.py#L573-L708)
- [detect_wheelchair.py:362-452](file://detector/detect_wheelchair.py#L362-L452)
- [permintaan_service.dart:97-124](file://whoosh_ramah/lib/services/permintaan_service.dart#L97-L124)

## Detailed Component Analysis

### PengirimFirebase Class
`PengirimFirebase` is responsible for:

- Validating the presence of the Firebase service account key file.
- Initializing the Firebase Admin SDK with the certificate.
- Creating Firestore client references.
- Writing new assistance request documents with required fields and enhanced retry logic.

Key behaviors:

- Constructor checks for the service account file path configured via environment variables.
- On initialization, it sets up Firebase Admin SDK and Firestore client.
- `kirim_tugas` builds a document payload containing:
  - `jenisBantuan`: always set to wheelchair assistance for this detector.
  - `titikJemput`: camera location string.
  - `status`: starts as `menunggu`.
  - `sumber`: marks the task as created by AI camera.
  - `idKamera`: camera identifier.
  - `keyakinan`: rounded confidence score.
  - `jumlahTerdeteksi`: count of wheelchairs detected in the frame.
  - `idLacak`: track ID from ByteTrack for person tracking.
  - `namaPenumpang`: null because the passenger did not book through the app.
  - `dibuatPada`: server timestamp.
- **Enhanced Retry Logic**: Implements exponential backoff with configurable retry attempts.

```mermaid
classDiagram
class PengirimFirebase {
-db
-SERVER_TIMESTAMP
+__init__()
+kirim_tugas(keyakinan, jumlah_terdeteksi=1, id_lacak=None, cuplikan=None)
-_kirim_foto(ref, cuplikan)
}
```

**Updated** Enhanced with retry logic and exponential backoff for robust operation

**Diagram sources**
- [detect_wheelchair.py:362-452](file://detector/detect_wheelchair.py#L362-L452)

**Section sources**
- [detect_wheelchair.py:362-452](file://detector/detect_wheelchair.py#L362-L452)

### Firestore Data Schema
The assistance request document lives in the `permintaan_pendampingan` collection. The schema is defined in the Flutter model and documented in the project specification.

Important fields:

| Field | Type | Meaning | Set By |
|---|---|---|---|
| `jenisBantuan` | String enum | Type of assistance requested | Passenger or detector |
| `titikJemput` | String | Pickup location | Passenger or detector |
| `status` | String enum | Workflow state | All actors |
| `sumber` | String | Source of the request (`aplikasi` or `kamera_ai`) | Automatic |
| `namaPenumpang` | String or null | Passenger name | Passenger; null for detector |
| `idPenumpang` | String or null | Passenger ID | Passenger |
| `kereta` | String or null | Train number | Passenger |
| `jamBerangkat` | String or null | Departure time | Passenger |
| `stasiunAsal` | String or null | Origin station | Passenger |
| `stasiunTujuan` | String or null | Destination station | Passenger |
| `gerbong` | String or null | Carriage number | Passenger |
| `kursi` | String or null | Seat number | Passenger |
| `catatan` | String or null | Notes | Passenger |
| `petugas` | String or null | Assigned staff member | Staff workflow |
| `idKamera` | String or null | Camera ID | Detector |
| `keyakinan` | Number or null | Detection confidence | Detector |
| `jumlahTerdeteksi` | Integer | Count of wheelchairs detected in frame | Detector |
| `idLacak` | Integer or null | Track ID from ByteTrack | Detector |
| `riwayat` | Array of maps | Status change history | All actors |
| `dibuatPada` | Timestamp | Creation time | Automatic |
| `diperbaruiPada` | Timestamp | Last update time | Automatic |

**Updated** Added new fields `jumlahTerdeteksi` and `idLacak` for enhanced tracking capabilities

Enums:

- `jenisBantuan`: includes wheelchair, visually impaired, deaf, elderly, pregnant, porter.
- `status`: mandatory progression from `menunggu` to `selesai`.

```mermaid
erDiagram
PERMINTAAN_PENDAMPINGAN {
string jenisBantuan
string titikJemput
string status
string sumber
string namaPenumpang
string idPenumpang
string kereta
string jamBerangkat
string stasiunAsal
string stasiunTujuan
string gerbong
string kursi
string catatan
string petugas
string idKamera
float keyakinan
int jumlahTerdeteksi
int idLacak
array riwayat
timestamp dibuatPada
timestamp diperbaruiPada
}
```

**Updated** Added new fields `jumlahTerdeteksi` and `idLacak` to the entity relationship diagram

**Diagram sources**
- [permintaan.dart:77-255](file://whoosh_ramah/lib/models/permintaan.dart#L77-L255)
- [PROJECT.md:54-95](file://PROJECT.md#L54-L95)

**Section sources**
- [permintaan.dart:77-255](file://whoosh_ramah/lib/models/permintaan.dart#L77-L255)
- [PROJECT.md:54-95](file://PROJECT.md#L54-L95)

### Status Progression and History
Status progression follows a strict order:

1. `menunggu`
2. `ditugaskan`
3. `bertemu`
4. `di_kursi`
5. `selesai`

Each status change:

- Updates the `status` field.
- Updates `diperbaruiPada` with a server timestamp.
- Adds an entry to the `riwayat` array with the new status and a local timestamp.
- Sets `petugas` to a demo staff value when moving to `ditugaskan`.

```mermaid
stateDiagram-v2
[*] --> menunggu
menunggu --> ditugaskan : "Terima tugas"
ditugaskan --> bertemu : "Sudah bertemu penumpang"
bertemu --> di_kursi : "Penumpang sudah di kursi"
di_kursi --> selesai : "Serahkan ke petugas tujuan"
selesai --> [*]
```

**Diagram sources**
- [permintaan.dart:27-57](file://whoosh_ramah/lib/models/permintaan.dart#L27-L57)
- [permintaan_service.dart:144-193](file://whoosh_ramah/lib/services/permintaan_service.dart#L144-L193)

**Section sources**
- [permintaan.dart:27-57](file://whoosh_ramah/lib/models/permintaan.dart#L27-L57)
- [permintaan_service.dart:144-193](file://whoosh_ramah/lib/services/permintaan_service.dart#L144-L193)

### Mobile Application Real-Time Integration
The Flutter side uses `PermintaanService` to interact with Firestore:

- `buatPermintaan`: Creates a new assistance request from the passenger app.
- `streamPermintaan(id)`: Streams a single request document.
- `streamSemua()`: Streams all requests, ordered by creation time, limited to 100.
- `streamTerbaruPenumpang(idPenumpang)`: Streams the latest request for a specific passenger.
- `majukanStatus(id)`: Advances the status according to the allowed workflow.

```mermaid
flowchart TD
Start(["User action"]) --> CreateRequest["Create assistance request"]
CreateRequest --> FirestoreWrite["Write to Firestore"]
FirestoreWrite --> StreamAll["Stream all requests"]
StreamAll --> UpdateUI["Update staff list"]
StreamAll --> UpdatePassenger["Update passenger status"]
StreamAll --> UpdateFamily["Update family monitoring"]
UpdateUI --> AdvanceStatus["Advance status"]
AdvanceStatus --> UpdateHistory["Add riwayat entry"]
UpdateHistory --> FirestoreUpdate["Update Firestore"]
```

**Diagram sources**
- [permintaan_service.dart:44-81](file://whoosh_ramah/lib/services/permintaan_service.dart#L44-L81)
- [permintaan_service.dart:144-193](file://whoosh_ramah/lib/services/permintaan_service.dart#L144-L193)

**Section sources**
- [permintaan_service.dart:44-193](file://whoosh_ramah/lib/services/permintaan_service.dart#L44-L193)

### Example Firestore Document Created by the Detector
When the detector identifies a wheelchair user, it creates a document similar to the following structure:

- `jenisBantuan`: `"kursi_roda"`
- `titikJemput`: camera location string
- `status`: `"menunggu"`
- `sumber`: `"kamera_ai"`
- `idKamera`: camera identifier
- `keyakinan`: rounded confidence value
- `jumlahTerdeteksi`: count of wheelchairs detected in the frame
- `idLacak`: track ID from ByteTrack (for person tracking)
- `namaPenumpang`: `null`
- `dibuatPada`: server timestamp

**Updated** Enhanced document structure with new tracking fields

This document appears immediately in the staff app's real-time list and can be advanced through the status workflow.

**Section sources**
- [detect_wheelchair.py:381-423](file://detector/detect_wheelchair.py#L381-L423)
- [PROJECT.md:60-80](file://PROJECT.md#L60-L80)

## Dependency Analysis
The integration has clear boundaries between Python and Flutter:

- Python detector depends on Firebase Admin SDK and environment configuration.
- Flutter app depends on Cloud Firestore SDK and the `Permintaan` model.
- Both sides must agree on collection names and field values.

```mermaid
graph LR
PY["Python Detector<br/>detect_wheelchair.py"] --> FIREBASE_ADMIN["Firebase Admin SDK"]
FIREBASE_ADMIN --> FIRESTORE["Firestore Collection<br/>permintaan_pendampingan"]
FLUTTER_MODEL["Flutter Model<br/>permintaan.dart"] --> FLUTTER_SERVICE["Flutter Service<br/>permintaan_service.dart"]
FLUTTER_SERVICE --> CLOUD_FIRESTORE["Cloud Firestore SDK"]
CLOUD_FIRESTORE --> FIRESTORE
```

**Diagram sources**
- [detect_wheelchair.py:362-452](file://detector/detect_wheelchair.py#L362-L452)
- [permintaan.dart:1-255](file://whoosh_ramah/lib/models/permintaan.dart#L1-L255)
- [permintaan_service.dart:1-228](file://whoosh_ramah/lib/services/permintaan_service.dart#L1-L228)

**Section sources**
- [detect_wheelchair.py:362-452](file://detector/detect_wheelchair.py#L362-L452)
- [permintaan.dart:1-255](file://whoosh_ramah/lib/models/permintaan.dart#L1-L255)
- [permintaan_service.dart:1-228](file://whoosh_ramah/lib/services/permintaan_service.dart#L1-L228)

## Performance Considerations
- **Detection throttling:** The detector limits detection calls per second to reduce API/model load.
- **Anti-spam delay:** A configurable delay prevents duplicate tasks for the same detection event.
- **Consecutive frame requirement:** A wheelchair must be detected multiple times consecutively before creating a task.
- **Firestore query design:** The Flutter service avoids composite indexes by ordering only on one field and sorting locally where needed.
- **Real-time streams:** Streams are used efficiently for passive UI updates rather than polling.
- **Retry mechanism:** Exponential backoff prevents overwhelming the network during transient failures.

[No sources needed since this section provides general guidance]

## Troubleshooting Guide

### Missing Firebase Service Account Key
If the service account key file is missing, the detector exits early with a clear message. Ensure the Firebase service account JSON file exists at the configured path.

**Section sources**
- [detect_wheelchair.py:367-372](file://detector/detect_wheelchair.py#L367-L372)

### Network Failures During Detection
Detection failures are caught and logged without stopping the detector loop. The detector continues running and retries subsequent frames.

**Section sources**
- [detect_wheelchair.py:623-627](file://detector/detect_wheelchair.py#L623-L627)

### Retry Mechanisms
The implementation now includes robust retry logic with exponential backoff:

- **Configurable retry attempts:** Controlled by `PERCOBAAN_KIRIM` environment variable (default: 3).
- **Exponential backoff:** Each retry attempt waits longer than the previous one using `JEDA_COBA_LAGI_DETIK * percobaan`.
- **Graceful degradation:** Failed Firestore writes don't stop the detection loop.
- **Logging:** All retry attempts are logged with attempt numbers and error details.

Configuration parameters:
- `PERCOBAAN_KIRIM`: Number of retry attempts (default: 3)
- `JEDA_COBA_LAGI_DETIK`: Base delay between retries in seconds (default: 2.0)

**Updated** Enhanced retry mechanism with exponential backoff

### Monitoring Detection-to-Task Conversion Rates
To monitor conversion quality:

- Track the number of successful detections per camera.
- Track the number of Firestore documents created per camera.
- Compare `keyakinan` distribution across created tasks.
- Use `idKamera` and `dibuatPada` to compute hourly/daily conversion metrics.
- Monitor `jumlahTerdeteksi` to understand detection density.
- Alert when conversion drops below expected thresholds.

**Updated** Added monitoring for new tracking fields

### Security Rules Configuration
For demo purposes, the security rules allow unrestricted read and write access to the `permintaan_pendampingan` collection. This is explicitly marked as demo-only and should not be used in production.

**Section sources**
- [PROJECT.md:116-130](file://PROJECT.md#L116-L130)

## Conclusion
The Firebase integration connects the AI wheelchair detector with the Whoosh Ramah mobile application through Firestore. The Python `PengirimFirebase` class writes structured assistance requests with enhanced reliability through retry logic and exponential backoff, while the Flutter `Permintaan` model and `PermintaanService` provide type-safe, real-time access to those requests. The schema enforces consistent field naming, enum-based types, and a strict status workflow. New fields like `jumlahTerdeteksi` and `idLacak` provide enhanced tracking capabilities for better operational insights. For production readiness, add robust retry mechanisms, secure Firestore rules, and monitoring dashboards for detection-to-task conversion metrics.

**Updated** Enhanced with improved reliability and tracking capabilities

[No sources needed since this section summarizes without analyzing specific files]