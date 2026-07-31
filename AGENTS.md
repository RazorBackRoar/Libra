# L!bra AGENTS

Guidance for agents in this repository. Use with `../AGENTS.md`.

## Branding

**Rule of thumb:** if a human reads it → **L!bra**. If a machine/path/API must
be ASCII → **Libra**.

| Surface | Value | Why |
| --- | --- | --- |
| UI, Dock, About, menus, window title | **L!bra** | Product brand |
| Application Support / Caches folder | **L!bra** | User-visible path |
| Built `.app` / `.dmg` / volume name | **L!bra** | Finder-facing |
| Docs, issue templates, SECURITY subject | **L!bra** | Human-facing |
| GitHub repo | `RazorBackRoar/Libra` | GitHub disallows `!` |
| Local workspace folder | `Apps/Libra` | Matches GitHub |
| `appId` | `com.razorbackroar.libra` | reverse-DNS |
| Mach-O / `CFBundleExecutable` | `Libra` | Avoid `!` in binary name |
| Swift package / module / `Sources/Libra` | `Libra` | Swift identifiers |
| Swift type names (`LibraApp`, …) | `Libra…` | Code identifiers |

Constants: `Sources/Libra/Utilities/Brand.swift`.

## Purpose and entry points

Local-first macOS video organization toolkit. Swift + SwiftUI.

- App entry: `Sources/Libra/LibraApp.swift`
- UI views: `Sources/Libra/Views/`
- Services: `Sources/Libra/Services/`
- Utilities: `Sources/Libra/Utilities/`

### RazorCore contracts (v1.1)

| Module | Role |
| --- | --- |
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

`swift test` requires the full Xcode.app (XCTest); the command-line tools ship
without it.

Package a macOS `.app` and DMG with ad-hoc signing:

```zsh
./scripts/build-mac.sh
```

Output: `build/Release/L!bra.app` and `build/Release/L!bra.dmg` (executable
inside stays `Libra`).

## Repository rules

- Do not create `Shared/razorcore-swift/` for v1.1.
- Do not rename the GitHub repo to include `!`.
- Do not commit, push, or create branches unless explicitly requested.


## Automated Agent & Jules Integration Guidelines
- **Jules PR Auto-Merge**: Automated PRs created on branches starting with `sentinel-`, `bolt-`, or `palette-` are handled by GitHub Actions (`.github/workflows/jules-automerge.yml`).
- **No Duplicate Issue/PR Reopening**: Jules subagents must verify existing closed and open PRs before proposing repetitive fixes or contact info updates.
- **Branch Cleanup**: Head branches are deleted automatically upon squash-merge.

