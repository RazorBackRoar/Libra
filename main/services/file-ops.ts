/**
 * File operations — move, rename, copy, delete with collision auto-suffix.
 * Never overwrites; supports dryRun.
 */

import * as fs from "node:fs/promises";
import * as path from "node:path";
import type { FileOpResult, VideoInfo, SortMode } from "./types.js";

// ─── Collision-safe destination ───────────────────────────────────────────────

/**
 * Given a target path, find a non-existing path by appending (1), (2), …
 */
export async function safeDest(targetPath: string): Promise<string> {
  let candidate = targetPath;
  let counter = 1;
  while (true) {
    try {
      await fs.access(candidate);
      // File exists — generate next candidate
      const ext = path.extname(targetPath);
      const base = targetPath.slice(0, targetPath.length - ext.length);
      candidate = `${base} (${counter})${ext}`;
      counter++;
    } catch {
      // access threw → file doesn't exist
      return candidate;
    }
  }
}

// ─── Core operations ──────────────────────────────────────────────────────────

async function ensureDir(dir: string): Promise<void> {
  await fs.mkdir(dir, { recursive: true });
}

export async function moveFile(
  from: string,
  to: string,
  dryRun: boolean,
): Promise<FileOpResult> {
  const dest = await safeDest(to);
  if (dryRun) {
    return { from, to: dest, status: "dryrun", error: null };
  }
  try {
    await ensureDir(path.dirname(dest));
    await fs.rename(from, dest);
    return { from, to: dest, status: "ok", error: null };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return { from, to: dest, status: "error", error: msg };
  }
}

export async function copyFile(
  from: string,
  to: string,
  dryRun: boolean,
): Promise<FileOpResult> {
  const dest = await safeDest(to);
  if (dryRun) {
    return { from, to: dest, status: "dryrun", error: null };
  }
  try {
    await ensureDir(path.dirname(dest));
    await fs.copyFile(from, dest);
    return { from, to: dest, status: "ok", error: null };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return { from, to: dest, status: "error", error: msg };
  }
}

export async function deleteFile(
  filePath: string,
  dryRun: boolean,
): Promise<{ path: string; status: "ok" | "error"; error: string | null }> {
  if (dryRun) {
    return { path: filePath, status: "ok", error: null };
  }
  try {
    await fs.unlink(filePath);
    return { path: filePath, status: "ok", error: null };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return { path: filePath, status: "error", error: msg };
  }
}

// ─── Rename helpers ───────────────────────────────────────────────────────────

/**
 * Apply prefix rename in-place (ProVid sort, rename:apply).
 * New name: prefix + original basename.
 */
export function buildRenamedPath(info: VideoInfo, prefix: string): string {
  const newName = prefix + info.name;
  return path.join(info.dir, newName);
}

/**
 * Build destination path for a sort move.
 * Folders are created under each file's own dir unless destRoot is given.
 */
export function buildSortDestPath(
  info: VideoInfo,
  mode: SortMode,
  prefix: string | undefined,
  destRoot: string | undefined,
): string {
  const base = destRoot ?? info.dir;
  const ext = path.extname(info.name);
  const stem = info.name.slice(0, info.name.length - ext.length);
  const newStem = prefix ? prefix + stem : stem;
  const newName = newStem + ext;

  switch (mode) {
    case "ProVid": {
      // Rename in place
      return path.join(info.dir, newName);
    }
    case "VidRes": {
      return path.join(base, info.resolutionClass, newName);
    }
    case "ProMax": {
      return path.join(base, info.resolutionClass, info.orientation, newName);
    }
    case "MaxVid": {
      const fps = info.fps !== null ? `${info.fps}fps` : "unknownfps";
      return path.join(base, info.resolutionClass, info.orientation, fps, newName);
    }
    case "KeepName": {
      // Same folder structure as VidRes but never alter the filename
      return path.join(base, info.resolutionClass, info.name);
    }
    case "SlowMotion": {
      return path.join(base, info.isSlowMotion ? "Slow Motion" : "Normal Speed", newName);
    }
  }
}

// ─── Batch operations ─────────────────────────────────────────────────────────

export async function applySort(opts: {
  mode: SortMode;
  files: VideoInfo[];
  prefix: string | undefined;
  dryRun: boolean;
  destRoot: string | undefined;
}): Promise<FileOpResult[]> {
  const { mode, files, prefix, dryRun, destRoot } = opts;
  const results: FileOpResult[] = [];
  for (const info of files) {
    const dest = buildSortDestPath(info, mode, prefix, destRoot);
    if (mode === "ProVid") {
      // Rename in place (same dir, no move needed if names differ)
      const result = await moveFile(info.path, dest, dryRun);
      results.push(result);
    } else {
      const result = await moveFile(info.path, dest, dryRun);
      results.push(result);
    }
  }
  return results;
}

export async function applyRename(opts: {
  files: VideoInfo[];
  prefix: string | undefined;
  dryRun: boolean;
}): Promise<FileOpResult[]> {
  const { files, prefix, dryRun } = opts;
  const results: FileOpResult[] = [];
  for (const info of files) {
    const dest = buildRenamedPath(info, prefix ?? "");
    const result = await moveFile(info.path, dest, dryRun);
    results.push(result);
  }
  return results;
}

export async function applyMove(opts: {
  moves: { from: string; toDir: string }[];
  dryRun: boolean;
}): Promise<FileOpResult[]> {
  const { moves, dryRun } = opts;
  const results: FileOpResult[] = [];
  for (const { from, toDir } of moves) {
    const dest = await safeDest(path.join(toDir, path.basename(from)));
    if (dryRun) {
      results.push({ from, to: dest, status: "dryrun", error: null });
      continue;
    }
    try {
      await fs.mkdir(toDir, { recursive: true });
      await fs.rename(from, dest);
      results.push({ from, to: dest, status: "ok", error: null });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      results.push({ from, to: dest, status: "error", error: msg });
    }
  }
  return results;
}

export async function applyDelete(opts: {
  paths: string[];
  dryRun: boolean;
}): Promise<{ deleted: number; failed: number; results: { path: string; status: "ok" | "error"; error: string | null }[] }> {
  const { paths, dryRun } = opts;
  const results: { path: string; status: "ok" | "error"; error: string | null }[] = [];
  let deleted = 0;
  let failed = 0;
  for (const p of paths) {
    const r = await deleteFile(p, dryRun);
    results.push(r);
    if (r.status === "ok") deleted++;
    else failed++;
  }
  return { deleted, failed, results };
}
