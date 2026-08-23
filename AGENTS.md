# Libra AGENTS

Guidance for agents in this repository. Use with `../AGENTS.md`.

## Branding

Product brand and display name is **Libra** across all surfaces.

| Surface | Value | Why |
| --- | --- | --- |
| UI, Dock, About, menus, window title | **Libra** | Product brand |
| Application Support / Caches folder | **Libra** | User-visible path |
| Built `.app` / `.dmg` / volume name | **Libra** | Finder-facing |
| Docs, issue templates, SECURITY subject | **Libra** | Human-facing |
| GitHub repo | `RazorBackRoar/Libra` | GitHub repository |
| Local workspace folder | `Apps/Libra` | Matches GitHub |
| `appId` | `com.razorbackroar.libra` | reverse-DNS |
| Mach-O / `CFBundleExecutable` | `Libra` | Binary name |
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
| `Utilities/Paths.swift` | Application Support / cache / logs under **Libra** |
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

Local output: `build/Release/Libra.dmg`
(executable inside stays `Libra`). CI keeps `Libra.dmg`.

## Repository rules

- Do not create `Shared/razorcore-swift/` for v1.1.
- Do not commit, push, or create branches unless explicitly requested.


## Jules Repository Contract

Jules reads this repository-root `AGENTS.md` when it clones the repository. Parent workspace policy files are not available in that clone.

- Jules runs tasks in an Ubuntu VM; SwiftUI, AppKit, AVFoundation, macOS frameworks, packaged-app behavior, and Apple Silicon runtime behavior are not proven there.
- The repository's GitHub macOS `quality` workflow is authoritative for merge readiness.
- Daily audits must inspect existing open and recently closed PRs before proposing work, avoid duplicates, and open at most one focused PR per task.
- `sentinel-*` security, `bolt-*` performance, and `palette-*` design branches always require human review.
- Jules PRs are merged by the owner. There is no auto-merge workflow.
- PR descriptions must list changed files, risk, verification commands and results, benchmark evidence when relevant, and unverified paths.
- Never auto-merge runtime, dependency, lockfile, workflow, packaging, release, privacy, file-operation, or user-data changes.
- **Startup stdout banner:** `AppInfoProvider.printStartupInfo()` runs before `Log.shared.setup()` and is intentional stdout startup output. Do NOT replace `print()` in `AppInfoProvider` or CLI scripts with logger calls.
- **Directory fallbacks:** `Paths.applicationSupportDirectory()` and `Paths.cacheDirectory()` safely coalesce to `FileManager.default.temporaryDirectory`.
- **Pure logic tests only:** Background test generation should target pure Swift utilities (`FfmpegOps.timeout`, `FileNaming`, `GPSCoordinateParser`) under `Tests/LibraTests/` without modifying core file operations, SwiftUI views, or GPS clustering algorithms.

## Automated Agent & Jules Integration Guidelines
- **Jules PR Review**: all Jules PRs require the owner to merge; there is no auto-merge workflow.
- **No Duplicate Issue/PR Reopening**: Jules subagents must verify existing closed and open PRs before proposing repetitive fixes or contact info updates.
- **Branch Cleanup**: Head branches are deleted automatically upon squash-merge.


### Jules Autonomous Execution Rules
- **Auto-Approve Plans**: Automatically approve execution plans for background suggestions (testing, code health, performance). Do not pause or wait for human plan approval on routine refactoring.
- **Batching**: Group related unit tests or code health fixes into a single PR rather than creating endless single-function PRs.

## Learned User Preferences
- Count labels should say photos and videos, never generic "files".
- User-facing preview is labeled Preview only; Desktop reports stay incrementing `Libra <Tool> Dry Run N.txt` files and must not overwrite earlier reports.
- After a drop, only preview; writing requires an explicit Write action. Turning Preview off must not start a write.
- Do not show container format (mov, mp4, …) in identification rows; the filename already includes it.
- Prefer taller layouts that avoid window scrollbars; numbered file lists (1, 2, 3…) may scroll in a small pane.
- After any change to an app under `Workspace/Apps/`, always rebuild that app’s DMG (`dist/<App>.dmg` or `build/Release/<App>.dmg` — for Libra that is `build/Release/Libra.dmg`). Do not wait to be asked.
- Home tile titles: Libra Sorter, iPhone Model Sort, GPS, Slo-Mo, 1-Min-Adjuster, Photos Only.

## Learned Workspace Facts
- Organization, rename, and sort tools must not require Homebrew ffmpeg; ffmpeg is optional for transform tools only.
- Libra is used on local disks only; iCloud and file-provider locations are out of scope.
- iPhone sort uses three folders: iPhone, Other Apple, and Not Apple.
- Photos is a sixth home tile named Photos Only, not a Video | Photos tab.
