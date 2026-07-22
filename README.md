# L!bra

[![Download](https://img.shields.io/github/v/release/RazorBackRoar/Libra?style=for-the-badge&label=Download%20DMG&color=d32f2f)](https://github.com/RazorBackRoar/Libra/releases/latest)
[![CI](https://img.shields.io/github/actions/workflow/status/RazorBackRoar/Libra/ci.yml?branch=main&style=for-the-badge&label=CI)](https://github.com/RazorBackRoar/Libra/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blueviolet?style=for-the-badge)](LICENSE)
[![Swift](https://img.shields.io/badge/Swift-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org/)
[![macOS](https://img.shields.io/badge/mac%20os-Apple%20Silicon-d32f2f?style=for-the-badge&logo=apple&logoColor=white)](https://support.apple.com/en-us/HT211814)

**Local-first macOS video organization toolkit.**

Sort, rename, and tidy video libraries with GPS / iPhone-oriented helpers — all on your machine. The user-facing brand is **L!bra**; the GitHub repo and machine IDs stay ASCII (`Libra`).

<p align="center">
  <a href="https://github.com/RazorBackRoar/Libra/releases/latest/download/Libra.dmg"><strong>↓ Download Libra.dmg</strong></a>
  ·
  <a href="https://github.com/RazorBackRoar/Libra/releases">All releases</a>
</p>

![L!bra](docs/screenshots/app.png)

## Features

- **Local-first** — organize videos without cloud upload
- **Sort & rename** — batch-friendly video library cleanup
- **GPS / iPhone tools** — helpers for phone-shot media workflows
- **Native SwiftUI** — Apple Silicon macOS app
- **Safe packaging** — ad-hoc signed DMG from Releases

## Install

1. Download [`Libra.dmg`](https://github.com/RazorBackRoar/Libra/releases/latest/download/Libra.dmg)
2. Open the DMG and drag **L!bra.app** to `/Applications`
3. First launch — right-click → **Open** (ad-hoc signed build)

Requires macOS on Apple Silicon.

## Usage

1. Open **L!bra**
2. Point it at the folders you want organized
3. Sort / rename / apply GPS or iPhone helpers as needed
4. Review results on disk — nothing leaves your Mac

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
```

| Surface | Value |
|---------|-------|
| Display name (UI, Dock, `.app`, DMG) | **L!bra** |
| GitHub | [RazorBackRoar/Libra](https://github.com/RazorBackRoar/Libra) |
| appId | `com.razorbackroar.libra` |

## Docs

- [BUILD_AND_RELEASE.md](BUILD_AND_RELEASE.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)
- [SECURITY.md](SECURITY.md)
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)

## License

MIT — see [LICENSE](LICENSE).
