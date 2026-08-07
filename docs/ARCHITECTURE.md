# Architecture — L!bra

Developer map for the Swift/SwiftUI video organization toolkit. User-facing
brand is **L!bra**; repo, binary, and Swift module names stay ASCII (`Libra`).

## Package layout

| Path | Role |
|------|------|
| `Sources/Libra/LibraApp.swift` | App entry, window shell |
| `Sources/Libra/LibraView.swift` | Tool picker and navigation |
| `Sources/Libra/ToolState.swift` | Per-tool scan/run state (`@MainActor`) |
| `Sources/Libra/Models.swift` | `Tool` enum, `VideoInfo`, results |
| `Sources/Libra/Services/` | Scan, probe, ffmpeg ops, iPhone sort logic |
| `Sources/Libra/Utilities/` | Brand, paths, logging, settings, updates |
| `Sources/Libra/Views/` | SwiftUI screens per tool |

## Tool catalog

Each sidebar tool owns a `ToolState` instance. **Dry run defaults on** for
every tool — preview renames/moves before applying.

| Tool | Purpose |
|------|---------|
| **ProVid** | Batch rename with resolution / workflow markers |
| **VidRes** | Resolution-based renaming |
| **ProMax** / **MaxVid** | ProRes / max-resolution workflows |
| **KeepName** | Preserve original names while organizing |
| **iPhone Sorter** | Classify phone-shot media (images + video) |
| **GPS Sorter** | Sort by GPS metadata |
| **Slo-Mo** | Slow-motion conversion (`slomoFactor`) |
| **1MinVid** | One-minute clip extraction |

## Scan → operate flow

```text
LibraView
  └─ ToolState.scan(paths:)
       └─ ScannerService.scan  (ffprobe metadata, extension filter)
  └─ ToolState.run(settings:ffmpegPath:ffprobePath:)
       └─ tool-specific service (FfmpegOps, IPhoneSortLogic, FileOps, …)
```

1. User selects folders; `ScannerService` walks extensions from settings.
2. `MediaProbe` / `ffprobe` populate `VideoInfo` (resolution, device hints).
3. **Run** applies the active tool. Unsupported files stay in `results` as
   skipped rows.

## External dependencies

**ffmpeg** and **ffprobe** are required for most tools. `AppState` resolves
them from Homebrew (`/opt/homebrew/bin`, `/usr/local/bin`) or prompts install
via Settings. `ProcessRunner` invokes binaries with hardened argument lists.

```bash
brew install ffmpeg
```

## Filename contract

`Services/FileNaming.swift` builds canonical names:

`OriginalName Resolution V|WFPS [🍎][📱][🌍] NNN.ext`

Resolution buckets, emoji device markers, and zero-padded sequence numbers are
defined in code — see that module before changing rename output.

## User data paths

| Path | Contents |
|------|----------|
| `~/Library/Application Support/L!bra/` | Settings JSON, logs |
| `~/Library/Caches/L!bra/` | Update check cache |

Constants: `Utilities/Paths.swift`, `Utilities/Settings.swift`.

## Testing

```bash
swift test   # requires full Xcode.app
```

iPhone Sorter verification harness:

```bash
./scripts/verify-iphone-sorter.sh
```

## Packaging

`scripts/build-mac.sh` expects a sibling `../../.razorcore` for branding and
DMG packaging. Output artifact: `build/Release/Libra.dmg` (display name on
volume: **L!bra**).

See [BUILD_AND_RELEASE.md](../BUILD_AND_RELEASE.md).

## Related docs

- [BUILD_AND_RELEASE.md](../BUILD_AND_RELEASE.md)
- [CONTRIBUTING.md](../CONTRIBUTING.md)
- [AGENTS.md](../AGENTS.md)
