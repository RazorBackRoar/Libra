/**
 * Recursive directory/file scanner.
 * Walks provided paths, filters by extension, probes with bounded concurrency.
 */

import * as fs from "node:fs/promises";
import * as path from "node:path";
import { probeFile } from "./ffprobe.js";
import { emitProgress } from "./jobs.js";
import { OUTPUT_FOLDER_NAMES, isHousekeepingName, type VideoInfo } from "./types.js";

const CONCURRENCY = 4;
const OUTPUT_FOLDERS = new Set(OUTPUT_FOLDER_NAMES);

/**
 * Collect video file paths under root (recursive). Recursion is safe:
 * - app-created output folders (4K/1080p/720p/HD/SD/MISC) are skipped so
 *   re-runs never re-read prior output,
 * - symbolic links are skipped (and reported),
 * - macOS housekeeping entries are ignored.
 */
async function collectFiles(
  root: string,
  extensionSet: Set<string>,
  out: string[],
  skippedSymlinks: string[],
  isTopLevel: boolean,
): Promise<void> {
  let stat;
  try {
    stat = await fs.stat(root);
  } catch {
    return; // skip unreadable paths
  }

  if (stat.isFile()) {
    const ext = path.extname(root).replace(/^\./, "").toLowerCase();
    if (extensionSet.has(ext)) out.push(root);
    return;
  }

  if (!stat.isDirectory()) return;

  // Never recurse into the app's own output folders (unless the user dropped
  // one of them directly as the top-level path).
  if (!isTopLevel && OUTPUT_FOLDERS.has(path.basename(root))) return;

  let entries;
  try {
    entries = await fs.readdir(root, { withFileTypes: true });
  } catch {
    return;
  }

  for (const entry of entries) {
    if (isHousekeepingName(entry.name)) continue;
    const full = path.join(root, entry.name);
    if (entry.isSymbolicLink()) {
      skippedSymlinks.push(full);
      continue;
    }
    if (entry.isDirectory()) {
      await collectFiles(full, extensionSet, out, skippedSymlinks, false);
    } else if (entry.isFile()) {
      const ext = path.extname(entry.name).replace(/^\./, "").toLowerCase();
      if (extensionSet.has(ext)) out.push(full);
    }
  }
}

export interface ScanResult {
  files: VideoInfo[];
  cancelled: boolean;
  skippedSymlinks: string[];
}

export async function scan(opts: {
  jobId: string;
  paths: string[];
  extensions: string[];
  ffprobePath: string;
  cancelFlag: { cancelled: boolean };
}): Promise<ScanResult> {
  const { jobId, paths, extensions, ffprobePath, cancelFlag } = opts;
  const extensionSet = new Set(extensions.map((e) => e.toLowerCase()));

  // Phase 1: collect file paths
  emitProgress({ jobId, done: 0, total: 0, phase: "scanning" });
  const filePaths: string[] = [];
  const skippedSymlinks: string[] = [];
  for (const p of paths) {
    if (cancelFlag.cancelled) return { files: [], cancelled: true, skippedSymlinks };
    await collectFiles(p, extensionSet, filePaths, skippedSymlinks, true);
  }

  const total = filePaths.length;
  const results: VideoInfo[] = [];
  let done = 0;

  // Phase 2: probe with bounded concurrency
  emitProgress({ jobId, done: 0, total, phase: "probing" });

  async function probe(filePath: string): Promise<void> {
    if (cancelFlag.cancelled) return;
    const info = await probeFile(ffprobePath, filePath);
    results.push(info);
    done++;
    emitProgress({ jobId, done, total, phase: "probing" });
  }

  // Process in batches of CONCURRENCY
  for (let i = 0; i < filePaths.length; i += CONCURRENCY) {
    if (cancelFlag.cancelled) break;
    const batch = filePaths.slice(i, i + CONCURRENCY);
    await Promise.all(batch.map(probe));
  }

  return { files: results, cancelled: cancelFlag.cancelled, skippedSymlinks };
}
