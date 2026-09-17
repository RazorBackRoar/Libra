# Architecture — Libra

Developer map for the native macOS media organizer (SwiftUI + AppKit interop, Swift Package Manager).

## Module Layout

| Component | Role |
| --- | --- |
| `Sources/Libra/LibraApp.swift` | `@main` entry point, `NSApplicationDelegateAdaptor`, menu bar |
| `Sources/Libra/AppState.swift` | App-wide `@MainActor` singleton — ffmpeg path resolution. Organize tools do not use ffprobe. |
| `Sources/Libra/ToolState.swift` | Per-tool `@MainActor` state — scan, preview, write, in-memory undo |
| `Sources/Libra/Models.swift` | `Tool` enum, `VideoInfo`, `OperationResult`, `UndoRecord`, `AppSettings` |
| `Sources/Libra/Views/` | SwiftUI views (`HomeView`, `ToolPage`, `GPSMapView`, `SettingsView`, `PhotoSweepView`, …) |
| `Sources/Libra/Views/LibraTheme.swift` | Design tokens — glossy yellow cards on near-black, `LibraCardFace`, `libraPanel()`, pill button styles |
| `Sources/Libra/Services/Scanner.swift` (`ScannerService`) | Bounded-concurrency directory walk + per-file probe (`TaskGroup`) |
| `Sources/Libra/Services/MediaProbe.swift` | Metadata via `AVFoundation` / `ImageIO` — no shelled-out `ffprobe` |
| `Sources/Libra/Services/MediaClassification.swift` | Resolution bucket (8K/4K/1440p/…) and orientation from displayed size |
| `Sources/Libra/Services/MediaIdentification.swift` | Identification row: resolution, fps, iPhone/Apple, GPS coordinates (never container) |
| `Sources/Libra/Services/FileOps.swift` | Symlink- and path-containment-checked move/copy/delete/rename/trash |
| `Sources/Libra/Services/FfmpegOps.swift` | `ffmpeg` for Slo-Mo copies and 1-Min-Adjuster timestamp remux; never overwrites an existing dest |
| `Sources/Libra/Services/ProcessRunner.swift` | `Process` wrapper — cancellation, timeout, SIGTERM→grace→SIGKILL |
| `Sources/Libra/Services/DuplicateDetector.swift` | Likely-duplicate heuristic: same size, duration, resolution, fps, codec (not a content hash) |
| `Sources/Libra/Services/UndoApply.swift` | Replays the `UndoRecord` log — moves files back or deletes created copies |
| `Sources/Libra/Services/ScanSafety.swift` | Warns before scanning `/`, home, Desktop, or a volume root, and before large batches |
| `Sources/Libra/Services/GPSGeocoder.swift`, `GPSMapModel.swift`, `GPSCoordinateParser.swift` | `CLGeocoder` on explicit "Resolve city names" / map expand / Write fallback, 5-mile pin clustering, ImageIO / ISO6709 coordinates |
| `Sources/Libra/Services/IPhoneSortLogic.swift` | iPhone / Other Apple / Not Apple classification |
| `Sources/Libra/Services/FileNaming.swift` | Standardized output filenames (resolution/orientation/fps/index) |
| `Sources/Libra/Services/PhotoMover.swift` | Moves stills out of mixed video folders |
| `Sources/Libra/Services/DryRunReport.swift` | Numbered before/after `.txt` reports on the Desktop |
| `Sources/Libra/Services/RunRecap.swift` | Human-readable summary after a run |
| `Sources/Libra/Utilities/` | `Brand`, `Paths`, `Logging`, `AppInfo`, `Updates` (GitHub Releases check), `Settings`, `LibraCommands`, `MediaOpen` |

## Data Flow

Drop/select a folder → `ScanSafety` path + count warnings → `ScannerService.scan` (bounded concurrent `MediaProbe`) → preview pass (Preview only is the default) → explicit **Write** with an `NSAlert` confirmation → `FileOps` / `FfmpegOps` write → an `UndoRecord` is kept in memory → `UndoApply` can replay it until the next scan or quit.

Home is a 3×2 grid: Libra Sorter, iPhone Model Sort, GPS, Slo-Mo, 1-Min-Adjuster, Photos Only. Libra Sorter opens as `.provid`; Filename / Folders pickers cover the legacy sort presets.

## Threading Model

- All `ObservableObject` state (`AppState`, `ToolState`, `SettingsStore`, `GPSMapModel`, `PhotoSweepState`) is `@MainActor`.
- Scanning and ffmpeg work run in `Task` / `TaskGroup`, reporting back via `@Sendable` progress closures.
- `ProcessRunner` guards continuation resumption with an `NSLock` + `hasResumed` flag.
- `MediaKinds` extension sets sit behind an `NSLock`-guarded box — background probes read a synchronized snapshot while `SettingsStore` edits apply live on the main actor.
- `Log` file appends run on a serial `DispatchQueue` off the main actor.

## Safety Model

Destructive operations are preview-only by default, require an explicit **Write** (or Move photos) plus a confirmation dialog when that setting is on, and log an in-memory undo journal for the current run. Turning Preview off does not start a write. `FileOps` rejects symlinks and checks physical path containment before any move/copy/delete, independent of the UI confirmations.

- GPS Sorter preview uses `GPS` / `No-GPS` folders until the explicit **Resolve city names** action geocodes and fills exact `City, ST/` destinations; the cached map is reused by Write so preview and write can't drift apart. If resolve is skipped, Write geocodes inline. The map starts expanded on the GPS tool only; other tools keep it collapsed so identification rows stay the GPS surface. The map geocodes when expanded. Identification rows always show coordinates when present.
- 1-Min-Adjuster inplace mode writes the new file, then moves the original to Trash (not a permanent delete) — the Trash URL is recorded so Undo restores the original bytes and removes the adjusted copy.
- Photos Only uses the same large-scan confirm as video tools. Photo undo goes through `UndoApply`.

## Verification

CI (`.github/workflows/ci.yml`) runs `swift build` and `swift test` on a macOS runner. `Tests/LibraTests/` covers the pure-logic services, the GPS 5,000-item clustering benchmark, and the in-place undo byte-restore path.

Default video extensions are limited to containers AVFoundation actually reads (`mp4`, `mov`, `m4v`, `mts`, `m2ts`, `3gp`); `mkv`/`avi`/`webm` report "metadata unreadable" and are skipped by every tool.
