# L!bra — Full Build Plan

## Context

L!bra is described in the prompt as an existing app needing a redesign, but exploration confirmed the app is currently an **empty Electron scaffold**: only the template home view, a single `/` route, stub IPC handlers, a theme-only Settings window, and no backend video logic. The prompt describing "the current Organizer split layout" etc. refers to a desired end-state, not existing code.

This plan therefore builds the **entire app from scratch in one pass**: a black/gold, drag-and-drop-first, local video toolkit with 12 tools, backed by ffprobe (metadata) and ffmpeg (write operations), with one-click Homebrew onboarding, Settings, session state persistence, and a consistent MaxVid-style page pattern across all tools.

Decisions confirmed with the user:
- **Delivery:** full build in one pass (all 12 tools + backend + Settings).
- **Tool defaults:** Re-encode Detector flags videos not in a preferred codec/container (non-H.264/HEVC MP4) as re-encode candidates; Slo-Mo Creator uses ffmpeg `setpts` slowdown at selectable 0.5x/0.25x, drops audio, writes dated output copies; Codec Checker is a read-only ffprobe report; GPS Sorter sorts into GPS / No-GPS folders from embedded location metadata.
- **ffmpeg onboarding:** detect missing ffmpeg/ffprobe on first launch/scan and show a macOS sheet with a large "Install with Homebrew" button + a manual custom-path secondary option.

The drag-drop path bridge is already wired: `renderer/preload.ts` exposes `webUtils` via `createWebUtilsAPI()`, so `window.electronAPI.webUtils.getPathForFile(file)` resolves Finder drop paths today. No preload change needed for that; sensitive APIs (shell.openPath) will be enabled in preload as needed.

## Visual language (black/gold) — applied globally

Establish once as reusable tokens/classes (in `renderer/styles.css` + small helpers), used by every page:
- near-black app background; dark card surfaces; thin charcoal borders; white titles; **gold section labels**; large **gold primary buttons**; **black secondary buttons**; muted-gray helper text; subtle bronze/gold glow accents; rounded modern macOS panels/cards.
- Prefer design-system components + Tailwind semantic utilities; introduce a small set of gold accent classes (e.g. `--libra-gold`) rather than hand-rolled CSS files. Use `app-theming` + `app-component-patterns` when implementing.

## Architecture

### Backend engine (`main/services/`)
- `cli-utils.ts` — `isCliInstalled()`, resolve ffmpeg/ffprobe paths (Settings override → `which` → common Homebrew paths). `execFile` only, explicit `maxBuffer` + `timeout` (per `app-cli-dependencies`).
- `ffprobe.ts` — probe one file → normalized `VideoInfo`. Fields: `path, name, dir, ext, sizeBytes, width, height, resolutionClass (4K|1080p|720p|SD), orientation (landscape|portrait|square), fps, durationSec, codec, container, make, model, isApple, hasGPS, gps{lat,lon}, creationTime, error?`.
- `scanner.ts` — walk folder(s)/files, filter by configurable extensions, probe with bounded concurrency; emit progress; support cancel via job token.
- `hashing.ts` — streamed MD5 (exact-match duplicate detection, clearly labeled "Exact MD5").
- `file-ops.ts` — move/rename/copy/delete with **collision auto-suffix `(1),(2)…`**, never silent overwrite; per-file success/error results; dry-run support; used by all sort/rename/delete tools.
- `ffmpeg-ops.ts` — slo-mo (`setpts`), timestamp adjust (metadata `creation_time` + fs mtime), any re-encode writes. Cancelable child processes.
- `jobs.ts` — job registry keyed by `jobId`: tracks child processes / cancel flags, emits `job:progress` and `job:done` notifications, supports `job:cancel`.
- `settings-store.ts` — JSON persistence in `app.getPath("userData")`: ffmpeg/ffprobe paths, video extension list, dry-run defaults, last-folder-per-tool, basic filter states. (Follow `app-data-storage` / `app-backend-rules`.)

