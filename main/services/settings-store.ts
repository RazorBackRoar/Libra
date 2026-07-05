/**
 * Persistent settings store — JSON file under app.getPath("userData").
 */

import { app } from "@glaze/core/backend";
import * as fs from "node:fs/promises";
import * as path from "node:path";
import { type Settings, DEFAULT_SETTINGS } from "./types.js";

class SettingsStore {
  private cache: Settings | null = null;
  private filePath: string | null = null;

  private async getFilePath(): Promise<string> {
    if (!this.filePath) {
      const userDataPath = app.getPath("userData");
      await fs.mkdir(userDataPath, { recursive: true });
      this.filePath = path.join(userDataPath, "settings.json");
    }
    return this.filePath;
  }

  private defaultOutputFolder(): string {
    return path.join(app.getPath("desktop"), "L!bra Organized");
  }

  async load(): Promise<Settings> {
    if (this.cache !== null) return this.cache;
    try {
      const filePath = await this.getFilePath();
      const data = await fs.readFile(filePath, "utf-8");
      this.cache = { ...DEFAULT_SETTINGS, ...(JSON.parse(data) as Partial<Settings>) };
    } catch {
      this.cache = { ...DEFAULT_SETTINGS };
    }
    // Resolve a concrete default output folder when unset.
    if (!this.cache.outputFolder) {
      this.cache.outputFolder = this.defaultOutputFolder();
    }
    return this.cache;
  }

  async patch(updates: Partial<Settings>): Promise<Settings> {
    const current = await this.load();
    this.cache = { ...current, ...updates };
    const filePath = await this.getFilePath();
    await fs.writeFile(filePath, JSON.stringify(this.cache, null, 2), "utf-8");
    return this.cache;
  }

  async get(): Promise<Settings> {
    return this.load();
  }
}

export const settingsStore = new SettingsStore();
