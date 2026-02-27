# Security Ownership

Updated: 2026-02-27

## Sensitive Hotspots
- `src/Libra/core/organizer.py` (`file_io`)
- `src/Libra/core/duplicate_finder.py` (`file_io`)
- `src/Libra/video_tools/**` (`media_pipeline`)

## Current Risk
- Bus factor is `1` for media pipeline and file-manipulation surfaces.
- This repo has the highest hotspot concentration in the workspace.

## Mitigations Applied
- Added explicit hotspot ownership in `.github/CODEOWNERS`.
- Added targeted regression tests for organizer/duplicate logic and video-tools CLI dispatch:
  - `tests/test_core_organizer_and_duplicates.py`
  - `tests/test_video_tools_cli.py`

## Required to Fully Close Risk
1. Add at least one additional human maintainer for each sensitive path.
2. Enforce code-owner review requirement in branch protection.
3. Add a monthly backup-maintainer rotation for `video_tools` changes.
