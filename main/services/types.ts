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
  hasGPS: boolean;
  gps: { lat: number; lon: number } | null;
  creationTime: string | null;
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

  // 4K — either side >= 3840.
  if (width >= 3840 || height >= 3840) return "4K";

  // 1080p — either side exactly 1920 or 1080, and the long edge does not
  // exceed 1920 (so 2048x1080 / 1080x2048 fall through to HD).
  if ((width === 1920 || height === 1920 || width === 1080 || height === 1080) && long <= 1920) {
    return "1080p";
  }

  // 720p — either side exactly 1280 or 720, and the long edge does not exceed 1280.
  if ((width === 1280 || height === 1280 || width === 720 || height === 720) && long <= 1280) {
    return "720p";
  }

  // HD — above SD but not an exact bucket above: either side greater than 1080.
  if (width > 1080 || height > 1080) return "HD";

  // SD — everything else.
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
