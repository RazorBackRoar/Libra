/**
 * L!bra processing engine.
 *
 * Runs the full pipeline against the exact dropped folder:
 *   1. Organize recognized videos per the selected mode (rotation-corrected
 *      classification already done at scan time), using the standardized
 *      filename template with per-category numbering and exact-duplicate
 *      X-suffixes.
 *   2. Move every non-video (and any unreadable/corrupted video) into a MISC
 *      subfolder inside the dropped folder.
 *   3. Never wrap the dropped folder in an extra parent. Depth is capped at
 *      2 layers below the dropped folder, except Max Vid (3 layers).
 *
 * Errors on a single file never stop the batch, except disk-full or the
 * dropped folder becoming unavailable, which halt the run with a report of
 * what completed.
 */

import { createHash } from "node:crypto";
import { createReadStream } from "node:fs";
import * as fs from "node:fs/promises";
import * as path from "node:path";
import { emitProgress } from "./jobs.js";
import {
    OUTPUT_FOLDER_NAMES,
    folderOrientation,
    fpsFolderToken,
    fpsToken,
    isHousekeepingName,
    orientationCode,
    type ProcessReport,
    type ProcessResultItem,
    type SortMode,
    type VideoInfo
} from "./types.js";

const OUTPUT_FOLDERS = new Set(OUTPUT_FOLDER_NAMES);

// ─── Stop signal for fatal, batch-ending conditions ──────────────────────────

class StopError extends Error {
  constructor(public reason: string) {
    super(reason);
  }
}

function classifyFsError(e: unknown): "disk-full" | "root-gone" | "permission" | "other" {
  const code = (e as { code?: string })?.code;
  if (code === "ENOSPC") return "disk-full";
  if (code === "ENOENT" || code === "EIO" || code === "ENXIO") return "root-gone";
  if (code === "EACCES" || code === "EPERM" || code === "EBUSY" || code === "ETXTBSY") return "permission";
  return "other";
}

// ─── Naming helpers ───────────────────────────────────────────────────────────

