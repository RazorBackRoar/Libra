# Build & Release — Libra

Organization-standard build and release guide for
[RazorBackRoar/Libra](https://github.com/RazorBackRoar/Libra).

## Overview

Libra is a native macOS app built with **Swift** / **SwiftUI**
(swift-tools 5.10+, macOS 14+), packaged with an ad-hoc signed `.app` / `.dmg`.

Built artifact is a single `Libra.dmg`; the `.app` bundle is consumed during packaging and not left in `build/Release`.

## Platform Requirements

| Requirement | Value |
|-------------|-------|
| OS | macOS 14+ |
| Arch | Apple Silicon (`arm64`) |
| Toolchain | Swift Package Manager (`swift`) |
| Tests | Full **Xcode.app** required for `swift test` (XCTest) |

## Prerequisites

```zsh
# Xcode Command Line Tools (or full Xcode)
xcode-select -p
cd /path/to/Libra
swift build
```

## Development Build

```zsh
swift build
swift run
```

`swift test` requires the full Xcode.app.

## Packaging

```zsh
./scripts/build-mac.sh
```

Output:

```text
build/Release/Libra.dmg
```

## Release Process

1. Ensure `main` is green (CI `swift build`).
2. Confirm version in `Sources/Libra/Resources/version.json`.
3. Run `./scripts/build-mac.sh`.
4. Install/smoke-test by mounting `build/Release/Libra.dmg` and dragging `Libra.app` to `/Applications`.
5. Publish a GitHub Release with title `Libra vX.Y.Z` and attach `build/Release/Libra.dmg`.
6. Tag `vX.Y.Z` to match `Sources/Libra/Resources/version.json`.

## Versioning Expectations

- Semantic Versioning in `Sources/Libra/Resources/version.json` (SSOT).
- Keep README version badges aligned when cutting a release.

## Troubleshooting

| Symptom | What to try |
|---------|-------------|
| `swift test` fails without XCTest | Install full Xcode.app, not only CLT |
| Gatekeeper blocks launch | Right-click → **Open** (ad-hoc signed builds) |
| Stale `/Applications` copy | Mount `build/Release/Libra.dmg` and drag `Libra.app` to `/Applications` |
| Window size restored huge | Quit app; relaunch after upgrading (defaults may cache old frames) |

## Related Docs

- [README.md](README.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)
- [SECURITY.md](SECURITY.md)
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
