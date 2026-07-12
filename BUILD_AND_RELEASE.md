# Build & Release — L!bra

Organization-standard build and release guide for
[RazorBackRoar/Libra](https://github.com/RazorBackRoar/Libra).

## Overview

L!bra is a native macOS app built with **Swift** / **SwiftUI**
(swift-tools 5.10+, macOS 14+), packaged with an ad-hoc signed `.app` / `.dmg`.

User-facing brand is **L!bra**; GitHub/repo/binary IDs stay ASCII (`Libra`).
Built artifacts: `L!bra.app` / `L!bra.dmg` (Mach-O inside remains `Libra`).

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
build/Release/L!bra.app
build/Release/L!bra.dmg
```

## Release Process

1. Ensure `main` is green (CI `swift build`).
2. Confirm version in `Sources/Libra/Resources/version.json`.
3. Run `./scripts/build-mac.sh`.
4. Install/smoke-test the `.app` (core happy path).
5. For GitHub, rename the asset to the machine-safe name: `cp "build/Release/L!bra.dmg" "build/Release/Libra.dmg"`.
   GitHub release asset names do not accept `!` — if you upload `L!bra.dmg`, it becomes `L.bra.dmg`.
6. Publish a GitHub Release with title `L!bra vX.Y.Z` and attach `build/Release/Libra.dmg`.
7. Tag `vX.Y.Z` to match `Sources/Libra/Resources/version.json`.

## Versioning Expectations

- Semantic Versioning in `Sources/Libra/Resources/version.json` (SSOT).
- Keep README version badges aligned when cutting a release.

## Troubleshooting

| Symptom | What to try |
|---------|-------------|
| `swift test` fails without XCTest | Install full Xcode.app, not only CLT |
| Gatekeeper blocks launch | Right-click → **Open** (ad-hoc signed builds) |
| Stale `/Applications` copy | Rebuild, then `ditto "build/Release/L!bra.app" "/Applications/L!bra.app"` |
| Window size restored huge | Quit app; relaunch after upgrading (defaults may cache old frames) |

## Related Docs

- [README.md](README.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)
- [SECURITY.md](SECURITY.md)
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
