# L!bra

[![CI](https://img.shields.io/github/actions/workflow/status/RazorBackRoar/Libra/ci.yml?branch=main&style=for-the-badge&label=CI)](https://github.com/RazorBackRoar/Libra/actions/workflows/ci.yml)
[![Version](https://img.shields.io/badge/version-1.0.0-blue?style=for-the-badge)](package.json)
[![License: MIT](https://img.shields.io/badge/license-MIT-blueviolet?style=for-the-badge)](LICENSE)
[![Electron](https://img.shields.io/badge/Electron-47848F?style=for-the-badge&logo=electron&logoColor=white)](https://www.electronjs.org/)
[![macOS](https://img.shields.io/badge/mac%20os-Apple%20Silicon-d32f2f?style=for-the-badge&logo=apple&logoColor=white)](https://support.apple.com/en-us/HT211814)

> **TL;DR:** Local-first macOS video organization toolkit. User-facing brand is **L!bra**; the GitHub repo and npm package stay ASCII (`Libra` / `l-bra`).

## Branding

| Surface | Value |
|---------|-------|
| Display name | **L!bra** |
| GitHub | [RazorBackRoar/Libra](https://github.com/RazorBackRoar/Libra) |
| npm | `l-bra` |
| appId | `com.razorbackroar.libra` |
| Executable | `Libra` |

## Features

L!bra is a local-first video toolkit. All processing runs on your Mac — no cloud upload.

### Video Organizer

The primary workflow scans folders and organizes videos by resolution and metadata.
Six sort modes are available from the home page:

| Mode | Behavior |
|------|----------|
| **Pro Vid** | Prefix rename |
| **Vid Res** | Sort by resolution |
| **Pro Max** | Resolution + orientation sort |
| **Max Vid** | Full sort (resolution, orientation, metadata) |
| **Name Keeper** | Resolution sort while preserving original filenames |
| **Slow Motion** | Separate slow-motion vs normal-speed clips |

### Utility tools

| Tool | Purpose |
|------|---------|
| **GPS Hunter** | Find videos with location metadata on or off |
| **Divided by One** | Adjust clip timestamps so files are spaced one minute apart |

Tool definitions live in `renderer/main/tools/registry.ts`; backend handlers in `main/handlers/`.

## Project layout

```text
Libra/
├── main/              # Electron main process (handlers, services)
├── renderer/          # React + Vite UI
├── electron-core/     # Per-app adapters (brand, paths, logging, appInfo, updates)
└── package.json
```

## Development

```bash
npm install
npm run type-check
npm run build
npm start
```

Package a macOS build with `npm run dist`.

Per-app Electron helpers live under `electron-core/` (not a shared workspace package). Contracts: see the Apps workspace `Docs/razorcore-api-spec.md`.

## License

MIT — see [LICENSE](LICENSE).
