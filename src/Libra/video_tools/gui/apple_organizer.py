#!/usr/bin/env python3
import sys
import os
from PySide6.QtWidgets import (
    QApplication,
    QMainWindow,
    QWidget,
    QVBoxLayout,
    QHBoxLayout,
    QCheckBox,
    QLabel,
    QFrame,
    QPushButton,
    QFileDialog,
    QProgressBar,
    QTreeWidget,
    QTreeWidgetItem,
    QMessageBox,
)
from PySide6.QtCore import Qt, QThread, Signal
from PySide6.QtGui import QColor, QPainter, QPen

from ..core import backend_utils


# --- WORKER THREAD (Prevents Freezing) ---
class ScanWorker(QThread):
    progress = Signal(int)
    finished = Signal(list)

    def __init__(self, folder):
        super().__init__()
        self.folder = folder

    def run(self):
        videos = []
        # Find all video files
        valid_exts = {".mp4", ".mov", ".avi", ".mkv", ".m4v"}
        all_files = []
        for root, _, files in os.walk(self.folder):
            for f in files:
                if os.path.splitext(f)[1].lower() in valid_exts:
                    all_files.append(os.path.join(root, f))

        total = len(all_files)
        for i, filepath in enumerate(all_files):
            # Extract metadata using our backend utility
            data = backend_utils.get_video_details(filepath)
            if data:
                videos.append(data)
            self.progress.emit(int((i + 1) / total * 100))

        self.finished.emit(videos)


# --- CUSTOM WIDGETS ---
class GridBackgroundWidget(QWidget):
    """Draws the faint grid background."""

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.fillRect(self.rect(), QColor("#121212"))
        pen = QPen(QColor("#2a2a2a"))
        pen.setWidth(1)
        painter.setPen(pen)
        grid_size = 40
        for x in range(0, self.width(), grid_size):
            painter.drawLine(x, 0, x, self.height())
        for y in range(0, self.height(), grid_size):
            painter.drawLine(0, y, self.width(), y)


