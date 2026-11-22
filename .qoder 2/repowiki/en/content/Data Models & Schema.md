# Data Models & Schema

<cite>
**Referenced Files in This Document**
- [PROJECT.md](file://PROJECT.md)
- [permintaan.dart](file://whoosh_ramah/lib/models/permintaan.dart)
- [permintaan_service.dart](file://whoosh_ramah/lib/services/permintaan_service.dart)
- [dummy.dart](file://whoosh_ramah/lib/data/dummy.dart)
- [permintaan_test.dart](file://whoosh_ramah/test/permintaan_test.dart)
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
10. [Appendices](#appendices)

## Introduction
This document describes the data model and Firestore schema for the Whoosh Ramah system, focusing on the `permintaan_pendampingan` collection. It explains the field definitions, enum values, workflow transitions, null safety behavior for AI-detected tasks, audit history structure, serialization logic, query patterns, security considerations, privacy requirements, and retention guidance. The goal is to provide a single source of truth for developers, testers, and reviewers working with the data layer.

## Project Structure
The data model lives in the Flutter application under `lib/models`, while Firestore access is encapsulated in `lib/services`. Dummy passenger, ticket, and staff data used by the demo are defined in `lib/data`. The project specification defines the Firestore schema and rules.

```mermaid
graph TB
subgraph "Flutter App"
M["models/permintaan.dart"]
S["services/permintaan_service.dart"]
D["data/dummy.dart"]
end
subgraph "External Systems"
F["Cloud Firestore<br/>Collection: permintaan_pendampingan"]
PY["detector Python (YOLO)"]
end
PY --> |"writes"| F
S --> |"reads/writes"| F
M --> |"enum + model"| S
D --> |"demo data"| S
```

**Diagram sources**
- [permintaan.dart:1-214](file://whoosh_ramah/lib/models/permintaan.dart#L1-L214)
- [permintaan_service.dart:1-136](file://whoosh_ramah/lib/services/permintaan_service.dart#L1-L136)
- [dummy.dart:1-90](file://whoosh_ramah/lib/data/dummy.dart#L1-L90)
- [PROJECT.md:54-108](file://PROJECT.md#L54-L108)

**Section sources**
- [PROJECT.md:54-108](file://PROJECT.md#L54-L108)
- [permintaan.dart:1-214](file://whoosh_ramah/lib/models/permintaan.dart#L1-L214)
- [permintaan_service.dart:1-136](file://whoosh_ramah/lib/services/permintaan_service.dart#L1-L136)
- [dummy.dart:1-90](file://whoosh_ramah/lib/data/dummy.dart#L1-L90)

## Core Components
- Enum `JenisBantuan`: assistance types stored as strings in Firestore.
- Enum `StatusPermintaan`: workflow states with display labels and next-state transition helper.
- Model `Permintaan`: one Firestore document representing a companion request.
- Model `RiwayatStatus`: one audit trail entry per status change.
- Service `PermintaanService`: Firestore operations for creating, streaming, and advancing requests.

Key responsibilities:
- Enforce consistent enum values between UI, service, and detector.
- Provide null-safe parsing for documents created by the AI camera.
- Maintain an append-only `riwayat` array for auditability.
- Use server timestamps for creation and update times.

**Section sources**
- [permintaan.dart:7-57](file://whoosh_ramah/lib/models/permintaan.dart#L7-L57)
- [permintaan.dart:59-75](file://whoosh_ramah/lib/models/permintaan.dart#L59-L75)
- [permintaan.dart:77-213](file://whoosh_ramah/lib/models/permintaan.dart#L77-L213)
- [permintaan_service.dart:6-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L6-L119)

## Architecture Overview
The system has three main data actors:
- Passenger app: creates requests with full passenger/ticket context.
- Staff app: reads active requests and advances workflow state.
- Family app: observes the latest request for a specific passenger ID.
- Detector (Python): writes minimal AI-detected requests directly to Firestore.

```mermaid
sequenceDiagram
participant Det as "Detector (Python)"
participant FS as "Firestore"
participant Staff as "Staff App"
participant Pass as "Passenger App"
participant Fam as "Family App"
Det->>FS : write {jenisBantuan, titikJemput, sumber='kamera_ai', idKamera, keyakinan}
Staff->>FS : stream semua (orderBy dibuatPada desc, limit 100)
Pass->>FS : stream satu dokumen (id)
Fam->>FS : where idPenumpang = X (sort di aplikasi)
Staff->>FS : update status + riwayat + petugas
FS-->>Pass : real-time status update
FS-->>Fam : real-time status update
```

**Diagram sources**
- [permintaan_service.dart:63-90](file://whoosh_ramah/lib/services/permintaan_service.dart#L63-L90)
- [permintaan_service.dart:92-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L92-L119)
- [PROJECT.md:24-36](file://PROJECT.md#L24-L36)

## Detailed Component Analysis

### Firestore Collection: `permintaan_pendampingan`
Each document represents one companion request. Fields are strongly aligned with the model and tests.

| Field | Type | Required? | Default / Behavior | Notes |
|---|---|---:|---|---|
| `jenisBantuan` | string | Yes | One of enum values | Stored value must match detector and model. |
| `titikJemput` | string | Yes | Free text | Displayed location; may include station prefix. |
| `status` | string | Yes | One of enum values | Workflow state; transitions enforced by service. |
| `sumber` | string | Yes | `'aplikasi'` or `'kamera_ai'` | Indicates origin. |
| `namaPenumpang` | string \| null | No | Null for AI-detected docs | PII; only present when user submits via app. |
| `idPenumpang` | string \| null | No | Null for AI-detected docs | Used by family screen to filter latest request. |
| `kereta` | string \| null | No | Null for AI-detected docs | Train number from dummy ticket. |
| `jamBerangkat` | string \| null | No | Null for AI-detected docs | Departure time string. |
| `stasiunAsal` | string \| null | No | Null for AI-detected docs | Origin station. |
| `stasiunTujuan` | string \| null | No | Null for AI-detected docs | Destination station. |
| `gerbong` | string \| null | No | Null for AI-detected docs | Carriage number. |
| `kursi` | string \| null | No | Null for AI-detected docs | Seat identifier. |
| `catatan` | string \| null | No | Null if not provided | Optional notes. |
| `petugas` | string \| null | No | Set when advanced to `ditugaskan` | Staff name; demo uses fixed value. |
| `idKamera` | string \| null | No | Present for AI-detected docs | Camera identifier. |
| `keyakinan` | number \| null | No | Confidence score from detector | Range typically 0–1; displayed as percentage. |
| `riwayat` | array of maps | No | Empty list if missing | Append-only audit trail. |
| `dibuatPada` | Timestamp | Yes (server) | Server timestamp | Creation time. |
| `diperbaruiPada` | Timestamp | No (server) | Server timestamp on updates | Last update time. |

Validation rules:
- `jenisBantuan` must be one of the allowed enum values. Unknown values fall back to default in model parsing.
- `status` must be one of the allowed enum values. Unknown values fall back to default in model parsing.
- `sumber` must be either `'aplikasi'` or `'kamera_ai'`.
- `riwayat` entries must contain at least `status`; `waktu` is optional but recommended.
- For AI-detected documents, many fields are intentionally absent or null; all parsing must handle this safely.

**Section sources**
- [PROJECT.md:56-95](file://PROJECT.md#L56-L95)
- [permintaan.dart:77-213](file://whoosh_ramah/lib/models/permintaan.dart#L77-L213)
- [permintaan_test.dart:11-71](file://whoosh_ramah/test/permintaan_test.dart#L11-L71)

### Enum: `JenisBantuan` (Assistance Types)
Values stored in Firestore and their display labels:

| Enum member | Firestore value | Display label |
|---|---|---|
| `kursiRoda` | `kursi_roda` | Kursi roda |
| `tunanetra` | `tunanetra` | Tunanetra |
| `tuli` | `tuli` | Tuli |
| `lansia` | `lansia` | Lansia |
| `hamil` | `hamil` | Ibu hamil |
| `porter` | `porter` | Porter barang |

Behavior:
- Parsing unknown or null values falls back to `kursiRoda`.
- Values must remain identical to those written by the detector script.

**Section sources**
- [permintaan.dart:3-25](file://whoosh_ramah/lib/models/permintaan.dart#L3-L25)
- [PROJECT.md:82-83](file://PROJECT.md#L82-L83)

### Enum: `StatusPermintaan` (Workflow States)
Allowed states and their semantics:

| Enum member | Firestore value | Display label | Staff button label | Next state |
|---|---|---|---|---|
| `menunggu` | `menunggu` | Permintaan diterima | — | `ditugaskan` |
| `ditugaskan` | `ditugaskan` | Petugas ditugaskan | Terima tugas | `bertemu` |
| `bertemu` | `bertemu` | Bertemu petugas | Sudah bertemu penumpang | `di_kursi` |
| `diKursi` | `di_kursi` | Sudah duduk di kursi | Penumpang sudah di kursi | `selesai` |
| `selesai` | `selesai` | Diserahkan ke petugas tujuan | Serahkan ke petugas tujuan | null |

Transition rules:
- Transitions follow the declared order; there is no backward jump.
- When transitioning to `ditugaskan`, the service sets `petugas` to the demo staff name.
- Once `selesai`, further advancement is ignored.

**Section sources**
- [permintaan.dart:27-57](file://whoosh_ramah/lib/models/permintaan.dart#L27-L57)
- [PROJECT.md:85-93](file://PROJECT.md#L85-L93)
- [permintaan_service.dart:92-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L92-L119)

### Model: `Permintaan`
Responsibilities:
- Represent one Firestore document.
- Provide null-safe parsing for both app-created and AI-detected documents.
- Expose helpers such as `dariKamera`, `sudahSelesai`, `lokasiSingkat`, and `persenKeyakinan`.
- Serialize to/from Firestore maps using consistent field names.

Important behaviors:
- `dariKamera` is true when `sumber == 'kamera_ai'`.
- `lokasiSingkat` extracts the part after `" - "` in `titikJemput`, useful for AI-detected locations like `"Stasiun Halim - Pintu Masuk Utara"`.
- `persenKeyakinan` converts `keyakinan` to a percentage integer; returns null when not available.
- `riwayat` is parsed defensively; non-list or non-map entries are ignored.

**Section sources**
- [permintaan.dart:77-213](file://whoosh_ramah/lib/models/permintaan.dart#L77-L213)
- [permintaan_test.dart:11-71](file://whoosh_ramah/test/permintaan_test.dart#L11-L71)
- [permintaan_test.dart:73-126](file://whoosh_ramah/test/permintaan_test.dart#L73-L126)

### Model: `RiwayatStatus` (Audit Trail Entry)
Structure:
- `status`: string value of the status at that point.
- `waktu`: optional timestamp when the status changed.

Rules:
- Each status change appends a new entry to `riwayat`.
- The first entry is created when the request is made.
- Subsequent entries are appended atomically using array union.

**Section sources**
- [permintaan.dart:59-75](file://whoosh_ramah/lib/models/permintaan.dart#L59-L75)
- [permintaan_service.dart:49-58](file://whoosh_ramah/lib/services/permintaan_service.dart#L49-L58)
- [permintaan_service.dart:108-114](file://whoosh_ramah/lib/services/permintaan_service.dart#L108-L114)

### Service: `PermintaanService`
Operations:
- Create a new request with full passenger/ticket context from dummy data.
- Stream a single document by ID.
- Stream all requests ordered by creation time descending, limited to 100.
- Stream the latest request for a given passenger ID, sorting client-side.
- Advance the workflow state, updating status, timestamp, and appending to `riwayat`.

Query characteristics:
- Single-field ordering (`dibuatPada`) avoids composite index requirements.
- Filtering by `idPenumpang` without ordering avoids composite index requirements; sorting is done in the app.

**Section sources**
- [permintaan_service.dart:6-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L6-L119)

### Dummy Data
Used to populate demo requests and staff information:
- Passenger: name and ID.
- Ticket: train, stations, times, carriage, seat, class, and label.
- Staff: name, role, and station.
- Pickup points: predefined list of locations.

These values are copied into Firestore documents when a passenger submits a request.

**Section sources**
- [dummy.dart:1-90](file://whoosh_ramah/lib/data/dummy.dart#L1-L90)
- [permintaan_service.dart:23-61](file://whoosh_ramah/lib/services/permintaan_service.dart#L23-L61)

## Dependency Analysis
```mermaid
classDiagram
class JenisBantuan {
+value
+label
+dariValue(value)
}
class StatusPermintaan {
+value
+label
+tombolPetugas
+berikutnya
+dariValue(value)
}
class RiwayatStatus {
+status
+waktu
+fromMap(map)
+toFirestore()
}
class Permintaan {
+id
+jenisBantuan
+titikJemput
+status
+sumber
+namaPenumpang
+idPenumpang
+kereta
+jamBerangkat
+stasiunAsal
+stasiunTujuan
+gerbong
+kursi
+catatan
+petugas
+idKamera
+keyakinan
+riwayat
+dibuatPada
+diperbaruiPada
+dariKamera
+sudahSelesai
+lokasiSingkat
+persenKeyakinan
+fromFirestore(snap)
+fromMap(data, id)
+toFirestore()
}
class PermintaanService {
+buatPermintaan(...)
+streamPermintaan(id)
+streamSemua()
+streamTerbaruPenumpang(idPenumpang)
+majukanStatus(id)
}
Permintaan --> JenisBantuan : "uses"
Permintaan --> StatusPermintaan : "uses"
Permintaan --> RiwayatStatus : "contains"
PermintaanService --> Permintaan : "creates/streams/updates"
```

**Diagram sources**
- [permintaan.dart:7-213](file://whoosh_ramah/lib/models/permintaan.dart#L7-L213)
- [permintaan_service.dart:10-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L10-L119)

**Section sources**
- [permintaan.dart:7-213](file://whoosh_ramah/lib/models/permintaan.dart#L7-L213)
- [permintaan_service.dart:10-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L10-L119)

## Performance Considerations
- Ordering by a single field (`dibuatPada`) avoids composite indexes and keeps queries efficient.
- Limiting streams to 100 documents prevents unbounded growth in memory usage.
- Client-side sorting for passenger-specific streams avoids additional indexes; acceptable for small datasets typical of the demo.
- Using server timestamps ensures consistent ordering across devices.

[No sources needed since this section provides general guidance]

## Troubleshooting Guide
Common issues and resolutions:
- Unknown enum values: model parsing falls back to defaults (`kursiRoda` for assistance type, `menunggu` for status). Verify that detector and app use identical string values.
- Missing fields in AI-detected documents: ensure all code handles nulls for passenger/ticket fields and empty `riwayat`.
- Status not advancing: check that current status is not already `selesai` and that the next state exists.
- Sorting anomalies: when `dibuatPada` is not yet populated, client-side comparator treats it as older than populated timestamps.

Relevant validation and fallback logic:
- Enum fallbacks and next-state computation.
- Defensive parsing of `riwayat`.
- Null-safe construction from Firestore snapshots.

**Section sources**
- [permintaan.dart:20-24](file://whoosh_ramah/lib/models/permintaan.dart#L20-L24)
- [permintaan.dart:45-56](file://whoosh_ramah/lib/models/permintaan.dart#L45-L56)
- [permintaan.dart:182-189](file://whoosh_ramah/lib/models/permintaan.dart#L182-L189)
- [permintaan_service.dart:121-134](file://whoosh_ramah/lib/services/permintaan_service.dart#L121-L134)
- [permintaan_test.dart:128-148](file://whoosh_ramah/test/permintaan_test.dart#L128-L148)

## Conclusion
The Whoosh Ramah data model centers on a single Firestore collection with clear enums, null-safe parsing, and an append-only audit trail. The service layer enforces workflow transitions and maintains consistency between the passenger app, staff app, family app, and AI detector. By adhering to the documented field contracts, enum values, and query patterns, the system remains simple, testable, and suitable for hackathon demonstrations while providing a solid foundation for future production hardening.

[No sources needed since this section summarizes without analyzing specific files]

## Appendices

### A. Firestore Security Rules (Demo)
For demonstration purposes, read/write access to the collection is open. Do not deploy these rules in production.

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /permintaan_pendampingan/{doc} {
      allow read, write: if true;   // Demo only
    }
  }
}
```

**Section sources**
- [PROJECT.md:97-108](file://PROJECT.md#L97-L108)

### B. Privacy and Retention Guidance
Privacy:
- The detector does not send photos or faces; only assistance type, location, confidence, and timestamps are stored.
- Passenger names and ticket details are demo data and should be treated as sensitive in production.

Retention:
- The repository does not define explicit retention policies. Implement lifecycle rules to archive or delete completed requests after a defined period.
- Avoid retaining unnecessary PII beyond operational needs.

**Section sources**
- [PROJECT.md:245-249](file://PROJECT.md#L245-L249)

### C. Query Patterns Summary
- All active requests: order by `dibuatPada` descending, limit 100.
- Latest request per passenger: filter by `idPenumpang`, sort client-side by `dibuatPada`.
- Single request stream: listen to document by ID.

**Section sources**
- [permintaan_service.dart:63-90](file://whoosh_ramah/lib/services/permintaan_service.dart#L63-L90)

### D. Sample Data Structures
Below are conceptual examples of what appears in Firestore. These are not code snippets; they illustrate the shape of documents.

AI-detected request:
- `jenisBantuan`: one of enum values
- `titikJemput`: e.g., `"Stasiun Halim - Pintu Masuk Utara"`
- `status`: `"menunggu"`
- `sumber`: `"kamera_ai"`
- `idKamera`: camera identifier
- `keyakinan`: confidence score
- `namaPenumpang`: null
- `dibuatPada`: server timestamp
- Other fields: absent or null

App-submitted request:
- Includes all passenger and ticket fields
- `sumber`: `"aplikasi"`
- `riwayat`: initial entry with status and timestamp
- `dibuatPada` and `diperbaruiPada`: server timestamps

**Section sources**
- [permintaan_test.dart:11-71](file://whoosh_ramah/test/permintaan_test.dart#L11-L71)
- [permintaan_test.dart:73-126](file://whoosh_ramah/test/permintaan_test.dart#L73-L126)