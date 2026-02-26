#!/usr/bin/env python3
"""
video_duplicate_finder_gui.py - Video Manager App
=================================================
A powerful, modern desktop application for analyzing, organizing, and finding duplicates
in your video library. Features a 3-panel VS Code-style interface.

FEATURES:
- **Left Panel**: Filters & Controls (Resolution, Device, Content, Reports)
- **Center Panel**: File List with real-time filtering and status colors
- **Right Panel**: Inspector showing detailed metadata for the selected video
- **Backend**: Multithreaded scanning, MD5/pHash detection, and caching

REQUIREMENTS:
    pip install PySide6 videohash
    FFmpeg must be installed on the system.
"""

import sys
import os
import json
import hashlib
import subprocess
from pathlib import Path
from collections import defaultdict
from datetime import datetime

from PySide6.QtWidgets import (
    QApplication,
    QMainWindow,
    QWidget,
    QVBoxLayout,
    QHBoxLayout,
    QLabel,
    QCheckBox,
    QPushButton,
    QTableWidget,
    QTableWidgetItem,
    QFrame,
    QSplitter,
    QFileDialog,
    QMessageBox,
    QProgressBar,
    QHeaderView,
)
from PySide6.QtCore import Qt, QThread, Signal
from PySide6.QtGui import QFont, QColor, QBrush, QIcon, QDragEnterEvent, QDropEvent

# Check for videohash
try:
    from videohash import VideoHash

    VIDEOHASH_AVAILABLE = True
except ImportError:
    VIDEOHASH_AVAILABLE = False

# ============================================================================
# CONSTANTS
# ============================================================================

CACHE_VERSION = "2.0"
CACHE_FILENAME = ".video_finder_cache.json"
# Added more extensions for broader support
VIDEO_EXTENSIONS = {
    ".mp4",
    ".mov",
    ".avi",
    ".mkv",
    ".m4v",
    ".mts",
    ".m2ts",
    ".wmv",
    ".flv",
    ".webm",
    ".3gp",
    ".mpg",
}

# Colors from User Design
COLOR_RED = QColor("#4a1a1a")  # Exact Duplicate Background
COLOR_GREEN = QColor("#1a3d1a")  # Similar Content Background
COLOR_BG_DARK = "#1a1a1a"
COLOR_BG_PANEL = "#2d2d2d"
COLOR_TEXT_WHITE = "#ffffff"
COLOR_TEXT_GRAY = "#cccccc"

# ============================================================================
# BACKEND LOGIC & WORKERS (Reused from previous robust implementation)
# ============================================================================


