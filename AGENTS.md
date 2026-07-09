# L!bra AGENTS

Guidance for AI agents working in this repository.

## Branding

| Surface | Value | Why |
|---------|-------|-----|
| Display name (UI, Dock, About, menus, Application Support) | **L!bra** | Product brand |
| GitHub repo | `RazorBackRoar/Libra` | GitHub disallows `!` in repo names |
| npm `package.json` `name` | `l-bra` | npm name rules |
| electron-builder `appId` | `com.razorbackroar.libra` | reverse-DNS; no `!` |
| `productName` / `app.setName` | `L!bra` | User-facing |
| `executableName` / binary | `Libra` | Avoid `!` in Mach-O executable name |

Constants live in `electron-core/utils/brand.ts`. Prefer `DISPLAY_NAME` over hardcoding.

## Purpose And Entry Points

L!bra is a local-first macOS video organization toolkit (Electron + React/Vite).

- Main: `main/index.ts`
- Renderer: `renderer/`
- Shared Electron adapters: `electron-core/` (per-app; not a shared workspace package)

## Commands

```zsh
npm run type-check
npm run build
npm run lint
```

## Repository Rules

- Do not create a shared `Shared/razorcore-ts/` package for v1.1.
- Do not rename the GitHub repo to include `!`.
- Do not commit/push/branch unless explicitly requested.
