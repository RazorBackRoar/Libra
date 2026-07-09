/**
 * Handler Registration
 *
 * Register all IPC handlers here.
 */

import * as path from "path";
import { fileURLToPath } from "url";
import * as fs from "node:fs/promises";

import { appHandlers } from "./app.js";
import { getSettingsWindow, openSettingsWindow } from "../windows/settings-window.js";

import { ipcMain, logger, shell, dialog } from "@electron-core/backend";

// Services
import { resolveBinaryPath } from "../services/cli-utils.js";
import { settingsStore } from "../services/settings-store.js";
import { registerJob, cancelJob, cleanupJob } from "../services/jobs.js";
import { scan } from "../services/scanner.js";
import { applySort, applyRename, applyDelete, applyMove } from "../services/file-ops.js";
import { processFolder } from "../services/processor.js";
import { createSloMo, applyTimeAdjust } from "../services/ffmpeg-ops.js";
import { getThumbnailPath } from "../services/thumbnails.js";
import { type VideoInfo, type SortMode } from "../services/types.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ─── Typed param interfaces (keep inline for IPC boundary validation) ─────────

interface ScanStartParams {
  jobId: string;
  paths: string[];
  extensions?: string[];
}

interface JobCancelParams {
  jobId: string;
}

interface SortApplyParams {
  mode: SortMode;
  files: VideoInfo[];
  prefix?: string;
  dryRun: boolean;
  destRoot?: string;
}

interface RenameApplyParams {
  files: VideoInfo[];
  prefix?: string;
  dryRun: boolean;
}

interface ProcessRunParams {
  jobId: string;
  mode: SortMode;
  files: VideoInfo[];
  unreadablePaths: string[];
  droppedPaths: string[];
  prefix?: string;
  dryRun: boolean;
}

interface FilesDeleteParams {
  paths: string[];
  dryRun: boolean;
}

interface FilesMoveParams {
  moves: { from: string; toDir: string }[];
  dryRun: boolean;
}

interface SlomoCreateParams {
  jobId: string;
  files: string[];
  factor: number;
  dryRun: boolean;
}

interface TimeAdjustParams {
  jobId: string;
  files: string[];
  startISO: string;
  stepSeconds: number;
  mode: "copies" | "inplace";
  dryRun: boolean;
}

interface CsvExportParams {
  rows: string[][];
  suggestedName?: string;
}

interface RevealInFinderParams {
  path: string;
}

interface ThumbnailGetParams {
  path: string;
}

interface SettingsSetParams {
  patch: Partial<import("../services/types.js").Settings>;
}

// ─── Helper: resolve ffmpeg/ffprobe paths from settings ──────────────────────

async function getFfmpegPath(): Promise<string> {
  const settings = await settingsStore.get();
  const p = await resolveBinaryPath(settings.ffmpegPath, "ffmpeg");
  if (!p) throw new Error("ffmpeg not found. Install via brew install ffmpeg or set path in Settings.");
  return p;
}

async function getFfprobePath(): Promise<string> {
  const settings = await settingsStore.get();
  const p = await resolveBinaryPath(settings.ffprobePath, "ffprobe");
  if (!p) throw new Error("ffprobe not found. Install via brew install ffmpeg or set path in Settings.");
  return p;
}

// ─── Type guard helpers ───────────────────────────────────────────────────────

function assertString(val: unknown, name: string): string {
  if (typeof val !== "string") throw new Error(`${name} must be a string`);
  return val;
}

function assertStringArray(val: unknown, name: string): string[] {
  if (!Array.isArray(val) || !val.every((v) => typeof v === "string"))
    throw new Error(`${name} must be a string[]`);
  return val as string[];
}

function assertBoolean(val: unknown, name: string): boolean {
  if (typeof val !== "boolean") throw new Error(`${name} must be a boolean`);
  return val;
}

function assertNumber(val: unknown, name: string): number {
  if (typeof val !== "number" || !isFinite(val)) throw new Error(`${name} must be a finite number`);
  return val;
}

