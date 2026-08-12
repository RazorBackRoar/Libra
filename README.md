# L!bra

[![Download](https://img.shields.io/github/v/release/RazorBackRoar/Libra?style=for-the-badge&label=Download%20DMG&color=d32f2f)](https://github.com/RazorBackRoar/Libra/releases/latest)
[![CI](https://img.shields.io/github/actions/workflow/status/RazorBackRoar/Libra/ci.yml?branch=main&style=for-the-badge&label=CI)](https://github.com/RazorBackRoar/Libra/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blueviolet?style=for-the-badge)](LICENSE)
[![Swift](https://img.shields.io/badge/Swift-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org/)
[![macOS](https://img.shields.io/badge/mac%20os-Apple%20Silicon-d32f2f?style=for-the-badge&logo=apple&logoColor=white)](https://support.apple.com/en-us/HT211814)
[![MapKit](https://img.shields.io/badge/MapKit-City%20%2F%20GPS-c9a227?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/documentation/mapkit)

**Local-first macOS video organization toolkit.**

Drag folders onto a tool, preview with Dry Run, and tidy libraries on your machine — sort, rename, slow-mo, 1-minute stamps, plus GPS / iPhone helpers with a built-in **City / GPS Map** (5-mile pins). The user-facing brand is **L!bra**; the GitHub repo and machine IDs stay ASCII (`Libra`).

<p align="center">
  <a href="https://github.com/RazorBackRoar/Libra/releases/latest/download/Libra.dmg"><strong>↓ Download Libra.dmg</strong></a>
  ·
  <a href="https://github.com/RazorBackRoar/Libra/releases">All releases</a>
</p>

![L!bra](docs/screenshots/app.png)

## Features

- **Drag-and-drop tools** — drop a folder to scan; Dry Run previews automatically, live writes ask first
- **Undo last run** — put moved files back (or delete created copies)
- **Dry Run first** — bright yellow toggle; Desktop reports named `L!bra ProVid Dry Run 1.txt` (tool name swaps per mode)
- **Sort & rename** — ProVid, VidRes, ProMax, MaxVid; KeepName keeps original filenames
- **City / GPS Map** — MapKit pins clustered within **5 miles**, merged by city
- **GPS Sorter** — city folders from coordinates, `No-GPS` when missing; photos welcome
- **Optional date / camera folders** — extra sort keys on the sort tools
- **Duplicates** — likely extras (same size, duration, name) go in a Duplicates folder
- **iPhone Sorter** — iPhone / Not iPhone, including photos
- **Transform** — Slo-Mo copies and 1MinVid sequential timestamps (these need ffmpeg)
- **Resilient import** — cancelable scans; per-file probe failures don’t stall the batch
- **Local-first** — nothing leaves your Mac
- **Native SwiftUI** — Apple Silicon macOS app, ad-hoc signed DMG

## Install

1. Download [`Libra.dmg`](https://github.com/RazorBackRoar/Libra/releases/latest/download/Libra.dmg)
2. Open the DMG and drag **L!bra.app** to `/Applications`
3. First launch — right-click → **Open** (ad-hoc signed build)

Requires macOS 14+ on Apple Silicon. ffmpeg / ffprobe via Homebrew when transforms need them.

## Usage

1. Open **L!bra** and pick a tool (ProVid, GPS Sorter, …)
2. Drop a folder or video files (or use Open Folder / Select Files)
3. Leave **Dry Run** on to preview; turn it off and confirm when you’re ready to write
4. Use **Undo last run** if a live pass wasn’t what you wanted
5. Use the City / GPS Map pins to inspect locations (5-mile / city clusters)
6. Review results on disk — click a row to Reveal in Finder

## Development

```bash
swift build
swift run
```

`swift test` requires the full Xcode.app (XCTest).

Package a macOS `.app` + DMG (ad-hoc signed):

```bash
./scripts/build-mac.sh
# → build/Release/Libra.dmg
# → ~/Desktop/L!bra.dmg (local handoff)
```

| Surface | Value |
|---------|-------|
| Display name (UI, Dock, `.app`, DMG) | **L!bra** |
| GitHub | [RazorBackRoar/Libra](https://github.com/RazorBackRoar/Libra) |
| appId | `com.razorbackroar.libra` |
| Version | `Sources/Libra/Resources/version.json` |

## Docs

- [BUILD_AND_RELEASE.md](BUILD_AND_RELEASE.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)
- [SECURITY.md](SECURITY.md)
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)

## License

MIT — see [LICENSE](LICENSE).

If you need me, give me a holler.
