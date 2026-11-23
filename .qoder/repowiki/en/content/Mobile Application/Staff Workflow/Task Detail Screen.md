# Task Detail Screen

<cite>
**Referenced Files in This Document**
- [petugas_detail_screen.dart](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart)
- [permintaan_service.dart](file://whoosh_ramah/lib/services/permintaan_service.dart)
- [permintaan.dart](file://whoosh_ramah/lib/models/permintaan.dart)
- [foto_permintaan.dart](file://whoosh_ramah/lib/models/foto_permintaan.dart)
- [foto_cuplikan.dart](file://whoosh_ramah/lib/widgets/foto_cuplikan.dart)
- [theme.dart](file://whoosh_ramah/lib/theme.dart)
- [hero_header.dart](file://whoosh_ramah/lib/widgets/hero_header.dart)
- [hero_back_button.dart](file://whoosh_ramah/lib/widgets/hero_back_button.dart)
- [Petugas-Detail.dc.html](file://design/Petugas-Detail.dc.html)
- [petugas_detail_test.dart](file://whoosh_ramah/test/petugas_detail_test.dart)
- [permintaan_test.dart](file://whoosh_ramah/test/permintaan_test.dart)
- [foto_permintaan_test.dart](file://whoosh_ramah/test/foto_permintaan_test.dart)
</cite>

## Update Summary
**Changes Made**
- Enhanced detail screen with comprehensive rejection capabilities for AI-detected tasks
- Added conditional AI camera snapshot display using dedicated `_kartuFoto` method
- Improved bottom action bar with rejection status indicators and dual-action layout
- Implemented proper loading states throughout the rejection workflow with separate `_menolak` state
- Added comprehensive error handling and user feedback for rejection operations
- Enhanced photo verification system with expiration handling and accessibility features

## Table of Contents
1. [Introduction](#introduction)
2. [Project Structure](#project-structure)
3. [Core Components](#core-components)
4. [Architecture Overview](#architecture-overview)
5. [Detailed Component Analysis](#detailed-component-analysis)
6. [Enhanced Rejection Workflow](#enhanced-rejection-workflow)
7. [Conditional Photo Display System](#conditional-photo-display-system)
8. [Dependency Analysis](#dependency-analysis)
9. [Performance Considerations](#performance-considerations)
10. [Troubleshooting Guide](#troubleshooting-guide)
11. [Conclusion](#conclusion)

## Introduction
This document explains the staff task detail screen implementation that shows a comprehensive view of an assistance request (task). It covers passenger information, assistance type, location details, train/carriage/seat information, AI detection confidence scores, and **anonymized passenger photos for verification**. The screen implements a five-step status progression workflow with action buttons to move through states: "Ditugaskan ke Anda" → "Bertemu penumpang" → "Penumpang di kursi" → "Selesai", plus **comprehensive rejection capabilities for AI-detected tasks marked as not a passenger**. It also documents the audit trail for status changes with timestamps and user actions, real-time updates via PermintaanService, UI components for different task sources (AI camera vs manual application), state management for transitions, permission checks for assignment, timeline visualization for status history, responsive design considerations, and accessibility features.

## Project Structure
The task detail screen is implemented as a Flutter widget within the screens layer, consuming a service for Firestore-backed data and using shared theme and header widgets. The photo verification system integrates with a separate collection for anonymized passenger photos, while the enhanced rejection system provides comprehensive false-positive handling for AI-detected tasks.

```mermaid
graph TB
subgraph "UI Layer"
PDS["PetugasDetailScreen<br/>Status stepper, info cards, bottom action"]
PH["PhotoVerificationCard<br/>Anonymized photo display"]
HH["HeroHeader<br/>Colored hero area"]
HBB["HeroBackButton<br/>Accessible back button"]
end
subgraph "Service Layer"
PS["PermintaanService<br/>Firestore streams & updates"]
FS["FotoPermintaanService<br/>Photo verification data"]
end
subgraph "Data Layer"
M["Permintaan model<br/>Enums, getters, parsing"]
FM["FotoPermintaan model<br/>Photo data handling"]
end
PDS --> PH
PDS --> HH
PDS --> HBB
PDS --> PS
PDS --> FS
PS --> M
FS --> FM
```

**Diagram sources**
- [petugas_detail_screen.dart:18-123](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L18-L123)
- [permintaan_service.dart:10-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L10-L119)
- [permintaan.dart:7-57](file://whoosh_ramah/lib/models/permintaan.dart#L7-L57)
- [foto_permintaan.dart:14-63](file://whoosh_ramah/lib/models/foto_permintaan.dart#L14-L63)
- [hero_header.dart:9-43](file://whoosh_ramah/lib/widgets/hero_header.dart#L9-L43)
- [hero_back_button.dart:8-45](file://whoosh_ramah/lib/widgets/hero_back_button.dart#L8-L45)

**Section sources**
- [petugas_detail_screen.dart:18-123](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L18-L123)
- [permintaan_service.dart:10-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L10-L119)
- [permintaan.dart:7-57](file://whoosh_ramah/lib/models/permintaan.dart#L7-L57)
- [foto_permintaan.dart:14-63](file://whoosh_ramah/lib/models/foto_permintaan.dart#L14-L63)
- [hero_header.dart:9-43](file://whoosh_ramah/lib/widgets/hero_header.dart#L9-L43)
- [hero_back_button.dart:8-45](file://whoosh_ramah/lib/widgets/hero_back_button.dart#L8-L45)

## Core Components
- PetugasDetailScreen: A StatefulWidget that listens to a single Firestore document stream, renders passenger info, assistance type, location or train/carriage/seat details, a five-step status stepper, notes, communication shortcuts, and a primary action button to advance status.
- PermintaanService: Provides Firestore streams for a single task and all tasks, plus methods to advance status and reject tasks while appending audit entries.
- Permintaan model: Encapsulates task data, enums for assistance type and status, helpers for source differentiation (camera vs app), short location extraction, confidence percentage formatting, **and photo verification fields (adaFoto, ditolakPada, alasanTolak)**.
- FotoPermintaan model: Handles anonymized passenger photo data including base64 decoding, expiration checking, and null-safe operations.
- FotoCuplikan widget: Dedicated component for displaying AI camera snapshots with proper loading states and expiration handling.
- Theme and widgets: Shared color palette, radii, shadows, HeroHeader, and HeroBackButton ensure consistent visual language and accessibility.

Key responsibilities:
- Real-time display of task data via StreamBuilder.
- Status progression with a single action button whose label adapts to the next step.
- **Comprehensive rejection workflow for AI-detected tasks with confirmation dialogs and loading states.**
- **Conditional rendering of AI camera snapshots using dedicated _kartuFoto method.**
- **Dual-action bottom bar supporting both status advancement and task rejection.**
- Audit trail appended on each status change.
- **Task rejection capability for AI-detected false positives with proper state management.**

**Section sources**
- [petugas_detail_screen.dart:18-123](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L18-L123)
- [permintaan_service.dart:23-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L23-L119)
- [permintaan.dart:7-57](file://whoosh_ramah/lib/models/permintaan.dart#L7-L57)
- [foto_permintaan.dart:14-63](file://whoosh_ramah/lib/models/foto_permintaan.dart#L14-L63)
- [foto_cuplikan.dart:9-152](file://whoosh_ramah/lib/widgets/foto_cuplikan.dart#L9-L152)
- [theme.dart:7-48](file://whoosh_ramah/lib/theme.dart#L7-L48)

## Architecture Overview
The screen uses a reactive architecture:
- UI subscribes to a single-document stream from PermintaanService.
- When the user taps the action button, the service advances the status and writes an audit entry.
- **Rejection workflow uses separate state management (_menolak) with confirmation dialogs and proper error handling.**
- **Photo verification data is handled separately through FotoCuplikan widget with TTL-based expiration.**
- Firestore pushes updated data back to the UI automatically.

```mermaid
sequenceDiagram
participant Staff as "Staff Device"
participant UI as "PetugasDetailScreen"
participant Service as "PermintaanService"
participant PhotoWidget as "FotoCuplikan"
participant DB as "Firestore"
Staff->>UI : Open task detail
UI->>Service : streamPermintaan(id)
Service->>DB : Listen to doc(id)
DB-->>Service : Snapshot {status, fields}
Service-->>UI : Permintaan?
UI-->>Staff : Render info, stepper, action button
Staff->>UI : Tap action button
UI->>Service : majukanStatus(id)
Service->>DB : Update status, append riwayat, serverTimestamps
DB-->>Service : Acknowledged
Service-->>UI : Done
DB-->>Service : New snapshot
Service-->>UI : Updated Permintaan
UI-->>Staff : Re-render with new status
Note over PhotoWidget,DB : Photo verification flow
PhotoWidget->>DB : Listen to permintaan_foto/{id}
DB-->>PhotoWidget : Anonymized photo data
PhotoWidget-->>UI : Photo bytes or expiration status
Note over Staff,UI : Rejection workflow
Staff->>UI : Tap rejection button
UI->>UI : Show confirmation dialog
Staff->>UI : Confirm rejection
UI->>Service : tolakTugas(id, reason)
Service->>DB : Set ditolakPada, alasanTolak
DB-->>Service : Acknowledged
Service-->>UI : Done
UI-->>Staff : Show success message & navigate back
```

**Diagram sources**
- [petugas_detail_screen.dart:30-50](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L30-L50)
- [permintaan_service.dart:65-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L65-L119)
- [foto_permintaan.dart:40-63](file://whoosh_ramah/lib/models/foto_permintaan.dart#L40-L63)
- [foto_cuplikan.dart:44-62](file://whoosh_ramah/lib/widgets/foto_cuplikan.dart#L44-L62)

## Detailed Component Analysis

### Enhanced Status Progression Workflow
The workflow enforces a strict sequence:
- Menunggu → Ditugaskan → Bertemu → DiKursi → Selesai

The UI displays a five-step stepper and a single action button whose label reflects the next step. When the current status is Selesai, the button is replaced by a success banner. **For AI-detected tasks, staff can reject false positives at any stage before completion using a dedicated rejection workflow with confirmation dialogs.**

```mermaid
flowchart TD
Start(["Current status"]) --> CheckDone{"Status == selesai?"}
CheckDone --> |Yes| Banner["Show 'Tugas selesai' banner"]
CheckDone --> |No| Next["Compute berikutnya"]
Next --> Label["Compute button label<br/>from berikutnya.tombolPetugas or label"]
Label --> Action["User taps action"]
Action --> Update["Service updates status,<br/>appends riwayat entry,<br/>sets petugas if ditugaskan"]
Update --> Refresh["Stream emits updated Permintaan"]
Refresh --> End(["UI re-renders stepper & button"])
CheckAI["Check if AI task"] --> CanReject{"bisaDitolak?"}
CanReject --> |Yes| RejectBtn["Show 'Bukan penumpang / tolak' button"]
CanReject --> |No| Continue["Continue normal workflow"]
RejectBtn --> RejectFlow["Confirmation dialog + loading state"]
RejectFlow --> RejectUpdate["Set ditolakPada & alasanTolak"]
RejectUpdate --> NavigateBack["Navigate back to task list"]
```

**Diagram sources**
- [permintaan.dart:32-57](file://whoosh_ramah/lib/models/permintaan.dart#L32-L57)
- [permintaan.dart:161-163](file://whoosh_ramah/lib/models/permintaan.dart#L161-L163)
- [petugas_detail_screen.dart:312-406](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L312-L406)
- [permintaan_service.dart:92-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L92-L119)

**Section sources**
- [permintaan.dart:32-57](file://whoosh_ramah/lib/models/permintaan.dart#L32-L57)
- [permintaan.dart:161-163](file://whoosh_ramah/lib/models/permintaan.dart#L161-L163)
- [petugas_detail_screen.dart:312-406](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L312-L406)
- [permintaan_service.dart:92-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L92-L119)

### Passenger Information and Task Source Rendering
- Manual application tasks show:
  - Passenger name and assistance type badge.
  - Pickup point, train number with departure time, carriage and seat, destination.
  - Optional note card.
  - Communication shortcuts: message and call.
- AI camera tasks show:
  - Placeholder name "Penumpang belum diketahui".
  - Short location extracted from pickup point.
  - Confidence percentage derived from AI detection score.
  - **Conditional anonymized passenger photo for verification (when available via adaFoto flag).**
  - No train/carriage/seat fields; instead, location and confidence are displayed.

```mermaid
classDiagram
class Permintaan {
+String id
+JenisBantuan jenisBantuan
+String titikJemput
+StatusPermintaan status
+String sumber
+String? namaPenumpang
+String? kereta
+String? jamBerangkat
+String? stasiunTujuan
+String? gerbong
+String? kursi
+String? catatan
+bool dariKamera
+bool adaFoto
+DateTime? ditolakPada
+String? alasanTolak
+bool bisaDitolak
+String lokasiSingkat()
+int? persenKeyakinan()
}
class FotoPermintaan {
+String id
+Uint8List? bytes
+DateTime? dibuatPada
+DateTime? kedaluwarsaPada
+bool kedaluwarsa(DateTime)
}
class PermintaanService {
+streamPermintaan(id) Stream~Permintaan?~
+majukanStatus(id) Future~void~
+tolakTugas(id, reason) Future~void~
}
class PetugasDetailScreen {
+build(context) Widget
-_kartuInfo(p) Widget
-_kartuFoto(p) Widget
-_tiles(p) List
-_barBawah(p) Widget
-_tolak() Future~void~
}
PermintaanService --> Permintaan : "streams"
PetugasDetailScreen --> Permintaan : "renders"
PetugasDetailScreen --> PermintaanService : "uses"
Permintaan --> FotoPermintaan : "verifies"
```

**Diagram sources**
- [permintaan.dart:81-148](file://whoosh_ramah/lib/models/permintaan.dart#L81-L148)
- [foto_permintaan.dart:14-63](file://whoosh_ramah/lib/models/foto_permintaan.dart#L14-L63)
- [permintaan_service.dart:65-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L65-L119)
- [petugas_detail_screen.dart:161-310](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L161-L310)

**Section sources**
- [petugas_detail_screen.dart:161-310](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L161-L310)
- [permintaan.dart:126-148](file://whoosh_ramah/lib/models/permintaan.dart#L126-L148)

### Audit Trail Implementation
Each status advancement appends an audit entry containing the new status and timestamp. The initial creation adds the first entry with status "menunggu". When transitioning to "ditugaskan", the assigned officer's name is set. **Rejection events are tracked separately via ditolakPada and alasanTolak fields without changing the status enum.**

Key behaviors:
- Append to riwayat array atomically using arrayUnion.
- Use serverTimestamp for diperbaruiPada to reflect server time.
- For ditugaskan, set petugas field to a default value.
- **Track rejection timestamps and reasons separately from status changes.**

Timeline visualization:
- The UI does not render the full history list directly; it computes the active step based on the current status and highlights completed steps.
- The model parses riwayat entries into RiwayatStatus objects with status and optional waktu.

```mermaid
flowchart TD
Create["Create task"] --> InitHistory["Append riwayat entry<br/>{status: menunggu, waktu: now}"]
Advance["Advance status"] --> AppendAudit["Append riwayat entry<br/={status: next, waktu: now}]
AppendAudit --> SetOfficer{"Next == ditugaskan?"}
SetOfficer --> |Yes| Assign["Set petugas = default"]
SetOfficer --> |No| Skip["Skip"]
Assign --> Persist["Update Firestore"]
Skip --> Persist
Persist --> Emit["Stream emits updated Permintaan"]
Emit --> CheckReject{"Check rejection"}
CheckReject --> |Rejected| TrackReject["Track ditolakPada & alasanTolak"]
CheckReject --> |Not Rejected| Continue["Continue workflow"]
TrackReject --> Continue
```

**Diagram sources**
- [permintaan_service.dart:23-61](file://whoosh_ramah/lib/services/permintaan_service.dart#L23-L61)
- [permintaan_service.dart:92-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L92-L119)
- [permintaan.dart:59-75](file://whoosh_ramah/lib/models/permintaan.dart#L59-L75)
- [permintaan.dart:141-147](file://whoosh_ramah/lib/models/permintaan.dart#L141-L147)

**Section sources**
- [permintaan_service.dart:23-61](file://whoosh_ramah/lib/services/permintaan_service.dart#L23-L61)
- [permintaan_service.dart:92-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L92-L119)
- [permintaan.dart:59-75](file://whoosh_ramah/lib/models/permintaan.dart#L59-L75)
- [permintaan.dart:141-147](file://whoosh_ramah/lib/models/permintaan.dart#L141-L147)

### Permission Checks for Task Assignment
The current implementation does not enforce role-based permissions at the screen level. Instead, it relies on the service logic to assign the officer when advancing to "ditugaskan". To add permission checks:
- Validate the current user's role before allowing the transition to "ditugaskan".
- Reject transitions if the user is not authorized.
- Return clear error feedback via SnackBar.

Suggested integration points:
- In _majukan(), check user role before calling majukanStatus().
- Extend PermintaanService.majukanStatus() to accept a userId and validate against a roles collection.

**Section sources**
- [petugas_detail_screen.dart:37-50](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L37-L50)
- [permintaan_service.dart:92-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L92-L119)

### State Management for Status Transitions
State is managed reactively:
- StreamBuilder listens to PermintaanService.streamPermintaan(id).
- Local loading state disables the action button during updates.
- Button label is computed from the next status enum.

Example patterns:
- Compute next status: p.status.berikutnya.
- Compute button label: use berikutnya.tombolPetugas or fallback to berikutnya.label; for final step, include destination station name.
- Disable button while loading and show spinner.

**Section sources**
- [petugas_detail_screen.dart:30-50](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L30-L50)
- [petugas_detail_screen.dart:398-406](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L398-L406)
- [permintaan.dart:45-57](file://whoosh_ramah/lib/models/permintaan.dart#L45-L57)

### Timeline Visualization for Status History
The stepper visualizes progress:
- Completed steps show a filled circle with a checkmark.
- Current step shows an outlined circle with a dot and "sekarang" suffix.
- Upcoming steps show an empty circle with neutral styling.

Labels adapt to context:
- "Penumpang di kursi" includes seat number when available.
- Final step includes destination station name.

**Section sources**
- [petugas_detail_screen.dart:312-348](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L312-L348)
- [petugas_detail_screen.dart:408-424](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L408-L424)
- [petugas_detail_screen.dart:429-505](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L429-L505)

## Enhanced Rejection Workflow

### Overview
The enhanced rejection system provides comprehensive handling for AI-detected false positives. Staff can reject tasks marked as "not a passenger" through a dedicated workflow that includes confirmation dialogs, loading states, error handling, and proper navigation back to the task list.

### Rejection State Management
- Separate `_menolak` boolean state manages rejection loading independently from status advancement.
- Confirmation dialog prevents accidental rejections with clear messaging about consequences.
- Proper error handling shows appropriate feedback messages for network failures.
- Successful rejections trigger navigation back to the task list after showing confirmation.

### Rejection Button Integration
- Conditional display based on `bisaDitolak` getter ensuring only AI-detected, non-completed, non-rejected tasks show the rejection option.
- Secondary pill button positioned below the main action button in the bottom action bar.
- Loading state disables the button and shows processing indicator.
- Key-based testing support with `tombol_tolak` key for automated tests.

### User Experience Flow
```mermaid
flowchart TD
TapReject["Staff taps 'Bukan penumpang / tolak'"] --> Dialog["Show confirmation dialog"]
Dialog --> Decision{"Confirm rejection?"}
Decision --> |Cancel| Cancel["Return to task detail"]
Decision --> |Confirm| Process["Set _menolak = true"]
Process --> ServiceCall["Call tolakTugas()"]
ServiceCall --> Success{"Success?"}
Success --> |Yes| Navigate["Navigate back to task list"]
Success --> |No| Error["Show error message"]
Error --> Reset["Reset _menolak = false"]
Reset --> Available["Button available again"]
```

**Diagram sources**
- [petugas_detail_screen.dart:65-117](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L65-L117)
- [permintaan_service.dart:215-243](file://whoosh_ramah/lib/services/permintaan_service.dart#L215-L243)

### Bottom Action Bar Enhancement
The bottom action bar now supports dual functionality:
- Primary action button for status advancement (red branded button).
- Secondary rejection button for AI-detected tasks (secondary pill button).
- Status indicators for rejected tasks ("Tugas ditolak · bukan penumpang").
- Proper spacing and accessibility considerations for both buttons.

**Section sources**
- [petugas_detail_screen.dart:65-117](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L65-L117)
- [petugas_detail_screen.dart:477-541](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L477-L541)
- [permintaan_service.dart:215-243](file://whoosh_ramah/lib/services/permintaan_service.dart#L215-L243)

## Conditional Photo Display System

### Overview
The photo display system uses a dedicated `_kartuFoto` method that conditionally renders AI camera snapshots based on the `adaFoto` flag and task source type. This ensures privacy and performance by only loading photos when needed.

### Conditional Rendering Logic
- Photo card only appears for AI-detected tasks (`p.dariKamera`) with available photos (`p.adaFoto`).
- Uses FotoCuplikan widget for proper loading states and expiration handling.
- Maintains consistent styling with other cards in the interface.
- Includes explanatory text about automatic deletion after 10 minutes.

### FotoCuplikan Widget Features
- Three-state display: valid photo, loading placeholder, expired photo.
- Proper Semantics labels for accessibility (screen readers).
- Thumbnail mode support for list views vs full-size for detail views.
- Automatic expiration checking based on TTL mechanism.
- Graceful error handling for corrupted or missing photos.

### Privacy and Security
- Photos are stored as base64-encoded JPEG data in the `permintaan_foto/{id}` collection.
- Images are automatically anonymized (pixelated, face-blurred) before storage.
- Maximum size: 160 pixels to protect privacy.
- Automatic expiration via TTL (Time-To-Live) mechanism.
- Null-safe handling for missing or expired photos.

```mermaid
flowchart TD
TaskLoad["Task loaded"] --> CheckSource{"dariKamera && adaFoto?"}
CheckSource --> |Yes| ShowCard["Render _kartuFoto()"]
CheckSource --> |No| SkipCard["Skip photo card"]
ShowCard --> LoadPhoto["Load FotoCuplikan widget"]
LoadPhoto --> PhotoState{"Photo state?"}
PhotoState --> |Valid| Display["Display anonymized photo"]
PhotoState --> |Loading| Placeholder["Show loading placeholder"]
PhotoState --> |Expired| Expired["Show 'Cuplikan sudah kedaluwarsa'"]
```

**Diagram sources**
- [petugas_detail_screen.dart:183-186](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L183-L186)
- [petugas_detail_screen.dart:391-436](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L391-L436)
- [foto_cuplikan.dart:44-62](file://whoosh_ramah/lib/widgets/foto_cuplikan.dart#L44-L62)

**Section sources**
- [petugas_detail_screen.dart:391-436](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L391-L436)
- [foto_cuplikan.dart:9-152](file://whoosh_ramah/lib/widgets/foto_cuplikan.dart#L9-L152)

### Responsive Design Considerations
- Hero header extends to status bar with rounded bottom corners and SafeArea handling.
- Cards overlap the hero using negative translation to match design specs.
- Two-column grid for info tiles adapts to screen width.
- Bottom action area remains fixed with padding and accessible tap targets.
- **Photo verification cards maintain aspect ratio and handle various image sizes gracefully.**

Design alignment:
- Colors, radii, and shadows follow AppColors and AppRadius.
- Typography uses Nunito with sizes and weights per design guidelines.

**Section sources**
- [hero_header.dart:9-43](file://whoosh_ramah/lib/widgets/hero_header.dart#L9-L43)
- [petugas_detail_screen.dart:53-123](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L53-L123)
- [theme.dart:7-48](file://whoosh_ramah/lib/theme.dart#L7-L48)
- [Petugas-Detail.dc.html:18-80](file://design/Petugas-Detail.dc.html#L18-L80)

### Accessibility Features
- Back button exposes explicit label for screen readers.
- Action button uses Semantics with enabled state and label reflecting processing or action text.
- Secondary buttons wrap content with MergeSemantics and Semantics(button: true) for proper announcements.
- Touch targets meet minimum size requirements.
- **Photo verification elements provide appropriate semantic labels for screen readers.**
- **Rejection buttons include descriptive labels explaining the action.**
- **Confirmation dialogs provide clear accessibility labels and navigation instructions.**

**Section sources**
- [hero_back_button.dart:8-45](file://whoosh_ramah/lib/widgets/hero_back_button.dart#L8-L45)
- [petugas_detail_screen.dart:622-670](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L622-L670)
- [petugas_detail_screen.dart:587-620](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L587-L620)
- [foto_cuplikan.dart:66-81](file://whoosh_ramah/lib/widgets/foto_cuplikan.dart#L66-L81)

## Dependency Analysis
The following diagram maps dependencies between core files:

```mermaid
graph LR
PDS["petugas_detail_screen.dart"] --> M["permintaan.dart"]
PDS --> PS["permintaan_service.dart"]
PDS --> FC["foto_cuplikan.dart"]
PDS --> HH["hero_header.dart"]
PDS --> HBB["hero_back_button.dart"]
PS --> M
PS --> FP["foto_permintaan.dart"]
FC --> FP
```

**Diagram sources**
- [petugas_detail_screen.dart:1-12](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L1-L12)
- [permintaan_service.dart:1-5](file://whoosh_ramah/lib/services/permintaan_service.dart#L1-L5)
- [permintaan.dart:1-2](file://whoosh_ramah/lib/models/permintaan.dart#L1-L2)
- [foto_permintaan.dart:1-4](file://whoosh_ramah/lib/models/foto_permintaan.dart#L1-L4)
- [foto_cuplikan.dart:1-7](file://whoosh_ramah/lib/widgets/foto_cuplikan.dart#L1-L7)
- [hero_header.dart:1-3](file://whoosh_ramah/lib/widgets/hero_header.dart#L1-L3)
- [hero_back_button.dart:1-3](file://whoosh_ramah/lib/widgets/hero_back_button.dart#L1-L3)

**Section sources**
- [petugas_detail_screen.dart:1-12](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L1-L12)
- [permintaan_service.dart:1-5](file://whoosh_ramah/lib/services/permintaan_service.dart#L1-L5)
- [permintaan.dart:1-2](file://whoosh_ramah/lib/models/permintaan.dart#L1-L2)
- [foto_permintaan.dart:1-4](file://whoosh_ramah/lib/models/foto_permintaan.dart#L1-L4)
- [foto_cuplikan.dart:1-7](file://whoosh_ramah/lib/widgets/foto_cuplikan.dart#L1-L7)

## Performance Considerations
- Single-document stream minimizes network overhead compared to listening to the entire collection.
- Avoid heavy computations inside build; delegate to model getters (e.g., lokasiSingkat, persenKeyakinan).
- Debounce rapid taps by disabling the action button during loading.
- Keep UI tree shallow where possible; reuse small widgets (_StepRow, _InfoTile, _Avatar, _BadgeSumber).
- **Photo verification uses efficient base64 decoding with null-safe error handling.**
- **Automatic photo expiration reduces storage overhead and privacy risks.**
- **Separate loading states prevent UI conflicts between status advancement and rejection operations.**

[No sources needed since this section provides general guidance]

## Troubleshooting Guide
Common issues and resolutions:
- Task not found:
  - If the document does not exist, the UI shows a friendly message. Verify the ID passed to the screen.
- Network errors updating status:
  - The UI displays a SnackBar when majukanStatus throws. Retry after ensuring connectivity.
- Incorrect status labels:
  - Ensure enum values match Firestore strings; fallbacks default to "menunggu" or "kursi_roda".
- Missing train/carriage/seat info:
  - These fields are only present for app-created tasks; AI camera tasks show location and confidence instead.
- **Photo verification issues:**
  - **Expired photos: Display "Cuplikan sudah kedaluwarsa" state instead of error.**
  - **Missing photos: Handle null bytes gracefully and show appropriate placeholder.**
  - **Base64 decoding errors: Treat corrupted images as unavailable photos.**
- **Rejection workflow problems:**
  - **Ensure only AI-detected tasks can be rejected (check bisaDitolak).**
  - **Verify rejection doesn't affect task status enum (only sets ditolakPada).**
  - **Check that rejection loading state properly disables the button during processing.**
  - **Confirm that successful rejections navigate back to the task list.**

Relevant code paths:
- Error handling in _majukan(): catch exceptions and show SnackBar.
- Null-safe parsing in Permintaan.fromMap handles missing fields gracefully.
- **FotoCuplikan widget handles photo loading states and expiration gracefully.**
- **Permintaan.bisaDitolak ensures proper rejection conditions.**
- **_tolak() method provides comprehensive error handling for rejection operations.**

**Section sources**
- [petugas_detail_screen.dart:37-50](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L37-L50)
- [permintaan.dart:157-189](file://whoosh_ramah/lib/models/permintaan.dart#L157-L189)
- [foto_permintaan.dart:55-62](file://whoosh_ramah/lib/models/foto_permintaan.dart#L55-L62)
- [permintaan.dart:161-163](file://whoosh_ramah/lib/models/permintaan.dart#L161-L163)
- [foto_cuplikan.dart:44-62](file://whoosh_ramah/lib/widgets/foto_cuplikan.dart#L44-L62)
- [petugas_detail_screen.dart:65-117](file://whoosh_ramah/lib/screens/petugas_detail_screen.dart#L65-L117)

## Conclusion
The staff task detail screen delivers a clear, accessible, and responsive interface for managing assistance requests with integrated photo verification capabilities and comprehensive rejection workflows. It integrates real-time updates via PermintaanService, enforces a strict status progression workflow, maintains an audit trail for compliance and transparency, and provides robust photo verification for AI-detected tasks. The enhanced rejection system handles false positives with proper confirmation dialogs, loading states, and error handling. The conditional photo display system ensures privacy and performance by only showing relevant AI camera snapshots. With thoughtful accessibility, responsive design, and privacy-focused photo handling, the screen supports efficient staff workflows across devices while maintaining passenger privacy and security.

[No sources needed since this section summarizes without analyzing specific files]