class BackendUtils:
    """Helper functions for video analysis."""

    @staticmethod
    def get_file_hash(filepath, chunk_size=8192):
        """Calculate MD5 hash for exact matching."""
        try:
            hash_md5 = hashlib.md5()
            with open(filepath, "rb") as f:
                for chunk in iter(lambda: f.read(chunk_size), b""):
                    hash_md5.update(chunk)
            return hash_md5.hexdigest()
        except:
            return None

    @staticmethod
    def get_perceptual_hash(filepath):
        """Calculate perceptual hash using videohash."""
        if not VIDEOHASH_AVAILABLE:
            return None
        try:
            vh = VideoHash(path=filepath)
            return str(vh)
        except:
            return None

    @staticmethod
    def compare_hashes(hash1, hash2):
        """Compare two hashes (distance)."""
        if not VIDEOHASH_AVAILABLE or not hash1 or not hash2:
            return 999
        try:
            h1 = VideoHash(hash=hash1)
            h2 = VideoHash(hash=hash2)
            return h1 - h2
        except:
            return 999

    @staticmethod
    def get_video_metadata(filepath):
        """Extract detailed metadata via ffprobe."""
        try:
            cmd = [
                "ffprobe",
                "-v",
                "error",
                "-show_entries",
                "format=duration,size,bit_rate,tags",
                "-show_entries",
                "stream=codec_name,width,height,r_frame_rate,tags",
                "-of",
                "json",
                filepath,
            ]
            # 15s timeout
            result = subprocess.run(cmd, capture_output=True, text=True, check=True, timeout=15)
            data = json.loads(result.stdout)

            format_info = data.get("format", {})
            tags = format_info.get("tags", {})

            # Find video stream
            video_stream = next(
                (s for s in data.get("streams", []) if s.get("codec_type") == "video"), None
            )
            if not video_stream:
                # Fallback
                video_stream = data.get("streams", [{}])[0] if data.get("streams") else {}

            # Calculate FPS
            fps = 0.0
            fps_str = video_stream.get("r_frame_rate", "0/1")
            if fps_str and "/" in fps_str:
                num, den = map(int, fps_str.split("/"))
                if den != 0:
                    fps = num / den
            elif fps_str:
                try:
                    fps = float(fps_str)
                except:
                    pass

            # Extract Make/Model/GPS
            make = tags.get("make", tags.get("com.apple.quicktime.make", "")).strip()
            model = tags.get("model", tags.get("com.apple.quicktime.model", "")).strip()
            location = tags.get("location", tags.get("com.apple.quicktime.location.ISO6709", ""))

            has_gps = True if location else False
            # Check other common GPS keys
            if not has_gps:
                # Simple check for GPS-like keys in all tags
                for k in tags.keys():
                    if "gps" in k.lower() or "location" in k.lower():
                        has_gps = True
                        break

            return {
                "duration": float(format_info.get("duration", 0)),
                "size": int(format_info.get("size", os.path.getsize(filepath))),
                "width": int(video_stream.get("width", 0)),
                "height": int(video_stream.get("height", 0)),
                "codec": video_stream.get("codec_name", "unknown"),
                "framerate": round(fps, 2),
                "resolution": f"{video_stream.get('width', 0)}x{video_stream.get('height', 0)}",
                "make": make if make else "Unknown",
                "model": model if model else "Unknown",
                "has_gps": has_gps,
            }
        except Exception:
            return {
                "duration": 0,
                "size": 0,
                "width": 0,
                "height": 0,
                "codec": "error",
                "framerate": 0,
                "resolution": "Unknown",
                "make": "Unknown",
                "model": "Unknown",
                "has_gps": False,
            }

    @staticmethod
    def format_size(size_bytes):
        if size_bytes == 0:
            return "0 B"
        size_name = ("B", "KB", "MB", "GB", "TB")
        i = 0
        p = float(size_bytes)
        while p >= 1024 and i < len(size_name) - 1:
            p /= 1024
            i += 1
        return f"{p:.2f} {size_name[i]}"

    @staticmethod
    def format_duration(seconds):
        if not seconds:
            return "00:00"
        m, s = divmod(int(seconds), 60)
        h, m = divmod(m, 60)
        if h > 0:
            return f"{h}:{m:02d}:{s:02d}"
        return f"{m:02d}:{s:02d}"


class CacheManager:
    """Manages scan cache."""

    def __init__(self, directory):
        self.directory = directory
        self.cache_path = os.path.join(directory, CACHE_FILENAME)
        self.cache = self._load()
        self.new_entries = False

    def _load(self):
        if os.path.exists(self.cache_path):
            try:
                with open(self.cache_path, "r") as f:
                    data = json.load(f)
                    if data.get("version") == CACHE_VERSION:
                        return data.get("files", {})
            except:
                pass
        return {}

    def get(self, filepath, mtime):
        if filepath in self.cache:
            entry = self.cache[filepath]
            if entry.get("mtime") == mtime:
                return entry.get("data")
        return None

    def set(self, filepath, mtime, data):
        self.cache[filepath] = {"mtime": mtime, "data": data}
        self.new_entries = True

    def save(self):
        if self.new_entries:
            try:
                with open(self.cache_path, "w") as f:
                    json.dump(
                        {
                            "version": CACHE_VERSION,
                            "timestamp": datetime.now().isoformat(),
                            "files": self.cache,
                        },
                        f,
                        indent=2,
                    )
            except:
                pass