### IPC contract (`main/handlers/index.ts`, channel → shape)
- `deps:check` → `{ ffmpeg: bool, ffprobe: bool, ffmpegPath, ffprobePath }`
- `deps:install` → runs `brew install ffmpeg`; returns `{ success }` (long timeout).
- `scan:start` `{ jobId, paths: string[], extensions }` → begins scan; streams `job:progress` `{ jobId, done, total }` notifications; resolves `{ files: VideoInfo[] }`.
- `job:cancel` `{ jobId }` → `{ cancelled }`.
- `hash:duplicates` `{ jobId, paths|files }` → `{ groups: {hash, files[]}[] }` (streamed progress).
- `sort:apply` `{ mode, files, prefix?, dryRun, destRoot? }` → `{ results: {from,to,status,error?}[] }`.
- `rename:apply` (ProVid) `{ files, prefix, dryRun }` → results.
- `files:delete` `{ paths, dryRun }` → `{ deleted, failed, results[] }` (drives delete summary).
- `slomo:create` `{ jobId, files[], factor, dryRun }` → streamed progress + results.
- `timeadjust:apply` `{ jobId, files[], startISO, stepSeconds:60, mode:'copies'|'inplace', dryRun }` → results.
- `codec:report` = reuse scan output (read-only).
- `csv:export` handled in renderer (build CSV string) → `window.electronAPI.dialog.showSaveDialog` + backend `file:write` handler, OR a `csv:export {rows, path}` handler. Use one backend write handler.
- `settings:get` / `settings:set` `{ patch }` → persisted settings.

All handlers: validate inputs, never overwrite silently, return structured per-file errors so the UI can render **red "Error" rows with inspectable details**.

### Frontend (`renderer/`)
- **Routing** (`main/router.tsx`): add a route per tool under root, e.g. `/tool/$toolId` (single param route) driving a tool registry, plus `/` home. Session tool-state preserved via a React context store (`renderer/main/tool-state.tsx`) keyed by toolId; last-folder/filters also persisted through `settings:*`.
- **Home** (`main/home-view.tsx`): 3-column scrollable grid of 12 tool cards (icon, title, description, large hit area, hover + drag-over states). Each card is a **drop target**; dropping resolves paths via `getPathForFile`, stashes them in the tool-state store, and navigates into that tool with content pre-loaded. Whole-window drag-over shows a global "Drop files here" affordance.
- **Shared components** (`renderer/components/`):
  - `tool-page.tsx` — MaxVid-style wrapper: consistent header (`← Back to Home`, centered/left title, optional right-side category label), centered dark card, spacing.
  - `drop-zone.tsx` — large dashed drop zone; states: normal (dashed gray), drag-over (gold border + subtle glow + warmer bg + "Drop files here"); handles nested-zone `stopPropagation`; resolves paths via `webUtils.getPathForFile`.
  - `results-table.tsx` — scanned/results rows, selectable, sortable; **error rows with red badge + expandable details**; empty state.
  - `filter-pills.tsx`, `count-pills.tsx`, `sort-select.tsx`, `dry-run-toggle.tsx`, `progress-bar.tsx`, `cancel-button.tsx`, `section-label.tsx`, gold/secondary `Button` usage.
  - Toasts via existing `Toaster`/`toast`; confirmations via `dialog.showMessageBox` (macOS sheets).
  - `deps-gate.tsx` / setup sheet — first-launch ffmpeg/ffprobe check with "Install with Homebrew" + manual path.
- **Filters/counters** update the table instantly (client-side over scanned `VideoInfo[]`). iPhone/iOS filter = `make === 'Apple' || /iphone|ipad/i.test(model)`.

### The 12 tools (all share the tool-page + drop-zone + status/results pattern)
1. **Main Organizer** — single-column centered MaxVid-style workflow (replaces any split idea): header → description ("Filter, organize, review duplicates, and inspect rich video metadata.") → large drop zone → **Open Folder…** (gold) + **Select Files** (black) → scan summary count pills (Files, Duplicates, GPS, iPhone, 4K, 1080p, 720p) → **Sort Mode** full-width select (ProVid/VidRes/ProMax/MaxVid/KeepName) → optional prefix input → filter pills (4K,1080p,720p,SD,GPS,iPhone,Duplicates) → "Scanned Videos" results table with **Export CSV** + **Delete Selected** and empty state → bottom large gold **Apply Sort** (disabled until scanned). Vertical scroll; no cramped columns.
2. **ProVid Renamer** — rename in place, keep folder, optional prefix; dry-run; results.
3. **VidRes** — sort into resolution folders.
4. **ProMax** — resolution + orientation folders.
5. **MaxVid** — resolution + orientation + FPS folders (the reference layout).
6. **KeepName** — sort into folders, keep original filename.
7. **Re-encode Detector** — flag files not in preferred codec/container (non-H.264/HEVC MP4) as candidates; read-only report (optional export).
8. **1MinVid Adjust** — segmented control (Create dated copies [default] / Update in place) + optional **Custom start time** (native date/time picker via `dialog.showDatePicker`); assigns sequential timestamps 60s apart; dry-run; results.
9. **Slo-Mo Creator** — drop/list of files with in-list drag reorder; factor 0.5x/0.25x; ffmpeg `setpts`, drops audio; dated copies; progress + cancel; results.
10. **Duplicate Finder** — drop folder → MD5 scan with progress; grouped exact-duplicate results (labeled "Exact MD5"); instant filters; select + delete with summary.
11. **GPS Sorter** — sort into GPS / No-GPS folders from embedded location metadata; dry-run; results.
12. **Codec Checker** — read-only ffprobe report table (codec, container, resolution, fps, duration, size).

