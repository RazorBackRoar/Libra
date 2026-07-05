# L!bra — Shared IPC Contract & Data Types

This is the single source of truth shared by the backend (`main/`) and frontend (`renderer/`) workstreams. Types cross the bridge as JSON, so both sides must define **structurally identical** interfaces (backend in `main/services/types.ts`, frontend in `renderer/main/types.ts`). Do not change a shape without updating this file.

Frontend calls: `window.glazeAPI.glaze.ipc.invoke("channel", params)` (single object arg).
Backend handles: `ipcMain.handle("channel", async (_event, params) => …)`.
Progress notifications: backend emits to the renderer; frontend subscribes via `window.glazeAPI.glaze.ipc.onNotification("job:progress", cb)`. Backend must verify the exact SDK send/broadcast API in the SDK API Reference so it pairs with preload's `onNotification` (e.g. `new WebContents("main").send("job:progress", payload)` or an `ipcMain` broadcast helper).

## Shared types

```ts
export type ResolutionClass = "4K" | "1080p" | "720p" | "SD" | "Unknown";
export type Orientation = "landscape" | "portrait" | "square" | "unknown";
export type SortMode = "ProVid" | "VidRes" | "ProMax" | "MaxVid" | "KeepName";

export interface VideoInfo {
  path: string;            // absolute path
  name: string;            // basename incl. extension
  dir: string;             // parent directory
  ext: string;             // lowercase, no dot, e.g. "mp4"
  sizeBytes: number;
  width: number | null;
  height: number | null;
  resolutionClass: ResolutionClass;
  orientation: Orientation;
  fps: number | null;
  durationSec: number | null;
  codec: string | null;    // e.g. "h264", "hevc"
  container: string | null;
  make: string | null;     // metadata make (e.g. "Apple")
  model: string | null;    // metadata model (e.g. "iPhone 14 Pro")
  isApple: boolean;        // make === "Apple" || /iphone|ipad/i.test(model)
  hasGPS: boolean;
  gps: { lat: number; lon: number } | null;
  creationTime: string | null; // ISO 8601
  md5: string | null;      // filled only by duplicate detection, else null
  error: string | null;    // non-null => probe failed; UI renders an error row
}

export interface FileOpResult {
  from: string;
  to: string | null;
  status: "ok" | "skipped" | "error" | "dryrun";
  error: string | null;
}

export interface DeleteSummary {
  deleted: number;
  failed: number;
  results: { path: string; status: "ok" | "error"; error: string | null }[];
}

export interface DuplicateGroup { hash: string; files: VideoInfo[]; }

export interface Settings {
  ffmpegPath: string | null;
  ffprobePath: string | null;
  videoExtensions: string[]; // default below
  dryRunDefault: boolean;
  lastFolders: Record<string, string>; // toolId -> last folder
}

export interface JobProgress {
  jobId: string;
  done: number;
  total: number;
  phase: string; // e.g. "scanning", "hashing", "encoding"
}
```

Default `videoExtensions`: `["mp4","mov","m4v","avi","mkv","webm","mpg","mpeg","wmv","flv","3gp","m2ts","mts"]`.

Resolution classing (by max dimension, i.e. long edge): ≥3840→"4K"; ≥1920→"1080p"; ≥1280→"720p"; >0→"SD"; else "Unknown".

## Channels

| Channel | Request | Response |
| --- | --- | --- |
| `deps:check` | `{}` | `{ ffmpeg: boolean; ffprobe: boolean; ffmpegPath: string \| null; ffprobePath: string \| null }` |
| `deps:install` | `{}` | `{ success: boolean; error?: string }` — runs `brew install ffmpeg` (installs ffprobe too); long timeout (10 min) |
| `scan:start` | `{ jobId: string; paths: string[]; extensions?: string[] }` | `{ files: VideoInfo[]; cancelled: boolean }` — recursively walks dirs, filters by ext, probes with bounded concurrency; emits `job:progress` |
| `job:cancel` | `{ jobId: string }` | `{ cancelled: boolean }` |
| `hash:duplicates` | `{ jobId: string; paths?: string[]; files?: VideoInfo[]; extensions?: string[] }` | `{ groups: DuplicateGroup[]; cancelled: boolean }` — exact MD5; groups only include hashes with ≥2 files; emits `job:progress` |
| `sort:apply` | `{ mode: SortMode; files: VideoInfo[]; prefix?: string; dryRun: boolean; destRoot?: string }` | `{ results: FileOpResult[] }` |
| `rename:apply` | `{ files: VideoInfo[]; prefix?: string; dryRun: boolean }` | `{ results: FileOpResult[] }` |
| `files:delete` | `{ paths: string[]; dryRun: boolean }` | `DeleteSummary` |
| `files:move` | `{ moves: { from: string; toDir: string }[]; dryRun: boolean }` | `{ results: FileOpResult[] }` — moves each file into `toDir` (created if missing) with collision auto-suffix, never overwrite; used by GPS Sorter (frontend sets `toDir = <file.dir>/GPS` or `/No-GPS`) and any bucket-move tool |
| `slomo:create` | `{ jobId: string; files: string[]; factor: number; dryRun: boolean }` | `{ results: FileOpResult[]; cancelled: boolean }` — ffmpeg `setpts=PTS/factor`... i.e. slower for factor<1; drops audio (`-an`); dated output copies; emits `job:progress` |
| `timeadjust:apply` | `{ jobId: string; files: string[]; startISO: string; stepSeconds: number; mode: "copies" \| "inplace"; dryRun: boolean }` | `{ results: FileOpResult[]; cancelled: boolean }` — assigns sequential timestamps `stepSeconds` apart from `startISO`; sets metadata `creation_time` (ffmpeg) + fs mtime; emits `job:progress` |
| `csv:export` | `{ rows: string[][]; suggestedName?: string }` | `{ saved: boolean; path: string \| null }` — backend shows save dialog and writes CSV |
| `reveal:inFinder` | `{ path: string }` | `{ ok: boolean }` — `shell.showItemInFolder`/`openPath`; enable the needed shell API in preload |
| `settings:get` | `{}` | `Settings` |
| `settings:set` | `{ patch: Partial<Settings> }` | `Settings` (merged + persisted) |

Notification (backend → renderer): `job:progress` with payload `JobProgress`.

## Sort semantics (folders created under each file's own directory unless `destRoot` given)
- **ProVid** — rename in place (same folder), apply `prefix`; no subfolders.
- **VidRes** — move into `<resolutionClass>/`.
- **ProMax** — move into `<resolutionClass>/<orientation>/`.
- **MaxVid** — move into `<resolutionClass>/<orientation>/<fps>fps/`.
- **KeepName** — same folders as VidRes but never alter the filename.
All moves use collision auto-suffix `(1),(2)…`, never overwrite; `dryRun` returns intended `to` paths with status `"dryrun"`.

## Re-encode detection (client-side, no channel)
Derive from scan results: a file is a re-encode candidate if `codec` not in `["h264","hevc"]` OR `ext` not `"mp4"`/`"mov"`. Reason string explains which.

## Backend notes
- `execFile` only (never `exec`); explicit `maxBuffer` (≥10MB for ffprobe JSON) + `timeout`.
- Resolve ffmpeg/ffprobe path order: Settings override → `which` → common Homebrew paths (`/opt/homebrew/bin`, `/usr/local/bin`).
- All long ops honor `job:cancel` (track child processes / cancel flag in a job registry keyed by `jobId`).
- Settings persisted as JSON under `app.getPath("userData")`.
</content>
