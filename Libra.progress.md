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
- [x] Home cards restyled — near-black faces with a subtle pale-gold wash over black, thin gold gradient border, gold icon/chip accents, compact fixed 148pt height; gold liner border tracing the whole window edge on every page (`LibraView`)
- [x] Window hugs content — `LibraView.resizeWindow` animates the window to 900×445 on home and 900×860 on tool pages (top edge anchored, clamped to the visible frame); home min size 780×430, `defaultSize` 900×445
- [x] Window chrome reverted per owner: gold border removed entirely, `.fullSizeContentView` removed so traffic lights render normal colored buttons on a standard transparent titlebar (verified focused-state capture)
- [x] Restrained-gold pass (verified via window capture): "Libra" is plain semibold white with 2.5pt tracking — outline removed; short gold accent line beneath header; cards are charcoal with a faint top gold tint, muted bronze borders warming to gold on hover, quiet gray uppercase category labels (pills removed), regular-weight descriptions, and glow only on hover
- [x] `docs/screenshots/app.png` refreshed with the restrained-gold home
- [ ] Owner visual verification of the corrected frame overlay and spaced title in the rebuilt DMG; earlier screenshot-verification claims did not establish that the top edge was correct
- [x] razorcore release policy: `publish_release` deletes prior releases+tags by default (one release per app); opt-out `--keep-old` / `RAZORCORE_KEEP_OLD_RELEASES=1`; stale Libra v1.3.0 and MetaBurn v2.2.10 releases+tags removed — all 8 apps show one Latest release each
- [ ] Manual UAT (owner): ⌘, Settings; drop→Preview vs Write; Cancel mid-scan; GPS pills→pins, resolve→Preview→Write gate, pin overlay filenames; iPhone sort; Photos Only; Slo-Mo audio on/off (MOV+WEBM); 1-Min copy + in-place + Undo; ~5k folder smoothness
- [ ] Release gate (explicit ask only): `razorbuild Libra`, SHA-256, `gh release create v1.4.0`, delete v1.3.0 release+tag

### Owner-requested GPS + filter redesign (Sep 17)

- [x] Filter buttons restored as real clickable capsules — gold-bordered dark pills in the exact contract order **SD → 720p → HD → 1080p → FHD → QHD → 4K → 30 → 60 → 120 → iPhone → Apple** (`MediaBrowserFilter.fps` added; bare numbers, no "FPS" text); non-GPS tools open the category browser, GPS page filters map pins
- [x] Radius clustering removed entirely — `GPSMapClustering.groups` buckets by resolved city name (one pin per city regardless of distance); unresolved media shows one pin per recorded spot (~11 m dedupe, no distance merging); every group's files sort by creation date then path
- [x] Geocoding buckets at ~1.1 km (`geocodeKey`) purely for API thrift — city name is the only grouping mechanism; Preview/Write still share the resolve cache; Write still gated until Resolve
- [x] Duplicates feature removed completely — `DuplicateDetector.swift` + tests deleted, `sortDuplicatesIntoFolder` setting gone, pill/toggle/Settings entries and "Duplicates/" folder logic all removed
- [x] GPS page checkboxes removed — `showsExtraFolderToggles` no longer includes `.gps`, so "Also sort by date / camera / Duplicates" never appear and city folders stay pure `City, ST/`
- [x] Map pin hover highlight — pins brighten/enlarge/glow on hover; click still opens the bottom overlay listing that group's files (creation-date order)
- [x] `GPSMapModel` regrouped synchronously — `isClustering`/detached build removed (dictionary bucketing is cheap at 5k files); benchmark tests updated
- [ ] Owner visual verification — Mac was locked during implementation; build/test/DMG all green but the new GPS page and buttons need a live look

## Verification notes

- `swift build` + `swift build -c release` clean, zero warnings · `swift test` **109/109 green** (5 duplicate tests removed; city-grouping tests added)
- Test isolation: `SettingsStore.fileURLOverride` + `DryRunReport.reportDirectoryOverride` — no real Desktop reports or settings writes from tests
- 1-Min in-place undo test restores original bytes via real Trash round-trip
- GPS geocode test seam: `GPSGeocoder.resolver` (tests stub it, restore in defer)
- GPS tests prove: map never geocodes, filters reuse base clusters, same-city merge, selection cleared on filter-out, Write blocked until Resolve, resolve publishes map names, preview shows exact folders
- Format gate: each default extension has a committed `fmt-probe.*` fixture that probes cleanly
- Live GPS verification (real app run): scan → pin click → bottom overlay with glossy filename pills + horizontal scroll; pill filters narrow pins without touching Preview/Write scope; Resolve rewrites pin/overlay to "Cupertino, CA" and Preview to exact folders; Write gated until Resolve, enabled after; write produced `Cupertino, CA/IMG_### 4K W60 🍎📱🌍 00N.mov`; Undo restored originals. Custom-annotation taps don't select via `Map(selection:)` on macOS — pins select via a `MapReader` onTap within ~24pt instead.

## Follow-up: extra-folder options removed entirely

- [x] "Also sort by date" / "Also sort by camera" removed from **all** tool pages (Libra Sorter, iPhone Model Sort) and Settings — `sortByDate`/`sortByCamera` settings, `extraFolderParts`, `showsExtraFolderToggles`, `Tool.supportsExtraFolders`, `dayFormatter` all deleted; destination folders are pure `City, ST/` / sort-layout / iPhone-classification only
- [x] Filename examples removed from all `ruleSummary` strings, the sort-controls "Example:" line, and the prefix-field help — no `Name 4K W30 …` patterns anywhere in the UI
- [x] Verified live via AX on rebuilt binary: GPS, Libra Sorter, and iPhone Model Sort pages each show only the Preview toggle; summaries clean
- [x] `swift build` clean · `swift test` 109/109 · `build/Release/Libra.dmg` + `~/Desktop/Libra.dmg` rebuilt

## GPS page: state buttons + footer counts + Finder reveal

- [x] GPS ruleSummary line removed — header is Back + "GPS" + state buttons only
- [x] `GPSStateStrip` — big gold state capsules right of the title, right-aligned, largest state rightmost and each smaller one extending left (order = file count desc); click pops a panel of that state's cities with per-city photo/video counts; right-click a city → Reveal in Finder
- [x] Footer counts on GPS page: GPS · No GPS · iPhone · Unknown as gold capsule map filters between Preview and Organize (`.noGps` + `.unknown` added to MediaBrowserFilter; `.gps` now matches `hasCoordinates`)
- [x] Right-click Reveal in Finder on map pins and the selected-city overlay header; `MediaOpen.reveal([paths])` added
- [x] `swift test` 113/113 · `build/Release/Libra.dmg` + `~/Desktop/Libra.dmg` rebuilt

## Collapsible map on all tool pages

- [x] `GPSMapPanel` (compact) now renders unconditionally on every non-GPS tool page — the gold "Location details" button no longer waits for coordinate-bearing files; opens/closes on click (empty map + hint when no GPS media)
- [x] Verified live on test build by PID (earlier dumps hit the installed /Applications copy — two same-named processes): button present on empty Libra Sorter page, expands to mini-map on click
- [x] `swift test` 113/113 · `build/Release/Libra.dmg` + `~/Desktop/Libra.dmg` rebuilt
