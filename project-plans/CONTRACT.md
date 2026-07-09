# L!bra — "Final Development Spec" Contract (2026-07-05)

Single source of truth for this task. Both workstreams read this file first. Types cross the
bridge as JSON — keep `main/services/types.ts` and `renderer/main/types.ts` structurally
identical. Do not change a shape without updating this file.

Frontend calls: `window.electronAPI.app.ipc.invoke("channel", params)`.
Backend handles: `ipcMain.handle("channel", async (_event, params) => …)`.

## 1. Resolution classification (replaces current 5-tier system with 6 tiers)

```ts
export type ResolutionClass = "4K" | "FHD" | "1080p" | "HD" | "720p" | "SD" | "Unknown";
export const RESOLUTION_CLASSES: ResolutionClass[] = ["4K", "FHD", "1080p", "HD", "720p", "SD"];
```

Classify using `long = max(width, height)` (dimensions already rotation-corrected). First match wins, in this order:
1. `long >= 3840` → `"4K"`
2. `long` within ±2 of 1920 → `"1080p"` (exact-ish 1920×1080)
3. `long` within ±2 of 1280 → `"720p"` (exact-ish 1280×720)
4. `long > 1920` (and < 3840) → `"FHD"` (between 1080p and 4K)
5. `long > 720` → `"HD"` (between 720p and 1080p — covers everything else above 720)
6. else → `"SD"`

Orientation unchanged (`landscape`/`portrait`/`square` from width vs height; `orientationCode` → `"W"`/`"V"` reused everywhere). **Delete `orientationFolder` ("Wide"/"Vertical")** — no longer used; folder names now use the single-letter `orientationCode` (see §3).

## 2. New VideoInfo fields

Add to the existing `VideoInfo` interface (in both type files):

```ts
cameraFront: boolean;        // best-effort: any tag value/key matches /front.?camera/i
cameraBack: boolean;         // best-effort: any tag value/key matches /back.?camera/i
isScreenRecording: boolean;  // filename starts with "rpreplay" (case-insensitive), OR any tag
                              // value contains "replaykit" or "screen recording"
isSlowMotion: boolean;       // fps !== null && fps >= 90 (iPhone slow-mo shoots 120/240fps)
thumbnailUrl: string | null; // always null from scan:start — populated lazily, see §4
```

`hasCameraInfo` (make/model present) is UNCHANGED and still backs the "Device" concept:
- Device = `"iPhone"` when `isApple`, else `"Misc Phone"` when `hasCameraInfo`, else none.
Camera front/back/none is a SEPARATE concept from Device, backed by the two new fields:
- `Camera` (has direction info) = `cameraFront || cameraBack`; `Front Camera` = `cameraFront`;
  `Back Camera` = `cameraBack` (a clip can be both); `No Camera` = neither.

## 3. SortMode + folder naming (flat single-level names, NOT nested)

```ts
export type SortMode = "ProVid" | "VidRes" | "ProMax" | "MaxVid" | "KeepName" | "SlowMotion";
```

`targetDir(root, mode, info)` in `main/services/processor.ts`:
- `ProVid` → `info.dir` (rename in place, unchanged)
- `VidRes` / `KeepName` → `path.join(root, info.resolutionClass)` e.g. `"FHD"`
- `ProMax` → `path.join(root, \`${info.resolutionClass} ${orientationCode(info.orientation)}\`)` e.g. `"4K W"` (flat — NOT nested `4K/Wide`)
- `MaxVid` → `path.join(root, \`${info.resolutionClass} ${orientationCode(info.orientation)} ${frameRateLabel(info.fps)}\`)` e.g. `"4K W 60"` (flat, 1 level — NOT 3 nested levels)
- `SlowMotion` (new) → `path.join(root, info.isSlowMotion ? "Slow Motion" : "Normal Speed")`

`OUTPUT_FOLDER_NAMES` (skip-list for recursive scan/process, both type files) must become:
```
4K, FHD, 1080p, HD, 720p, SD, MISC, GPS, No GPS, Slow Motion, Normal Speed,
4K W, 4K V, FHD W, FHD V, 1080p W, 1080p V, HD W, HD V, 720p W, 720p V, SD W, SD V,
4K W 60, 4K W 30, 4K V 60, 4K V 30, FHD W 60, FHD W 30, FHD V 60, FHD V 30,
1080p W 60, 1080p W 30, 1080p V 60, 1080p V 30, HD W 60, HD W 30, HD V 60, HD V 30,
720p W 60, 720p W 30, 720p V 60, 720p V 30, SD W 60, SD W 30, SD V 60, SD V 30
```
GPS Sorter keeps moving files directly via `files:move` into `"GPS"` / `"No GPS"` (already the case, just verify the folder names match this list — currently uses `"No-GPS"` with a hyphen, **rename to `"No GPS"`** with a space to match the skip-list and the spec).

## 4. Thumbnails — new IPC channel

```
Channel: "thumbnail:get"
Request: { path: string }
Response: { url: string | null }   // null if generation failed (e.g. corrupt file)
```
Backend: generate via ffmpeg (`-ss 1 -frames:v 1 -vf scale=160:-1`) into a cache file at
`app.getPath("userData")/thumbnails/<sha1(path+mtimeMs+size)>.jpg`, reuse if already cached.
Serve cached files through a registered custom protocol (invoke the `app-protocol-large-files`
skill for the exact registration pattern) — do NOT return base64 over IPC. Frontend requests a
thumbnail per visible row lazily (on row mount), caches the returned URL in component state
keyed by path, and shows a neutral placeholder icon until it resolves or fails.

## 5. Scan summary categories (18 total) — all independently toggleable and combinable (AND logic)

`Total Videos` (clears all filters), `GPS`, `No GPS`, `4K`, `FHD`, `1080p`, `HD`, `720p`, `SD`,
`30fps`, `60fps`, `iPhone`, `Misc Phone`, `Camera`, `Front Camera`, `Back Camera`, `No Camera`,
`Screen REC`. Predicates: resolution → `resolutionClass`; GPS/No GPS → `hasGPS`; fps buckets →
`frameRateLabel(fps) === 30/60`; iPhone → `isApple`; Misc Phone → `hasCameraInfo && !isApple`;
Camera/Front/Back/No Camera → §2; Screen REC → `isScreenRecording`.

## 6. Existing channels — no shape change other than the new VideoInfo fields flowing through
`scan:start`, `process:run` (mode may now be `"SlowMotion"`), `files:move`, `job:cancel`,
`csv:export`, `slomo:create`/`timeadjust:apply` (unrelated, unchanged).