export function registerHandlers(): void {
  logger.info("handlers", "Registering IPC handlers...");

  // ── Existing app/window handlers ────────────────────────────────────────────

  ipcMain.handle("app:getInfo", async (_event) => {
    return await appHandlers.getInfo();
  });

  ipcMain.handle("app:getProjectPath", async () => {
    return path.join(__dirname, "..", "..");
  });

  ipcMain.handle("window:openSettings", async (_event) => {
    await openSettingsWindow();
  });

  ipcMain.handle("window:closeSettings", async (_event) => {
    getSettingsWindow()?.close();
  });

  // ── deps:check ──────────────────────────────────────────────────────────────

  ipcMain.handle("deps:check", async (_event, _params: unknown) => {
    logger.info("handlers", "[deps:check]");
    const settings = await settingsStore.get();
    const ffmpegPath = await resolveBinaryPath(settings.ffmpegPath, "ffmpeg");
    const ffprobePath = await resolveBinaryPath(settings.ffprobePath, "ffprobe");
    const result = {
      ffmpeg: ffmpegPath !== null,
      ffprobe: ffprobePath !== null,
      ffmpegPath,
      ffprobePath,
    };
    console.log("[deps:check]", result);
    return result;
  });

  // ── deps:install ────────────────────────────────────────────────────────────

  ipcMain.handle("deps:install", async (_event, _params: unknown) => {
    logger.info("handlers", "[deps:install] Starting brew install ffmpeg");
    console.log("[deps:install]", { action: "brew install ffmpeg" });
    const { execFile } = await import("node:child_process");
    const { promisify } = await import("node:util");
    const execFileAsync = promisify(execFile);
    try {
      await execFileAsync("brew", ["install", "ffmpeg"], {
        maxBuffer: 10 * 1024 * 1024,
        timeout: 10 * 60_000,
      });
      console.log("[deps:install]", { result: "success" });
      return { success: true };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.log("[deps:install]", { error: msg });
      return { success: false, error: msg };
    }
  });

  // ── scan:start ──────────────────────────────────────────────────────────────

  ipcMain.handle("scan:start", async (_event, params: unknown) => {
    const p = params as ScanStartParams;
    const jobId = assertString(p?.jobId, "jobId");
    const paths = assertStringArray(p?.paths, "paths");
    const settings = await settingsStore.get();
    const extensions = Array.isArray(p?.extensions) ? (p.extensions as string[]) : settings.videoExtensions;
    console.log("[scan:start]", { jobId, paths, extensions });

    const ffprobePath = await getFfprobePath();
    const { cancelFlag } = registerJob(jobId);

    try {
      const result = await scan({ jobId, paths, extensions, ffprobePath, cancelFlag });
      console.log("[scan:start] done", { jobId, fileCount: result.files.length, cancelled: result.cancelled });
      return result;
    } finally {
      cleanupJob(jobId);
    }
  });

  // ── job:cancel ──────────────────────────────────────────────────────────────

  ipcMain.handle("job:cancel", async (_event, params: unknown) => {
    const p = params as JobCancelParams;
    const jobId = assertString(p?.jobId, "jobId");
    console.log("[job:cancel]", { jobId });
    const cancelled = cancelJob(jobId);
    return { cancelled };
  });

  // ── sort:apply ──────────────────────────────────────────────────────────────

  ipcMain.handle("sort:apply", async (_event, params: unknown) => {
    const p = params as SortApplyParams;
    const mode = p?.mode as SortMode;
    if (!["ProVid", "VidRes", "ProMax", "MaxVid", "KeepName"].includes(mode)) {
      throw new Error(`Invalid sort mode: ${String(mode)}`);
    }
    const dryRun = assertBoolean(p?.dryRun, "dryRun");
    console.log("[sort:apply]", { mode, fileCount: p?.files?.length ?? 0, dryRun });
    const results = await applySort({
      mode,
      files: p.files,
      prefix: p.prefix,
      dryRun,
      destRoot: p.destRoot,
    });
    console.log("[sort:apply] done", { resultCount: results.length });
    return { results };
  });

  // ── process:run ───────────────────────────────────────────────────────────────

  ipcMain.handle("process:run", async (_event, params: unknown) => {
    const p = params as ProcessRunParams;
    const jobId = assertString(p?.jobId, "jobId");
    const mode = p?.mode as SortMode;
    if (!["ProVid", "VidRes", "ProMax", "MaxVid", "KeepName"].includes(mode)) {
      throw new Error(`Invalid mode: ${String(mode)}`);
    }
    const droppedPaths = assertStringArray(p?.droppedPaths, "droppedPaths");
    const unreadablePaths = Array.isArray(p?.unreadablePaths) ? assertStringArray(p.unreadablePaths, "unreadablePaths") : [];
    const dryRun = assertBoolean(p?.dryRun, "dryRun");
    const files = Array.isArray(p?.files) ? (p.files as VideoInfo[]) : [];
    const settings = await settingsStore.get();
    console.log("[process:run]", { jobId, mode, fileCount: files.length, unreadable: unreadablePaths.length, dryRun });

    const { cancelFlag } = registerJob(jobId);
    try {
      const report = await processFolder({
        jobId,
        mode,
        files,
        unreadablePaths,
        droppedPaths,
        prefix: p.prefix,
        dryRun,
        extensions: settings.videoExtensions,
        cancelFlag,
      });
      console.log("[process:run] done", { jobId, counts: report.counts, stopped: report.stopped });
      return report;
    } finally {
      cleanupJob(jobId);
    }
  });

  // ── rename:apply ────────────────────────────────────────────────────────────

  ipcMain.handle("rename:apply", async (_event, params: unknown) => {
    const p = params as RenameApplyParams;
    const dryRun = assertBoolean(p?.dryRun, "dryRun");
    console.log("[rename:apply]", { fileCount: p?.files?.length ?? 0, prefix: p?.prefix, dryRun });
    const results = await applyRename({
      files: p.files,
      prefix: p.prefix,
      dryRun,
    });
    console.log("[rename:apply] done", { resultCount: results.length });
    return { results };
  });

  // ── files:delete ─────────────────────────────────────────────────────────────

  ipcMain.handle("files:delete", async (_event, params: unknown) => {
    const p = params as FilesDeleteParams;
    const paths = assertStringArray(p?.paths, "paths");
    const dryRun = assertBoolean(p?.dryRun, "dryRun");
    console.log("[files:delete]", { count: paths.length, dryRun });
    const summary = await applyDelete({ paths, dryRun });
    console.log("[files:delete] done", { deleted: summary.deleted, failed: summary.failed });
    return summary;
  });

  // ── files:move ───────────────────────────────────────────────────────────────

  ipcMain.handle("files:move", async (_event, params: unknown) => {
    const p = params as FilesMoveParams;
    if (!Array.isArray(p?.moves)) throw new Error("moves must be an array");
    for (const m of p.moves as unknown[]) {
      if (
        typeof (m as Record<string, unknown>)?.from !== "string" ||
        typeof (m as Record<string, unknown>)?.toDir !== "string"
      ) {
        throw new Error("each move must have from: string and toDir: string");
      }
    }
    const dryRun = assertBoolean(p?.dryRun, "dryRun");
    const count = (p.moves as { from: string; toDir: string }[]).length;
    console.log("[files:move]", { count, dryRun });
    const results = await applyMove({ moves: p.moves as { from: string; toDir: string }[], dryRun });
    console.log("[files:move] done", { resultCount: results.length });
    return { results };
  });

  // ── slomo:create ─────────────────────────────────────────────────────────────

  ipcMain.handle("slomo:create", async (_event, params: unknown) => {
    const p = params as SlomoCreateParams;
    const jobId = assertString(p?.jobId, "jobId");
    const files = assertStringArray(p?.files, "files");
    const factor = assertNumber(p?.factor, "factor");
    const dryRun = assertBoolean(p?.dryRun, "dryRun");
    console.log("[slomo:create]", { jobId, fileCount: files.length, factor, dryRun });

    const ffmpegPath = await getFfmpegPath();
    const { cancelFlag } = registerJob(jobId);

    try {
      const result = await createSloMo({ jobId, files, factor, dryRun, ffmpegPath, cancelFlag });
      console.log("[slomo:create] done", { jobId, resultCount: result.results.length, cancelled: result.cancelled });
      return result;
    } finally {
      cleanupJob(jobId);
    }
  });

  // ── timeadjust:apply ─────────────────────────────────────────────────────────

  ipcMain.handle("timeadjust:apply", async (_event, params: unknown) => {
    const p = params as TimeAdjustParams;
    const jobId = assertString(p?.jobId, "jobId");
    const files = assertStringArray(p?.files, "files");
    const startISO = assertString(p?.startISO, "startISO");
    const stepSeconds = assertNumber(p?.stepSeconds, "stepSeconds");
    const mode = p?.mode;
    if (mode !== "copies" && mode !== "inplace") {
      throw new Error(`Invalid timeadjust mode: ${String(mode)}`);
    }
    const dryRun = assertBoolean(p?.dryRun, "dryRun");
    console.log("[timeadjust:apply]", { jobId, fileCount: files.length, startISO, stepSeconds, mode, dryRun });

    const ffmpegPath = await getFfmpegPath();
    const { cancelFlag } = registerJob(jobId);

    try {
      const result = await applyTimeAdjust({ jobId, files, startISO, stepSeconds, mode, dryRun, ffmpegPath, cancelFlag });
      console.log("[timeadjust:apply] done", { jobId, resultCount: result.results.length, cancelled: result.cancelled });
      return result;
    } finally {
      cleanupJob(jobId);
    }
  });

  // ── csv:export ────────────────────────────────────────────────────────────────

  ipcMain.handle("csv:export", async (_event, params: unknown) => {
    const p = params as CsvExportParams;
    if (!Array.isArray(p?.rows)) throw new Error("rows must be an array");
    const rows = p.rows as string[][];
    console.log("[csv:export]", { rowCount: rows.length, suggestedName: p.suggestedName });

    const saveResult = await dialog.showSaveDialog({
      title: "Export CSV",
      defaultPath: p.suggestedName ?? "export.csv",
      filters: [{ name: "CSV Files", extensions: ["csv"] }],
    });

    if (saveResult.canceled || !saveResult.filePath) {
      console.log("[csv:export]", { saved: false });
      return { saved: false, path: null };
    }

    const csvContent = rows
      .map((row) =>
        row
          .map((cell) => `"${String(cell).replace(/"/g, '""')}"`)
          .join(","),
      )
      .join("\n");

    await fs.writeFile(saveResult.filePath, csvContent, "utf-8");
    console.log("[csv:export]", { saved: true, path: saveResult.filePath });
    return { saved: true, path: saveResult.filePath };
  });

  // ── reveal:inFinder ───────────────────────────────────────────────────────────

  ipcMain.handle("reveal:inFinder", async (_event, params: unknown) => {
    const p = params as RevealInFinderParams;
    const filePath = assertString(p?.path, "path");
    console.log("[reveal:inFinder]", { path: filePath });
    try {
      shell.showItemInFolder(filePath);
      return { ok: true };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.log("[reveal:inFinder] error", { path: filePath, error: msg });
      return { ok: false };
    }
  });

  // ── thumbnail:get ─────────────────────────────────────────────────────────────

  ipcMain.handle("thumbnail:get", async (_event, params: unknown) => {
    const p = params as ThumbnailGetParams;
    const filePath = assertString(p?.path, "path");
    console.log("[thumbnail:get]", { path: filePath });
    try {
      const ffmpegPath = await getFfmpegPath();
      const cachePath = await getThumbnailPath(filePath, ffmpegPath);
      if (!cachePath) {
        console.log("[thumbnail:get] failed", { path: filePath });
        return { url: null };
      }
      const url = `app-thumb://thumb?file=${encodeURIComponent(path.basename(cachePath))}`;
      console.log("[thumbnail:get] done", { path: filePath, url });
      return { url };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.log("[thumbnail:get] error", { path: filePath, error: msg });
      return { url: null };
    }
  });

  // ── settings:get ──────────────────────────────────────────────────────────────

  ipcMain.handle("settings:get", async (_event, _params: unknown) => {
    const settings = await settingsStore.get();
    console.log("[settings:get]", settings);
    return settings;
  });

  // ── settings:set ──────────────────────────────────────────────────────────────

  ipcMain.handle("settings:set", async (_event, params: unknown) => {
    const p = params as SettingsSetParams;
    if (typeof p?.patch !== "object" || p.patch === null) {
      throw new Error("settings:set requires a patch object");
    }
    console.log("[settings:set]", { patch: p.patch });
    const updated = await settingsStore.patch(p.patch);
    ipcMain.broadcast("settings:changed", { value: updated });
    console.log("[settings:set] done", updated);
    return updated;
  });

  logger.info("handlers", "IPC handlers registered");
}
