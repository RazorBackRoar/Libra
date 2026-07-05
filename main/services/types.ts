/**
 * L!bra — Shared IPC types (backend copy).
 * Keep structurally identical to renderer/main/types.ts.
 */

export type ResolutionClass = "4K" | "1080p" | "720p" | "HD" | "SD" | "Unknown";

/** Canonical, ordered list of resolution labels shown anywhere in the app. */
export const RESOLUTION_CLASSES: ResolutionClass[] = ["4K", "1080p", "720p", "HD", "SD"];
export type Orientation = "landscape" | "portrait" | "square" | "unknown";
export type SortMode = "ProVid" | "VidRes" | "ProMax" | "MaxVid" | "KeepName";

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
  isEdited: boolean;
  hasGPS: boolean;
  gps: { lat: number; lon: number } | null;
  creationTime: string | null;
  /** Display rotation actually applied (0/90/180/270), or the raw value when abnormal. */
  rotate: number | null;
  /** True when the rotate metadata was a non-standard value (treated as 0). */
  rotateAbnormal: boolean;
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

/** Folder names L!bra itself creates — skipped when scanning recursively so
 *  re-runs never re-process the app's own output. */
export const OUTPUT_FOLDER_NAMES: string[] = ["4K", "1080p", "720p", "HD", "SD", "MISC"];

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
 * Classify resolution from detected width/height.
 * Order matters — each video stops at the first matching rule:
 *   4K → 1080p → 720p → HD → SD
 * Works for both landscape and portrait (rules test "either side").
 */
export function classifyResolution(
  width: number | null,
  height: number | null,
): ResolutionClass {
  if (width === null || height === null || width <= 0 || height <= 0) {
    return "Unknown";
  }
  const long = Math.max(width, height);

  // Order matters — first match wins. Each check looks at either side so
  // orientation never changes the result (dimensions are rotation-corrected).

  // 4K — width or height >= 2160.
  if (width >= 2160 || height >= 2160) return "4K";

  // 1080p — either side exactly 1920 or 1080.
  if (width === 1920 || height === 1920 || width === 1080 || height === 1080) {
    return "1080p";
  }

  // 720p — either side exactly 1280 or 720.
  if (width === 1280 || height === 1280 || width === 720 || height === 720) {
    return "720p";
  }

  // HD — longer side >= 720.
  if (long >= 720) return "HD";

  // SD — longer side < 720.
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

/** Folder-name orientation label used by Pro Max / Max Vid. */
export function orientationFolder(o: Orientation): "Wide" | "Vertical" {
  return o === "portrait" ? "Vertical" : "Wide";
}

/** Frame-rate label: 60 when the source runs above 45fps, otherwise 30. */
export function frameRateLabel(fps: number | null): 30 | 60 {
  return fps !== null && fps > 45 ? 60 : 30;
}
