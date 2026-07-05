/**
 * L!bra — Shared IPC types (backend copy).
 * Keep structurally identical to renderer/main/types.ts.
 */

export type ResolutionClass = "4K" | "1080p" | "720p" | "SD" | "Unknown";
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
  md5: string | null;
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

export interface DuplicateGroup {
  hash: string;
  files: VideoInfo[];
}

export interface Settings {
  ffmpegPath: string | null;
  ffprobePath: string | null;
  videoExtensions: string[];
  dryRunDefault: boolean;
  lastFolders: Record<string, string>;
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
};

/** Classify resolution by longest edge */
export function classifyResolution(
  width: number | null,
  height: number | null,
): ResolutionClass {
  if (width === null || height === null) return "Unknown";
  const long = Math.max(width, height);
  if (long >= 3840) return "4K";
  if (long >= 1920) return "1080p";
  if (long >= 1280) return "720p";
  if (long > 0) return "SD";
  return "Unknown";
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
