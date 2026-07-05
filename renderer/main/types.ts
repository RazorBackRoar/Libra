// Shared types mirroring the IPC contract in project-plans/CONTRACT.md.
// These match structurally what the backend emits over JSON.

export type ResolutionClass = "4K" | "1080p" | "720p" | "SD" | "Unknown";
export type Orientation = "landscape" | "portrait" | "square" | "unknown";
export type SortMode = "ProVid" | "VidRes" | "ProMax" | "MaxVid" | "KeepName";

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
  hasGPS: boolean;
  gps: { lat: number; lon: number } | null;
  creationTime: string | null; // ISO 8601
  md5: string | null; // filled only by duplicate detection, else null
  error: string | null; // non-null => probe failed; UI renders an error row
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

export interface DuplicateGroup {
  hash: string;
  files: VideoInfo[];
}

export interface Settings {
  ffmpegPath: string | null;
  ffprobePath: string | null;
  videoExtensions: string[]; // default: ["mp4","mov","m4v","avi","mkv","webm","mpg","mpeg","wmv","flv","3gp","m2ts","mts"]
  dryRunDefault: boolean;
  lastFolders: Record<string, string>; // toolId -> last folder
}

export interface JobProgress {
  jobId: string;
  done: number;
  total: number;
  phase: string; // e.g. "scanning", "hashing", "encoding"
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
}

export interface HashDuplicatesParams {
  jobId: string;
  paths?: string[];
  files?: VideoInfo[];
  extensions?: string[];
}

export interface HashDuplicatesResult {
  groups: DuplicateGroup[];
  cancelled: boolean;
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

export interface JobCancelParams {
  jobId: string;
}

export interface JobCancelResult {
  cancelled: boolean;
}