function escapeRegex(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/** Remove characters illegal in macOS filenames (and control chars). */
function sanitizePrefix(raw: string | undefined): string {
  if (!raw) return "";
  let out = "";
  for (const ch of raw) {
    if (ch === "/" || ch === "\\" || ch === ":") continue;
    if (ch.charCodeAt(0) < 0x20) continue; // strip control characters
    out += ch;
  }
  return out.trim();
}

/** Emoji segment in the fixed order 📱 📷 🌍 ✂️, empty when none apply. */
function emojiSet(info: VideoInfo): string {
  let s = "";
  if (info.isApple) s += "📱";
  if (info.hasCameraInfo) s += "📷";
  if (info.hasGPS) s += "🌍";
  if (info.isEdited) s += "✂️";
  return s;
}

/** Strip a previously-applied L!bra convention suffix so re-runs never stack
 *  metadata (e.g. "Jennifer 1080p W 60 📱🌍 003" → "Jennifer"). */
function stripConventionSuffix(base: string): string {
  let b = base;
  // trailing " RES O fps [emoji] NNN [X…]" (emojis are a single non-space, non-digit run).
  b = b.replace(
    /\s+(?:4K|1080p|720p|HD|SD|Unknown)\s+[WV]\s+(?:30|60)(?:\s+[^\s\d]+)?\s+\d{3,}(?:\s+X+)?$/iu,
    "",
  );
  // trailing " NNN" / " NNN X…" (bare number suffix from old names or duplicates).
  b = b.replace(/\s+\d{3,}(?:\s+X+)?$/i, "");
  return b.trim();
}

/** Name base: the custom prefix when provided, else the original filename base
 *  with any prior convention suffix stripped (spec §15). */
function baseNameFor(prefix: string, info: VideoInfo): string {
  if (prefix) return prefix;
  const originalBase = info.name.slice(0, info.name.length - path.extname(info.name).length);
  return sanitizePrefix(stripConventionSuffix(originalBase)) || "video";
}

/** Full name without NUMBER/extension: "{base} {RES} {O} {fps} [emojis]" (spec §15). */
function buildBaseName(prefix: string, info: VideoInfo): string {
  const parts: string[] = [
    baseNameFor(prefix, info),
    info.resolutionClass,
    `${orientationCode(info.orientation)} ${fpsToken(info.fps)}`,
  ];
  const em = emojiSet(info);
  if (em) parts.push(em);
  return parts.join(" ");
}

/** 3-digit zero-padded; extends to 4+ digits past 999. */
function numberStr(n: number): string {
  return n < 1000 ? String(n).padStart(3, "0") : String(n);
}

/** Output-group token (resolution + orientation + frame rate) used to reset
 *  numbering in Pro Vid (spec §18). */
function groupToken(info: VideoInfo): string {
  return `${info.resolutionClass} ${orientationCode(info.orientation)} ${fpsToken(info.fps)}`;
}

function targetDir(root: string, mode: SortMode, info: VideoInfo): string {
  switch (mode) {
    case "ProVid":
      return info.dir; // rename in place
    case "VidRes":
    case "KeepName":
      return path.join(root, info.resolutionClass);
    case "ProMax":
      // Resolution/Orientation (2 layers): e.g. "4K/Wide".
      return path.join(root, info.resolutionClass, folderOrientation(info.orientation));
    case "MaxVid":
      // Resolution/Orientation+FPS (2 layers): e.g. "4K/Wide 60fps".
      return path.join(
        root,
        info.resolutionClass,
        `${folderOrientation(info.orientation)} ${fpsFolderToken(info.fps)}`,
      );
    case "SlowMotion":
      return path.join(root, info.isSlowMotion ? "Slow Motion" : "Normal Speed");
  }
}

// ─── Filesystem helpers ─────────────────────────────────────────────────────

async function pathExists(p: string): Promise<boolean> {
  try {
    await fs.access(p);
    return true;
  } catch {
    return false;
  }
}

/** Collision-safe destination using the X-suffix scheme ("name X.ext", "name XX.ext", …). */
async function safeDestX(targetPath: string): Promise<string> {
  if (!(await pathExists(targetPath))) return targetPath;
  const ext = path.extname(targetPath);
  const base = targetPath.slice(0, targetPath.length - ext.length);
  let x = 1;
  while (true) {
    const candidate = `${base} ${"X".repeat(x)}${ext}`;
    if (!(await pathExists(candidate))) return candidate;
    x++;
  }
}

/**
 * Highest existing NUMBER in a directory (0 if none), used to seed numbering on
 * re-runs. When `groupInfix` is given (Pro Vid), only files whose name contains
 * that output-group token are considered; otherwise (folder modes) every
 * conventioned file in the folder counts.
 */
async function existingMaxNumber(dir: string, ext: string, groupInfix: string | null): Promise<number> {
  let entries: string[];
  try {
    entries = await fs.readdir(dir);
  } catch {
    return 0;
  }
  const re = groupInfix
    ? new RegExp(` ${escapeRegex(groupInfix)}(?: [^ ]+)? (\\d{3,})( X+)?${escapeRegex(ext)}$`, "i")
    : new RegExp(` (\\d{3,})( X+)?${escapeRegex(ext)}$`, "i");
  let max = 0;
  for (const name of entries) {
    const m = re.exec(name);
    if (m) {
      const n = parseInt(m[1]!, 10);
      if (n > max) max = n;
    }
  }
  return max;
}

async function hashFile(filePath: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const hash = createHash("sha256");
    const stream = createReadStream(filePath);
    stream.on("error", reject);
    stream.on("data", (chunk) => hash.update(chunk));
    stream.on("end", () => resolve(hash.digest("hex")));
  });
}

// ─── Dropped-folder root resolution ──────────────────────────────────────────

async function resolveDroppedRoot(droppedPaths: string[]): Promise<string> {
  if (droppedPaths.length === 0) throw new Error("No dropped paths provided");
  if (droppedPaths.length === 1) {
    const only = droppedPaths[0]!;
    try {
      const stat = await fs.stat(only);
      if (stat.isDirectory()) return only;
    } catch {
      /* fall through */
    }
    return path.dirname(only);
  }
  // Multiple selections — assume they share one parent folder.
  return path.dirname(droppedPaths[0]!);
}

// ─── MISC / non-video collection ─────────────────────────────────────────────

