# Scorecard — L!bra UI

1. Good design is innovative — Score: 2/3  
   Evidence: Tool-grid + Dry Run + GPS city/5-mi map is a clear refresh of file-organizer patterns (`HomeView`, `GPSMapView`, `ToolState` dry-run default), not a novel paradigm.  
   Justification: Improves a known pattern with restraint; does not invent a new interaction model.

2. Good design is useful — Score: 2/3  
   Evidence: Primary path Home → ToolCard → DropZone → Dry Run → write is direct (`LibraView`, `ToolPage`, `ToolState.startScan` auto-run); dead `requireConfirmToWrite` / unused `lastFolder` add no value.  
   Justification: Primary task works in few steps, but adjacent dead settings and cryptic tool names add friction.

3. Good design is aesthetic — Score: 2/3  
   Evidence: Coherent black/yellow system, soft cards, SF type (`HomeView`, screenshot); Settings is unstyled stock Form (`SettingsView.swift`).  
   Justification: ≤2 inconsistencies — Settings and missing design tokens vs polished Home.

4. Good design is understandable — Score: 1/3  
   Evidence: Titles ProVid/VidRes/ProMax/MaxVid/KeepName/1MinVid require descriptions (`Models.swift:55–93`); FHD vs 1080p and dual “iPhone” pills (`CountPills.swift`).  
   Justification: 2–3+ primary controls unclear without reading secondary copy; jargon present.

5. Good design is unobtrusive — Score: 2/3  
   Evidence: Black chrome, transparent titlebar, conditional dep banner (not modal), map collapsed by default (`LibraApp.swift:39–45`, `GPSMapView.swift:8–10`).  
   Justification: Chrome is quiet; yellow accent is assertive but content remains figure.

6. Good design is honest — Score: 1/3  
   Evidence: Unused `requireConfirmToWrite` (`Models.swift:188`); Install without confirm (`AppState.swift:52–57`); Live string omits copies (`ToolPage.swift:280` vs Slo-Mo/1Min); Analyze category for movers (`Models.swift:99–100`).  
   Justification: Multiple label/behavior mismatches and a confirm flag that does not protect writes.

7. Good design is long-lasting — Score: 2/3  
   Evidence: System SF + simple dark utility chrome ages better than fad typography; dark+yellow is a common 2020s utility look (one trend marker).  
   Justification: One dated marker (default dark-mode toolkit aesthetic), otherwise durable.

8. Good design is thorough down to the last detail — Score: 1/3  
   Evidence: Empty/loading/error/disabled/success on tool flows (`ResultsTable`, `ToolPage`); focus styling largely absent; Settings has no error/loading; Photo Dry Run ignores settings default (`PhotoSweepView.swift:12`).  
   Justification: 2–3 states missing or inconsistent across surfaces.

9. Good design is environmentally friendly — Score: 3/3  
   Evidence: Native app, 0 idle animation, 0 network on home, local-first, no autoplay (`CategoryBrowserView` muted).  
   Justification: Conserves attention and network; native weight replaces JS rubric favorably.

10. Good design is as little design as possible — Score: 1/3  
    Evidence: Five overlapping sort/rename tools (ProVid/VidRes/KeepName/ProMax/MaxVid); 10 duplicated UI patterns across Views.  
    Justification: 3–5 elements could consolidate without losing the primary task.

**Total: 17 / 30**
