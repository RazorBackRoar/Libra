/**
 * L!bra — Shared IPC types (backend copy).
 * Keep structurally identical to renderer/main/types.ts.
 */

export type ResolutionClass = "4K" | "FHD" | "1080p" | "HD" | "720p" | "SD" | "Unknown";

/** Canonical, ordered list of resolution labels shown anywhere in the app. */
export const RESOLUTION_CLASSES: ResolutionClass[] = ["4K", "FHD", "1080p", "HD", "720p", "SD"];
export type Orientation = "landscape" | "portrait" | "square" | "unknown";
export type SortMode = "ProVid" | "VidRes" | "ProMax" | "MaxVid" | "KeepName" | "SlowMotion";

export interface VideoInfo {
  path: string;
  name: string;
  dir: string;
  ext: string;
  sizeBytes: number;
  width: number | null;
  height: number | null;
  resolutionClass: ResolutionClass;
  orientation: Orientation;
  fps: number | null;
  durationSec: number | null;
  codec: string | null;
  container: string | null;
  make: string | null;
  model: string | null;
  isApple: boolean;
  hasCameraInfo: boolean;
  /** Best-effort: any tag value/key matches /front.?camera/i. */
  cameraFront: boolean;
  /** Best-effort: any tag value/key matches /back.?camera/i. */
  cameraBack: boolean;
  /** Filename starts with "rpreplay" (case-insensitive), or any tag value contains "replaykit"/"screen recording". */
  isScreenRecording: boolean;
  /** fps !== null && fps >= 90 (iPhone slow-mo shoots 120/240fps). */
  isSlowMotion: boolean;
  isEdited: boolean;
  hasGPS: boolean;
  gps: { lat: number; lon: number } | null;
  creationTime: string | null;
  /** Display rotation actually applied (0/90/180/270), or the raw value when abnormal. */
  rotate: number | null;
  /** True when the rotate metadata was a non-standard value (treated as 0). */
  rotateAbnormal: boolean;
  /** Always null from scan:start — populated lazily via thumbnail:get. */
  thumbnailUrl: string | null;
  error: string | null;
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
  videoExtensions: string[];
  dryRunDefault: boolean;
  lastFolders: Record<string, string>;
  /** Where the Media Organizer moves sorted files. Empty => resolved to
   *  "<Desktop>/L!bra Organized" at load time. */
  outputFolder: string;
}

export interface JobProgress {
  jobId: string;
  done: number;
  total: number;
  phase: string;
}

/** Stable frame-rate folder tokens (matches fpsFolderToken output). */
const FPS_FOLDER_TOKENS = ["30", "60", "120", "Sub", "NA"] as const;

/** Folder names L!bra itself creates — skipped when scanning recursively so
 *  re-runs never re-process the app's own output. Computed from the resolution
 *  classes × orientation × frame-rate tokens plus the fixed utility folders. */
export const OUTPUT_FOLDER_NAMES: string[] = [
  ...RESOLUTION_CLASSES,
  "MISC", "GPS", "No GPS", "Slow Motion", "Normal Speed",
  ...RESOLUTION_CLASSES.flatMap((r) => ["W", "V"].map((o) => `${r} ${o}`)),
  ...RESOLUTION_CLASSES.flatMap((r) =>
    ["W", "V"].flatMap((o) => FPS_FOLDER_TOKENS.map((f) => `${r} ${o} ${f}`)),
  ),
];

/** macOS housekeeping entries — never moved, never counted. */
export function isHousekeepingName(name: string): boolean {
  if (name === ".DS_Store") return true;
  if (name.startsWith("._")) return true; // AppleDouble sidecars
  return (
    name === ".Spotlight-V100" ||
    name === ".Trashes" ||
    name === ".fseventsd" ||
    name === ".TemporaryItems"
  );
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
  /** Set when the run halted early (disk full / folder disconnected). */
  stopped: { reason: string } | null;
  /** True when no recognized videos were available to organize. */
  noVideos: boolean;
}

export const DEFAULT_VIDEO_EXTENSIONS: string[] = [
  "mp4", "mov", "m4v", "avi", "mkv", "webm",
  "mpg", "mpeg", "wmv", "flv", "3gp", "m2ts", "mts",
];

export const DEFAULT_SETTINGS: Settings = {
  ffmpegPath: null,
  ffprobePath: null,
  videoExtensions: DEFAULT_VIDEO_EXTENSIONS,
  dryRunDefault: false,
  lastFolders: {},
  outputFolder: "",
};

/**
 * Classify resolution from detected width/height (already rotation-corrected).
 * Uses long = max(width, height). Order matters — first match wins:
 *   4K → 1080p (~1920) → 720p (~1280) → FHD (>1080p, <4K) → HD (>720p) → SD
 */
export function classifyResolution(
  width: number | null,
  height: number | null,
): ResolutionClass {
  if (width === null || height === null || width <= 0 || height <= 0) {
    return "Unknown";
  }
  const long = Math.max(width, height);

  // 4K — long side >= 3840.
  if (long >= 3840) return "4K";

  // 1080p — long side within ±2 of 1920 (exact-ish 1920x1080).
  if (Math.abs(long - 1920) <= 2) return "1080p";

  // 720p — long side within ±2 of 1280 (exact-ish 1280x720).
  if (Math.abs(long - 1280) <= 2) return "720p";

  // FHD — strictly between 1080p and 4K.
  if (long > 1920 && long < 3840) return "FHD";

  // HD — everything else above 720p.
  if (long > 720) return "HD";

  // SD — long side <= 720.
  return "SD";
}

export function classifyOrientation(
  width: number | null,
  height: number | null,
): Orientation {
  if (width === null || height === null) return "unknown";
  if (width > height) return "landscape";
  if (height > width) return "portrait";
  return "square";
}

/** Filename orientation code: V for vertical, W otherwise (square counts as wide). */
export function orientationCode(o: Orientation): "W" | "V" {
  return o === "portrait" ? "V" : "W";
}

/** Frame-rate label: 60 when the source runs above 45fps, otherwise 30. */
export function frameRateLabel(fps: number | null): 30 | 60 {
  return fps !== null && fps > 45 ? 60 : 30;
}

export type FpsBucket = "Sub" | "30" | "60" | "120" | null;

/**
 * Frame-rate bucket per spec §8:
 *   Sub  = fps < 28.00
 *   30   = 28.00–32.00
 *   60   = 55.00–65.00
 *   120  = 100.00–130.00
 * Missing/unreadable fps, or values between named buckets, return null (so a
 * missing fps is never counted as 120fps).
 */
export function fpsBucket(fps: number | null): FpsBucket {
  if (fps === null || !isFinite(fps) || fps <= 0) return null;
  if (fps < 28) return "Sub";
  if (fps <= 32) return "30";
  if (fps >= 55 && fps <= 65) return "60";
  if (fps >= 100 && fps <= 130) return "120";
  return null;
}

/** Frame-rate token used in generated filenames: bucket number, or the rounded
 *  fps for Sub / out-of-bucket values, or "" when fps is unknown. */
export function fpsToken(fps: number | null): string {
  const b = fpsBucket(fps);
  if (b === "30" || b === "60" || b === "120") return b;
  return fps !== null && isFinite(fps) && fps > 0 ? String(Math.round(fps)) : "";
}

/** Stable frame-rate token used in folder names (always one of the known
 *  tokens so the scanner skip-list stays exhaustive). */
export function fpsFolderToken(fps: number | null): string {
  return fpsBucket(fps) ?? "NA";
}
