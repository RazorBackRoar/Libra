# L!bra AGENTS

Guidance for agents in this repository. Use with `../AGENTS.md`.

## Branding

| Surface | Value | Why |
|---------|-------|-----|
| Display (UI, Dock, About, menus, Application Support) | **L!bra** | Product brand |
| GitHub | `RazorBackRoar/Libra` | GitHub disallows `!` |
| npm `name` | `l-bra` | npm name rules |
| `appId` | `com.razorbackroar.libra` | reverse-DNS |
| `productName` / `app.setName` | `L!bra` | User-facing |
| Executable / Mach-O name | `Libra` | Avoid `!` in binary name |

Constants: `electron-core/utils/brand.ts`. Prefer `DISPLAY_NAME` over hardcoding.

## Purpose and entry points

Local-first macOS video organization toolkit (Electron + React/Vite).

- Main: `main/index.ts`
- Renderer: `renderer/`
- Per-app Electron adapters: `electron-core/` (not a shared workspace package)

### electron-core contracts (v1.1)

| Module | Role |
|--------|------|
| `utils/brand.ts` | Display vs machine-safe IDs |
| `utils/paths.ts` | userData / cache under display name **L!bra** |
| `utils/logging.ts` | Logs under Application Support |
| `utils/appInfo.ts` | Metadata + startup banner |
| `utils/updates.ts` | GitHub Releases check (`RazorBackRoar/Libra`) |

Behavioral SSOT: `../Docs/razorcore-api-spec.md`.

## Commands

```zsh
npm run type-check
npm run build
npm run lint
npm start
npm run dist
```

## Repository rules

- Do not create `Shared/razorcore-ts/` for v1.1.
- Do not rename the GitHub repo to include `!`.
- Do not commit, push, or create branches unless explicitly requested.