async function collectNonVideos(
  root: string,
  extensionSet: Set<string>,
  nonVideos: string[],
  symlinks: string[],
  depth = 0,
): Promise<void> {
  if (depth > 2) return;
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
      symlinks.push(full);
      continue;
    }
    if (entry.isDirectory()) {
      // Never descend into our own output folders (incl. MISC) and never go
      // deeper than 2 layers below the dropped folder.
      if (OUTPUT_FOLDERS.has(entry.name)) continue;
      if (depth < 2) {
        await collectNonVideos(full, extensionSet, nonVideos, symlinks, depth + 1);
      }
    } else if (entry.isFile()) {
      const ext = path.extname(entry.name).replace(/^\./, "").toLowerCase();
      if (!extensionSet.has(ext)) nonVideos.push(full);
    }
  }
}

// ─── Main pipeline ────────────────────────────────────────────────────────────

export interface ProcessOptions {
  jobId: string;
  mode: SortMode;
  files: VideoInfo[]; // videos to organize (error === null, already filtered)
  unreadablePaths: string[]; // video-ext files that failed to probe → MISC
  droppedPaths: string[];
  prefix: string | undefined;
  dryRun: boolean;
  extensions: string[];
  cancelFlag: { cancelled: boolean };
}

export async function processFolder(opts: ProcessOptions): Promise<ProcessReport> {
  const { jobId, mode, files, unreadablePaths, droppedPaths, dryRun, extensions, cancelFlag } = opts;
  const prefix = sanitizePrefix(opts.prefix);
  const extensionSet = new Set(extensions.map((e) => e.toLowerCase()));

  const root = await resolveDroppedRoot(droppedPaths);
  const items: ProcessResultItem[] = [];
  let stopped: { reason: string } | null = null;

  // Non-video sweep up front so totals are known.
  const nonVideos: string[] = [];
  const symlinks: string[] = [];
  await collectNonVideos(root, extensionSet, nonVideos, symlinks);

  const total = files.length + unreadablePaths.length + nonVideos.length;
  let done = 0;
  emitProgress({ jobId, done, total, phase: "processing" });

  // Per-category numbering counters (seeded lazily from disk for re-runs).
  const counters = new Map<string, number>();
  async function nextNumber(key: string, dir: string, ext: string, groupInfix: string | null): Promise<number> {
    if (!counters.has(key)) {
      const seed = await existingMaxNumber(dir, ext, groupInfix);
      counters.set(key, seed + 1);
    }
    const n = counters.get(key)!;
    counters.set(key, n + 1);
    return n;
  }

  // Content-hash memory for exact-duplicate detection.
  const sizeCounts = new Map<number, number>();
  for (const f of files) sizeCounts.set(f.sizeBytes, (sizeCounts.get(f.sizeBytes) ?? 0) + 1);
  const seenHash = new Map<string, { fullBase: string; dupCount: number; dir: string; ext: string }>();

  const generatesNames = mode !== "KeepName" && mode !== "SlowMotion";

  // Perform a move/rename, classifying fatal vs. skippable errors.
  async function performMove(
    from: string,
    destPath: string,
    kind: ProcessResultItem["kind"],
    note: string | null,
  ): Promise<void> {
    const dest = await safeDestX(destPath);
    if (dryRun) {
      items.push({ from, to: dest, status: "dryrun", kind, note });
      return;
    }
    try {
      await fs.mkdir(path.dirname(dest), { recursive: true });
      await fs.rename(from, dest);
      items.push({ from, to: dest, status: "ok", kind, note });
    } catch (e) {
      const cls = classifyFsError(e);
      const msg = e instanceof Error ? e.message : String(e);
      if (cls === "disk-full") throw new StopError("Disk full — run stopped early.");
      if (cls === "root-gone" && !(await pathExists(root))) {
        throw new StopError("The dropped folder became unavailable — run stopped early.");
      }
      if (cls === "permission") {
        items.push({ from, to: null, status: "skipped", kind, note: "skipped — permission denied or file in use" });
        return;
      }
      items.push({ from, to: null, status: "error", kind, note: msg });
    }
  }

  try {
    // 1) Organize videos.
    for (const info of files) {
      if (cancelFlag.cancelled) break;
      const dir = targetDir(root, mode, info);
      const ext = path.extname(info.name);
      const abnormalNote = info.rotateAbnormal
        ? `non-standard rotate metadata (${info.rotate}) — treated as unrotated`
        : null;

      if (generatesNames) {
        const baseName = buildBaseName(prefix, info);
        const orientFps = `${orientationCode(info.orientation)} ${fpsToken(info.fps)}`;
        const conventionRe = new RegExp(
          `^${escapeRegex(baseName)} ${escapeRegex(info.resolutionClass)} ${escapeRegex(orientFps)}(?:\\s+[^\\s\\d]+)?\\s+(\\d{3,})(?:\\s+X+)?${escapeRegex(ext)}$`,
          "iu",
        );

        // Already organized (correct folder + convention name) → skip.
        if (path.dirname(info.path) === dir && conventionRe.test(info.name)) {
          items.push({ from: info.path, to: info.path, status: "skipped", kind: "organized", note: "already organized" });
          done++;
          emitProgress({ jobId, done, total, phase: "processing" });
          continue;
        }

        // Exact-duplicate detection (size first, then hash).
        let dupOf: { fullBase: string; dupCount: number; dir: string; ext: string } | null = null;
        let hash: string | null = null;
        if ((sizeCounts.get(info.sizeBytes) ?? 0) > 1) {
          try {
            hash = await hashFile(info.path);
          } catch {
            hash = null;
          }
          if (hash && seenHash.has(hash)) dupOf = seenHash.get(hash)!;
        }

        if (dupOf) {
          dupOf.dupCount++;
          const name = `${dupOf.fullBase} ${"X".repeat(dupOf.dupCount)}${ext}`;
          await performMove(info.path, path.join(dupOf.dir, name), "duplicate", abnormalNote);
        } else {
          // Numbering resets per output group (spec §18): Pro Vid → per
          // (dir, resolution+orientation+fps); folder modes → per target folder
          // (which already encodes resolution / +orientation / +fps).
          const gt = groupToken(info);
          const key = mode === "ProVid" ? `PV|${dir}|${gt}` : `${mode}|${dir}`;
          const groupInfix = mode === "ProVid" ? gt : null;
          const num = await nextNumber(key, dir, ext, groupInfix);
          const fullBase = `${baseName} ${numberStr(num)}`;
          const name = `${fullBase}${ext}`;
          if (hash) seenHash.set(hash, { fullBase, dupCount: 0, dir, ext });
          await performMove(info.path, path.join(dir, name), "organized", abnormalNote);
        }
      } else {
        // KeepName / SlowMotion — original filename preserved; only sort into folders.
        if (path.dirname(info.path) === dir) {
          items.push({ from: info.path, to: info.path, status: "skipped", kind: "organized", note: "already organized" });
        } else {
          await performMove(info.path, path.join(dir, info.name), "organized", abnormalNote);
        }
      }
      done++;
      emitProgress({ jobId, done, total, phase: "processing" });
    }

    // 2) Unreadable/corrupted videos → MISC (logged distinctly).
    const miscDir = path.join(root, "MISC");
    for (const p of unreadablePaths) {
      if (cancelFlag.cancelled) break;
      await performMove(p, path.join(miscDir, path.basename(p)), "unreadable", "moved to MISC — unreadable/corrupted video");
      done++;
      emitProgress({ jobId, done, total, phase: "processing" });
    }

    // 3) Non-videos → MISC.
    for (const p of nonVideos) {
      if (cancelFlag.cancelled) break;
      await performMove(p, path.join(miscDir, path.basename(p)), "misc", null);
      done++;
      emitProgress({ jobId, done, total, phase: "processing" });
    }
  } catch (e) {
    if (e instanceof StopError) {
      stopped = { reason: e.reason };
    } else {
      throw e;
    }
  }

  // 4) Report skipped symlinks.
  for (const link of symlinks) {
    items.push({ from: link, to: null, status: "skipped", kind: "misc", note: "symbolic link — skipped" });
  }

  const counts = {
    organized: items.filter((i) => i.kind === "organized" && (i.status === "ok" || i.status === "dryrun")).length,
    duplicates: items.filter((i) => i.kind === "duplicate" && (i.status === "ok" || i.status === "dryrun")).length,
    misc: items.filter((i) => i.kind === "misc" && (i.status === "ok" || i.status === "dryrun")).length,
    unreadable: items.filter((i) => i.kind === "unreadable" && (i.status === "ok" || i.status === "dryrun")).length,
    skipped: items.filter((i) => i.status === "skipped").length,
    errors: items.filter((i) => i.status === "error").length,
  };

  return {
    mode,
    dryRun,
    droppedRoot: root,
    items,
    counts,
    stopped,
    noVideos: files.length === 0,
  };
}
