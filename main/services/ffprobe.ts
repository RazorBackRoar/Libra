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
  rotation?: number | string;  // some builds expose this directly on the stream
  side_data_list?: { rotation?: number }[]; // newer ffprobe display-matrix rotation
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

/** Resolve the raw rotate value from the tag, side-data, or stream field. */
function readRotate(
  stream: FfprobeStream | undefined,
  streamTags: Record<string, string> | undefined,
): number | null {
  const tag = streamTags?.["rotate"];
  if (tag !== undefined) {
    const n = parseInt(tag, 10);
    if (isFinite(n)) return n;
  }
  const sideRotation = stream?.side_data_list?.find(
    (d) => typeof d.rotation === "number",
  )?.rotation;
  if (typeof sideRotation === "number" && isFinite(sideRotation)) return sideRotation;
  if (typeof stream?.rotation === "number" && isFinite(stream.rotation)) return stream.rotation;
  if (typeof stream?.rotation === "string") {
    const n = parseInt(stream.rotation, 10);
    if (isFinite(n)) return n;
  }
  return null;
}

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

/** True if any tag key or value matches `re`. */
function anyTagKeyOrValueMatches(
  tags: Record<string, string> | undefined,
  re: RegExp,
): boolean {
  if (!tags) return false;
  for (const [k, v] of Object.entries(tags)) {
    if (re.test(k) || re.test(v)) return true;
  }
  return false;
}

/** True if any tag value contains `needle` (case-insensitive). */
function anyTagValueContains(
  tags: Record<string, string> | undefined,
  needle: string,
): boolean {
  if (!tags) return false;
  const lower = needle.toLowerCase();
  return Object.values(tags).some((v) => v.toLowerCase().includes(lower));
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
    hasCameraInfo: false,
    cameraFront: false,
    cameraBack: false,
    isScreenRecording: false,
    isSlowMotion: false,
    isEdited: false,
    hasGPS: false,
    gps: null,
    creationTime: null,
    rotate: null,
    rotateAbnormal: false,
    thumbnailUrl: null,
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

    // Dimensions — account for rotation (Section 4).
    let width = videoStream?.width ?? null;
    let height = videoStream?.height ?? null;

    // Raw rotate value: prefer the `rotate` tag, then side-data rotation, then
    // any stream-level rotation. null when no rotation metadata exists.
    const rawRotate = readRotate(videoStream, streamTags);
    let rotate: number | null = null;
    let rotateAbnormal = false;
    if (rawRotate !== null) {
      const norm = ((rawRotate % 360) + 360) % 360; // fold into 0..359
      if (norm === 90 || norm === 270) {
        rotate = norm;
        [width, height] = [height, width];
      } else if (norm === 0 || norm === 180) {
        rotate = norm;
      } else {
        // Corrupted / non-standard rotate metadata → treat as 0, but flag it.
        rotate = rawRotate;
        rotateAbnormal = true;
      }
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

    // 📷 — any device/camera info present. Co-exists with 📱 for iPhone clips.
    const hasCameraInfo = make !== null || model !== null;

    // ✂️ — appears edited/trimmed: editing apps (Photos/iMovie/etc.) stamp a
    // quicktime.software tag on export.
    const editSoftware =
      formatTags?.["com.apple.quicktime.software"] ??
      streamTags?.["com.apple.quicktime.software"] ??
      null;
    const isEdited = editSoftware !== null;

    const creationTime = extractCreationTime(formatTags, streamTags);

    const resolutionClass = classifyResolution(width, height);
    const orientation = classifyOrientation(width, height);

    // Camera front/back — best-effort tag scan (separate concept from Device/hasCameraInfo).
    const frontRe = /front.?camera/i;
    const backRe = /back.?camera/i;
    const cameraFront =
      anyTagKeyOrValueMatches(formatTags, frontRe) || anyTagKeyOrValueMatches(streamTags, frontRe);
    const cameraBack =
      anyTagKeyOrValueMatches(formatTags, backRe) || anyTagKeyOrValueMatches(streamTags, backRe);

    // Screen recording — best-effort filename + metadata clues (spec §13).
    // Strong indicators: RPReplay / ReplayKit / "Screen Recording" / QuickTime
    // Player (com.apple.QuickTimePlayerX). No clear evidence → not flagged.
    const screenRecTags = [
      "replaykit",
      "screen recording",
      "quicktime player",
      "com.apple.quicktimeplayerx",
    ];
    const isScreenRecording =
      /rpreplay|replaykit|screen recording/i.test(name) ||
      screenRecTags.some(
        (needle) =>
          anyTagValueContains(formatTags, needle) || anyTagValueContains(streamTags, needle),
      );

    // Slow motion — iPhone slow-mo shoots 120/240fps.
    const isSlowMotion = fps !== null && fps >= 90;

    if (cameraFront || cameraBack || isScreenRecording || isSlowMotion) {
      console.log("[ffprobe] detection flags", {
        filePath,
        cameraFront,
        cameraBack,
        isScreenRecording,
        isSlowMotion,
      });
    }

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
      hasCameraInfo,
      cameraFront,
      cameraBack,
      isScreenRecording,
      isSlowMotion,
      isEdited,
      hasGPS: gps !== null,
      gps,
      creationTime,
      rotate,
      rotateAbnormal,
      thumbnailUrl: null,
    };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.log("[ffprobe] probe failed", { filePath, error: msg });
    return { ...base, error: `ffprobe failed: ${msg}` };
  }
}
