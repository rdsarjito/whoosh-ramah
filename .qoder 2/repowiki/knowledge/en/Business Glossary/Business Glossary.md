---
kind: business_term
name: Business Glossary
category: business_term
scope:
    - '**'
---

### Whoosh Ramah
- Definition：Hackathon prototype name for the Whoosh high-speed train companion-assistance app. It lets priority passengers request station assistance, assigns trained KCIC officers, forwards data to the destination station, and lets families monitor — plus an AI camera that auto-creates tasks when it detects a wheelchair user at the entrance.
- Aliases：whoosh_ramah

### KCIC
- Definition：Kereta Cepat Indonesia-China, the operator of the Whoosh Jakarta–Bandung high-speed line. The app serves its priority passengers (elderly, disabled, pregnant, sick, unaccompanied minors) and its trained station officers.

### Permintaan Pendampingan
- Definition：A companion-assistance request — the Firestore document in collection `permintaan_pendampingan` representing one passenger's need for station assistance, tracked through the fixed status lifecycle `menunggu → ditugaskan → bertemu → di_kursi → selesai`.
- Aliases：permintaan、tugas

### Penumpang
- Definition：Role 0 in the app: a priority passenger who selects a jenis bantuan and titik jemput, submits a request, then follows the 5-step status timeline until handed over to the destination-station officer.

### Petugas
- Definition：Role 1 in the app: a KCIC station officer who receives tasks (from passengers or the AI camera), advances each task through the status stepper, and hands the passenger over at the destination station.

### Keluarga
- Definition：Role 2 in the app: a family member who monitors the latest request for `idPenumpang = demo-siti`, viewing current status, trip progress, and timestamped history.

### Kamera AI
- Definition：External detector window (not built in Flutter) that watches a station-camera feed, detects wheelchair users, and writes a task to Firestore with `sumber='kamera_ai'`. On the officer list it is flagged with a red 'Kamera AI' badge.
- Aliases：detektor、AI camera

### Titik Jemput
- Definition：Pickup point chosen by the passenger (or set by the camera as a full location string). For camera tasks the value is the full string such as 'Stasiun Halim - Pintu Masuk Utara'; the app derives the short form ('Pintu Masuk Utara') by taking the part after ' - '.
- Aliases：titikjemput

### Jenis Bantuan
- Definition：Type of assistance requested by a passenger. Enum values: `kursi_roda`, `tunanetra`, `tuli`, `lansia`, `hamil`, `porter`. Display labels: Kursi roda, Tunanetra, Tuli, Lansia, Ibu hamil, Porter barang.
- Aliases：jenisbantuan

### Status Permintaan
- Definition：Fixed lifecycle of a permintaan: `menunggu` (request received) → `ditugaskan` (officer assigned) → `bertemu` (met the passenger) → `di_kursi` (seated) → `selesai` (handed over to destination-station officer). Each step has display labels for passengers/family and a button label for officers.
- Aliases：status

### demo-siti
- Definition：Hard-coded passenger identity `idPenumpang = demo-siti` (Siti Aminah) used throughout dummy data and the family-monitoring screen.

### G1123
- Definition：Dummy active ticket number: Whoosh G1123, departing Halim 08.10, arriving Tegalluar 08.56, Saturday 22 Nov, Gerbong 5, Kursi 7A, Premium Economy, labeled 'Tiket contoh'.

### Rina
- Definition：Dummy officer name used as default when a task becomes `ditugaskan` (`petugas: 'Rina'`) and displayed on the officer card and family screen.

### Halim
- Definition：Dummy origin station (`stasiunAsal`) for the G1123 ticket and the camera-detector scenario.

### Tegalluar
- Definition：Dummy destination station (`stasiunTujuan`) for the G1123 ticket; appears in design copy such as 'Serahkan ke petugas Tegalluar' and 'Dijemput petugas di Tegalluar'.
