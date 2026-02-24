# Video Sorter & Duplicate Finder Suite

A suite of professional desktop applications to help you organize your video library. Built with **Python** and **PySide6** featuring a modern dark theme.

## 🚀 Quick Start

### 1. Install System Dependencies
Ensure **FFmpeg** is installed on your system:
- **macOS:** `brew install ffmpeg`
- **Linux:** `sudo apt-get install ffmpeg`
- **Windows:** `choco install ffmpeg`

### 2. Install Python Packages

```bash
python3 -m pip install -r docs/video_tools/requirements.txt
```

### 3. Run an Application

```bash
# General Video Organizer (metadata filtering)
PYTHONPATH=src python3 -m Libra.video_tools.gui.video_sorter

# Duplicate & Similarity Finder
PYTHONPATH=src python3 -m Libra.video_tools.gui.duplicate_finder

# Apple-Specific Organizer
PYTHONPATH=src python3 -m Libra.video_tools.gui.apple_organizer

# Batch Processing (headless)
PYTHONPATH=src python3 -m Libra.video_tools.cli.batch_processor /path/to/videos

# Unified launcher
PYTHONPATH=src python3 -m Libra.video_tools sorter
```

---

## 📂 Project Structure

| File | Description |
| --- | --- |
| `src/Libra/video_tools/core/classifier.py` | Core metadata extraction engine using FFprobe |
| `src/Libra/video_tools/gui/video_sorter.py` | General video organizer with Make/Model/GPS filters |
| `src/Libra/video_tools/gui/duplicate_finder.py` | Find exact duplicates (MD5) and similar videos (perceptual hash) |
| `src/Libra/video_tools/gui/apple_organizer.py` | Specialized organizer for Apple device videos |
| `src/Libra/video_tools/core/backend_utils.py` | Shared utilities for Apple organizer |
| `src/Libra/video_tools/cli/batch_processor.py` | Headless batch processing script for automation |
| `docs/video_tools/requirements.txt` | Python dependencies |

---

## ✨ Features

### Video Duplicate Finder
- **Exact Duplicates**: Uses MD5 hashing - only byte-for-byte identical files match
- **Similar Content**: Uses perceptual hashing (`videohash`) to find visually similar videos
- **Adjustable Threshold**: Control how strict the similarity matching is
- **Quick Mode**: Skip similarity detection for faster scans

### Video Sorter
- **AND Logic Filtering**: Check multiple filters = video must match ALL conditions
- **Export**: Save filtered results to CSV or TXT

### Apple Organizer
- **Apple Device Filter**: Show only videos from Apple devices
- **iPhone Only Filter**: Show only iPhone videos
- **GPS Filter**: Show only videos with location data
- **Strict AND Logic**: Check Apple + GPS = only Apple videos WITH GPS appear

---

## 📋 Requirements

- Python 3.8+
- FFmpeg (system dependency)
- PySide6 (GUI framework)
- videohash (optional, for similarity detection)

---

## 🔧 Troubleshooting

### FFmpeg not found

```bash
# macOS
brew install ffmpeg

# Verify installation
ffprobe -version
```

### videohash not working

```bash
pip install videohash

# Note: videohash requires FFmpeg to be installed
```

### Videos not showing metadata
- Some video formats don't store Make/Model/GPS data
- Only videos from phones (iPhone, Samsung, etc.) typically have this metadata

---

*Created from the Video Duplicate Finder Guide.*
