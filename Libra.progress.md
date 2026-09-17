# Libra Progress

## Task: Post-audit megaplan (v1.4.0)

Shipped previously: **v1.3.0** on GitHub Releases (single release per policy).

### Phase 0 — Correctness & safety

- [x] `MediaKinds` extension sets behind `NSLock`-guarded box — no more cross-actor data race; settings edits still apply live
- [x] `hasAppleMake` word-boundary matching — "Pineapple Corp" no longer classifies as Apple
- [x] 1-Min-Adjuster in-place undo records the Trash URL (`trashedOriginal` + `createdCopy`); undo restores original bytes and removes the adjusted copy
- [x] Slo-Mo audio choice: `sloMoKeepAudio` setting (default on), `atempo` chaining below 0.5, `libopus` for WebM
- [x] `VideoInfo.warning` wired — "No embedded timestamp — used file date" surfaces in rows and scan recaps
- [x] Settings opens via `openSettings` environment + `LibraCommands.openSettings` notification (no selector string)
- [x] Photos Only parity — Cancel, Esc, all four menu notifications, cancellation inside `PhotoMover`/`UndoApply` loops
- [x] `Log` file I/O on a serial `DispatchQueue` off the main actor

### Phase 1 — Format honesty

- [x] Empirical AVFoundation probe on this machine: `mp4 mov m4v 3gp mts m2ts` read; `webm mkv avi` fail ("Cannot Open")
- [x] Default `videoExtensions` trimmed to the six readable containers; Settings stays editable with a note that unreadable containers are skipped
- [x] Test pins defaults to the verified set

### Phase 2 — GPS

- [x] Explicit **Resolve city names** action — geocodes, rewrites Preview to exact `City, ST/` folders, caches for Write (no preview/write drift); skipped resolve still geocodes at Write; unresolved files land in `GPS/` with a recap count
- [x] 5,000-item clustering benchmark — 500 clusters in ~1.6s (< 2s gate), no rewrite needed; test stays as regression guard

### Phase 3 — UI redesign

- [x] `LibraTheme.swift` — near-black base, `LibraCardFace` (yellow→gold→amber gradient, top gloss, inner bottom shadow, ambient shadow, hover lift + shine sweep), `libraPanel()` dark glass, yellow-gloss / dark-glass pill button styles
- [x] Applied across HomeView (six glossy cards, titles unchanged), ToolPage, ResultsTable, CountPills, DropZone, GPSMapPanel/Pin, CategoryBrowserView, PhotoSweepView, SettingsView, LibraView
- [x] Per-tool `ruleSummary` line under each page title reflecting real naming/folder rules

### Phase 4 — Docs & release

- [x] `version.json` → 1.4.0, README badge aligned
- [x] README — deduped badge block, GPS resolve + Slo-Mo audio + 1-Min undo documented
- [x] `docs/ARCHITECTURE.md` — LibraTheme, geocode flow, MediaKinds lock, in-place undo, format-honesty note
- [ ] `docs/screenshots/app.png` refresh after UI (needs a real app run)
- [ ] Manual UAT (owner): ⌘, Settings; drop→Preview vs Write; Cancel mid-scan; GPS resolve→Preview→Write; iPhone sort; Photos Only; Slo-Mo audio on/off (MOV+WEBM); 1-Min copy + in-place + Undo; ~5k folder smoothness
- [ ] Release gate (explicit ask only): `razorbuild Libra`, SHA-256, `gh release create v1.4.0`, delete v1.3.0 release+tag

## Verification notes

- `swift build` clean · `swift test` **99/99 green**
- Test isolation: `SettingsStore.fileURLOverride` + `DryRunReport.reportDirectoryOverride` — no real Desktop reports or settings writes from tests
- 1-Min in-place undo test restores original bytes via real Trash round-trip
- GPS geocode test seam: `GPSGeocoder.resolver` (tests stub it, restore in defer)
