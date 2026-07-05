/**
 * Thumbnail generation + disk cache.
 *
 * Generates a small JPEG per video file via ffmpeg and caches it under
 * `app.getPath("userData")/thumbnails/<sha1(path+mtimeMs+size)>.jpg`, keyed
 * so cache entries self-invalidate when the source file changes on disk.
 * Served to the renderer through a registered custom protocol (see
 * main/index.ts) — never returned as base64 over IPC.
 */

import { execFile } from "node:child_process";
import { promisify } from "node:util";
import * as fs from "node:fs/promises";
import * as path from "node:path";
import { createHash } from "node:crypto";
import { app } from "@glaze/core/backend";

const execFileAsync = promisify(execFile);

export function thumbnailsCacheDir(): string {
  return path.join(app.getPath("userData"), "thumbnails");
}

function cacheKey(filePath: string, mtimeMs: number, size: number): string {
  return createHash("sha1").update(`${filePath}${mtimeMs}${size}`).digest("hex");
}

async function pathExists(p: string): Promise<boolean> {
  try {
    await fs.access(p);
    return true;
  } catch {
    return false;
  }
}

/**
 * Return an absolute path to a cached thumbnail JPEG for `filePath`,
 * generating it via ffmpeg if not already cached. Returns null on any
 * failure (missing file, corrupt video, ffmpeg error) — never throws.
 */
export async function getThumbnailPath(
  filePath: string,
  ffmpegPath: string,
): Promise<string | null> {
  let stat;
  try {
    stat = await fs.stat(filePath);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.log("[thumbnails:get] stat failed", { filePath, error: msg });
    return null;
  }

  const dir = thumbnailsCacheDir();
  const key = cacheKey(filePath, stat.mtimeMs, stat.size);
  const cachePath = path.join(dir, `${key}.jpg`);

  if (await pathExists(cachePath)) {
    console.log("[thumbnails:get] cache hit", { filePath, cachePath });
    return cachePath;
  }

  try {
    await fs.mkdir(dir, { recursive: true });
    await execFileAsync(
      ffmpegPath,
      [
        "-y",
        "-ss", "1",
        "-i", filePath,
        "-frames:v", "1",
        "-vf", "scale=160:-1",
        cachePath,
      ],
      { maxBuffer: 10 * 1024 * 1024, timeout: 30_000 },
    );
    console.log("[thumbnails:get] generated", { filePath, cachePath });
    return cachePath;
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.log("[thumbnails:get] generation failed", { filePath, error: msg });
    return null;
  }
}
