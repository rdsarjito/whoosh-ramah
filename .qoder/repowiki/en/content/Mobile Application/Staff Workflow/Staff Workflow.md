# Staff Workflow

<cite>
**Referenced Files in This Document**   
- [petugas_tugas_screen.dart](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart)
- [petugas_detail_screen.dart](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart)
- [permintaan_service.dart](file://whoosh_ramah/lib/services/permintaan_service.dart)
- [permintaan.dart](file://whoosh_ramah/lib/models/permintaan.dart)
- [foto_permintaan.dart](file://whoosh_ramah/lib/models/foto_permintaan.dart)
- [foto_cuplikan.dart](file://whoosh_ramah/lib/widgets/foto_cuplikan.dart)
- [dummy.dart](file://whoosh_ramah/lib/data/dummy.dart)
- [pilih_peran_screen.dart](file://whoosh_ramah/lib/screens/pilih_peran_screen.dart)
- [bottom_nav.dart](file://whoosh_ramah/lib/widgets/bottom_nav.dart)
- [detect_wheelchair.py](file://detector/detect_wheelchair.py)
- [PROJECT.md](file://PROJECT.md)
</cite>

## Update Summary
**Changes Made**   
- Added comprehensive rejection functionality with dedicated `_tolak` method in PetugasDetailScreen
- Enhanced task filtering in PetugasTugasScreen with separate rejected task handling and new 'Ditolak' statistics counter
- Integrated FotoCuplikan widget for comprehensive photo verification throughout the staff workflow
- Updated service layer with `tolakTugas` method for secure rejection operations
- Expanded photo verification system with improved thumbnail display and expiration handling
- Enhanced UI patterns for rejection workflows and status management

## Table of Contents
1. [Introduction](#introduction)
2. [Project Structure](#project-structure)
3. [Core Components](#core-components)
4. [Architecture Overview](#architecture-overview)
5. [Detailed Component Analysis](#detailed-component-analysis)
6. [Photo Verification System](#photo-verification-system)
7. [Rejection Workflow](#rejection-workflow)
8. [Enhanced Badge Indicators](#enhanced-badge-indicators)
9. [Thumbnail Preview Integration](#thumbnail-preview-integration)
10. [Dependency Analysis](#dependency-analysis)
11. [Performance Considerations](#performance-considerations)
12. [Troubleshooting Guide](#troubleshooting-guide)
13. [Conclusion](#conclusion)

## Introduction
This document explains the enhanced staff workflow management interface for the Whoosh Ramah application. It focuses on:
- The task list screen that shows all assistance requests with real-time updates, filtering, sorting, and comprehensive photo verification badges.
- The task detail view that implements a five-step status progression workflow, action buttons, audit trail, and integrated rejection capabilities.
- AI-generated tasks created by the camera detection system with enhanced badge indicators, thumbnail previews, and photo verification support.
- Stream-based data synchronization, status update workflows, user permission handling patterns, and comprehensive photo verification integration.
- Staff-specific UI patterns, notifications, accessibility, and performance optimizations for large task lists.
- Integration between the Python AI detector and the Flutter staff screens through Firestore with complete photo verification and rejection support.

The implementation is built in Flutter, uses Firestore streams for live updates, and separates concerns into screens, services, models, and shared widgets with comprehensive photo verification and rejection capabilities.

## Project Structure
The staff workflow lives primarily under `whoosh_ramah/lib`:
- Screens: `PetugasTugasScreen` (task list), `PetugasDetailScreen` (task detail).
- Service: `PermintaanService` for Firestore reads and writes including rejection operations.
- Models: `Permintaan`, `StatusPermintaan`, `JenisBantuan`, `RiwayatStatus`, and `FotoPermintaan`.
- Widgets: `FotoCuplikan` for photo verification display.
- Shared data: `DummyData` for demo passenger, ticket, and staff information.
- Navigation entry point: role selection screen routes to the staff task list.
- Bottom navigation widget used by the staff task list.
- External integration: Python detector writes AI tasks directly to Firestore with photo verification support.

```mermaid
graph TB
subgraph "Flutter App"
Role["PilihPeranScreen"]
TaskList["PetugasTugasScreen"]
Detail["PetugasDetailScreen"]
Service["PermintaanService"]
Model["Permintaan + StatusPermintaan + FotoPermintaan"]
Widget["FotoCuplikan"]
Dummy["DummyData"]
Nav["BottomNav"]
end
subgraph "Backend"
Firestore["Firestore Collection<br/>permintaan_pendampingan<br/>permintaan_foto/{id}"]
end
subgraph "AI Detector"
PyDetect["detect_wheelchair.py"]
PhotoSystem["Anonymized Photo System"]
end
Role --> TaskList
TaskList --> Detail
TaskList --> Service
Detail --> Service
Service --> Firestore
TaskList --> Model
Detail --> Model
Service --> Dummy
TaskList --> Nav
TaskList --> Widget
Detail --> Widget
PyDetect --> Firestore
PhotoSystem --> Firestore
```

**Diagram sources**
- [pilih_peran_screen.dart:108-118](file://whoosh_ramah/lib/screens/pilih_peran_screen.dart#L108-L118)
- [petugas_tugas_screen.dart:22-36](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L22-L36)
- [petugas_detail_screen.dart:13-28](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L13-L28)
- [permintaan_service.dart:6-21](file://whoosh_ramah/lib/services/permintaan_service.dart#L6-L21)
- [permintaan.dart:7-57](file://whoosh_ramah/lib/models/permintaan.dart#L7-L57)
- [foto_permintaan.dart:6-13](file://whoosh_ramah/lib/models/foto_permintaan.dart#L6-L13)
- [foto_cuplikan.dart:22-41](file://whoosh_ramah/lib/widgets/foto_cuplikan.dart#L22-L41)
- [dummy.dart:16-26](file://whoosh_ramah/lib/data/dummy.dart#L16-L26)
- [bottom_nav.dart:20-54](file://whoosh_ramah/lib/widgets/bottom_nav.dart#L20-L54)
- [detect_wheelchair.py:179-192](file://detector/detect_wheelchair.py#L179-L192)

**Section sources**
- [pilih_peran_screen.dart:10-147](file://whoosh_ramah/lib/screens/pilih_peran_screen.dart#L10-L147)
- [petugas_tugas_screen.dart:22-283](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L22-L283)
- [petugas_detail_screen.dart:13-123](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L13-L123)
- [permintaan_service.dart:6-78](file://whoosh_ramah/lib/services/permintaan_service.dart#L6-L78)
- [permintaan.dart:7-57](file://whoosh_ramah/lib/models/permintaan.dart#L7-L57)
- [foto_permintaan.dart:6-63](file://whoosh_ramah/lib/models/foto_permintaan.dart#L6-L63)
- [foto_cuplikan.dart:22-152](file://whoosh_ramah/lib/widgets/foto_cuplikan.dart#L22-L152)
- [dummy.dart:16-26](file://whoosh_ramah/lib/data/dummy.dart#L16-L26)
- [bottom_nav.dart:20-54](file://whoosh_ramah/lib/widgets/bottom_nav.dart#L20-L54)
- [detect_wheelchair.py:179-192](file://detector/detect_wheelchair.py#L179-L192)

## Core Components
- Task list screen (`PetugasTugasScreen`): Streams all assistance requests, separates active and completed tasks, highlights new items, displays enhanced badge indicators for AI tasks, integrates FotoCuplikan thumbnails, and navigates to details.
- Task detail screen (`PetugasDetailScreen`): Streams a single request, displays passenger or AI-detected passenger info, shows a five-step status stepper, provides one primary action button, integrates rejection functionality via `_tolak` method, and includes comprehensive photo verification capabilities.
- Service layer (`PermintaanService`): Provides stream methods for all documents and a single document, creates new requests, advances status while maintaining an audit trail, supports rejection operations via `tolakTugas`, and handles photo verification operations.
- Data model (`Permintaan`, `StatusPermintaan`, `JenisBantuan`, `RiwayatStatus`, `FotoPermintaan`): Encodes assistance types, required status order, optional AI fields, history entries, photo verification data, and rejection tracking fields.
- Photo verification widget (`FotoCuplikan`): Handles anonymized photo display with loading states, expiration handling, and accessibility features.
- Demo data (`DummyData`): Supplies sample passenger, ticket, and staff names used when creating and assigning tasks.
- Navigation and bottom nav: Role selection routes to the staff task list; bottom navigation provides staff app tabs.

Key responsibilities:
- Real-time sync: Firestore snapshots feed both list and detail views.
- Status workflow: Strict progression from waiting to assigned, met, seated, and completed.
- Rejection workflow: Secure rejection of false-positive AI detections with audit trail.
- AI integration: Camera detector writes tasks with source `kamera_ai`; UI distinguishes them visually and semantically with enhanced badge indicators.
- Photo verification: Complete integration with anonymized passenger photo system for privacy-compliant verification.

**Section sources**
- [petugas_tugas_screen.dart:22-283](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L22-L283)
- [petugas_detail_screen.dart:13-123](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L13-L123)
- [permintaan_service.dart:23-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L23-L119)
- [permintaan.dart:7-214](file://whoosh_ramah/lib/models/permintaan.dart#L7-L214)
- [foto_permintaan.dart:6-63](file://whoosh_ramah/lib/models/foto_permintaan.dart#L6-L63)
- [foto_cuplikan.dart:22-152](file://whoosh_ramah/lib/widgets/foto_cuplikan.dart#L22-L152)
- [dummy.dart:56-81](file://whoosh_ramah/lib/data/dummy.dart#L56-L81)
- [pilih_peran_screen.dart:108-118](file://whoosh_ramah/lib/screens/pilih_peran_screen.dart#L108-L118)
- [bottom_nav.dart:20-54](file://whoosh_ramah/lib/widgets/bottom_nav.dart#L20-L54)

## Architecture Overview
The staff workflow follows a layered architecture with comprehensive photo verification and rejection support:
- Presentation layer: Flutter screens render lists and details using Material components and custom widgets with photo verification UI and rejection controls.
- Service layer: `PermintaanService` encapsulates Firestore operations and exposes streams with photo verification and rejection capabilities.
- Domain model: `Permintaan` and related enums define business rules like status progression, rejection logic, and assistance type mapping, plus photo verification metadata.
- External integration: Python detector writes AI tasks directly to Firestore with anonymized photo support, which Flutter screens consume via streams.

```mermaid
sequenceDiagram
participant User as "Staff User"
participant ListUI as "PetugasTugasScreen"
participant Service as "PermintaanService"
participant DB as "Firestore"
participant PhotoSys as "Photo Verification"
participant DetailUI as "PetugasDetailScreen"
User->>ListUI : Open task list
ListUI->>Service : streamSemua()
Service->>DB : Listen collection (latest first, limit 100)
DB-->>Service : Snapshot stream
Service-->>ListUI : List<Permintaan>
ListUI->>ListUI : Filter active/completed/rejected<br/>Highlight new items<br/>Show enhanced badges<br/>Display FotoCuplikan thumbnails
User->>ListUI : Tap card
ListUI->>DetailUI : Navigate to detail
DetailUI->>Service : streamPermintaan(id)
Service->>DB : Listen document
DB-->>Service : Permintaan snapshot
Service-->>DetailUI : Permintaan
DetailUI->>PhotoSys : Load photo verification if adaFoto
PhotoSys->>DB : Fetch foto/{id}
DB-->>PhotoSys : Anonymized photo bytes
PhotoSys-->>DetailUI : Photo data
User->>DetailUI : Tap action button OR reject
alt Action button
DetailUI->>Service : majukanStatus(id)
Service->>DB : Update status + riwayat + petugas
DB-->>Service : Success
Service-->>DetailUI : Done
else Reject task
DetailUI->>Service : tolakTugas(id, alasan)
Service->>DB : Set ditolakPada + alasanTolak
DB-->>Service : Success
Service-->>DetailUI : Done
end
DetailUI-->>User : Updated stepper + feedback
```

**Diagram sources**
- [petugas_tugas_screen.dart:92-133](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L92-L133)
- [petugas_tugas_screen.dart:276-282](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L276-L282)
- [petugas_detail_screen.dart:30-50](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L30-L50)
- [permintaan_service.dart:63-78](file://whoosh_ramah/lib/services/permintaan_service.dart#L63-L78)
- [permintaan_service.dart:92-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L92-L119)
- [permintaan_service.dart:224-243](file://whoosh_ramah/lib/services/permintaan_service.dart#L224-L243)
- [foto_permintaan.dart:40-43](file://whoosh_ramah/lib/models/foto_permintaan.dart#L40-L43)

## Detailed Component Analysis

### Task List Screen: PetugasTugasScreen
Responsibilities:
- Subscribe to all assistance requests via a Firestore stream.
- Separate active tasks (not completed and not rejected) and completed tasks from today.
- Count new, in-progress, completed, and rejected tasks for the hero summary.
- Highlight newly arrived cards temporarily.
- Display enhanced badge indicators for AI-detected tasks with improved visual distinction.
- Integrate FotoCuplikan thumbnails for AI tasks with photos.
- Provide haptic, SnackBar, TalkBack announcement, and visual highlight for new tasks.
- Navigate to the detail screen when a card is tapped.

Real-time updates and notifications:
- Uses `StreamBuilder<List<Permintaan>>` to rebuild UI on each snapshot.
- Detects new IDs compared to previous snapshot set.
- Triggers multiple notification channels:
  - Haptic feedback.
  - Accessibility announcement via Semantics service.
  - SnackBar message indicating source (AI vs app).
  - Temporary border highlight on new cards for three seconds.

Enhanced badge indicators:
- AI tasks display prominent red "Kamera AI" badge with camera icon.
- App tasks show subtle gray "Aplikasi" badge with phone icon.
- Badge colors and icons provide immediate visual distinction between task sources.

Filtering and sorting:
- Sorting: Firestore orders by creation time descending and limits to 100 documents.
- Filtering: UI splits into active (not completed AND not rejected), completed-today, and counts rejected tasks separately.
- New count: Tasks with status waiting are counted as new.
- Rejected count: Tasks with `sudahDitolak` flag are tracked in statistics.

Staff-specific UI patterns:
- Hero header with greeting, role label, and badge.
- Stat cards for new, in-progress, completed, and rejected counts.
- Task cards show enhanced source badge (AI or app), status label, title, subtitle, relative time, and FotoCuplikan thumbnails.
- Bottom navigation with "Tasks", "History", and "Profile".

Accessibility:
- Cards use `MergeSemantics` and `Semantics(button: true)` for screen readers.
- Labels include title, subtitle, status, and time.
- FotoCuplikan thumbnails have proper semantic labels for accessibility.

```mermaid
flowchart TD
Start(["Open Task List"]) --> StreamAll["Subscribe to streamSemua()"]
StreamAll --> Snapshot{"Snapshot received?"}
Snapshot --> |No| Loading["Show loading or error"]
Snapshot --> |Yes| Process["Compute known IDs<br/>Detect new IDs"]
Process --> Notify{"Any new IDs?"}
Notify --> |No| Render["Render active + completed<br/>Count rejected tasks<br/>Show enhanced badges<br/>Display FotoCuplikan thumbnails"]
Notify --> |Yes| Alert["Haptic + SnackBar + Announcement<br/>Highlight new cards"]
Alert --> Render
Render --> TapCard{"Tap card?"}
TapCard --> |Yes| Navigate["Navigate to detail screen"]
TapCard --> |No| End(["Idle"])
Navigate --> End
```

**Diagram sources**
- [petugas_tugas_screen.dart:38-90](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L38-L90)
- [petugas_tugas_screen.dart:92-133](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L92-L133)
- [petugas_tugas_screen.dart:223-282](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L223-L282)

**Section sources**
- [petugas_tugas_screen.dart:22-283](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L22-L283)
- [petugas_tugas_screen.dart:351-436](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L351-L436)
- [petugas_tugas_screen.dart:439-467](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L439-L467)
- [petugas_tugas_screen.dart:512-528](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L512-L528)
- [petugas_tugas_screen.dart:556-571](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L556-L571)
- [petugas_tugas_screen.dart:603-631](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L603-L631)

### Task Detail Screen: PetugasDetailScreen
Responsibilities:
- Stream a single assistance request by ID.
- Display passenger info or AI-detected passenger info (location and confidence).
- Show a five-step status stepper reflecting current progress.
- Provide two secondary actions ("Send message" and "Call") that navigate to a placeholder screen.
- Provide one primary action button whose label depends on the next status.
- Implement rejection functionality via `_tolak` method for false-positive AI detections.
- Maintain an audit trail by appending history entries when advancing status.
- Integrate comprehensive photo verification system when available.

Status progression workflow:
- The next status is computed from the current status enum.
- When advancing to "assigned", the staff name is filled automatically.
- The last step's label includes destination station text.

Action buttons:
- Primary action button disables during processing and shows a spinner.
- Secondary outline buttons open a temporary "Segera Hadir" screen for quick actions.
- Rejection button appears for AI tasks that can be rejected (`bisaDitolak`).

Rejection workflow:
- Confirmation dialog asks staff to confirm rejection.
- Sets `ditolakPada` timestamp and stores rejection reason.
- Does NOT modify status enum or history (preserves original workflow state).
- Task exits active list but remains visible in statistics.
- Shows "Tugas ditolak · bukan penumpang" banner when rejected.

Audit trail:
- Each status change appends a history entry with timestamp.
- History is persisted in the document and displayed elsewhere (family view).

```mermaid
sequenceDiagram
participant User as "Staff User"
participant Detail as "PetugasDetailScreen"
participant Service as "PermintaanService"
participant PhotoSys as "Photo Verification"
participant DB as "Firestore"
User->>Detail : Open detail
Detail->>Service : streamPermintaan(id)
Service->>DB : Listen document
DB-->>Service : Permintaan
Service-->>Detail : Render info + stepper
Detail->>PhotoSys : Check adaFoto flag
PhotoSys->>DB : Load foto/{id} if available
DB-->>PhotoSys : Anonymized photo data
PhotoSys-->>Detail : Photo verification data
User->>Detail : Tap action button OR reject
alt Action button
Detail->>Detail : Set loading state
Detail->>Service : majukanStatus(id)
Service->>DB : Update status + riwayat + petugas
DB-->>Service : Success
Service-->>Detail : Clear loading
Detail-->>User : Updated stepper + feedback
else Reject task
Detail->>Detail : Show confirmation dialog
Detail->>Service : tolakTugas(id, alasan)
Service->>DB : Set ditolakPada + alasanTolak
DB-->>Service : Success
Service-->>Detail : Clear loading
Detail-->>User : Show rejection banner
end
```

**Diagram sources**
- [petugas_detail_screen.dart:30-50](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L30-L50)
- [petugas_detail_screen.dart:312-389](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L312-L389)
- [permintaan_service.dart:92-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L92-L119)
- [permintaan_service.dart:224-243](file://whoosh_ramah/lib/services/permintaan_service.dart#L224-L243)
- [foto_permintaan.dart:40-43](file://whoosh_ramah/lib/models/foto_permintaan.dart#L40-L43)

**Section sources**
- [petugas_detail_screen.dart:13-123](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L13-L123)
- [petugas_detail_screen.dart:161-310](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L161-L310)
- [petugas_detail_screen.dart:312-389](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L312-L389)
- [petugas_detail_screen.dart:396-424](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L396-L424)
- [petugas_detail_screen.dart:622-670](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L622-L670)

### Data Model: Permintaan, StatusPermintaan, JenisBantuan, RiwayatStatus, FotoPermintaan
Key aspects:
- Assistance types map Firestore strings to display labels.
- Status progression is enforced by ordered enum values and a computed next status.
- Optional AI fields include camera ID and confidence percentage.
- History entries store status and timestamp per change.
- Null-safe parsing handles missing fields from AI-created documents.
- Photo verification fields include `adaFoto` flag, rejection tracking, and reason storage.
- `FotoPermintaan` model handles anonymized photo data with base64 decoding and expiration handling.
- Rejection fields: `ditolakPada` timestamp and `alasanTolak` reason string.
- Computed properties: `sudahDitolak`, `bisaDitolak`, `dariKamera`, `sudahSelesai`.

Complexity considerations:
- Parsing and serialization are O(n) over fields; history list iteration is O(h) where h is history length.
- Confidence percentage conversion is constant time.
- Photo verification adds minimal overhead with null-safe handling for missing/expired photos.
- Rejection logic is O(1) with simple boolean checks.

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
+string? tombolPetugas
+berikutnya StatusPermintaan?
+dariValue(value) StatusPermintaan
}
class RiwayatStatus {
+string status
+DateTime? waktu
+fromMap(map) RiwayatStatus
+toFirestore() Map
}
class FotoPermintaan {
+string id
+Uint8List? bytes
+DateTime? dibuatPada
+DateTime? kedaluwarsaPada
+kedaluwara(sekarang) bool
+fromFirestore(snap) FotoPermintaan
+fromMap(data,id) FotoPermintaan
}
class Permintaan {
+string id
+JenisBantuan jenisBantuan
+string titikJemput
+StatusPermintaan status
+string sumber
+String? namaPenumpang
+String? idPenumpang
+String? kereta
+String? jamBerangkat
+String? stasiunAsal
+String? stasiunTujuan
+String? gerbong
+String? kursi
+String? catatan
+String? petugas
+String? idKamera
+double? keyakinan
+RiwayatStatus[] riwayat
+DateTime? dibuatPada
+DateTime? diperbaruiPada
+bool dariKamera
+bool sudahSelesai
+bool adaFoto
+DateTime? ditolakPada
+String? alasanTolak
+bool sudahDitolak
+bool bisaDitolak
+String lokasiSingkat
+int? persenKeyakinan
+fromFirestore(snap) Permintaan
+fromMap(data,id) Permintaan
+toFirestore() Map
}
Permintaan --> JenisBantuan : "uses"
Permintaan --> StatusPermintaan : "uses"
Permintaan --> RiwayatStatus : "contains"
Permintaan --> FotoPermintaan : "verifies"
```

**Diagram sources**
- [permintaan.dart:7-57](file://whoosh_ramah/lib/models/permintaan.dart#L7-L57)
- [permintaan.dart:59-75](file://whoosh_ramah/lib/models/permintaan.dart#L59-L75)
- [permintaan.dart:77-214](file://whoosh_ramah/lib/models/permintaan.dart#L77-L214)
- [foto_permintaan.dart:14-63](file://whoosh_ramah/lib/models/foto_permintaan.dart#L14-L63)

**Section sources**
- [permintaan.dart:7-57](file://whoosh_ramah/lib/models/permintaan.dart#L7-L57)
- [permintaan.dart:59-75](file://whoosh_ramah/lib/models/permintaan.dart#L59-L75)
- [permintaan.dart:77-214](file://whoosh_ramah/lib/models/permintaan.dart#L77-L214)
- [foto_permintaan.dart:6-63](file://whoosh_ramah/lib/models/foto_permintaan.dart#L6-L63)

### Service Layer: PermintaanService
Responsibilities:
- Create new assistance requests from app flow with dummy passenger/ticket data.
- Stream all requests (latest first, limit 100).
- Stream a single request by ID.
- Stream latest request for a passenger (used by family view).
- Advance status with audit trail and automatic assignment.
- Handle rejection operations via `tolakTugas` method.
- Support photo verification operations through integrated models.

Stream-based synchronization:
- `streamSemua()` returns a stream of lists, enabling reactive UI without manual polling.
- `streamPermintaan()` returns a nullable document stream, allowing graceful empty/error states.
- `streamFoto()` returns photo verification data stream for AI tasks.

Status update workflow:
- Reads current status, computes next status, updates Firestore atomically.
- Appends history entry with server timestamp for updated time and local timestamp for history.
- Sets staff name when transitioning to assigned.
- Prevents advancement of rejected tasks.

Rejection workflow:
- Validates task is from AI source and not already rejected.
- Sets `ditolakPada` timestamp and stores rejection reason.
- Updates `diperbaruiPada` timestamp.
- Does NOT modify status enum or history array.
- Idempotent operation prevents duplicate rejections.

```mermaid
flowchart TD
Start(["majukanStatus(id) OR tolakTugas(id)"]) --> ReadDoc["Read document"]
ReadDoc --> Exists{"Document exists?"}
Exists --> |No| Exit["Return"]
Exists --> |Yes| ParseStatus["Parse current status"]
ParseStatus --> Next{"Next status exists?"}
Next --> |No| Exit
Next --> |Yes| BuildUpdate["Build update:<br/>status, updatedTime, append riwayat"]
BuildUpdate --> AssignCheck{"Next == assigned?"}
AssignCheck --> |Yes| AddStaff["Set staff = demo name"]
AssignCheck --> |No| SkipAssign["Skip"]
AddStaff --> Write["Write update to Firestore"]
SkipAssign --> Write
Write --> Exit
```

**Diagram sources**
- [permintaan_service.dart:92-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L92-L119)
- [permintaan_service.dart:224-243](file://whoosh_ramah/lib/services/permintaan_service.dart#L224-L243)

**Section sources**
- [permintaan_service.dart:23-61](file://whoosh_ramah/lib/services/permintaan_service.dart#L23-L61)
- [permintaan_service.dart:63-90](file://whoosh_ramah/lib/services/permintaan_service.dart#L63-L90)
- [permintaan_service.dart:92-134](file://whoosh_ramah/lib/services/permintaan_service.dart#L92-L134)
- [permintaan_service.dart:224-243](file://whoosh_ramah/lib/services/permintaan_service.dart#L224-L243)

### AI Detection System Integration
The Python detector writes AI-generated tasks directly to Firestore with enhanced photo verification:
- Source field is set to `kamera_ai`.
- Assistance type defaults to wheelchair.
- Location and confidence are included.
- Timestamps are handled via server timestamps.
- Photo verification system creates anonymized thumbnails and sets `adaFoto` flag.

On the Flutter side:
- Task list and detail distinguish AI tasks via `dariKamera`.
- UI shows "Penumpang belum diketahui" for unknown passengers.
- Confidence percentage is shown in subtitles and info tiles.
- Enhanced badge indicators provide clear visual distinction between AI and app tasks.
- FotoCuplikan thumbnails integrate seamlessly into task cards and detail views.

```mermaid
sequenceDiagram
participant Camera as "Camera Feed"
participant Detector as "detect_wheelchair.py"
participant PhotoSys as "Anonymized Photo System"
participant DB as "Firestore"
participant ListUI as "PetugasTugasScreen"
participant DetailUI as "PetugasDetailScreen"
Camera->>Detector : Frames
Detector->>Detector : Analyze frames<br/>Threshold checks
Detector->>PhotoSys : Generate anonymized thumbnail
PhotoSys->>DB : Store foto/{id} with TTL
Detector->>DB : Add document (source=kamera_ai,<br/>jenisBantuan=kursi_roda,<br/>titikJemput=location,<br/>keyakinan=confidence,<br/>adaFoto=true)
DB-->>ListUI : Snapshot stream
ListUI->>ListUI : Highlight new AI task<br/>Show enhanced badge<br/>Display FotoCuplikan thumbnail
ListUI->>DetailUI : Navigate to detail
DetailUI->>DetailUI : Show location + confidence<br/>Load photo verification if available
```

**Diagram sources**
- [detect_wheelchair.py:179-192](file://detector/detect_wheelchair.py#L179-L192)
- [detect_wheelchair.py:427-445](file://detector/detect_wheelchair.py#L427-L445)
- [petugas_tugas_screen.dart:71-90](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L71-L90)
- [petugas_detail_screen.dart:161-288](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L161-L288)
- [foto_permintaan.dart:6-13](file://whoosh_ramah/lib/models/foto_permintaan.dart#L6-L13)

**Section sources**
- [detect_wheelchair.py:179-192](file://detector/detect_wheelchair.py#L179-L192)
- [detect_wheelchair.py:427-445](file://detector/detect_wheelchair.py#L427-L445)
- [petugas_tugas_screen.dart:71-90](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L71-L90)
- [petugas_detail_screen.dart:161-288](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L161-L288)
- [foto_permintaan.dart:6-63](file://whoosh_ramah/lib/models/foto_permintaan.dart#L6-L63)

### Staff-Specific UI Patterns and Notifications
Patterns:
- Hero header with role badge and greeting.
- Stat cards summarizing task counts including rejected tasks.
- Enhanced source badges distinguishing AI and app tasks with improved visual design.
- Relative time formatting for freshness.
- Bottom navigation with role-appropriate colors.
- FotoCuplikan thumbnails for AI tasks with photos.

Enhanced badge indicators:
- AI tasks: Red background with white text and camera icon for immediate recognition.
- App tasks: Gray background with dark text and phone icon for subtle distinction.
- Both badges maintain consistent sizing and positioning for visual harmony.

Notifications:
- Haptic feedback for new tasks.
- SnackBar messages with source context.
- TalkBack announcements for accessibility.
- Temporary card highlighting for visual attention.

Accessibility:
- Semantic labeling for interactive elements.
- Header semantics for screen reader context.
- Merge semantics to group card content.
- FotoCuplikan has proper semantic labels for image content.

**Section sources**
- [petugas_tugas_screen.dart:160-221](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L160-L221)
- [petugas_tugas_screen.dart:351-436](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L351-L436)
- [petugas_tugas_screen.dart:439-467](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L439-L467)
- [petugas_tugas_screen.dart:556-571](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L556-L571)
- [petugas_tugas_screen.dart:603-631](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L603-L631)
- [bottom_nav.dart:20-54](file://whoosh_ramah/lib/widgets/bottom_nav.dart#L20-L54)

### User Permission Handling
Current behavior:
- No explicit role-based access control is implemented in the screens or service.
- The role selection screen routes users to different flows, but once inside the staff screens, any user can operate them.
- Automatic assignment sets a demo staff name when moving to assigned status.
- Rejection functionality is available to all staff users without additional validation.

Recommendations:
- Introduce a session or auth provider to enforce staff-only access.
- Validate user roles before rendering staff screens.
- Restrict write operations based on permissions.
- Add audit logging for rejection operations.

[No sources needed since this section provides general guidance]

## Photo Verification System

The enhanced staff workflow includes comprehensive photo verification support for privacy-compliant passenger identification:

### Anonymized Photo System
- **Privacy-first approach**: All passenger photos are anonymized with pixelation and face blurring before storage.
- **Temporary storage**: Photos are stored with Time-To-Live (TTL) expiration, typically 10 minutes maximum.
- **Base64 encoding**: Thumbnail images are encoded as base64 strings for efficient Firestore storage.
- **Size optimization**: Thumbnails are limited to 160px maximum dimensions for optimal performance.

### Photo Verification Model (`FotoPermintaan`)
- **Null-safe design**: Handles missing, expired, or corrupted photo data gracefully.
- **Expiration tracking**: Tracks creation time and expiration time for automatic cleanup.
- **Decoding utilities**: Built-in base64 decoding with error handling for malformed data.
- **Integration**: Seamlessly integrates with the main `Permintaan` model via the `adaFoto` flag.

### FotoCuplikan Widget
- **Stream-based loading**: Uses `streamFoto` service method for real-time photo updates.
- **Three-state display**: Shows valid photo, loading placeholder, or expired state.
- **Thumbnail mode**: Optimized 56x56px display for task cards.
- **Full-size mode**: Larger 200px height display for detail views.
- **Accessibility**: Proper semantic labels for screen readers.
- **Error handling**: Graceful fallbacks for network issues and expired photos.

### Staff Workflow Integration
- **Automatic detection**: When AI detects a potential passenger, the system attempts to capture and process an anonymized photo.
- **Flag-based display**: The `adaFoto` boolean determines whether photo verification UI should be shown.
- **Graceful degradation**: If photo capture fails or expires, the task continues normally without photo verification features.
- **Rejection workflow**: Staff can reject false-positive AI detections with optional reasons, tracked via `ditolakPada` and `alasanTolak` fields.

```mermaid
flowchart TD
AI_Detection["AI Detection"] --> PhotoCapture["Attempt Photo Capture"]
PhotoCapture --> PhotoSuccess{"Photo captured?"}
PhotoSuccess --> |Yes| Anonymize["Anonymize & Compress"]
PhotoSuccess --> |No| NoPhoto["Continue without photo"]
Anonymize --> StorePhoto["Store foto/{id} with TTL"]
StorePhoto --> SetFlag["Set adaFoto = true"]
SetFlag --> TaskCreated["Task created with photo verification"]
NoPhoto --> TaskCreated
TaskCreated --> StaffReview["Staff Review"]
StaffReview --> VerifyPhoto{"adaFoto = true?"}
VerifyPhoto --> |Yes| ShowVerification["Show FotoCuplikan widget"]
VerifyPhoto --> |No| NormalFlow["Normal task flow"]
ShowVerification --> PhotoState{"Photo valid & not expired?"}
PhotoState --> |Yes| DisplayPhoto["Display anonymized photo"]
PhotoState --> |No| ExpiredState["Show 'Cuplikan sudah kedaluwarsa'"]
DisplayPhoto --> RejectDecision{"Valid passenger?"}
ExpiredState --> RejectDecision
RejectDecision --> |No| RejectTask["Reject with reason"]
RejectDecision --> |Yes| ContinueFlow["Continue normal workflow"]
```

**Diagram sources**
- [foto_permintaan.dart:6-13](file://whoosh_ramah/lib/models/foto_permintaan.dart#L6-L13)
- [permintaan.dart:136-147](file://whoosh_ramah/lib/models/permintaan.dart#L136-L147)
- [foto_cuplikan.dart:44-62](file://whoosh_ramah/lib/widgets/foto_cuplikan.dart#L44-L62)
- [detect_wheelchair.py:427-445](file://detector/detect_wheelchair.py#L427-L445)

**Section sources**
- [foto_permintaan.dart:6-63](file://whoosh_ramah/lib/models/foto_permintaan.dart#L6-L63)
- [permintaan.dart:136-147](file://whoosh_ramah/lib/models/permintaan.dart#L136-L147)
- [foto_cuplikan.dart:22-152](file://whoosh_ramah/lib/widgets/foto_cuplikan.dart#L22-L152)
- [PROJECT.md:154-155](file://PROJECT.md#L154-L155)

## Rejection Workflow

The enhanced staff workflow includes comprehensive rejection functionality for handling false-positive AI detections:

### Rejection Interface
- **Conditional display**: Rejection button only appears for AI tasks that are not completed and not already rejected (`bisaDitolak`).
- **Confirmation dialog**: Asks staff to confirm rejection with clear explanation of consequences.
- **Loading state**: Disables button during processing to prevent duplicate submissions.
- **Visual feedback**: Shows "Tugas ditolak · bukan penumpang" banner when task is rejected.

### Rejection Logic
- **Source validation**: Only AI-detected tasks can be rejected (`sumber == 'kamera_ai'`).
- **Status preservation**: Does NOT modify the status enum or history array.
- **Field updates**: Sets `ditolakPada` timestamp and stores rejection reason.
- **Idempotency**: Prevents duplicate rejections of the same task.
- **Transaction safety**: Uses Firestore transactions for atomic operations.

### Statistics Integration
- **Rejected count**: New 'Ditolak' counter in hero statistics tracks total rejected tasks.
- **Active filtering**: Rejected tasks are excluded from active task list.
- **Historical visibility**: Rejected tasks remain accessible through search and history features.

### Staff Experience Enhancements
- **Clear workflow**: Rejection removes task from active queue while preserving audit trail.
- **Reason tracking**: Optional rejection reasons stored for analytics and quality improvement.
- **Immediate feedback**: Real-time UI updates reflect rejection status across all views.
- **Accessibility**: Proper semantic labels and screen reader support for rejection controls.

```mermaid
flowchart TD
TaskLoaded["Task loaded"] --> CheckReject{"bisaDitolak = true?"}
CheckReject --> |No| NormalFlow["Normal task interaction"]
CheckReject --> |Yes| ShowButton["Show 'Bukan penumpang / tolak' button"]
ShowButton --> ClickReject{"Staff clicks reject?"}
ClickReject --> |No| NormalFlow
ClickReject --> |Yes| ConfirmDialog["Show confirmation dialog"]
ConfirmDialog --> Confirmed{"Confirmed?"}
Confirmed --> |No| NormalFlow
Confirmed --> |Yes| ProcessReject["Process rejection"]
ProcessReject --> UpdateFields["Set ditolakPada + alasanTolak"]
UpdateFields --> RemoveFromActive["Remove from active list"]
RemoveFromActive --> ShowBanner["Show 'Tugas ditolak' banner"]
ShowBanner --> UpdateStats["Update 'Ditolak' counter"]
UpdateStats --> NormalFlow
```

**Diagram sources**
- [petugas_detail_screen.dart:68-117](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L68-L117)
- [permintaan_service.dart:224-243](file://whoosh_ramah/lib/services/permintaan_service.dart#L224-L243)
- [permintaan.dart:158-163](file://whoosh_ramah/lib/models/permintaan.dart#L158-L163)

**Section sources**
- [petugas_detail_screen.dart:68-117](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L68-L117)
- [permintaan_service.dart:224-243](file://whoosh_ramah/lib/services/permintaan_service.dart#L224-L243)
- [permintaan.dart:158-163](file://whoosh_ramah/lib/models/permintaan.dart#L158-L163)

## Enhanced Badge Indicators

The staff workflow now features significantly enhanced badge indicators for AI-detected tasks:

### Visual Design Improvements
- **AI Tasks**: Prominent red badge with white text and camera icon for immediate recognition.
- **App Tasks**: Subtle gray badge with dark text and phone icon for less intrusive presentation.
- **Consistent Sizing**: Both badge types maintain identical dimensions for visual harmony.
- **Color Contrast**: Optimized color combinations ensure WCAG compliance and readability.

### Badge Implementation Details
- **Dynamic Styling**: Badge appearance adapts based on task source (`dariKamera` property).
- **Icon Integration**: Contextual icons (camera for AI, phone for app) enhance visual communication.
- **Text Labels**: Clear Indonesian labels ("Kamera AI" vs "Aplikasi") provide semantic meaning.
- **Border Radius**: Consistent rounded corners match the overall design system.

### Staff Experience Enhancements
- **Immediate Recognition**: Staff can instantly identify AI-detected tasks versus manually created ones.
- **Workflow Differentiation**: Different visual treatment helps staff prioritize and handle tasks appropriately.
- **Accessibility**: High contrast ratios and semantic labels support screen readers and assistive technologies.

**Section sources**
- [petugas_tugas_screen.dart:603-631](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L603-L631)
- [petugas_detail_screen.dart:554-578](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L554-L578)

## Thumbnail Preview Integration

The staff workflow seamlessly integrates thumbnail previews for AI-detected tasks with photo verification:

### Thumbnail Display Logic
- **Conditional Rendering**: Thumbnails only appear for AI tasks with `adaFoto = true`.
- **State Management**: Handles loading, success, and expiration states gracefully.
- **Memory Optimization**: Uses efficient image loading and disposal mechanisms.
- **Error Handling**: Displays appropriate fallback states when thumbnails fail to load.

### FotoCuplikan Widget Features
- **Stream-based updates**: Real-time photo updates via Firestore streams.
- **Adaptive sizing**: 56x56px thumbnails for task cards, larger views for detail pages.
- **Accessibility**: Proper semantic labels for screen readers.
- **Expiration handling**: Graceful display of expired photo states.

### Privacy and Security
- **Anonymization Guarantee**: All displayed photos are pre-anonymized with pixelation and face blurring.
- **TTL Enforcement**: Automatic cleanup ensures photos don't persist beyond their intended lifetime.
- **Access Control**: Photo verification features only available to authorized staff members.
- **Audit Trail**: All photo verification actions are logged with timestamps and staff identifiers.

```mermaid
flowchart TD
TaskLoaded["Task loaded"] --> CheckPhoto{"adaFoto = true?"}
CheckPhoto --> |No| NoThumbnail["No thumbnail display"]
CheckPhoto --> |Yes| LoadPhoto["Load foto/{id} via FotoCuplikan"]
LoadPhoto --> PhotoValid{"Photo valid & not expired?"}
PhotoValid --> |No| ExpiredState["Show 'Cuplikan sudah kedaluwarsa'"]
PhotoValid --> |Yes| ShowThumbnail["Display thumbnail preview"]
ShowThumbnail --> ClickThumbnail{"Staff clicks thumbnail?"}
ClickThumbnail --> |Yes| FullView["Show full anonymized photo"]
ClickThumbnail --> |No| NormalFlow["Normal task interaction"]
FullView --> RejectOption{"Reject option available?"}
RejectOption --> |Yes| RejectButton["Show 'Bukan penumpang / tolak'"]
RejectOption --> |No| CloseView["Close full view"]
```

**Diagram sources**
- [foto_permintaan.dart:33-37](file://whoosh_ramah/lib/models/foto_permintaan.dart#L33-L37)
- [permintaan.dart:161-163](file://whoosh_ramah/lib/models/permintaan.dart#L161-L163)
- [foto_cuplikan.dart:44-62](file://whoosh_ramah/lib/widgets/foto_cuplikan.dart#L44-L62)
- [PROJECT.md:154-155](file://PROJECT.md#L154-L155)

**Section sources**
- [foto_permintaan.dart:33-37](file://whoosh_ramah/lib/models/foto_permintaan.dart#L33-L37)
- [permintaan.dart:161-163](file://whoosh_ramah/lib/models/permintaan.dart#L161-L163)
- [foto_cuplikan.dart:44-62](file://whoosh_ramah/lib/widgets/foto_cuplikan.dart#L44-L62)
- [PROJECT.md:154-155](file://PROJECT.md#L154-L155)

## Dependency Analysis
Coupling and cohesion:
- Screens depend on `PermintaanService` for data operations including rejection.
- Services depend on Firestore and dummy data for demo payloads.
- Models are independent and reusable across screens.
- External dependency: Python detector writes to Firestore, decoupled from Flutter code.
- Photo verification adds minimal coupling through the `FotoPermintaan` model and `FotoCuplikan` widget.

Potential circular dependencies:
- None observed; screens import service and models, service imports models and dummy data.

External integrations:
- Firestore streams connect UI to backend.
- Python detector integrates via Firestore collection naming conventions.
- Photo verification system integrates through separate `permintaan_foto/{id}` collection.

```mermaid
graph LR
TaskList["PetugasTugasScreen"] --> Service["PermintaanService"]
Detail["PetugasDetailScreen"] --> Service
Service --> Model["Permintaan + Enums"]
Service --> Dummy["DummyData"]
Detector["detect_wheelchair.py"] --> Firestore["Firestore"]
Service --> Firestore
TaskList --> Model
Detail --> Model
PhotoModel["FotoPermintaan"] --> Detail
PhotoModel --> Firestore
Widget["FotoCuplikan"] --> Service
Widget --> PhotoModel
```

**Diagram sources**
- [petugas_tugas_screen.dart:7-14](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L7-L14)
- [petugas_detail_screen.dart:3-8](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L3-L8)
- [permintaan_service.dart:1-4](file://whoosh_ramah/lib/services/permintaan_service.dart#L1-L4)
- [permintaan_service.dart:20-21](file://whoosh_ramah/lib/services/permintaan_service.dart#L20-L21)
- [detect_wheelchair.py:179-192](file://detector/detect_wheelchair.py#L179-L192)
- [foto_permintaan.dart:6-13](file://whoosh_ramah/lib/models/foto_permintaan.dart#L6-L13)
- [foto_cuplikan.dart:5-7](file://whoosh_ramah/lib/widgets/foto_cuplikan.dart#L5-L7)

**Section sources**
- [petugas_tugas_screen.dart:7-14](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L7-L14)
- [petugas_detail_screen.dart:3-8](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L3-L8)
- [permintaan_service.dart:1-21](file://whoosh_ramah/lib/services/permintaan_service.dart#L1-L21)
- [detect_wheelchair.py:179-192](file://detector/detect_wheelchair.py#L179-L192)
- [foto_permintaan.dart:6-13](file://whoosh_ramah/lib/models/foto_permintaan.dart#L6-L13)
- [foto_cuplikan.dart:5-7](file://whoosh_ramah/lib/widgets/foto_cuplikan.dart#L5-L7)

## Performance Considerations
Optimizations already present:
- Firestore query uses a single-field order-by and limit to avoid composite indexes and reduce payload size.
- UI performs client-side splitting of active vs completed tasks rather than complex queries.
- Stream listeners are scoped to screens; dispose cancels timers for highlights.
- Photo verification uses efficient base64 encoding and size-limited thumbnails.
- Rejection operations use transaction queues to prevent race conditions.

Enhanced performance considerations:
- **Photo Caching**: Implement local caching for frequently accessed photo thumbnails.
- **Lazy Loading**: Load photo verification data only when needed to reduce initial load time.
- **Memory Management**: Properly dispose of image resources when navigating away from detail screens.
- **Network Optimization**: Batch photo verification requests when possible to reduce API calls.
- **Rejection Optimization**: Use transaction queues to prevent duplicate rejection operations.

Recommendations for large task lists:
- Implement pagination or infinite scrolling if more than 100 tasks are common.
- Debounce heavy computations (e.g., relative time formatting) if list grows significantly.
- Use virtualized lists (e.g., ListView.builder) for better memory usage.
- Cache recent snapshots locally to handle brief network outages gracefully.
- Avoid redundant setState calls by isolating small UI updates.
- Implement photo verification lazy loading to improve initial screen performance.
- Optimize rejection statistics calculation for large datasets.

[No sources needed since this section provides general guidance]

## Troubleshooting Guide
Common issues and resolutions:
- No tasks appearing:
  - Verify Firestore connection and collection name matches detector configuration.
  - Check that AI detector writes to the same collection and fields.
- Status not updating:
  - Ensure the document exists and is not already completed.
  - Confirm service method is called and Firestore permissions allow updates.
- Incorrect AI task display:
  - Confirm `sumber` is `kamera_ai` and fields like `titikJemput` and `keyakinan` are present.
- Photo verification issues:
  - Check `adaFoto` flag is properly set when photo capture succeeds.
  - Verify photo documents exist in `permintaan_foto/{id}` collection.
  - Handle expired photo scenarios gracefully with appropriate UI feedback.
- Rejection problems:
  - Ensure rejection button only appears for AI tasks (`dariKamera = true`).
  - Verify `bisaDitolak` property returns true for eligible tasks.
  - Check that rejection doesn't modify status enum or history array.
  - Confirm rejected tasks are properly filtered from active list.
- Badge indicator problems:
  - Ensure `dariKamera` property is correctly computed from `sumber` field.
  - Verify badge styling is applied consistently across all task displays.
- Accessibility problems:
  - Ensure semantic labels are attached to interactive cards and buttons.
  - Test with TalkBack/VoiceOver to verify announcements.
  - Verify FotoCuplikan has proper semantic labels for image content.

Relevant implementation references:
- Error handling in detail screen shows SnackBar on failure and clears loading state.
- Task list handles null snapshots and errors with centered messages.
- History entries are appended only when advancing status successfully.
- Photo verification handles missing/expired photos with null-safe operations.
- Rejection operations use transaction queues and idempotency checks.

**Section sources**
- [petugas_detail_screen.dart:37-50](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L37-L50)
- [petugas_tugas_screen.dart:98-112](file://whoosh_ramah/lib/screens/petugas_tugas_screen.dart#L98-L112)
- [permintaan_service.dart:92-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L92-L119)
- [permintaan_service.dart:224-243](file://whoosh_ramah/lib/services/permintaan_service.dart#L224-L243)
- [foto_permintaan.dart:55-62](file://whoosh_ramah/lib/models/foto_permintaan.dart#L55-L62)

## Conclusion
The enhanced staff workflow interface provides a robust, real-time experience for managing assistance requests with comprehensive photo verification and rejection support:
- The task list screen offers clear summaries, filtering, sorting, immediate notifications for new tasks, enhanced badge indicators for AI-detected tasks, and FotoCuplikan thumbnails.
- The detail screen enforces a strict status progression with an audit trail, contextual action labels, seamless photo verification integration, and comprehensive rejection functionality.
- AI-generated tasks integrate seamlessly via Firestore, with distinct UI treatment for unknown passengers, enhanced visual indicators, and thumbnail previews.
- Stream-based synchronization ensures consistent state across screens and external systems.
- The photo verification system provides privacy-compliant passenger identification with anonymized thumbnails, automatic expiration, and FotoCuplikan widget integration.
- The rejection workflow securely handles false-positive AI detections while preserving workflow integrity and providing clear audit trails.
- Future enhancements should include role-based access control, pagination, improved caching for scalability, advanced photo verification analytics, and enhanced rejection reporting.

The implementation successfully balances functionality, privacy, and performance while providing staff with the tools they need to effectively manage passenger assistance requests in a modern, accessible interface with comprehensive photo verification and rejection capabilities.