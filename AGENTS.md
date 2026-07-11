# L!bra AGENTS

Guidance for agents in this repository. Use with `../AGENTS.md`.

## Branding

| Surface | Value | Why |
|---------|-------|-----|
| Display (UI, Dock, About, menus, Application Support) | **L!bra** | Product brand |
| GitHub | `RazorBackRoar/Libra` | GitHub disallows `!` |
| `appId` | `com.razorbackroar.libra` | reverse-DNS |
| `productName` / app name | `L!bra` | User-facing |
| Executable / Mach-O name | `Libra` | Avoid `!` in binary name |

Constants: `Sources/Libra/Utilities/Brand.swift`.

## Purpose and entry points

Local-first macOS video organization toolkit. Swift + SwiftUI.

- App entry: `Sources/Libra/LibraApp.swift`
- UI views: `Sources/Libra/Views/`
- Services: `Sources/Libra/Services/`
- Utilities: `Sources/Libra/Utilities/`

### RazorCore contracts (v1.1)

| Module | Role |
|--------|------|
| `Utilities/Brand.swift` | Display vs machine-safe IDs |
| `Utilities/Paths.swift` | Application Support / cache / logs under **L!bra** |
| `Utilities/Logging.swift` | Console + file logs under Application Support |
| `Utilities/AppInfo.swift` | Metadata + startup banner |
| `Utilities/Updates.swift` | GitHub Releases check (`RazorBackRoar/Libra`) |
| `Utilities/Settings.swift` | Persistent JSON settings |

## Commands

```zsh
swift build
swift run
```

`swift test` requires the full Xcode.app (XCTest); the command-line tools ship without it.

Package a macOS `.app` and DMG with ad-hoc signing:

```zsh
./scripts/build-mac.sh
```

Output: `build/Release/Libra.app` and `build/Release/Libra.dmg`.

## Repository rules

- Do not create `Shared/razorcore-swift/` for v1.1.
- Do not rename the GitHub repo to include `!`.
- Do not commit, push, or create branches unless explicitly requested.