# --- MAIN WINDOW ---
class AppleVideoSorter(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Video Organizer - Apple Edition")
        self.resize(1100, 750)
        self.all_video_data = []  # Stores raw data

        # Main Layout
        container = QWidget()
        self.setCentralWidget(container)
        main_layout = QHBoxLayout(container)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)

        # =========================================
        # LEFT SIDEBAR
        # =========================================
        sidebar = QFrame()
        sidebar.setFixedWidth(260)
        sidebar.setStyleSheet("background-color: #1e1e1e; border-right: 1px solid #333;")
        self.sidebar_layout = QVBoxLayout(sidebar)
        self.sidebar_layout.setContentsMargins(20, 30, 20, 30)
        self.sidebar_layout.setSpacing(15)

        # 1. APPLE FILTERS SECTION
        self.add_header("APPLE FILTERS")
        self.chk_make = self.add_checkbox("Apple Device (Make)")
        self.chk_model = self.add_checkbox("iPhone Only (Model)")
        self.chk_gps = self.add_checkbox("Has GPS Data")

        # Connect signals to trigger re-filtering immediately
        self.chk_make.stateChanged.connect(self.apply_filters)
        self.chk_model.stateChanged.connect(self.apply_filters)
        self.chk_gps.stateChanged.connect(self.apply_filters)

        self.sidebar_layout.addSpacing(20)

        # 2. EXPORT SECTION
        self.add_header("EXPORT")
        self.chk_csv = self.add_checkbox("CSV Report", checked=True, accent=True)
        self.chk_txt = self.add_checkbox("TXT Report")

        self.sidebar_layout.addStretch()

        # Scan Button area in Sidebar
        self.btn_scan = QPushButton("Select Folder & Scan")
        self.btn_scan.setFixedHeight(50)
        self.btn_scan.setStyleSheet("""
            QPushButton { background-color: #2a82da; color: white; border: none; font-weight: bold; font-size: 14px; border-radius: 4px; }
            QPushButton:hover { background-color: #3a92ea; }
        """)
        self.btn_scan.clicked.connect(self.start_scan)
        self.sidebar_layout.addWidget(self.btn_scan)

        main_layout.addWidget(sidebar)

        # =========================================
        # RIGHT CONTENT AREA
        # =========================================
        content_area = GridBackgroundWidget()
        content_layout = QVBoxLayout(content_area)

        # Progress Bar (Hidden by default)
        self.progress = QProgressBar()
        self.progress.setStyleSheet(
            "QProgressBar { height: 4px; border: none; background: #333; } QProgressBar::chunk { background: #2a82da; }"
        )
        self.progress.setTextVisible(False)
        self.progress.hide()
        content_layout.addWidget(self.progress)

        # Results Tree
        self.tree = QTreeWidget()
        self.tree.setHeaderLabels(["Filename", "Make", "Model", "GPS", "Res"])
        self.tree.setStyleSheet("""
            QTreeWidget { background-color: transparent; border: none; color: #ddd; font-size: 13px; }
            QHeaderView::section { background-color: #1e1e1e; color: #aaa; border: none; padding: 5px; font-weight: bold; }
            QTreeWidget::item { padding: 5px; }
        """)
        self.tree.setColumnWidth(0, 300)
        content_layout.addWidget(self.tree)

        main_layout.addWidget(content_area)

    # --- HELPER FUNCTIONS ---
    def add_header(self, text):
        lbl = QLabel(text)
        lbl.setStyleSheet("color: #777; font-size: 11px; font-weight: bold; letter-spacing: 1px;")
        self.sidebar_layout.addWidget(lbl)

    def add_checkbox(self, text, checked=False, accent=False):
        chk = QCheckBox(text)
        chk.setChecked(checked)
        active_col = "#2a82da" if accent else "#666"
        chk.setStyleSheet(f"""
            QCheckBox {{ color: #ccc; font-size: 14px; spacing: 10px; }}
            QCheckBox::indicator {{ width: 18px; height: 18px; border-radius: 4px; border: 2px solid #555; background: #2a2a2a; }}
            QCheckBox::indicator:checked {{ background-color: {active_col}; border-color: {active_col}; }}
        """)
        self.sidebar_layout.addWidget(chk)
        return chk

    # --- LOGIC ---
    def start_scan(self):
        folder = QFileDialog.getExistingDirectory(self, "Select Folder")
        if folder:
            self.tree.clear()
            self.all_video_data = []  # Reset data
            self.progress.show()
            self.btn_scan.setEnabled(False)

            # Start Background Thread
            self.worker = ScanWorker(folder)
            self.worker.progress.connect(self.progress.setValue)
            self.worker.finished.connect(self.on_scan_finished)
            self.worker.start()

    def on_scan_finished(self, data):
        self.all_video_data = data
        self.progress.hide()
        self.btn_scan.setEnabled(True)
        self.apply_filters()  # Show results immediately

    def apply_filters(self):
        """The Brains: Filters data based on the Apple Checkboxes."""
        self.tree.clear()

        filtered_count = 0

        for vid in self.all_video_data:
            # 1. Check "Make = Apple"
            if self.chk_make.isChecked():
                # If filter is ON, but video is NOT Apple -> Skip
                if not vid["make"] or "apple" not in vid["make"].lower():
                    continue

            # 2. Check "Model = iPhone"
            if self.chk_model.isChecked():
                # If filter is ON, but video is NOT iPhone -> Skip
                if not vid["model"] or "iphone" not in vid["model"].lower():
                    continue

            # 3. Check "Has GPS"
            if self.chk_gps.isChecked():
                # If filter is ON, but video has NO GPS -> Skip
                if not vid["has_gps"]:
                    continue

            # If we survived all checks, add to tree
            self.add_tree_item(vid)
            filtered_count += 1

        if len(self.all_video_data) > 0 and filtered_count == 0:
            QMessageBox.information(self, "No Matches", "No videos matched your selected filters.")

    def add_tree_item(self, vid):
        item = QTreeWidgetItem(self.tree)
        item.setText(0, vid["filename"])
        item.setText(1, vid["make"] if vid["make"] else "--")
        item.setText(2, vid["model"] if vid["model"] else "--")
        item.setText(3, "✅ Yes" if vid["has_gps"] else "❌ No")
        item.setText(4, vid["resolution"])


def main() -> int:
    app = QApplication(sys.argv)
    app.setStyle("Fusion")

    window = AppleVideoSorter()
    window.show()

    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
