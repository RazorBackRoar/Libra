# Libra Progress

## Task: Resilient import UX

- [x] Diagnose scan stall / resilience gaps (ProcessRunner, unretained Task, Cancel no-op)
- [x] Sanitize ProcessRunnerTests (portable stream / timeout / cancellation)
- [x] Harden ProcessRunner (typed errors, drain pipes, grace + force-kill)
- [x] Scanner off-main + ScanOutcome + injectable probe
- [x] MediaProbe cancellation + concise errors + nonfatal enrichment warnings
- [x] ToolState retained task + cancelActiveWork + accurate summaries
- [x] ToolPage / ResultsTable wiring for cancel, warnings, cancelled status
- [x] ScannerServiceTests (75 synthetic fixtures)
- [x] Focused `swift test` (ProcessRunner + Scanner) — 5/5 passed
- [x] Full `swift test` — 86/86 passed
- [x] `swift build` — passed
- [x] `./scripts/build-mac.sh` → `build/Release/Libra.dmg` (layout verified)
- [x] Copied to `~/Desktop/Libra.dmg` (not mounted/opened/installed)
- [ ] Manual UAT (user): install from Desktop DMG; drag original 75-video folder; verify completed total or bounded per-file failures; Cancel during scan; Cancel during Dry Run

## Verification notes

- The `"MetaBurn & Libra Test"` folder markers in `ScanSafety` are personal test-path
  shortcuts — kept, but gated to `#if DEBUG` so release builds always warn.
- Process timeout/cancel bound verified (< 5s in tests; 0.4s timeout + grace).
- Scanner continues after one injected timeout-style failure; cancellation keeps partial results.
- Dry-run report and settings writes are test-isolated via `DryRunReport.reportDirectoryOverride`
  and `SettingsStore.fileURLOverride` (tests redirect both to per-test temp dirs).
