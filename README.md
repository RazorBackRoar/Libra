# L!bra

> Workspace context source: `/Users/home/Workspace/Apps/.code-analysis/` (`AGENTS.md`, `monorepo-analysis.md`, `essential-queries.md`).

[![CI](https://github.com/RazorBackRoar/Libra/actions/workflows/ci.yml/badge.svg)](https://github.com/RazorBackRoar/Libra/actions/workflows/ci.yml)
[![Ruff](https://github.com/RazorBackRoar/Libra/actions/workflows/ruff.yml/badge.svg)](https://github.com/RazorBackRoar/Libra/actions/workflows/ruff.yml)
[![Version](https://img.shields.io/badge/version-0.1.12-blue.svg)](pyproject.toml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-Native-brightgreen.svg)](https://support.apple.com/en-us/HT211814)
[![PySide6](https://img.shields.io/badge/PySide6-Qt6-orange.svg)](https://doc.qt.io/qtforpython/)

```text
██╗     ██╗██████╗ ██████╗  █████╗
██║     ██║██╔══██╗██╔══██╗██╔══██╗
██║     ██║██████╔╝██████╔╝███████║
██║     ██║██╔══██╗██╔══██╗██╔══██║
███████╗██║██████╔╝██║  ██║██║  ██║
╚══════╝╚═╝╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝
```

> **Native macOS video workflow suite**
> Drag-and-drop file/folder processing, metadata-aware sorting, and sanitizer-first rename pipelines in a gold/black L!bra UI.

---

## ✨ Features

- ⚡ **Fast Tool Navigation** - Home cards route directly to dedicated second screens
- 📂 **Dual Input Modes** - Every tool supports drag-and-drop files/folders plus dialog-based selection
- 🧼 **Automatic Sanitization** - Filename and filepath sanitization are always ON for tool runs
- 🧠 **Metadata-Aware Workflows** - Resolution/orientation/FPS classification with duplicate visibility
- 🖥️ **Apple Silicon Native** - PySide6 desktop app optimized for macOS

---

## 🚀 Quick Start

### Fast Preview (Codex App)

Paste this in the Codex app **Run** box:

```bash
./run_preview.sh
```

### Usage

1. Open a tool card from Home.
2. Drop files/folders directly into the tool panel, or click `Select Folder (Auto Run)` / `Select Files (Auto Run)`.
3. Processing starts automatically with filename and filepath sanitization enabled by default.

### Local Development

This project uses `.razorcore` for workspace build/save tooling.

```bash
git clone <<<https://github.com/RazorBackRoar/Libra.git>>>
cd Libra
uv venv --python 3.13
uv sync
uv add --editable ../.razorcore
uv run python -m Libra.main
```

---

## 🏗️ Build & Release

```bash
# Build app and create DMG
razorbuild L!bra

# Save/release flow
librapush
```

---

## 🛠️ Video Tools

```bash
# Unified launcher (choose a mode)
uv run python -m Libra.video_tools sorter
uv run python -m Libra.video_tools duplicates
uv run python -m Libra.video_tools apple
uv run python -m Libra.video_tools batch /path/to/videos
```

Direct module entrypoints:

```bash
uv run python -m Libra.video_tools.gui.video_sorter
uv run python -m Libra.video_tools.gui.duplicate_finder
uv run python -m Libra.video_tools.gui.apple_organizer
uv run python -m Libra.video_tools.cli.batch_processor /path/to/videos
```

---

## 📦 Project Structure

```text
L!bra/
├── main.py
├── run_preview.sh
├── src/Libra/
│   ├── main.py
│   ├── core/
│   ├── gui/
│   └── video_tools/
│       ├── core/
│       ├── gui/
│       └── cli/
├── docs/video_tools/
├── tests/
└── L!bra.spec
```

---

## 📜 License

MIT License - see [LICENSE](LICENSE) for details.
Copyright © 2026 RazorBackRoar
