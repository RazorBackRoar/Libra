// Shared types mirroring the IPC contract in project-plans/CONTRACT.md.
// These match structurally what the backend emits over JSON.

export type ResolutionClass = "4K" | "FHD" | "1080p" | "HD" | "720p" | "SD" | "Unknown";
export type Orientation = "landscape" | "portrait" | "square" | "unknown";
export type SortMode = "ProVid" | "VidRes" | "ProMax" | "MaxVid" | "KeepName" | "SlowMotion";

/** Canonical, ordered resolution labels shown anywhere in the UI. */
export const RESOLUTION_CLASSES: ResolutionClass[] = ["4K", "FHD", "1080p", "HD", "720p", "SD"];

export interface VideoInfo {
  path: string; // absolute path
  name: string; // basename incl. extension
  dir: string; // parent directory
  ext: string; // lowercase, no dot, e.g. "mp4"
  sizeBytes: number;
  width: number | null;
  height: number | null;
  resolutionClass: ResolutionClass;
  orientation: Orientation;
  fps: number | null;
  durationSec: number | null;
  codec: string | null; // e.g. "h264", "hevc"
  container: string | null;
  make: string | null; // metadata make (e.g. "Apple")
  model: string | null; // metadata model (e.g. "iPhone 14 Pro")
  isApple: boolean; // make === "Apple" || /iphone|ipad/i.test(model)
  hasCameraInfo: boolean; // 📷 — make/model camera info present
  cameraFront: boolean; // best-effort: any tag value/key matches /front.?camera/i
  cameraBack: boolean; // best-effort: any tag value/key matches /back.?camera/i
  isScreenRecording: boolean; // filename starts with "rpreplay", or tag contains "replaykit"/"screen recording"
  isSlowMotion: boolean; // fps !== null && fps >= 90
  isEdited: boolean; // ✂️ — appears edited/trimmed
  hasGPS: boolean;
  gps: { lat: number; lon: number } | null;
  creationTime: string | null; // ISO 8601
  rotate: number | null; // display rotation applied (0/90/180/270) or raw abnormal value
  rotateAbnormal: boolean; // non-standard rotate metadata, treated as 0
  thumbnailUrl: string | null; // always null from scan:start — populated lazily via thumbnail:get
  error: string | null; // non-null => probe failed; UI renders an error row
}

export type ProcessItemKind = "organized" | "duplicate" | "misc" | "unreadable";

export interface ProcessResultItem {
  from: string;
  to: string | null;
  status: "ok" | "dryrun" | "skipped" | "error";
  kind: ProcessItemKind;
  note: string | null;
}

export interface ProcessReport {
  mode: SortMode;
  dryRun: boolean;
  droppedRoot: string;
  items: ProcessResultItem[];
  counts: {
    organized: number;
    duplicates: number;
    misc: number;
    unreadable: number;
    skipped: number;
    errors: number;
  };
  stopped: { reason: string } | null;
  noVideos: boolean;
}

export interface ProcessRunParams {
  jobId: string;
  mode: SortMode;
  files: VideoInfo[]; // filtered videos to organize (error === null)
  unreadablePaths: string[]; // video-ext files that failed to probe → MISC
  droppedPaths: string[]; // original dropped paths → dropped-folder root
  prefix?: string;
  dryRun: boolean;
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

export interface Settings {
  ffmpegPath: string | null;
  ffprobePath: string | null;
  videoExtensions: string[]; // default: ["mp4","mov","m4v","avi","mkv","webm","mpg","mpeg","wmv","flv","3gp","m2ts","mts"]
  dryRunDefault: boolean;
  lastFolders: Record<string, string>; // toolId -> last folder
  outputFolder: string; // where Media Organizer moves sorted files (default: <Desktop>/L!bra Organized)
}

export interface JobProgress {
  jobId: string;
  done: number;
  total: number;
  phase: string; // e.g. "scanning", "encoding"
}

export interface DepsCheckResult {
  ffmpeg: boolean;
  ffprobe: boolean;
  ffmpegPath: string | null;
  ffprobePath: string | null;
}

export interface DepsInstallResult {
  success: boolean;
  error?: string;
}

export interface ScanStartParams {
  jobId: string;
  paths: string[];
  extensions?: string[];
}

export interface ScanResult {
  files: VideoInfo[];
  cancelled: boolean;
  skippedSymlinks: string[];
}


export interface SortApplyParams {
  mode: SortMode;
  files: VideoInfo[];
  prefix?: string;
  dryRun: boolean;
  destRoot?: string;
}

export interface SortApplyResult {
  results: FileOpResult[];
}

export interface RenameApplyParams {
  files: VideoInfo[];
  prefix?: string;
  dryRun: boolean;
}

export interface RenameApplyResult {
  results: FileOpResult[];
}

export interface FilesDeleteParams {
  paths: string[];
  dryRun: boolean;
}

export interface SlomoCreateParams {
  jobId: string;
  files: string[];
  factor: number;
  dryRun: boolean;
}

export interface SlomoCreateResult {
  results: FileOpResult[];
  cancelled: boolean;
}

export interface TimeadjustApplyParams {
  jobId: string;
  files: string[];
  startISO: string;
  stepSeconds: number;
  mode: "copies" | "inplace";
  dryRun: boolean;
}

export interface TimeadjustApplyResult {
  results: FileOpResult[];
  cancelled: boolean;
}

export interface CsvExportParams {
  rows: string[][];
  suggestedName?: string;
}

export interface CsvExportResult {
  saved: boolean;
  path: string | null;
}

export interface RevealInFinderParams {
  path: string;
}

export interface RevealInFinderResult {
  ok: boolean;
}

export interface ThumbnailGetParams {
  path: string;
}

export interface ThumbnailGetResult {
  url: string | null;
}

export interface JobCancelParams {
  jobId: string;
}

export interface JobCancelResult {
  cancelled: boolean;
}
