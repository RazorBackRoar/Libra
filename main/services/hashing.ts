/**
 * Streamed MD5 hashing and duplicate grouping.
 */

import * as crypto from "node:crypto";
import * as fs from "node:fs";
import { probeFile } from "./ffprobe.js";
import { emitProgress } from "./jobs.js";
import type { VideoInfo, DuplicateGroup } from "./types.js";

const CONCURRENCY = 4;

/** Compute MD5 of a file via streaming (never buffers the whole file). */
function hashFile(filePath: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const hash = crypto.createHash("md5");
    const stream = fs.createReadStream(filePath);
    stream.on("error", reject);
    stream.on("data", (chunk: Buffer | string) => hash.update(chunk));
    stream.on("end", () => resolve(hash.digest("hex")));
  });
}

export interface HashDuplicatesResult {
  groups: DuplicateGroup[];
  cancelled: boolean;
}

export async function findDuplicates(opts: {
  jobId: string;
  files: VideoInfo[];
  ffprobePath: string;
  cancelFlag: { cancelled: boolean };
}): Promise<HashDuplicatesResult> {
  const { jobId, files, cancelFlag } = opts;
  const total = files.length;
  let done = 0;

  const hashMap = new Map<string, VideoInfo[]>();

  emitProgress({ jobId, done: 0, total, phase: "hashing" });

  async function processOne(info: VideoInfo): Promise<void> {
    if (cancelFlag.cancelled) return;
    try {
      const md5 = await hashFile(info.path);
      const entry = { ...info, md5 };
      const existing = hashMap.get(md5);
      if (existing) {
        existing.push(entry);
      } else {
        hashMap.set(md5, [entry]);
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.log("[hashing] hashFile failed", { path: info.path, error: msg });
      // Skip files that can't be hashed
    }
    done++;
    emitProgress({ jobId, done, total, phase: "hashing" });
  }

  // Process with bounded concurrency
  for (let i = 0; i < files.length; i += CONCURRENCY) {
    if (cancelFlag.cancelled) break;
    const batch = files.slice(i, i + CONCURRENCY);
    await Promise.all(batch.map(processOne));
  }

  // Only return groups with ≥ 2 files
  const groups: DuplicateGroup[] = [];
  for (const [hash, groupFiles] of hashMap) {
    if (groupFiles.length >= 2) {
      groups.push({ hash, files: groupFiles });
    }
  }

  return { groups, cancelled: cancelFlag.cancelled };
}

/**
 * Hash a list of raw file paths (when caller passes paths instead of VideoInfo).
 * Probes files first then hashes.
 */
export async function findDuplicatesFromPaths(opts: {
  jobId: string;
  paths: string[];
  extensions: string[];
  ffprobePath: string;
  cancelFlag: { cancelled: boolean };
}): Promise<HashDuplicatesResult> {
  const { jobId, paths, extensions, ffprobePath, cancelFlag } = opts;
  const extSet = new Set(extensions.map((e) => e.toLowerCase()));

  // Filter paths by extension
  const filtered = paths.filter((p) => {
    const ext = p.split(".").pop()?.toLowerCase() ?? "";
    return extSet.has(ext);
  });

  // Probe to get VideoInfo
  emitProgress({ jobId, done: 0, total: filtered.length, phase: "probing" });
  const infos: VideoInfo[] = [];
  let probeDone = 0;
  for (let i = 0; i < filtered.length; i += CONCURRENCY) {
    if (cancelFlag.cancelled) return { groups: [], cancelled: true };
    const batch = filtered.slice(i, i + CONCURRENCY);
    const results = await Promise.all(batch.map((p) => probeFile(ffprobePath, p)));
    infos.push(...results);
    probeDone += results.length;
    emitProgress({ jobId, done: probeDone, total: filtered.length, phase: "probing" });
  }

  return findDuplicates({ jobId, files: infos, ffprobePath, cancelFlag });
}
