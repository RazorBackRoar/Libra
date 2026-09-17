# Libra Progress

## Task: Post-audit megaplan (v1.4.0) + GPS map-first redesign

Shipped previously: **v1.3.0** on GitHub Releases (single release per policy).
Source/build version is **1.4.0** — not yet published.

### Phase 0 — Correctness & safety

- [x] `MediaKinds` extension sets behind `NSLock`-guarded box — no more cross-actor data race; settings edits still apply live
- [x] `hasAppleMake` word-boundary matching — "Pineapple Corp" no longer classifies as Apple
- [x] 1-Min-Adjuster in-place undo records the Trash URL (`trashedOriginal` + `createdCopy`); undo restores original bytes and removes the adjusted copy
- [x] Slo-Mo audio choice: `sloMoKeepAudio` setting (default on), `atempo` chaining below 0.5, `libopus` for WebM
- [x] `VideoInfo.warning` wired — "No embedded timestamp — using file date" surfaces in rows and scan recaps
- [x] Settings opens via `openSettings` environment + `LibraCommands.openSettings` notification (no selector string)
- [x] Photos Only parity — Cancel, Esc, all four menu notifications, cancellation inside `PhotoMover`/`UndoApply` loops; file picker is image-only (no generic `.data`)
- [x] `Log` file I/O on a serial `DispatchQueue` off the main actor; `maxLogBytes` nonisolated — debug and release builds are warning-free

### Phase 1 — Format honesty

- [x] Empirical AVFoundation probe on this machine: `mp4 mov m4v 3gp mts m2ts` read; `webm mkv avi` fail ("Cannot Open")
- [x] Default `videoExtensions` trimmed to the six readable containers; Settings stays editable with a note that unreadable containers are skipped
- [x] Bundled fixture per default extension (`fmt-probe.*`) probed through the real `MediaProbe` path in tests

### Phase 2 — GPS exact preview + performance

- [x] Explicit **Resolve city names** action — geocodes, rewrites Preview to exact `City, ST/` folders, caches for Write (no preview/write drift); unresolved files land in `GPS/` with a recap count
- [x] 5,000-item clustering benchmark — 500 clusters in ~1.6s (< 2s gate); test stays as regression guard

### GPS map-first redesign (megaplan 3)

- [x] `GPSMapModel` is a pure view model — no `GPSGeocoder` reference; opening/expanding/filtering the map makes zero geocoder calls
- [x] Base 5-mile clustering builds once per scan off the main actor (generation-guarded); count pills re-filter visible pins in O(clustered files) — no re-clustering per click
- [x] `gpsPlaceByPath` published from the explicit resolve feeds map labels; same-city pins merge deterministically
- [x] Write gated: coordinate-bearing batches require Resolve first (`gpsWriteBlockReason`); all-no-GPS batches write directly to `No-GPS/`; cancelled resolve keeps Write off; partial failures use `GPS/` + recap
- [x] GPS page: always-expanded primary map fills remaining space; bottom overlay shows city/coords + count + horizontally scrolling glossy filename buttons only (no thumbnails, ID rows, or embedded playback); no `ResultsTable`; count pills filter pins instead of opening `CategoryBrowserView`/`AVPlayerView`
- [x] Other tools keep the collapsible compact mini-map + full results table + category browser unchanged
- [x] Glossy treatment on all GPS controls (filter pills, Resolve, filename pills, Undo, Cancel, Write) via shared `LibraTheme` styles
- [x] Empty/no-coordinate/filter-empty map states show explanatory overlays

### Phase 3 — UI redesign

- [x] `LibraTheme.swift` — near-black base, `LibraCardFace` (yellow→gold→amber gradient, top gloss, inner bottom shadow, ambient shadow, hover lift + shine sweep), `libraPanel()` dark glass, yellow-gloss / dark-glass pill button styles, glossy filter + file pills
- [x] Applied across HomeView (six glossy cards, titles unchanged), ToolPage, ResultsTable, CountPills, DropZone, GPSMapPanel/Pin, CategoryBrowserView, PhotoSweepView, SettingsView, LibraView
- [x] Per-tool `ruleSummary` line under each page title reflecting real naming/folder rules

### Phase 4 — Docs & release

- [x] `version.json` → 1.4.0; README badge points at version.json (v1.4.0 not published yet — GitHub latest is v1.3.0)
- [x] README — deduped badge block; GPS map-first flow, explicit Resolve, map-filter pills, filename overlay documented
- [x] `docs/ARCHITECTURE.md` — LibraTheme, sole-owner geocode flow, MediaKinds lock, in-place undo, format-honesty note, primary/compact map modes
- [x] `docs/screenshots/app.png` refreshed — real run of the GPS map-first layout (selected pin, resolved city, filename overlay)
- [x] Selected-location card docks flush at the map's bottom edge, fully opaque (solid panel fill + gold top hairline), slides up on pin tap
- [x] Non-GPS tools: location details hide behind a full-width gold "Location details" button pinned at the section's bottom; clicking expands the mini-map upward above it (spring animation), chevron flips direction with state
- [x] Preview/Live control: custom `PreviewModeToggleStyle` — gold circle knob docked left on a gold-edged track while Preview only; flipping slides a white knob right onto an amber track and the label reads "Live"
- [x] Action button names the operation — "Rename N Videos" (sort family + iPhone: "Sort N Videos"), "Organize N Videos" (GPS), "Make N Slo-Mo", "Adjust N Timestamps", "Move N Photos"; confirm alert button uses the matching verb
- [ ] Manual UAT (owner): ⌘, Settings; drop→Preview vs Write; Cancel mid-scan; GPS pills→pins, resolve→Preview→Write gate, pin overlay filenames; iPhone sort; Photos Only; Slo-Mo audio on/off (MOV+WEBM); 1-Min copy + in-place + Undo; ~5k folder smoothness
- [ ] Release gate (explicit ask only): `razorbuild Libra`, SHA-256, `gh release create v1.4.0`, delete v1.3.0 release+tag

## Verification notes

- `swift build` + `swift build -c release` clean, zero warnings · `swift test` **113/113 green**
- Test isolation: `SettingsStore.fileURLOverride` + `DryRunReport.reportDirectoryOverride` — no real Desktop reports or settings writes from tests
- 1-Min in-place undo test restores original bytes via real Trash round-trip
- GPS geocode test seam: `GPSGeocoder.resolver` (tests stub it, restore in defer)
- GPS tests prove: map never geocodes, filters reuse base clusters, same-city merge, selection cleared on filter-out, Write blocked until Resolve, resolve publishes map names, preview shows exact folders
- Format gate: each default extension has a committed `fmt-probe.*` fixture that probes cleanly
- Live GPS verification (real app run): scan → pin click → bottom overlay with glossy filename pills + horizontal scroll; pill filters narrow pins without touching Preview/Write scope; Resolve rewrites pin/overlay to "Cupertino, CA" and Preview to exact folders; Write gated until Resolve, enabled after; write produced `Cupertino, CA/IMG_### 4K W60 🍎📱🌍 00N.mov`; Undo restored originals. Custom-annotation taps don't select via `Map(selection:)` on macOS — pins select via a `MapReader` onTap within ~24pt instead.
