/**
 * CLI utility helpers — ffmpeg/ffprobe path resolution and install checks.
 * Resolution order: Settings override → `which` → common Homebrew paths.
 */

import { execFile } from "node:child_process";
import { promisify } from "node:util";
import * as fs from "node:fs/promises";

const execFileAsync = promisify(execFile);

const HOMEBREW_PATHS = ["/opt/homebrew/bin", "/usr/local/bin"];

/** Returns true if the given command can be found by `/usr/bin/which`. */
export async function isCliInstalled(cmd: string): Promise<boolean> {
  try {
    await execFileAsync("/usr/bin/which", [cmd], {
      maxBuffer: 1024 * 1024,
      timeout: 5_000,
    });
    return true;
  } catch {
    return false;
  }
}

/** Try a path string — return it if the file exists and is executable, else null. */
async function tryPath(p: string): Promise<string | null> {
  try {
    await fs.access(p, fs.constants.X_OK);
    return p;
  } catch {
    return null;
  }
}

/**
 * Resolve the absolute path for a CLI binary.
 * @param settingsOverride - value from persisted Settings (may be null/empty)
 * @param binary - e.g. "ffmpeg" or "ffprobe"
 */
export async function resolveBinaryPath(
  settingsOverride: string | null | undefined,
  binary: string,
): Promise<string | null> {
  // 1. Settings override
  if (settingsOverride) {
    const found = await tryPath(settingsOverride);
    if (found) return found;
  }

  // 2. which
  try {
    const { stdout } = await execFileAsync("/usr/bin/which", [binary], {
      maxBuffer: 1024 * 1024,
      timeout: 5_000,
    });
    const p = stdout.trim();
    if (p) return p;
  } catch {
    // not on PATH — fall through
  }

  // 3. Common Homebrew paths
  for (const dir of HOMEBREW_PATHS) {
    const p = `${dir}/${binary}`;
    const found = await tryPath(p);
    if (found) return found;
  }

  return null;
}
