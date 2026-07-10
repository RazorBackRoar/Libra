# L!bra

[![Version](https://img.shields.io/badge/version-1.0.0-blue?style=for-the-badge)](Sources/Libra/Resources/version.json)
[![License: MIT](https://img.shields.io/badge/license-MIT-blueviolet?style=for-the-badge)](LICENSE)
[![Swift](https://img.shields.io/badge/Swift-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org/)
[![macOS](https://img.shields.io/badge/mac%20os-Apple%20Silicon-d32f2f?style=for-the-badge&logo=apple&logoColor=white)](https://support.apple.com/en-us/HT211814)

> **TL;DR:** Local-first macOS video organization toolkit. User-facing brand is **L!bra**; the GitHub repo and npm package stay ASCII (`Libra` / `l-bra`).

## Branding

| Surface | Value |
|---------|-------|
| Display name | **L!bra** |
| GitHub | [RazorBackRoar/Libra](https://github.com/RazorBackRoar/Libra) |
| npm | `l-bra` |
| appId | `com.razorbackroar.libra` |
| Executable | `Libra` |

## Development

```bash
swift build
swift run
```

`swift test` requires the full Xcode.app (XCTest).

Package a macOS `.app` and DMG with ad-hoc signing:

```bash
./scripts/build-mac.sh
```

Output: `build/Release/Libra.app` and `build/Release/Libra.dmg`.

## License

MIT — see [LICENSE](LICENSE).