Mutating tools include: dry-run toggle, cancel during long ops, collision auto-suffix + toast, red error rows, and a post-delete summary ("12 files deleted" / "10 deleted, 2 failed — view details").

### Settings window (`renderer/settings/`)
Extend existing window: ffmpeg path, ffprobe path, editable video-extension list, persistence options, dry-run defaults. Keep theme control. Wire to `settings:get/set`.

### Window & preload
- `main/index.ts`: keep 1000×700 (fits 3-col grid); set a comfortable min (~760×560) so tool workflows aren't cramped; use `app-window-sizing`. No frameless/transparent window; keep standard frame. If any frosted panel is wanted, use native vibrancy (never CSS blur) per project rules.
- `preload.ts`: enable only the sensitive APIs actually needed (e.g. `shell.openPath` to reveal results in Finder) following IPC security rules; everything else through backend handlers.

## Execution order
1. **Foundation:** styles/tokens, `tool-page`, `drop-zone`, shared UI components, router `/tool/$toolId` + tool registry, tool-state context, home grid with card drop targets + global drag overlay.
2. **Backend engine + IPC:** cli-utils, ffprobe, scanner, hashing, file-ops, ffmpeg-ops, jobs, settings-store, all handlers; preload wiring; deps check/install.
3. **Onboarding + Settings:** first-launch ffmpeg/ffprobe gate sheet; Settings fields.
4. **Tools:** Main Organizer first (exercises scan/sort/filter/delete/CSV), then the 4 sort tools (share sort engine), Duplicate Finder, GPS Sorter, Codec Checker, Re-encode Detector, 1MinVid Adjust, Slo-Mo Creator.
5. **Polish:** toasts, error rows, cancel, empty states, keyboard shortcuts, persistence.

Given breadth, backend engine (step 2) and the large frontend surface (steps 1/4) are candidates for delegation to `app-backend-architect` / `app-frontend-architect` against the IPC contract above, integrated and validated by me. Relevant skills invoked before each layer: `app-frontend-rules`, `app-backend-rules`, `app-drag-and-drop`, `app-cli-dependencies`, `app-backend-performance`, `app-data-storage`, `app-browser-window-recipes`, `app-component-patterns`, `app-window-sizing`, `app-theming`, `app-icon-usage`.

## Critical files
- `main/index.ts` (window/min sizes), `main/handlers/index.ts` (all IPC), new `main/services/*` (engine), `renderer/preload.ts` (enable needed sensitive APIs).
- `renderer/main/router.tsx` (tool routes), `renderer/main/home-view.tsx` (grid + drop), `renderer/main/tool-state.tsx` (session store), `renderer/components/*` (shared UI), `renderer/main/tools/*` (12 pages), `renderer/settings/settings-view.tsx` (settings), `renderer/styles.css` (black/gold tokens).

## Verification
- `npm run type-check && npm run lint` clean.
- Build the app; on first launch with ffmpeg absent, confirm the Homebrew setup sheet appears; after install, `deps:check` passes.
- Drag a folder of videos from Finder onto a home card → tool opens pre-loaded and scans; count pills + filters update instantly; iPhone filter matches Apple make / iPhone·iPad models.
- Organizer: run each Sort Mode in dry-run then real; verify collision auto-suffix toast, no overwrites, red error rows with details, CSV export, delete summary.
- Duplicate Finder: verify exact MD5 grouping + delete summary; Cancel aborts a long scan.
- Slo-Mo/1MinVid/GPS Sorter/Re-encode/Codec: verify writes (dated copies vs in-place), progress + cancel, read-only reports.
- Runtime UI checks via DOM inspection for the multi-section Organizer and drag-over states; screenshot only for the drop-zone glow/visual states if needed.
- Confirm Settings persist (ffmpeg paths, extensions, dry-run defaults) and last-folder/window frame restore across relaunch.
- Update `.app_memory/PROJECT-CONTEXT.md` after completion.
