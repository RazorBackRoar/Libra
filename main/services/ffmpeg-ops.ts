/**
 * ffmpeg operations — slo-mo and timestamp adjustment.
 * All operations are cancelable via jobId.
 */

import { execFile, type ChildProcess } from "node:child_process";
import * as fs from "node:fs/promises";
import * as path from "node:path";
import { addChildProcess, emitProgress } from "./jobs.js";
import { safeDest } from "./file-ops.js";
import type { FileOpResult } from "./types.js";

// ─── Helpers ──────────────────────────────────────────────────────────────────

/** Run ffmpeg; returns stdout+stderr; throws on non-zero exit. */
function runFfmpeg(
  ffmpegPath: string,
  args: string[],
  jobId: string,
  cancelFlag: { cancelled: boolean },
): Promise<void> {
  return new Promise((resolve, reject) => {
    if (cancelFlag.cancelled) {
      reject(new Error("cancelled"));
      return;
    }

    const child = execFile(
      ffmpegPath,
      args,
      { maxBuffer: 10 * 1024 * 1024, timeout: 10 * 60_000 },
      (err) => {
        if (err) {
          if (cancelFlag.cancelled) {
            reject(new Error("cancelled"));
          } else {
            console.log("[ffmpeg] execFile error", { args: args.slice(0, 4), error: err.message });
            reject(err);
          }
        } else {
          resolve();
        }
      },
    ) as ChildProcess;

    addChildProcess(jobId, child);
  });
}

/** Build a dated copy path — appends _slomo or _ts suffix before extension. */
function buildOutputPath(
  filePath: string,
  suffix: string,
): string {
  const ext = path.extname(filePath);
  const base = filePath.slice(0, filePath.length - ext.length);
  return `${base}_${suffix}${ext}`;
}

// ─── Slo-mo ───────────────────────────────────────────────────────────────────

export interface SlomoResult {
  results: FileOpResult[];
  cancelled: boolean;
}

export async function createSloMo(opts: {
  jobId: string;
  files: string[];
  factor: number;
  dryRun: boolean;
  ffmpegPath: string;
  cancelFlag: { cancelled: boolean };
}): Promise<SlomoResult> {
  const { jobId, files, factor, dryRun, ffmpegPath, cancelFlag } = opts;
  const results: FileOpResult[] = [];
  const total = files.length;
  let done = 0;

  emitProgress({ jobId, done: 0, total, phase: "encoding" });

  for (const filePath of files) {
    if (cancelFlag.cancelled) break;

    const rawDest = buildOutputPath(filePath, `slomo${factor}x`);
    const dest = await safeDest(rawDest);

    if (dryRun) {
      results.push({ from: filePath, to: dest, status: "dryrun", error: null });
      done++;
      emitProgress({ jobId, done, total, phase: "encoding" });
      continue;
    }

    // setpts=PTS/factor slows down (factor<1) or speeds up (factor>1)
    // Contract says "slower for factor<1" — i.e. factor IS the speed multiplier
    const ptsExpr = `PTS/${factor}`;
    const args = [
      "-y",
      "-i", filePath,
      "-vf", `setpts=${ptsExpr}`,
      "-an",            // drop audio
      dest,
    ];

    try {
      await runFfmpeg(ffmpegPath, args, jobId, cancelFlag);
      results.push({ from: filePath, to: dest, status: "ok", error: null });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (msg === "cancelled") {
        results.push({ from: filePath, to: null, status: "error", error: "cancelled" });
        break;
      }
      results.push({ from: filePath, to: null, status: "error", error: msg });
    }

    done++;
    emitProgress({ jobId, done, total, phase: "encoding" });
  }

  return { results, cancelled: cancelFlag.cancelled };
}

// ─── Timestamp adjustment ─────────────────────────────────────────────────────

export interface TimeAdjustResult {
  results: FileOpResult[];
  cancelled: boolean;
}

export async function applyTimeAdjust(opts: {
  jobId: string;
  files: string[];
  startISO: string;
  stepSeconds: number;
  mode: "copies" | "inplace";
  dryRun: boolean;
  ffmpegPath: string;
  cancelFlag: { cancelled: boolean };
}): Promise<TimeAdjustResult> {
  const { jobId, files, startISO, stepSeconds, mode, dryRun, ffmpegPath, cancelFlag } = opts;
  const results: FileOpResult[] = [];
  const total = files.length;
  let done = 0;

  emitProgress({ jobId, done: 0, total, phase: "timestamping" });

  let currentTime = new Date(startISO).getTime();

  for (const filePath of files) {
    if (cancelFlag.cancelled) break;

    const targetDate = new Date(currentTime);
    // ffmpeg creation_time format: YYYY-MM-DDTHH:MM:SS.ffffffZ
    const creationTimeStr = targetDate.toISOString();

    if (mode === "copies") {
      const rawDest = buildOutputPath(filePath, "ts");
      const dest = await safeDest(rawDest);

      if (dryRun) {
        results.push({ from: filePath, to: dest, status: "dryrun", error: null });
      } else {
        const args = [
          "-y",
          "-i", filePath,
          "-c", "copy",
          "-metadata", `creation_time=${creationTimeStr}`,
          dest,
        ];
        try {
          await runFfmpeg(ffmpegPath, args, jobId, cancelFlag);
          // Also update fs mtime
          await fs.utimes(dest, targetDate, targetDate);
          results.push({ from: filePath, to: dest, status: "ok", error: null });
        } catch (e) {
          const msg = e instanceof Error ? e.message : String(e);
          if (msg === "cancelled") {
            results.push({ from: filePath, to: null, status: "error", error: "cancelled" });
            break;
          }
          results.push({ from: filePath, to: null, status: "error", error: msg });
        }
      }
    } else {
      // inplace: write metadata to a temp file then replace original
      if (dryRun) {
        results.push({ from: filePath, to: filePath, status: "dryrun", error: null });
      } else {
        const ext = path.extname(filePath);
        const tmpDest = await safeDest(filePath.replace(ext, `_tmp${ext}`));
        const args = [
          "-y",
          "-i", filePath,
          "-c", "copy",
          "-metadata", `creation_time=${creationTimeStr}`,
          tmpDest,
        ];
        try {
          await runFfmpeg(ffmpegPath, args, jobId, cancelFlag);
          // Replace original
          await fs.rename(tmpDest, filePath);
          // Update fs mtime
          await fs.utimes(filePath, targetDate, targetDate);
          results.push({ from: filePath, to: filePath, status: "ok", error: null });
        } catch (e) {
          const msg = e instanceof Error ? e.message : String(e);
          // Clean up temp if it exists
          try { await fs.unlink(tmpDest); } catch { /* ignore */ }
          if (msg === "cancelled") {
            results.push({ from: filePath, to: null, status: "error", error: "cancelled" });
            break;
          }
          results.push({ from: filePath, to: null, status: "error", error: msg });
        }
      }
    }

    done++;
    currentTime += stepSeconds * 1000;
    emitProgress({ jobId, done, total, phase: "timestamping" });
  }

  return { results, cancelled: cancelFlag.cancelled };
}