class ScanWorker(QThread):
    """Background worker for scanning and hashing."""

    log = Signal(str)
    progress = Signal(int, int)
    finished = Signal(dict, list, list)  # video_data, exact_groups, similar_groups

    def __init__(self, folder, recursive=True, threshold=10, quick_mode=False):
        super().__init__()
        self.folder = folder
        self.recursive = recursive
        self.threshold = threshold
        self.quick_mode = quick_mode
        self.running = True

    def run(self):
        self.log.emit(f"🚀 Scanning: {self.folder}")
        video_files = []

        # 1. Find Files
        try:
            if self.recursive:
                for root, _, files in os.walk(self.folder):
                    for f in files:
                        if os.path.splitext(f)[1].lower() in VIDEO_EXTENSIONS:
                            video_files.append(os.path.join(root, f))
            else:
                for f in os.listdir(self.folder):
                    if os.path.splitext(f)[1].lower() in VIDEO_EXTENSIONS:
                        video_files.append(os.path.join(self.folder, f))
        except Exception as e:
            self.log.emit(f"❌ Error access folder: {e}")
            return

        total = len(video_files)
        self.log.emit(f"📂 Found {total} files.")

        # 2. Hash & Metadata
        cache = CacheManager(self.folder)
        data = {}

        for i, filepath in enumerate(video_files):
            if not self.running:
                return
            self.progress.emit(i + 1, total)

            try:
                mtime = os.path.getmtime(filepath)
                cached = cache.get(filepath, mtime)

                if cached:
                    info = cached
                else:
                    self.log.emit(f"Analyzing: {os.path.basename(filepath)}")
                    info = BackendUtils.get_video_metadata(filepath)
                    info["md5"] = BackendUtils.get_file_hash(filepath)

                    if not self.quick_mode and VIDEOHASH_AVAILABLE:
                        info["phash"] = BackendUtils.get_perceptual_hash(filepath)

                    cache.set(filepath, mtime, info)

                # Add filepath to info for easy access
                info["filepath"] = filepath
                info["filename"] = os.path.basename(filepath)
                data[filepath] = info

            except Exception as e:
                self.log.emit(f"⚠️ Error {os.path.basename(filepath)}: {e}")

        cache.save()

        # 3. Detect Duplicates
        self.log.emit("🔍 Comparing files...")

        # Exact (MD5)
        md5_map = defaultdict(list)
        for f, d in data.items():
            if d.get("md5"):
                md5_map[d["md5"]].append(f)
        exact_groups = [g for g in md5_map.values() if len(g) > 1]

        # Similar (pHash) - Only check files that aren't exact duplicates
        similar_groups = []
        if not self.quick_mode and VIDEOHASH_AVAILABLE:
            # Flatten exact groups to skip them in similarity check to avoid redundancy
            # actually, similar check is useful even for exacts sometimes, but usually we skip
            # let's just Compare all that have phash
            files_phash = [(f, d) for f, d in data.items() if d.get("phash")]
            processed = set()

            for idx1, (f1, d1) in enumerate(files_phash):
                if not self.running:
                    return
                for f2, d2 in files_phash[idx1 + 1 :]:
                    pair = tuple(sorted((f1, f2)))
                    if pair in processed:
                        continue

                    # If exact md5 match, skip visualization (it's already caught)
                    if d1.get("md5") == d2.get("md5"):
                        continue

                    dist = BackendUtils.compare_hashes(d1["phash"], d2["phash"])
                    if dist <= self.threshold:
                        # Add to group
                        added = False
                        for g in similar_groups:
                            if f1 in g["files"] or f2 in g["files"]:
                                if f1 not in g["files"]:
                                    g["files"].append(f1)
                                if f2 not in g["files"]:
                                    g["files"].append(f2)
                                added = True
                                break
                        if not added:
                            similar_groups.append({"files": [f1, f2], "distance": dist})
                    processed.add(pair)

        self.log.emit("✅ Finished.")
        self.finished.emit(data, exact_groups, similar_groups)

    def stop(self):
        self.running = False


# ============================================================================
# MAIN GUI (Video Manager App)
# ============================================================================


class VideoManagerApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Video Manager")
        self.setGeometry(100, 100, 1300, 800)

        # Data Storage
        self.all_video_data = {}  # {filepath: data_dict}
        self.exact_groups = []  # List of lists of filepaths
        self.similar_groups = []  # List of dicts {'files': [], 'distance': int}
        self.current_folder = ""
        self.scan_worker = None

        # Apply dark theme stylesheet
        self.setStyleSheet(f"""
            QMainWindow {{
                background-color: {COLOR_BG_DARK};
            }}
            QLabel {{
                color: {COLOR_TEXT_WHITE};
            }}
            QCheckBox {{
                color: {COLOR_TEXT_GRAY};
                font-size: 13px;
            }}
            QCheckBox::indicator {{
                width: 16px;
                height: 16px;
                background-color: #3d3d3d;
                border: 1px solid #555;
            }}
            QCheckBox::indicator:checked {{
                background-color: #4CAF50;
                border: 1px solid #4CAF50;
            }}
            QPushButton {{
                font-size: 13px;
                font-weight: 600;
                padding: 12px;
                border-radius: 4px;
                border: none;
                color: white;
            }}
            QPushButton:disabled {{
                background-color: #444;
                color: #888;
            }}
            QProgressBar {{
                border: 1px solid #444;
                border-radius: 4px;
                text-align: center;
                color: white;
            }}
            QProgressBar::chunk {{
                background-color: #4CAF50;
            }}
        """)

        # Create main layout
        main_widget = QWidget()
        main_layout = QHBoxLayout()
        main_layout.setSpacing(0)
        main_layout.setContentsMargins(0, 0, 0, 0)

        # Create three panels
        left_panel = self.create_left_panel()
        center_panel = self.create_center_panel()
        right_panel = self.create_right_panel()

        # Add panels to layout
        main_layout.addWidget(left_panel)
        main_layout.addWidget(center_panel, 1)  # Center panel stretch
        main_layout.addWidget(right_panel)

        main_widget.setLayout(main_layout)
        self.setCentralWidget(main_widget)

        # Initialize Drag & Drop
        self.setAcceptDrops(True)

    # --- DRAG & DROP SUPPORT ---
    def dragEnterEvent(self, event: QDragEnterEvent):
        if event.mimeData().hasUrls():
            event.acceptProposedAction()

    def dropEvent(self, event: QDropEvent):
        urls = event.mimeData().urls()
        if urls:
            path = urls[0].toLocalFile()
            if os.path.isdir(path):
                self.start_scan(path)
            else:
                QMessageBox.warning(self, "Invalid Drop", "Please drop a folder, not a file.")

    # --- LEFT PANEL: CONTROLS ---
    def create_left_panel(self):
        panel = QFrame()
        panel.setFixedWidth(240)
        panel.setStyleSheet(f"""
            QFrame {{
                background-color: {COLOR_BG_PANEL};
                padding: 20px;
            }}
        """)

        layout = QVBoxLayout()
        layout.setAlignment(Qt.AlignTop)
        layout.setSpacing(15)

        # >> Resolution
        lbl = QLabel("RESOLUTION")
        lbl.setStyleSheet("font-size: 13px; font-weight: 600; margin-bottom: 5px;")
        layout.addWidget(lbl)

        self.chk_4k = QCheckBox("4K Resolution")
        self.chk_1080p = QCheckBox("1080p Resolution")
        self.chk_720p = QCheckBox("720p Resolution")

        for chk in [self.chk_4k, self.chk_1080p, self.chk_720p]:
            layout.addWidget(chk)
            chk.stateChanged.connect(self.apply_filters)

        layout.addSpacing(10)

        # >> Device
        lbl = QLabel("DEVICE")
        lbl.setStyleSheet("font-size: 13px; font-weight: 600; margin-bottom: 5px;")
        layout.addWidget(lbl)

        self.chk_apple = QCheckBox("Make: Apple")
        self.chk_iphone = QCheckBox("Model: iPhone")

        for chk in [self.chk_apple, self.chk_iphone]:
            layout.addWidget(chk)
            chk.stateChanged.connect(self.apply_filters)

        layout.addSpacing(10)

        # >> Content
        lbl = QLabel("CONTENT")
        lbl.setStyleSheet("font-size: 13px; font-weight: 600; margin-bottom: 5px;")
        layout.addWidget(lbl)

        self.chk_gps = QCheckBox("Has GPS Data")
        self.chk_duplicates = QCheckBox("Duplicates (Red)")
        self.chk_similar = QCheckBox("Similar (Green)")

        # Default checked for content
        # self.chk_duplicates.setChecked(True)

        for chk in [self.chk_gps, self.chk_duplicates, self.chk_similar]:
            layout.addWidget(chk)
            chk.stateChanged.connect(self.apply_filters)

        layout.addSpacing(15)

        # >> Report / Actions
        lbl = QLabel("REPORT / ACTIONS")
        lbl.setStyleSheet("font-size: 13px; font-weight: 600; margin-bottom: 5px;")
        layout.addWidget(lbl)

        # Dry Run / Scan Button
        self.btn_dry_run = QPushButton("SCAN FOLDER")
        self.btn_dry_run.setStyleSheet("""
            QPushButton {
                background-color: #FFC107;
                color: #000000;
            }
            QPushButton:hover { background-color: #FFB300; }
        """)
        self.btn_dry_run.clicked.connect(self.select_folder_dialog)
        layout.addWidget(self.btn_dry_run)

        # Exports
        self.btn_csv = QPushButton("Export CSV")
        self.btn_csv.setStyleSheet("background-color: #333; color: #ccc;")
        self.btn_csv.clicked.connect(self.export_csv)
        layout.addWidget(self.btn_csv)

        self.btn_json = QPushButton("Export JSON")
        self.btn_json.setStyleSheet("background-color: #333; color: #ccc;")
        self.btn_json.clicked.connect(self.export_json)
        layout.addWidget(self.btn_json)

        layout.addSpacing(15)

        # Status Label
        self.status_label = QLabel("Ready")
        self.status_label.setStyleSheet("font-size: 12px; color: #888; font-style: italic;")
        self.status_label.setWordWrap(True)
        layout.addWidget(self.status_label)

        # Progress Bar
        self.progress_bar = QProgressBar()
        self.progress_bar.setVisible(False)
        self.progress_bar.setFixedHeight(8)
        layout.addWidget(self.progress_bar)

        panel.setLayout(layout)
        return panel

    # --- CENTER PANEL: TABLE ---
    def create_center_panel(self):
        panel = QFrame()
        panel.setStyleSheet(f"background-color: {COLOR_BG_DARK};")

        layout = QVBoxLayout()
        layout.setContentsMargins(0, 0, 0, 0)

        self.table = QTableWidget()
        self.table.setColumnCount(4)
        self.table.setHorizontalHeaderLabels(["Filename", "Resolution", "Framerate", "Status"])
        self.table.setShowGrid(False)
        self.table.setSelectionBehavior(QTableWidget.SelectRows)
        self.table.setSelectionMode(QTableWidget.SingleSelection)
        self.table.setEditTriggers(QTableWidget.NoEditTriggers)
        self.table.verticalHeader().setVisible(False)

        # Table Styling
        self.table.setStyleSheet(f"""
            QTableWidget {{
                background-color: {COLOR_BG_DARK};
                border: none;
                color: {COLOR_TEXT_GRAY};
            }}
            QHeaderView::section {{
                background-color: {COLOR_BG_PANEL};
                color: white;
                padding: 8px;
                border: none;
                font-weight: bold;
            }}
            QTableWidget::item {{
                padding: 8px;
                border-bottom: 1px solid #2a2a2a;
            }}
            QTableWidget::item:selected {{
                background-color: #3d3d3d;
            }}
        """)

        # Column Resizing
        header = self.table.horizontalHeader()
        header.setSectionResizeMode(0, QHeaderView.Stretch)  # Filename takes space
        header.setSectionResizeMode(1, QHeaderView.Fixed)
        header.setSectionResizeMode(2, QHeaderView.Fixed)
        header.setSectionResizeMode(3, QHeaderView.Fixed)

        self.table.setColumnWidth(1, 120)
        self.table.setColumnWidth(2, 100)
        self.table.setColumnWidth(3, 120)

        # Click Connection
        self.table.itemClicked.connect(self.update_inspector)

        layout.addWidget(self.table)
        panel.setLayout(layout)
        return panel

    # --- RIGHT PANEL: INSPECTOR ---
    def create_right_panel(self):
        panel = QFrame()
        panel.setFixedWidth(320)
        panel.setStyleSheet(f"""
            QFrame {{
                background-color: {COLOR_BG_PANEL};
                padding: 20px;
            }}
        """)

        layout = QVBoxLayout()
        layout.setAlignment(Qt.AlignTop)

        # Header
        lbl = QLabel("INSPECTOR")
        lbl.setStyleSheet("font-size: 14px; font-weight: bold; letter-spacing: 1px;")
        layout.addWidget(lbl)
        layout.addSpacing(20)

        # Metadata Fields placeholder
        self.inspector_labels = {}
        fields = [
            "Filename",
            "Path",
            "Resolution",
            "Framerate",
            "Duration",
            "Size",
            "Codec",
            "Make",
            "Model",
            "GPS",
            "Status",
        ]

        for field in fields:
            row = QHBoxLayout()
            l_key = QLabel(f"{field}:")
            l_key.setStyleSheet("color: #888; font-weight: 500; min-width: 80px;")
            l_key.setAlignment(Qt.AlignRight | Qt.AlignVCenter)

            l_val = QLabel("-")
            l_val.setStyleSheet("color: white;")
            l_val.setWordWrap(True)
            self.inspector_labels[field] = l_val

            row.addWidget(l_key)
            row.addSpacing(10)
            row.addWidget(l_val, 1)
            layout.addLayout(row)

            # Divider
            div = QFrame()
            div.setFrameShape(QFrame.HLine)
            div.setStyleSheet("background-color: #3d3d3d; max-height: 1px;")
            layout.addWidget(div)
            layout.addSpacing(5)

        layout.addStretch()

        # Actions
        self.btn_preview = QPushButton("Open File")
        self.btn_preview.setStyleSheet("background-color: #2196F3;")
        self.btn_preview.clicked.connect(self.open_file)

        self.btn_delete = QPushButton("Delete File")
        self.btn_delete.setStyleSheet("background-color: #F44336;")
        self.btn_delete.clicked.connect(self.delete_file)

        layout.addWidget(self.btn_preview)
        layout.addWidget(self.btn_delete)

        panel.setLayout(layout)
        return panel

    # --- LOGIC & SLOTS ---

    def select_folder_dialog(self):
        folder = QFileDialog.getExistingDirectory(self, "Select Video Folder")
        if folder:
            self.start_scan(folder)

    def start_scan(self, folder_path):
        self.current_folder = folder_path
        self.status_label.setText(f"Scanning: {os.path.basename(folder_path)}...")
        self.progress_bar.setVisible(True)
        self.progress_bar.setValue(0)
        self.table.setRowCount(0)
        self.all_video_data = {}

        # Disable inputs
        self.btn_dry_run.setEnabled(False)

        # Start Worker
        self.scan_worker = ScanWorker(folder_path)
        self.scan_worker.progress.connect(
            lambda c, t: (self.progress_bar.setMaximum(t), self.progress_bar.setValue(c))
        )
        self.scan_worker.log.connect(lambda s: print(s))  # Optional console log
        self.scan_worker.finished.connect(self.on_scan_finished)
        self.scan_worker.start()

    def on_scan_finished(self, data, exact_groups, similar_groups):
        self.all_video_data = data
        self.exact_groups = exact_groups
        self.similar_groups = similar_groups

        self.progress_bar.setVisible(False)
        self.btn_dry_run.setEnabled(True)
        self.status_label.setText(f"Scan complete. Found {len(data)} videos.")

        # Mark duplicates for easy lookup
        # Flatten structure: path -> "Exact", "Similar"
        self.dup_status = {}
        for group in exact_groups:
            # Skip the first one if we want to keep one "original", but typically all match
            # Let's mark all as exact duplicate group members
            for p in group:
                self.dup_status[p] = "Exact Duplicate"

        for group in similar_groups:
            for p in group["files"]:
                if p not in self.dup_status:  # exact overrides similar
                    self.dup_status[p] = "Similar Content"

        self.populate_table()

    def populate_table(self):
        """Fill table with rows based on self.all_video_data"""
        self.table.setRowCount(0)

        for filepath, info in self.all_video_data.items():
            row = self.table.rowCount()
            self.table.insertRow(row)

            # 0: Filename
            item_name = QTableWidgetItem(info.get("filename", ""))
            item_name.setData(Qt.UserRole, filepath)  # Store full path
            self.table.setItem(row, 0, item_name)

            # 1: Resolution
            self.table.setItem(row, 1, QTableWidgetItem(info.get("resolution", "")))

            # 2: Framerate
            fps = f"{info.get('framerate', 0)} fps"
            self.table.setItem(row, 2, QTableWidgetItem(fps))

            # 3: Status (Duplicate/Similar)
            status = self.dup_status.get(filepath, "Unique")
            item_status = QTableWidgetItem(status)

            # Color coding
            if status == "Exact Duplicate":
                for col in range(4):
                    item = self.table.item(row, col) or item_status
                    item.setBackground(COLOR_RED)
                    # self.table.setItem(row, col, item) # Need to set for created items
                item_status.setBackground(COLOR_RED)

            elif status == "Similar Content":
                for col in range(4):
                    item = self.table.item(row, col) or item_status
                    item.setBackground(COLOR_GREEN)
                item_status.setBackground(COLOR_GREEN)

            self.table.setItem(row, 3, item_status)

        # Apply current filters immediately
        self.apply_filters()

    def apply_filters(self):
        """Show/Hide rows based on left panel checkboxes (AND logic)."""
        root_count = self.table.rowCount()

        # Gather active filters
        res_4k = self.chk_4k.isChecked()
        res_1080 = self.chk_1080p.isChecked()
        res_720 = self.chk_720p.isChecked()

        dev_apple = self.chk_apple.isChecked()
        dev_iphone = self.chk_iphone.isChecked()

        con_gps = self.chk_gps.isChecked()
        con_dup = self.chk_duplicates.isChecked()  # Red
        con_sim = self.chk_similar.isChecked()  # Green

        for row in range(root_count):
            item = self.table.item(row, 0)
            filepath = item.data(Qt.UserRole)
            info = self.all_video_data.get(filepath, {})
            status = self.dup_status.get(filepath, "Unique")

            visible = True

            # Resolution Filter
            width = info.get("width", 0)
            height = info.get("height", 0)
            # Simple resolution checks (width or height match)
            is_4k = width >= 3840 or height >= 3840
            is_1080 = width == 1920 or height == 1920
            is_720 = width == 1280 or height == 1280

            # Logic: If ANY resolution box checked, must match ONE of them
            if res_4k or res_1080 or res_720:
                match_res = False
                if res_4k and is_4k:
                    match_res = True
                if res_1080 and is_1080:
                    match_res = True
                if res_720 and is_720:
                    match_res = True
                if not match_res:
                    visible = False

            # Device Filters (AND logic)
            if visible and dev_apple:
                if "apple" not in str(info.get("make", "")).lower():
                    visible = False

            if visible and dev_iphone:
                if "iphone" not in str(info.get("model", "")).lower():
                    visible = False

            # Content Filters
            if visible and con_gps:
                if not info.get("has_gps"):
                    visible = False

            # Duplicate specific filters
            # If "Duplicates" is unchecked, hide exact duplicates?
            # Or is it "Show ONLY duplicates"?
            # Usually filters are "Show only if", but for status let's assume filtering DOWN
            # If user unchecks "Duplicates", hide red rows?
            # Let's interpret user checkbox: "Show Duplicates" means show them. If unchecked, hide them?
            # Left panel says "CONTENT", suggesting presence.
            # Let's treat them as "Show rows that are..."

            # Wait, user request said "AND logic filtering".
            # If "Duplicates" is checked, does it mean "Must be duplicate"? yes.
            if visible and con_dup:
                if status != "Exact Duplicate":
                    visible = False

            if visible and con_sim:
                if status != "Similar Content":
                    visible = False

            # Note: Checking both Dup and Sim will result in NO rows, as a file can't be both (in this logic)
            # Unless user means OR logic for status categories?
            # Sticking to strict AND per previous instruction.

            self.table.setRowHidden(row, not visible)

    def update_inspector(self, item):
        """Update right panel with metadata."""
        row = item.row()
        filepath = self.table.item(row, 0).data(Qt.UserRole)
        info = self.all_video_data.get(filepath, {})
        status = self.dup_status.get(filepath, "Unique")

        self.inspector_labels["Filename"].setText(os.path.basename(filepath))
        # Path: truncate if too long
        short_path = "..." + filepath[-30:] if len(filepath) > 30 else filepath
        self.inspector_labels["Path"].setText(short_path)
        self.inspector_labels["Path"].setToolTip(filepath)

        self.inspector_labels["Resolution"].setText(str(info.get("resolution")))
        self.inspector_labels["Framerate"].setText(f"{info.get('framerate')} fps")
        self.inspector_labels["Duration"].setText(
            BackendUtils.format_duration(info.get("duration", 0))
        )
        self.inspector_labels["Size"].setText(BackendUtils.format_size(info.get("size", 0)))
        self.inspector_labels["Codec"].setText(str(info.get("codec")))
        self.inspector_labels["Make"].setText(str(info.get("make")))
        self.inspector_labels["Model"].setText(str(info.get("model")))
        self.inspector_labels["GPS"].setText("Yes" if info.get("has_gps") else "No")
        self.inspector_labels["Status"].setText(status)

        # Color status label
        if status == "Exact Duplicate":
            self.inspector_labels["Status"].setStyleSheet("color: #ff5555; font-weight: bold;")
        elif status == "Similar Content":
            self.inspector_labels["Status"].setStyleSheet("color: #5599ff; font-weight: bold;")
        else:
            self.inspector_labels["Status"].setStyleSheet("color: white;")

    def open_file(self):
        row = self.table.currentRow()
        if row >= 0:
            filepath = self.table.item(row, 0).data(Qt.UserRole)
            # Open in default OS viewer
            if sys.platform == "win32":
                os.startfile(filepath)
            elif sys.platform == "darwin":
                subprocess.call(("open", filepath))
            else:
                subprocess.call(("xdg-open", filepath))

    def delete_file(self):
        row = self.table.currentRow()
        if row >= 0:
            filepath = self.table.item(row, 0).data(Qt.UserRole)
            confirm = QMessageBox.question(
                self,
                "Delete File",
                f"Are you sure you want to permanently delete:\n{os.path.basename(filepath)}?",
                QMessageBox.Yes | QMessageBox.No,
            )
            if confirm == QMessageBox.Yes:
                try:
                    os.remove(filepath)
                    self.table.removeRow(row)
                    self.status_label.setText(f"Deleted: {os.path.basename(filepath)}")
                except Exception as e:
                    QMessageBox.warning(self, "Error", f"Could not delete file: {e}")

    # --- EXPORT ---
    def export_csv(self):
        if not self.all_video_data:
            return
        path, _ = QFileDialog.getSaveFileName(
            self,
            "Export CSV",
            os.path.expanduser("~/Desktop/video_report.csv"),
            "CSV Files (*.csv)",
        )
        if path:
            try:
                import csv

                with open(path, "w", newline="", encoding="utf-8") as f:
                    writer = csv.writer(f)
                    writer.writerow(
                        [
                            "Filename",
                            "Resolution",
                            "FPS",
                            "Duration",
                            "Size",
                            "Make",
                            "Model",
                            "GPS",
                            "Duplicate Status",
                            "Path",
                        ]
                    )
                    # Export visible rows only? or all? Let's export all found.
                    for fp, info in self.all_video_data.items():
                        writer.writerow(
                            [
                                info.get("filename"),
                                info.get("resolution"),
                                info.get("framerate"),
                                BackendUtils.format_duration(info.get("duration")),
                                BackendUtils.format_size(info.get("size")),
                                info.get("make"),
                                info.get("model"),
                                info.get("has_gps"),
                                self.dup_status.get(fp, "header"),
                                fp,
                            ]
                        )
                QMessageBox.information(self, "Export", "CSV Exported successfully!")
            except Exception as e:
                QMessageBox.warning(self, "Error", str(e))

    def export_json(self):
        """Export JSON in the specific format requested."""
        if not self.exact_groups and not self.similar_groups:
            return
        path, _ = QFileDialog.getSaveFileName(
            self,
            "Export JSON",
            os.path.expanduser("~/Desktop/duplicates.json"),
            "JSON Files (*.json)",
        )
        if path:
            try:
                output = {"duplicate_groups": [], "summary": {}}

                group_id_counter = 1
                total_wasted = 0
                total_dupes = 0

                # Process Exact Groups
                for group in self.exact_groups:
                    if len(group) < 2:
                        continue
                    rep = group[0]
                    dupes = group[1:]
                    info = self.all_video_data[rep]

                    entry = {
                        "group_id": group_id_counter,
                        "type": "exact",
                        "representative": rep,
                        "duplicates": dupes,
                        "file_size": info.get("size"),
                        "duration": BackendUtils.format_duration(info.get("duration")),
                        "hash": info.get("md5"),
                    }
                    output["duplicate_groups"].append(entry)

                    wasted = info.get("size", 0) * len(dupes)
                    total_wasted += wasted
                    total_dupes += len(dupes)
                    group_id_counter += 1

                # Summary
                output["summary"] = {
                    "total_groups": len(output["duplicate_groups"]),
                    "total_duplicates": total_dupes,
                    "space_wasted_bytes": total_wasted,
                    "space_wasted_formatted": BackendUtils.format_size(total_wasted),
                }

                with open(path, "w", encoding="utf-8") as f:
                    json.dump(output, f, indent=2)

                QMessageBox.information(self, "Export", "JSON Report exported successfully!")
            except Exception as e:
                QMessageBox.warning(self, "Error", str(e))


def main():
    app = QApplication(sys.argv)

    # Set application-wide font
    font = QFont("Segoe UI", 10)
    app.setFont(font)

    window = VideoManagerApp()
    window.show()

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
