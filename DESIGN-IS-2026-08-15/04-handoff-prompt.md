# /make-plan handoff

````
/make-plan Redesign L!bra primary tool IA and home/tool chrome. Current design failed audit at 17/30 with critical gaps in principles #4 understandable, #6 honest (also weak #8 thorough, #10 as little design as possible).

Verdict paragraph (quoted from 03-verdict.md):
> REDESIGN — Total 17/30 (< 20). Load-bearing gaps: understandable (#4 = 1) and honest (#6 = 1). The product bones (local-first, Dry Run, drop → preview → write) are worth keeping; the tool IA and naming need rebuilding, not a coat of paint.

Why redesign and not refine: Total is below the REFINE threshold and two load-bearing principles (#4, #6) scored 1 with multiple mismatches — renaming paint alone will not fix overlapping tools or honesty gaps.

Preserve from current design (MUST keep):
- Brand display `L!bra` / machine `Libra` split (`Sources/Libra/Utilities/Brand.swift:10–14`)
- Black shell + yellow accent language (`HomeView.swift:18–20,53`; `DropZone.swift:73–74`)
- Dry Run default-on + Live/Preview status pattern (`ToolState.swift:33–34`; `ToolPage.swift:268–280`)
- DropZone Open Folder / Select Files / onDrop (`DropZone.swift:26–41`)
- GPS City / 5-mi map clustering concept (`GPSMapView.swift`, `GPSMapModel.swift`)
- Undo last run (`ToolPage.swift:286–289`)

Discard (structural patterns causing failures):
- Opaque compound tool titles (ProVid, VidRes, ProMax, MaxVid, KeepName, 1MinVid). Evidence: `Models.swift:55–63`. Caused failure on principle #4.
- Five overlapping Sort/Rename tools as separate home cards. Evidence: `Models.swift:55–59`, `HomeView.swift:58–64`. Caused failure on principle #10.
- Unused `requireConfirmToWrite` and Install-without-confirm. Evidence: `Models.swift:188`, `AppState.swift:52–57`. Caused failure on principle #6.
- Category label `Analyze` on movers (iPhone Sorter, GPS Sorter). Evidence: `Models.swift:99–100`. Caused failure on principle #6.
- Stock unstyled Settings Form as a second visual system. Evidence: `SettingsView.swift`. Caused failure on principles #3 and #8.

Top 3–5 moves from the audit (verbatim):
1. #4 Understandable: Replace opaque tool titles (ProVid, VidRes, ProMax, MaxVid, KeepName, 1MinVid) with plain task names; keep short descriptions as secondary. Evidence: `Models.swift:55–93`, `HomeView.swift:112–116`.
2. #10 As little design as possible: Collapse the five sort/rename variants into one Sort/Rename tool with options (resolution / orientation / FPS / keep name / prefix). Evidence: `Models.swift:55–59`, `HomeView.swift:58–64`.
3. #6 Honest: Honor or remove `requireConfirmToWrite`; confirm before Homebrew Install; fix Live copy for copy-creating tools; retag Analyze movers. Evidence: `Models.swift:188`, `AppState.swift:52–57`, `ToolPage.swift:280`, `Models.swift:99–100`.
4. #8 Thorough: Shared design tokens (color/type/spacing); focus rings on Home/ToolPage; Settings error states; PhotoSweep Dry Run reads settings. Evidence: no theme module; `PhotoSweepView.swift:12`; `SettingsView.swift`.
5. #3 Aesthetic: Style Settings to match Home/ToolPage so the product feels one system. Evidence: `SettingsView.swift` vs `HomeView.swift`.

Redesign principles in priority order:
1. #4 Understandable — a first-time user can name every home control without reading the blurb
2. #6 Honest — every label and safety toggle matches behavior (confirm, Live/Preview, categories)
3. #10 As little design as possible — one Sort/Rename surface with options instead of five near-duplicate cards

Deliverables for the plan:
- New information architecture (not derived from old nine-card grid)
- New primary flow (low-fi, labeled, compared side-by-side to current)
- States checklist (empty, loading, error, success, focus, disabled)
- Migration path for users currently on the old design (map old tool → new mode)
- Cutover criteria (when is the old design retired)

Anti-patterns to guard against (specific to REDESIGN):
- Porting old structure under new styling
- Keeping both designs behind a flag indefinitely
- Redesigning to follow a trend rather than the principles above
- Treating the Preserve list as optional — it must be filled before this handoff is valid
````
