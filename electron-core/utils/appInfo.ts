import {
  ARCHITECTURE,
  COPYRIGHT_FULL,
  DISPLAY_NAME,
  LICENSE_TEXT,
  ORGANIZATION,
} from "./brand.js";

export interface AppInfo {
  name: string;
  version: string;
  license: string;
  copyright: string;
  organization: string;
  architecture: string;
}

function resolveVersion(): string {
  try {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { app } = require("electron") as typeof Electron;
    const v = app.getVersion();
    if (v) return v;
  } catch {
    // not in electron
  }
  return "0.0.0";
}

export function getAppInfo(): AppInfo {
  return {
    name: DISPLAY_NAME,
    version: resolveVersion(),
    license: LICENSE_TEXT,
    copyright: COPYRIGHT_FULL,
    organization: ORGANIZATION,
    architecture: ARCHITECTURE,
  };
}

/** Print the standardized startup banner to stdout (mirrors Python razorcore). */
export function printStartupInfo(): void {
  const info = getAppInfo();
  console.log(`
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ${info.name}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Version:  ${info.version}
  License:  ${info.license}
  Arch:     ${info.architecture}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
`);
}
