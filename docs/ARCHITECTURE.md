# Architecture — Libra

Developer map for the native macOS media organizer, deduplication engine, and duplicate triage app (AppKit + Swift).

## Module Layout

| Component | Role |
|---|---|
| `Libra/DuplicateDetector.swift` | Perceptual hashing, byte-level comparison, and cluster scoring |
| `Libra/ScannerService.swift` | Multithreaded file system scanner with safety guards against system paths |
| `Libra/MediaProbe.swift` | ExifTool / AVFoundation metadata extractor (GPS, creation dates, camera tags) |
| `Libra/UndoManager.swift` | Transactional rollback log for batch file renames and moves |

## Playback & Threading Model

- **Engine:** Swift Concurrency (`TaskGroup`, `actor`) for background hashing without UI hitches.
- **Safety:** Read-only analysis by default. Destructive operations require explicit user confirmation and generate undo journals.

## Verification

CI executes full Swift Package Manager test suites via `swift test` across all 13 core test files.
