/**
 * ffprobe wrapper — probe a single file and return a normalized VideoInfo.
 * Never throws; on failure returns a VideoInfo with error set.
 */

import { execFile } from "node:child_process";
import { promisify } from "node:util";
import * as fs from "node:fs/promises";
import * as path from "node:path";
import {
  type VideoInfo,
  classifyResolution,
  classifyOrientation,
} from "./types.js";

const execFileAsync = promisify(execFile);

// ─── ffprobe JSON types (internal) ──────────────────────────────────────────

interface FfprobeStream {
  codec_type?: string;
  codec_name?: string;
  width?: number;
  height?: number;
  r_frame_rate?: string;       // e.g. "30000/1001"
  avg_frame_rate?: string;
  rotation?: number | string;  // side_data may have this
  tags?: Record<string, string>;
}

interface FfprobeFormat {
  format_name?: string;        // e.g. "mov,mp4,m4a,3gp,3g2,mj2"
  duration?: string;
  tags?: Record<string, string>;
}

interface FfprobeOutput {
  streams?: FfprobeStream[];
  format?: FfprobeFormat;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function parseFps(rational: string | undefined): number | null {
  if (!rational) return null;
  const [n, d] = rational.split("/").map(Number);
  if (!n || !d || d === 0) return null;
  const fps = n / d;
  return isFinite(fps) && fps > 0 ? Math.round(fps * 100) / 100 : null;
}

/** Parse ISO 6709 location string like "+37.3861-122.0839/" */
function parseISO6709(loc: string): { lat: number; lon: number } | null {
  const m = /^([+-]\d+(?:\.\d+)?)([+-]\d+(?:\.\d+)?)/.exec(loc);
  if (!m) return null;
  const lat = parseFloat(m[1]!);
  const lon = parseFloat(m[2]!);
  if (!isFinite(lat) || !isFinite(lon)) return null;
  return { lat, lon };
}

function extractGps(
  tags: Record<string, string> | undefined,
): { lat: number; lon: number } | null {
  if (!tags) return null;
  const loc =
    tags["location"] ??
    tags["com.apple.quicktime.location.ISO6709"] ??
    tags["com.apple.quicktime.location.accuracy.horizontal"];
  if (loc) {
    const parsed = parseISO6709(loc);
    if (parsed) return parsed;
  }
  return null;
}

function extractCreationTime(
  formatTags: Record<string, string> | undefined,
  streamTags: Record<string, string> | undefined,
): string | null {
  const raw =
    formatTags?.["creation_time"] ??
    formatTags?.["com.apple.quicktime.creationdate"] ??
    streamTags?.["creation_time"] ??
    streamTags?.["com.apple.quicktime.creationdate"];
  if (!raw) return null;
  try {
    return new Date(raw).toISOString();
  } catch {
    return null;
  }
}

// ─── Main probe function ──────────────────────────────────────────────────────

export async function probeFile(
  ffprobePath: string,
  filePath: string,
): Promise<VideoInfo> {
  const name = path.basename(filePath);
  const dir = path.dirname(filePath);
  const ext = path.extname(filePath).replace(/^\./, "").toLowerCase();

  // Base result with nulls; populated below
  const base: VideoInfo = {
    path: filePath,
    name,
    dir,
    ext,
    sizeBytes: 0,
    width: null,
    height: null,
    resolutionClass: "Unknown",
    orientation: "unknown",
    fps: null,
    durationSec: null,
    codec: null,
    container: null,
    make: null,
    model: null,
    isApple: false,
    hasGPS: false,
    gps: null,
    creationTime: null,
    md5: null,
    error: null,
  };

  try {
    // Get file size
    const stat = await fs.stat(filePath);
    base.sizeBytes = stat.size;
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.log("[ffprobe] stat failed", { filePath, error: msg });
    return { ...base, error: `stat failed: ${msg}` };
  }

  try {
    const { stdout } = await execFileAsync(
      ffprobePath,
      [
        "-v", "quiet",
        "-print_format", "json",
        "-show_streams",
        "-show_format",
        filePath,
      ],
      {
        maxBuffer: 10 * 1024 * 1024,
        timeout: 30_000,
      },
    );

    const data = JSON.parse(stdout) as FfprobeOutput;
    const videoStream = data.streams?.find((s) => s.codec_type === "video");
    const format = data.format;
    const formatTags = format?.tags;
    const streamTags = videoStream?.tags;

    // Dimensions — account for rotation
    let width = videoStream?.width ?? null;
    let height = videoStream?.height ?? null;
    const rotation =
      typeof videoStream?.rotation === "number"
        ? videoStream.rotation
        : typeof videoStream?.rotation === "string"
          ? parseInt(videoStream.rotation, 10)
          : 0;
    if (rotation === 90 || rotation === -90 || rotation === 270) {
      [width, height] = [height, width];
    }

    // FPS: prefer r_frame_rate, fall back to avg_frame_rate
    const fps =
      parseFps(videoStream?.r_frame_rate) ??
      parseFps(videoStream?.avg_frame_rate);

    // Duration
    const rawDuration = format?.duration;
    const durationSec = rawDuration ? parseFloat(rawDuration) : null;

    // Container: first token of format_name
    const container = format?.format_name?.split(",")[0] ?? null;

    // GPS
    const gps = extractGps(formatTags) ?? extractGps(streamTags);

    // Make / model
    const make =
      formatTags?.["com.apple.quicktime.make"] ??
      formatTags?.["make"] ??
      streamTags?.["com.apple.quicktime.make"] ??
      streamTags?.["make"] ??
      null;
    const model =
      formatTags?.["com.apple.quicktime.model"] ??
      formatTags?.["model"] ??
      streamTags?.["com.apple.quicktime.model"] ??
      streamTags?.["model"] ??
      null;

    const isApple =
      make === "Apple" || /iphone|ipad/i.test(model ?? "");

    const creationTime = extractCreationTime(formatTags, streamTags);

    const resolutionClass = classifyResolution(width, height);
    const orientation = classifyOrientation(width, height);

    return {
      ...base,
      width,
      height,
      resolutionClass,
      orientation,
      fps,
      durationSec: durationSec !== null && isFinite(durationSec) ? durationSec : null,
      codec: videoStream?.codec_name ?? null,
      container,
      make,
      model,
      isApple,
      hasGPS: gps !== null,
      gps,
      creationTime,
    };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.log("[ffprobe] probe failed", { filePath, error: msg });
    return { ...base, error: `ffprobe failed: ${msg}` };
  }
}
