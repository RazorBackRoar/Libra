Level 2 Document: Refer to `/Users/home/Workspace/Apps/AGENTS.md` (Level 1) for global SSOT standards.

# L!bra Agent Guide

## Workspace Pointers (Load Order)

1. `/Users/home/Workspace/Apps/AGENTS.md`
2. `/Users/home/Workspace/Apps/README.md`
3. `/Users/home/Workspace/Apps/MCP.md`
4. `/Users/home/Workspace/Apps/.code-analysis/AGENTS.md`
5. `/Users/home/Workspace/Apps/.code-analysis/monorepo-analysis.md`
6. `/Users/home/Workspace/Apps/.code-analysis/essential-queries.md`
7. `/Users/home/Workspace/Apps/L!bra/AGENT.md`

## Project Context

- App: `L!bra` (native macOS desktop app)
- Stack: Python + PySide6
- Primary package: `/Users/home/Workspace/Apps/L!bra/src/Libra/`
- Legacy video utilities are now professionalized under:
  - `/Users/home/Workspace/Apps/L!bra/src/Libra/video_tools/core/`
  - `/Users/home/Workspace/Apps/L!bra/src/Libra/video_tools/gui/`
  - `/Users/home/Workspace/Apps/L!bra/src/Libra/video_tools/cli/`

## Mandatory Tooling

- Python: use `python3` in the local venv (`.venv`)
- Installer: `pip` only (no `uv`)
- Tests: `pytest`
- Type/Lint/Format: `ty`, `ruff check`, `ruff format` (workspace standards)

## Canonical Commands

### Setup

```bash
cd /Users/home/Workspace/Apps/L!bra
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install --no-user -U pip pytest PySide6
```

### Run

```bash
./run_preview.sh
PYTHONPATH=src python3 -m Libra.main
python3 main.py
```

### Video Tools

```bash
PYTHONPATH=src python3 -m Libra.video_tools sorter
PYTHONPATH=src python3 -m Libra.video_tools duplicates
PYTHONPATH=src python3 -m Libra.video_tools apple
PYTHONPATH=src python3 -m Libra.video_tools batch /path/to/videos
```

### Test

```bash
source .venv/bin/activate
pytest -q
```

### Build

```bash
librabuild
razorbuild L!bra
```

## Engineering Rules

- Do not reintroduce an `isort` folder. Keep video modules under `video_tools/{core,gui,cli}`.
- Keep imports package-correct (`from Libra...` or package-relative within `video_tools`).
- Keep changes scoped and atomic; avoid unrelated refactors.
- Preserve macOS-first behavior and UI responsiveness.
- External binary dependencies used by tooling include `ffprobe`, `ffmpeg`, `exiftool`, and `mediainfo`.
