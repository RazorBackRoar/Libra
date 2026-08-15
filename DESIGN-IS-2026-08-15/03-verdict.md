# Verdict

**REDESIGN** — Total 17/30 (&lt; 20). Load-bearing gaps: understandable (#4 = 1) and honest (#6 = 1). The product bones (local-first, Dry Run, drop → preview → write) are worth keeping; the tool IA and naming need rebuilding, not a coat of paint.

## Highest-leverage moves

1. **#4 Understandable:** Replace opaque tool titles (ProVid, VidRes, ProMax, MaxVid, KeepName, 1MinVid) with plain task names; keep short descriptions as secondary. Evidence: `Models.swift:55–93`, `HomeView.swift:112–116`.
2. **#10 As little design as possible:** Collapse the five sort/rename variants into one Sort/Rename tool with options (resolution / orientation / FPS / keep name / prefix). Evidence: `Models.swift:55–59`, `HomeView.swift:58–64`.
3. **#6 Honest:** Honor or remove `requireConfirmToWrite`; confirm before Homebrew Install; fix Live copy for copy-creating tools; retag Analyze movers. Evidence: `Models.swift:188`, `AppState.swift:52–57`, `ToolPage.swift:280`, `Models.swift:99–100`.
4. **#8 Thorough:** Shared design tokens (color/type/spacing); focus rings on Home/ToolPage; Settings error states; PhotoSweep Dry Run reads settings. Evidence: no theme module; `PhotoSweepView.swift:12`; `SettingsView.swift`.
5. **#3 Aesthetic:** Style Settings to match Home/ToolPage so the product feels one system. Evidence: `SettingsView.swift` vs `HomeView.swift`.
