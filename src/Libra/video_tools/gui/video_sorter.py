#!/usr/bin/env python3
"""
video_sorter.py - Video organizer metadata GUI.
"""

import csv
import os
import sys
from pathlib import Path

from PySide6.QtCore import Qt, QThread, Signal
from PySide6.QtGui import QColor, QDragEnterEvent, QDropEvent, QPalette
from PySide6.QtWidgets import (
    QApplication,
    QCheckBox,
    QFileDialog,
    QGroupBox,
    QHBoxLayout,
    QHeaderView,
    QMainWindow,
    QMessageBox,
    QProgressBar,
    QPushButton,
    QTableWidget,
    QTableWidgetItem,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from ..core.classifier import classify_video


class VideoProcessorThread(QThread):
    """Background thread to prevent GUI freeze."""

    progress = Signal(int, int)
    log = Signal(str)
    result = Signal(dict)
    finished = Signal()

    def __init__(self, video_files):
        super().__init__()
        self.video_files = video_files
        self.is_running = True

    def run(self):
        total = len(self.video_files)
        for i, video_path in enumerate(self.video_files):
            if not self.is_running:
                break

            self.progress.emit(i + 1, total)
            self.log.emit(f"Processing: {os.path.basename(video_path)}")

            data = classify_video(video_path)
            self.result.emit(data)

        self.finished.emit()

    def stop(self):
        self.is_running = False


class VideoSorterWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.all_videos = []
        self.init_ui()

    def init_ui(self):
        self.setWindowTitle("Video Organizer")
        self.resize(1200, 800)

        # Main Layout
        main_widget = QWidget()
        self.setCentralWidget(main_widget)
        main_layout = QHBoxLayout(main_widget)

        # --- Left Sidebar (Controls) ---
        sidebar = QWidget()
        sidebar.setFixedWidth(250)
        sidebar_layout = QVBoxLayout(sidebar)
        sidebar_layout.setContentsMargins(10, 10, 10, 10)

        # Filters Section
        filter_group = QGroupBox("Organize By")
        filter_layout = QVBoxLayout()

        self.check_make = QCheckBox("Filter by Make")
        self.check_model = QCheckBox("Filter by Model")
        self.check_camera = QCheckBox("Has Camera Data")
        self.check_gps = QCheckBox("Has GPS Data")

        for chk in [self.check_make, self.check_model, self.check_camera, self.check_gps]:
            chk.stateChanged.connect(self._apply_filters)
            filter_layout.addWidget(chk)

        filter_group.setLayout(filter_layout)
        sidebar_layout.addWidget(filter_group)

        # Export Section
        export_group = QGroupBox("Export")
        export_layout = QVBoxLayout()
        self.btn_csv = QPushButton("Export CSV Report")
        self.btn_txt = QPushButton("Export TXT Report")
        self.btn_csv.clicked.connect(lambda: self._export("csv"))
        self.btn_txt.clicked.connect(lambda: self._export("txt"))

        export_layout.addWidget(self.btn_csv)
        export_layout.addWidget(self.btn_txt)
        export_group.setLayout(export_layout)
        sidebar_layout.addWidget(export_group)

        sidebar_layout.addStretch()
        main_layout.addWidget(sidebar)

        # --- Right Content (Table & Drop Zone) ---
        content_layout = QVBoxLayout()

        # Drop Zone / Controls
        top_controls = QHBoxLayout()
        self.btn_select = QPushButton("Select Folder")
        self.btn_select.setFixedHeight(40)
        self.btn_select.clicked.connect(self._select_folder)
        top_controls.addWidget(self.btn_select)

        self.progress_bar = QProgressBar()
        self.progress_bar.setVisible(False)
        top_controls.addWidget(self.progress_bar)
        content_layout.addLayout(top_controls)

        # Results Table
        self.table = QTableWidget(0, 8)
        self.table.setHorizontalHeaderLabels(
            ["Filename", "Res", "Orient", "FPS", "Make", "Model", "Cam", "GPS"]
        )
        self.table.horizontalHeader().setSectionResizeMode(0, QHeaderView.Stretch)
        self.table.setAlternatingRowColors(True)
        content_layout.addWidget(self.table)

        # Log
        self.log_text = QTextEdit()
        self.log_text.setMaximumHeight(100)
        self.log_text.setReadOnly(True)
        content_layout.addWidget(self.log_text)

        main_layout.addLayout(content_layout)
        self.setAcceptDrops(True)

    def dragEnterEvent(self, event: QDragEnterEvent):
        if event.mimeData().hasUrls():
            event.acceptProposedAction()

    def dropEvent(self, event: QDropEvent):
        for url in event.mimeData().urls():
            path = url.toLocalFile()
            if os.path.isdir(path):
                self._start_scan(path)

    def _select_folder(self):
        folder = QFileDialog.getExistingDirectory(self, "Select Folder")
        if folder:
            self._start_scan(folder)

    def _start_scan(self, folder):
        video_exts = {".mp4", ".mov", ".avi", ".mkv", ".m4v"}
        files = []
        for root, _, filenames in os.walk(folder):
            for f in filenames:
                if Path(f).suffix.lower() in video_exts:
                    files.append(os.path.join(root, f))

        if not files:
            self._log("No videos found.")
            return

        self.all_videos = []
        self.table.setRowCount(0)
        self.progress_bar.setVisible(True)

        self.worker = VideoProcessorThread(files)
        self.worker.progress.connect(
            lambda c, t: (self.progress_bar.setMaximum(t), self.progress_bar.setValue(c))
        )
        self.worker.log.connect(self._log)
        self.worker.result.connect(self._add_result)
        self.worker.finished.connect(lambda: self.progress_bar.setVisible(False))
        self.worker.start()

    def _add_result(self, data):
        self.all_videos.append(data)
        if self._passes_filter(data):
            self._add_row(data)

    def _add_row(self, data):
        row = self.table.rowCount()
        self.table.insertRow(row)
        self.table.setItem(row, 0, QTableWidgetItem(os.path.basename(data["filepath"])))
        self.table.setItem(row, 1, QTableWidgetItem(data["resolution"]))
        self.table.setItem(row, 2, QTableWidgetItem(data["orientation"]))
        self.table.setItem(row, 3, QTableWidgetItem(str(data["framerate_category"])))
        self.table.setItem(row, 4, QTableWidgetItem(data["make"] or ""))
        self.table.setItem(row, 5, QTableWidgetItem(data["model"] or ""))
        self.table.setItem(row, 6, QTableWidgetItem("Yes" if data["has_camera"] else ""))
        self.table.setItem(row, 7, QTableWidgetItem("Yes" if data["has_gps"] else ""))

    def _passes_filter(self, data):
        if self.check_make.isChecked() and not data["make"]:
            return False
        if self.check_model.isChecked() and not data["model"]:
            return False
        if self.check_camera.isChecked() and not data["has_camera"]:
            return False
        if self.check_gps.isChecked() and not data["has_gps"]:
            return False
        return True

    def _apply_filters(self):
        self.table.setRowCount(0)
        for vid in self.all_videos:
            if self._passes_filter(vid):
                self._add_row(vid)

    def _log(self, msg):
        self.log_text.append(msg)

    def _export(self, fmt):
        if not self.all_videos:
            return
        path, _ = QFileDialog.getSaveFileName(self, f"Export {fmt.upper()}", f"report.{fmt}")
        if not path:
            return

        visible = [v for v in self.all_videos if self._passes_filter(v)]

        try:
            if fmt == "csv":
                with open(path, "w", newline="", encoding="utf-8") as f:
                    writer = csv.DictWriter(f, fieldnames=visible[0].keys())
                    writer.writeheader()
                    writer.writerows(visible)
            else:
                with open(path, "w", encoding="utf-8") as f:
                    for v in visible:
                        f.write(
                            f"{os.path.basename(v['filepath'])} | {v['resolution']} | {v['make']}\n"
                        )
            QMessageBox.information(self, "Success", f"Exported {len(visible)} items.")
        except Exception as e:
            QMessageBox.critical(self, "Error", str(e))


def set_dark_theme(app):
    app.setStyle("Fusion")
    palette = QPalette()
    palette.setColor(QPalette.Window, QColor(53, 53, 53))
    palette.setColor(QPalette.WindowText, Qt.white)
    palette.setColor(QPalette.Base, QColor(25, 25, 25))
    palette.setColor(QPalette.AlternateBase, QColor(53, 53, 53))
    palette.setColor(QPalette.ToolTipBase, Qt.white)
    palette.setColor(QPalette.ToolTipText, Qt.white)
    palette.setColor(QPalette.Text, Qt.white)
    palette.setColor(QPalette.Button, QColor(53, 53, 53))
    palette.setColor(QPalette.ButtonText, Qt.white)
    palette.setColor(QPalette.BrightText, Qt.red)
    palette.setColor(QPalette.Link, QColor(42, 130, 218))
    palette.setColor(QPalette.Highlight, QColor(42, 130, 218))
    palette.setColor(QPalette.HighlightedText, Qt.black)
    app.setPalette(palette)


def main() -> int:
    app = QApplication(sys.argv)
    set_dark_theme(app)
    window = VideoSorterWindow()
    window.show()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
