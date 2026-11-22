# Project Overview

<cite>
**Referenced Files in This Document**
- [PROJECT.md](file://PROJECT.md)
- [whoosh_ramah/README.md](file://whoosh_ramah/README.md)
- [detector/README.md](file://detector/README.md)
- [design/README.md](file://design/README.md)
- [main.dart](file://whoosh_ramah/lib/main.dart)
- [theme.dart](file://whoosh_ramah/lib/theme.dart)
- [permintaan.dart](file://whoosh_ramah/lib/models/permintaan.dart)
- [permintaan_service.dart](file://whoosh_ramah/lib/services/permintaan_service.dart)
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
Whoosh Ramah is an accessibility management system for KCIC high-speed train stations. It helps priority passengers—elderly travelers, people with disabilities, pregnant women, sick passengers, and unaccompanied children—request assistance from station staff, while letting family members monitor the process in real time. The project was created as a hackathon prototype: a demonstrable end-to-end flow that can run on two or three phones and one laptop within a week.

The core problem it solves is that assistance requests are still manual. Passengers often have to approach station staff in person or call the contact center. Staff may only learn about the need when the passenger arrives, seat information is passed manually to the destination station, and families cannot track progress. Whoosh Ramah centralizes this workflow into a Flutter mobile app backed by Cloud Firestore, plus an optional Python AI camera detector that automatically creates assistance tasks when it detects a wheelchair at the station entrance.

Business context shows the scale of the issue: KCIC served around 9,000 priority passengers between January and August 2026, with elderly assistance requests averaging about 60 per day on weekdays and up to 100 per day on weekends. There are 64 trained service officers available, but the current manual process makes coordination difficult.

The target audience includes:
- Priority passengers who need assistance.
- Station staff responsible for receiving, assigning, and completing assistance tasks.
- Family members who want to monitor a passenger’s journey and status.

What is out of scope for this hackathon prototype includes real login accounts, integration with KCIC ticketing systems, payment processing, automatic officer scheduling, push notifications, and storing facial photos. These are important production concerns, but they are intentionally excluded so the demo stays focused.

**Section sources**
- [PROJECT.md:8-20](file://PROJECT.md#L8-L20)
- [whoosh_ramah/README.md:1-18](file://whoosh_ramah/README.md#L1-L18)

## Project Structure
At a high level, the repository contains:
- A Flutter application under `whoosh_ramah/`, which implements the passenger, officer, and family workflows.
- A Python-based wheelchair detector under `detector/`, which writes assistance tasks directly to Firebase Cloud Firestore.
- Design references under `design/`, describing the visual layout and interaction patterns for each screen.
- A master specification document `PROJECT.md` that defines business context, architecture, data model, screens, design rules, accessibility requirements, folder structure, implementation steps, demo checklist, and privacy notes.

```mermaid
graph TB
subgraph "Mobile App"
Flutter["Flutter App<br/>Passenger / Officer / Family"]
end
subgraph "Backend"
Firestore["Cloud Firestore<br/>Collection: permintaan_pendampingan"]
end
subgraph "AI Detector"
Laptop["Laptop<br/>Python + YOLO"]
Camera["Camera"]
end
Camera --> Laptop
Laptop --> Firestore
Flutter --> Firestore
```

**Diagram sources**
- [PROJECT.md:24-37](file://PROJECT.md#L24-L37)
- [detector/README.md:1-8](file://detector/README.md#L1-L8)

The Flutter app initializes Firebase, applies a consistent theme, and starts with a role-selection screen. The app does not run AI locally; it reads assistance documents written either by passengers through the app or by the Python detector.

**Section sources**
- [PROJECT.md:24-37](file://PROJECT.md#L24-L37)
- [PROJECT.md:179-203](file://PROJECT.md#L179-L203)
- [main.dart:8-33](file://whoosh_ramah/lib/main.dart#L8-L33)

## Core Components
Whoosh Ramah has three main user roles, each with a clear workflow:

| Role | Purpose | Main Workflow |
| --- | --- | --- |
| Penumpang (Passenger) | Request assistance and track its progress | View active ticket → request assistance → choose assistance type and pickup point → view real-time status timeline → optionally share with family |
| Petugas (Officer) | Receive, assign, and complete assistance tasks | View active tasks → open task details → advance status through waiting, assigned, met, seated, completed → update history |
| Keluarga (Family) | Monitor a specific passenger’s latest assistance request | Open monitoring screen → see current status, journey progress, and timestamped history |

The system supports six assistance types: wheelchair, blind passenger, deaf passenger, elderly, pregnant woman, and porter. Tasks also distinguish whether they came from the app or the AI camera.

The data model centers on a single Firestore collection called `permintaan_pendampingan`. Each document represents one assistance request and includes fields such as assistance type, pickup location, source, passenger identifiers, train details, officer name, camera identifier, confidence score, history log, and timestamps.

The required status progression is:
1. Waiting
2. Assigned
3. Met
4. Seated
5. Completed

This ordered state machine ensures that both passenger and family views show a consistent journey, while officers move the task forward with one primary action per step.

**Section sources**
- [PROJECT.md:54-95](file://PROJECT.md#L54-L95)
- [PROJECT.md:121-135](file://PROJECT.md#L121-L135)
- [permintaan.dart:3-57](file://whoosh_ramah/lib/models/permintaan.dart#L3-L57)

## Architecture Overview
The solution combines a Flutter mobile app with a Python AI detection system. They do not communicate directly; instead, they share Cloud Firestore as the single source of truth.

```mermaid
sequenceDiagram
participant Passenger as "Passenger Phone"
participant App as "Flutter App"
participant Firestore as "Cloud Firestore"
participant Officer as "Officer Phone"
participant Family as "Family Phone"
participant Detector as "Python Detector"
participant Camera as "Station Camera"
Camera->>Detector : Video feed
Detector->>Firestore : Create assistance task
Note over Detector,Firestore : Source = kamera_ai
Passenger->>App : Request assistance
App->>Firestore : Create assistance task
Note over App,Firestore : Source = aplikasi
Officer->>Firestore : Read active tasks
Firestore-->>Officer : Real-time task list
Officer->>Firestore : Advance status
Firestore-->>Passenger : Update status timeline
Firestore-->>Family : Update monitoring screen
```

**Diagram sources**
- [PROJECT.md:24-37](file://PROJECT.md#L24-L37)
- [PROJECT.md:121-135](file://PROJECT.md#L121-L135)
- [permintaan_service.dart:23-60](file://whoosh_ramah/lib/services/permintaan_service.dart#L23-L60)
- [permintaan_service.dart:92-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L92-L119)
- [detector/README.md:39-61](file://detector/README.md#L39-L61)

Key architectural points:
- One Flutter app handles all three roles through role selection.
- Cloud Firestore provides real-time updates without a custom backend server.
- The Python detector runs separately and writes assistance documents with `sumber = kamera_ai`.
- The Flutter app only consumes these documents; it does not run AI inference.
- All UI flows are guided by HTML design references in the `design/` folder.

**Section sources**
- [PROJECT.md:24-37](file://PROJECT.md#L24-L37)
- [design/README.md:1-8](file://design/README.md#L1-L8)

## Detailed Component Analysis

### Application Entry Point and Theme
The Flutter app entry point initializes Firebase, sets the app title, disables debug banners, applies the light theme, and opens the role-selection screen. The theme defines colors, typography, radii, shadows, and button styles following the “bright and friendly” design style.

```mermaid
flowchart TD
Start["App Launch"] --> InitFirebase["Initialize Firebase"]
InitFirebase --> ApplyTheme["Apply AppTheme"]
ApplyTheme --> ShowRoleScreen["Show Role Selection Screen"]
ShowRoleScreen --> End["User chooses Penumpang / Petugas / Keluarga"]
```

**Diagram sources**
- [main.dart:8-33](file://whoosh_ramah/lib/main.dart#L8-L33)
- [theme.dart:65-113](file://whoosh_ramah/lib/theme.dart#L65-L113)

**Section sources**
- [main.dart:8-33](file://whoosh_ramah/lib/main.dart#L8-L33)
- [theme.dart:1-164](file://whoosh_ramah/lib/theme.dart#L1-L164)

### Data Model and State Machine
The data model defines enums for assistance type and status, a history entry class, and a null-safe `Permintaan` document model. It maps Firestore strings to enums, computes derived values like short pickup location and confidence percentage, and serializes back to Firestore maps.

```mermaid
classDiagram
class JenisBantuan {
+string value
+string label
+dariValue(value)
}
class StatusPermintaan {
+string value
+string label
+string tombolPetugas
+berikutnya
+dariValue(value)
}
class RiwayatStatus {
+string status
+DateTime waktu
+fromMap(map)
+toFirestore()
}
class Permintaan {
+string id
+JenisBantuan jenisBantuan
+String titikJemput
+StatusPermintaan status
+String sumber
+bool dariKamera
+bool sudahSelesai
+String lokasiSingkat
+int persenKeyakinan
+fromFirestore(snap)
+fromMap(data)
+toFirestore()
}
Permintaan --> JenisBantuan : "uses"
Permintaan --> StatusPermintaan : "uses"
Permintaan --> RiwayatStatus : "contains"
```

**Diagram sources**
- [permintaan.dart:3-57](file://whoosh_ramah/lib/models/permintaan.dart#L3-L57)
- [permintaan.dart:59-149](file://whoosh_ramah/lib/models/permintaan.dart#L59-L149)
- [permintaan.dart:150-213](file://whoosh_ramah/lib/models/permintaan.dart#L150-L213)

**Section sources**
- [permintaan.dart:3-213](file://whoosh_ramah/lib/models/permintaan.dart#L3-L213)

### Firestore Service Layer
The service layer encapsulates all Firestore operations for the `permintaan_pendampingan` collection. It creates new assistance requests, streams a single document, streams all active tasks, streams the latest request for a passenger, and advances the status through the required sequence.

```mermaid
flowchart TD
Start["Advance Status"] --> ReadDoc["Read Current Document"]
ReadDoc --> Exists{"Document Exists?"}
Exists --> |No| Exit["Exit Without Changes"]
Exists --> |Yes| ParseStatus["Parse Current Status"]
ParseStatus --> Next{"Has Next Status?"}
Next --> |No| Exit
Next --> |Yes| BuildUpdate["Build Update Map"]
BuildUpdate --> AssignOfficer{"Next Status = Assigned?"}
AssignOfficer --> |Yes| SetOfficer["Set petugas = Rina"]
AssignOfficer --> |No| SkipOfficer["Skip Officer Assignment"]
SetOfficer --> WriteUpdate["Write Status, Timestamp, History"]
SkipOfficer --> WriteUpdate
WriteUpdate --> Done["Done"]
```

**Diagram sources**
- [permintaan_service.dart:92-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L92-L119)

Important behaviors:
- New requests use dummy passenger and ticket data for the demo.
- Requests from the app set `sumber = aplikasi`; requests from the detector set `sumber = kamera_ai`.
- Status advancement appends a history entry and updates the last-updated timestamp.
- When moving to the assigned status, the officer field is filled with the demo officer name.
- Streams avoid composite indexes by limiting ordering to one field or sorting client-side.

**Section sources**
- [permintaan_service.dart:6-135](file://whoosh_ramah/lib/services/permintaan_service.dart#L6-L135)

### AI Wheelchair Detector
The detector runs on a laptop, reads video input from a camera, detects wheelchairs, and writes assistance tasks to Firestore. It uses either a Roboflow-hosted model or a locally trained YOLO model. Privacy is preserved by sending only assistance type, location, time, and confidence to Firestore—not faces or images.

```mermaid
flowchart TD
Start["Start Detector"] --> LoadEnv["Load .env Configuration"]
LoadEnv --> ChooseModel{"Use Roboflow or Local Model?"}
ChooseModel --> |Roboflow| UseAPI["Call Roboflow API"]
ChooseModel --> |Local| LoadPT["Load Local YOLO Model"]
UseAPI --> DetectFrame["Detect Wheelchair Frame"]
LoadPT --> DetectFrame
DetectFrame --> Threshold{"Confidence >= Threshold?"}
Threshold --> |No| WaitNext["Wait Next Frame"]
Threshold --> |Yes| CheckCooldown{"Task Cooldown Passed?"}
CheckCooldown --> |No| WaitNext
CheckCooldown --> |Yes| WriteFirestore["Write Assistance Task"]
WriteFirestore --> StreamTasks["Flutter App Reads Task"]
```

**Diagram sources**
- [detector/README.md:21-61](file://detector/README.md#L21-L61)
- [detector/README.md:77-93](file://detector/README.md#L77-L93)

**Section sources**
- [detector/README.md:1-93](file://detector/README.md#L1-L93)

### User Roles and Workflows

#### Passenger Workflow
A passenger opens the app, sees their active ticket, requests assistance, selects the assistance type and pickup point, and then tracks the real-time status timeline. The passenger can also share the request with family.

```mermaid
sequenceDiagram
participant P as "Passenger"
participant PT as "Ticket Screen"
participant PM as "Request Screen"
participant PS as "Status Screen"
participant F as "Firestore"
P->>PT : Open active ticket
P->>PM : Request assistance
PM->>F : Create permintaan_pendampingan
F-->>PS : Real-time status stream
P->>PS : Track timeline
```

**Diagram sources**
- [PROJECT.md:121-131](file://PROJECT.md#L121-L131)
- [permintaan_service.dart:23-60](file://whoosh_ramah/lib/services/permintaan_service.dart#L23-L60)

#### Officer Workflow
An officer views all active tasks, opens a task detail, and advances the status using one primary button. The UI shows badges indicating whether a task came from the app or the AI camera.

```mermaid
sequenceDiagram
participant O as "Officer"
participant OT as "Task List"
participant OD as "Task Detail"
participant S as "Service Layer"
participant F as "Firestore"
O->>OT : Open task list
OT->>F : Stream active tasks
O->>OD : Open task detail
O->>S : Advance status
S->>F : Update status, history, officer
F-->>O : Refresh task list and detail
```

**Diagram sources**
- [PROJECT.md:132-133](file://PROJECT.md#L132-L133)
- [permintaan_service.dart:70-78](file://whoosh_ramah/lib/services/permintaan_service.dart#L70-L78)
- [permintaan_service.dart:92-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L92-L119)

#### Family Workflow
A family member monitors the latest assistance request for a specific passenger ID. The screen shows current status, journey progress, and a timestamped history.

```mermaid
sequenceDiagram
participant K as "Family Member"
participant KP as "Monitoring Screen"
participant S as "Service Layer"
participant F as "Firestore"
K->>KP : Open monitoring screen
KP->>S : Stream latest request by passenger ID
S->>F : Query by idPenumpang
F-->>KP : Latest Permintaan
KP-->>K : Show status, progress, history
```

**Diagram sources**
- [PROJECT.md:134-135](file://PROJECT.md#L134-L135)
- [permintaan_service.dart:80-90](file://whoosh_ramah/lib/services/permintaan_service.dart#L80-L90)

## Dependency Analysis
The Flutter app depends on Firebase Core and Cloud Firestore for initialization and real-time data access. The data model depends on Firestore types for timestamps and map conversion. The service layer depends on the data model and dummy data. The detector is independent of the Flutter app and communicates only through Firestore.

```mermaid
graph LR
Main["main.dart"] --> Theme["theme.dart"]
Main --> RoleScreen["pilih_peran_screen.dart"]
RoleScreen --> Screens["screens/*"]
Screens --> Models["models/permintaan.dart"]
Screens --> Services["services/permintaan_service.dart"]
Services --> Models
Services --> Dummy["data/dummy.dart"]
Detector["detector/detect_wheelchair.py"] --> Firestore["Cloud Firestore"]
Flutter["Flutter App"] --> Firestore
```

**Diagram sources**
- [main.dart:1-33](file://whoosh_ramah/lib/main.dart#L1-L33)
- [permintaan_service.dart:1-135](file://whoosh_ramah/lib/services/permintaan_service.dart#L1-L135)
- [permintaan.dart:1-213](file://whoosh_ramah/lib/models/permintaan.dart#L1-L213)
- [detector/README.md:39-61](file://detector/README.md#L39-L61)

Coupling and cohesion observations:
- The service layer isolates Firestore logic, improving testability and keeping screens focused on presentation.
- The data model centralizes enum mapping and serialization, reducing duplication across screens.
- The detector is decoupled from the app, communicating only through a stable Firestore schema.
- The design references are external to runtime code but guide UI consistency.

**Section sources**
- [PROJECT.md:179-203](file://PROJECT.md#L179-L203)
- [permintaan_service.dart:1-135](file://whoosh_ramah/lib/services/permintaan_service.dart#L1-L135)
- [permintaan.dart:1-213](file://whoosh_ramah/lib/models/permintaan.dart#L1-L213)

## Performance Considerations
- Firestore queries avoid composite indexes by limiting ordering to one field or sorting results client-side.
- The task list stream limits results to 100 documents to keep real-time updates manageable.
- The detector uses configuration options such as confidence threshold, consecutive frames, cooldown interval, and detection frequency to balance accuracy, performance, and API usage.
- The app relies on real-time streams rather than polling, reducing unnecessary network calls.

[No sources needed since this section provides general guidance]

## Troubleshooting Guide
Common issues and how to address them:
- If AI-detected tasks do not appear for officers, verify that the detector writes to the correct Firestore collection and that the schema matches the expected fields.
- If status updates do not propagate to passengers or family, confirm that the service correctly advances status, appends history, and updates timestamps.
- If the app crashes on documents from the detector, ensure null-safe handling for missing fields such as history, passenger ID, train details, and officer name.
- If the demo fails due to internet problems, prepare a backup demo video as recommended by the project checklist.
- If accessibility testing fails, ensure buttons meet minimum touch targets, icons have semantics or tooltips, and layouts remain usable at larger text sizes.

**Section sources**
- [PROJECT.md:95-108](file://PROJECT.md#L95-L108)
- [PROJECT.md:169-176](file://PROJECT.md#L169-L176)
- [PROJECT.md:237-243](file://PROJECT.md#L237-L243)
- [permintaan.dart:77-149](file://whoosh_ramah/lib/models/permintaan.dart#L77-L149)
- [permintaan_service.dart:92-119](file://whoosh_ramah/lib/services/permintaan_service.dart#L92-L119)

## Conclusion
Whoosh Ramah addresses a real operational gap in KCIC station assistance by digitizing and coordinating support for priority passengers. It brings together three user roles—passengers, officers, and family—into one coherent workflow, while optionally automating task creation through an AI camera detector. The hackathon scope keeps the prototype focused, accessible, and demonstrable, leaving production features like authentication, ticketing integration, payments, scheduling, and push notifications for future work. For international developers, the key takeaway is a simple but robust pattern: a Flutter frontend, a shared Firestore schema, and a separate AI component writing structured assistance tasks.

[No sources needed since this section summarizes without analyzing specific files]