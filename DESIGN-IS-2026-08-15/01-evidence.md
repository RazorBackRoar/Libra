# Evidence — L!bra (2026-08-15)

Consolidated from structural, visual, copy, and weight sub-passes. Source-only except Home screenshot.

## Structural

- **Home Video at-rest interactives:** 11 (2 tabs + 9 ToolCards); +1 Install if deps missing. `HomeView.swift:58–91,101`
- **ToolPage at-rest:** 11–19 by tool (Back, DropZone×3, workspace tabs×2, CountPills 4–10, Dry Run, optional Prefix/Date/Camera/Pickers). `ToolPage.swift`, `CountPills.swift`, `DropZone.swift`
- **Settings:** 8 controls. `SettingsView.swift:13–26`
- **Max nesting depth:** 9 (ToolPage → GPSMapPanel cluster file list; or CategoryBrowser list). `GPSMapView.swift:87–125`, `CategoryBrowserView.swift:22–150`
- **Repeated patterns:** 10 (Install banner, DropZone, underline tabs, Dry Run toggle, Date/Camera toggles, Move photos, Open/Reveal, MediaOpen tap, Back). See structural report.
- **Dead surface:** `requireConfirmToWrite` never read (`Models.swift:176–226`); `lastFolder` write-only (`AppState.swift:65–66`); `ToolState.filteredFiles` identity (`ToolState.swift:40`).

## Visual (INFERRED + screenshot)

- **Spacing scale:** `[0,1,2,3,4,5,6,8,10,12,14,16]` (+ bare `.padding()`).
- **Type scale:** system sizes `[10,11,12,13,14,15,17,18,20,22,36]`; SF only.
- **Colors (10 tokens):** black, white, yellow, orange, red, green, gray, clear, secondary, systemGray. No hex theme module; `Brand.swift` is identity only.
- **Contrast:** unknown (semantic colors only).
- **Screenshot (`docs/screenshots/app.png`):** dark shell, yellow accents, 3×3 tool cards, Video|Photo tabs — matches `HomeView` structure. Note: screenshot may show a “Last: …” control removed in 1.2.3; current `HomeView` has no Last button.
- **States:** empty/loading/error/success/disabled present on tool flows; **focus** only in CategoryBrowser; Settings lacks error/loading chrome.

## Copy & honesty

- Brand display `L!bra` vs machine `Libra` consistent (`Brand.swift:10–14`).
- Tool titles opaque: ProVid, VidRes, KeepName, ProMax, MaxVid, 1MinVid (`Models.swift:55–63`) with clearer descriptions underneath.
- **Inflations:** none as marketing superlatives in-app.
- **Dark-pattern-adjacent:** `Install` runs `brew install ffmpeg` without confirm (`AppState.swift:52–57`); drop auto-runs after scan (`ToolState.swift:153–169`); `requireConfirmToWrite` unused.
- **Label≠behavior:** category `Analyze` for iPhone/GPS sorters that move files; Live copy says “renamed or moved” but Slo-Mo/1Min copies; map “every video” vs photo+video media; Photo vs Photos singular/plural.

## Weight & friction (native app adapted)

| Metric | Value | Method |
| --- | --- | --- |
| Initial JS bytes | 0 (N/A — native SwiftUI) | No web UI |
| Network requests on primary view | 0 | Local-first; Updates only on menu |
| Idle animations | 0 | No `withAnimation` on idle Home |
| Badges/modals on load | 0 | `NSAlert` only for About/Updates |
| Sources size | ~2.7M `Sources/`; ~4.8k LOC Swift | `du` / `wc` |

## Accessibility (light)

- Map pins `.accessibilityHidden(true)` (`GPSMapView.swift:156`).
- `@FocusState` only in CategoryBrowser (`CategoryBrowserView.swift:14,82–84`).
- No skip-link concept (desktop window). Keyboard reachability of Home ToolCards: SwiftUI Button — assumed yes, not runtime-verified.
