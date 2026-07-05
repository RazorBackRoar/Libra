/**
 * Job registry — tracks running jobs (child processes / cancel flags)
 * and provides helpers to emit job:progress notifications.
 */

import type { ChildProcess } from "node:child_process";
import { ipcMain } from "@glaze/core/backend";
import type { JobProgress } from "./types.js";

interface JobEntry {
  cancelFlag: { cancelled: boolean };
  childProcesses: ChildProcess[];
}

const registry = new Map<string, JobEntry>();

/** Register a new job and return its mutable cancel flag. */
export function registerJob(jobId: string): JobEntry {
  const entry: JobEntry = { cancelFlag: { cancelled: false }, childProcesses: [] };
  registry.set(jobId, entry);
  return entry;
}

/** Attach a child process to a job so it can be killed on cancel. */
export function addChildProcess(jobId: string, child: ChildProcess): void {
  registry.get(jobId)?.childProcesses.push(child);
}

/**
 * Cancel a job — set its cancel flag and kill all tracked child processes.
 * Returns true if the job was found.
 */
export function cancelJob(jobId: string): boolean {
  const entry = registry.get(jobId);
  if (!entry) return false;
  entry.cancelFlag.cancelled = true;
  for (const child of entry.childProcesses) {
    try {
      child.kill("SIGTERM");
    } catch {
      // already exited
    }
  }
  return true;
}

/** Clean up a completed/cancelled job from the registry. */
export function cleanupJob(jobId: string): void {
  registry.delete(jobId);
}

/** Broadcast a job:progress notification to all renderer windows. */
export function emitProgress(progress: JobProgress): void {
  ipcMain.broadcast("job:progress", progress);
}
