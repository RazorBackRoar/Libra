/**
 * L!bra brand vs machine-safe identifiers.
 *
 * GitHub / npm / reverse-DNS cannot use `!`, so those stay ASCII `Libra` /
 * `libra` / `l-bra`. Everything user-facing uses the display name `L!bra`.
 */

/** User-facing product name (Dock, About, menus, Application Support folder). */
export const DISPLAY_NAME = "L!bra";

/** GitHub repository name under RazorBackRoar (no `!` allowed). */
export const GITHUB_REPO = "Libra";

export const GITHUB_ORG = "RazorBackRoar";

/** npm package.json `name` (already set; documented here for clarity). */
export const NPM_PACKAGE_NAME = "l-bra";

/** macOS / electron-builder reverse-DNS id (`!` not allowed). */
export const APP_ID = "com.razorbackroar.libra";

export const ORGANIZATION = "RazorBackRoar";
export const LICENSE_TEXT = "2026 RazorBackRoar";
export const COPYRIGHT_FULL = "© 2026 RazorBackRoar. All rights reserved.";
export const ARCHITECTURE = "ARM64 (Apple Silicon)";
