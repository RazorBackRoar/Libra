"""
ProVid — Orange Dark UI
==========================
A gorgeous dark layout heavily inspired by the user's mockup.
Features a vertical Home screen with a gradient header, a middle navigation bar,
and a 2x2 grid of tool cards with vibrant orange accents.
"""

import csv
import os
import re
from pathlib import Path

from PySide6.QtCore import Qt, QThread, Signal
from PySide6.QtGui import QBrush, QColor, QDragEnterEvent, QDropEvent
from PySide6.QtWidgets import (
    QCheckBox,
    QComboBox,
    QFileDialog,
    QFrame,
    QGridLayout,
    QHBoxLayout,
    QHeaderView,
    QLabel,
    QLineEdit,
    QMainWindow,
    QMessageBox,
    QProgressBar,
    QPushButton,
    QScrollArea,
    QSpinBox,
    QStackedWidget,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

from Libra.core.duplicate_finder import DuplicateFinder
from Libra.core.organizer import VideoClassifier
from Libra.core.video_metadata import MetadataExtractor

# ─────────────────────────────────────────────────────────────────────────────
#  ORANGE DARK DESIGN TOKENS
# ─────────────────────────────────────────────────────────────────────────────
VIDEO_EXTENSIONS = {
    ".mp4",
    ".mov",
    ".avi",
    ".mkv",
    ".m4v",
    ".mts",
    ".m2ts",
    ".wmv",
    ".webm",
    ".3gp",
}

BG_APP = "#000000"  # Pure Black (main background)
BG_CARD = "#121212"  # Very dark gray (cards, panels)
BG_HOVER = "#222222"  # Hover state for interactive items
ACCENT = "#D4AF37"  # Metallic Gold (primary actions, highlights)
ACCENT_HOVER = "#F5D061"  # Lighter gold for hover states
TXT_PRI = "#FFFFFF"  # Pure white (main text)
TXT_SEC = "#888888"  # Light gray (secondary text, borders)
L_CARD = "#D4AF37"  # Gold color for the left banner card
R_TXT_SEC = "rgba(0,0,0,0.8)"  # Dark text for the gold left panel
BORDER = "#333333"  # Subtle borders
STATUS_OK = "#34C759"
STATUS_DUP = "#FF3B30"
ROW_DUP = QColor(40, 20, 20)

FONT = ".AppleSystemUIFont, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"
FONT_MONO = "SF Mono, ui-monospace, Menlo, Monaco, Consolas, 'Courier New', monospace"

CARDS = [
    {
        "id": "organizer",
        "icon": "⚖️",
        "title": "Main Organizer",
        "desc": "Filter, organize, review duplicates, and inspect rich video metadata.",
        "t": "tool",
    },
    {
        "id": "provid",
        "icon": "🎬",
        "title": "ProVid Renamer",
        "desc": "Rename files using resolution, orientation, FPS, and emojis.",
        "t": "tool",
    },
    {
        "id": "vidres",
        "icon": "📁",
        "title": "VidRes Sorter",
        "desc": "Sort videos into 4K, 1080p, 720p, and SD folders.",
        "t": "tool",
    },
    {
        "id": "promax",
        "icon": "📱",
        "title": "ProMax Sorter",
        "desc": "Sort videos by resolution and orientation combined.",
        "t": "tool",
    },
    {
        "id": "maxvid",
        "icon": "🎞️",
        "title": "MaxVid Sorter",
        "desc": "Deep sort by resolution, orientation, and precise FPS.",
        "t": "tool",
    },
    {
        "id": "keepname",
        "icon": "🗂️",
        "title": "KeepName Sorter",
        "desc": "Sort videos by resolution while preserving original filenames.",
        "t": "tool",
    },
    {
        "id": "emoji",
        "icon": "🤠",
        "title": "Emoji Renamer",
        "desc": "Rename videos using only relevant emojis for metadata.",
        "t": "tool",
    },
    {
        "id": "ogedits",
        "icon": "🕵️‍♂️",
        "title": "OG/Edits Analyzer",
        "desc": "Forensic EXIF analysis to detect originals vs re-exported files.",
        "t": "tool",
    },
    {
        "id": "1minvid",
        "icon": "⏱️",
        "title": "1MinVid Adjust",
        "desc": "Shift creation date logic by accurate 1-minute increments for sequential timelines.",
        "t": "tool",
    },
    {
        "id": "metamov",
        "icon": "📅",
        "title": "MetaMov Rewrite",
        "desc": "Intelligently fix corrupted metadata dates using precise chronological analysis.",
        "t": "tool",
    },
    {
        "id": "mutevid",
        "icon": "🔇",
        "title": "MuteVid Silent",
        "desc": "Completely strip all audio metadata tracks to produce clean, silent, lightweight copies.",
        "t": "tool",
    },
    {
        "id": "slomo",
        "icon": "🐢",
        "title": "Slo-Mo Creator",
        "desc": "Duplicate videos in custom fractional frame-rates for beautiful slow-motion sequences.",
        "t": "tool",
    },
]


# ─────────────────────────────────────────────────────────────────────────────
#  SCAN WORKER
# ─────────────────────────────────────────────────────────────────────────────
class ScanWorker(QThread):
    progress = Signal(int, int)
    result = Signal(dict)
    done = Signal()

    def __init__(self, files: list[Path]):
        super().__init__()
        self.files = files
        self.running = True
        self._dup = DuplicateFinder()

    def run(self):
        total = len(self.files)
        for i, fp in enumerate(self.files):
            if not self.running:
                return
            self.progress.emit(i + 1, total)
            is_dup = self._dup.is_duplicate(fp)
            try:
                meta = MetadataExtractor.extract(fp)
                res, orient, fps_cat = VideoClassifier.classify(meta)
            except Exception:
                res, orient, fps_cat = "SD", "W", 30
                meta = None
            self.result.emit(
                {
                    "filepath": str(fp),
                    "filename": fp.name,
                    "resolution": res,
                    "orientation": orient,
                    "fps": fps_cat,
                    "width": meta.width if meta else 0,
                    "height": meta.height if meta else 0,
                    "iphone": meta.iphone_model if meta else None,
                    "has_gps": meta.has_gps if meta else False,
                    "has_camera": meta.has_camera_lens if meta else False,
                    "is_duplicate": is_dup,
                }
            )
        self.done.emit()

    def stop(self):
        self.running = False


# ─────────────────────────────────────────────────────────────────────────────
#  UI EXTENSIONS (Clickable Cards)
# ─────────────────────────────────────────────────────────────────────────────
class ClickableFrame(QFrame):
    clicked = Signal()

    def mouseReleaseEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.clicked.emit()
        super().mouseReleaseEvent(event)


# ─────────────────────────────────────────────────────────────────────────────
#  MAIN WINDOW
# ─────────────────────────────────────────────────────────────────────────────
class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("L!bra")
        self.setGeometry(80, 40, 1320, 940)
        self.setMinimumSize(1040, 760)

        self.all_video_data: dict[str, dict] = {}
        self.scan_worker: ScanWorker | None = None
        self.current_mode: str = ""
        self.tool_page_indexes: dict[str, int] = {}
        self.tool_drop_zones: dict[str, QFrame] = {}
        self.tool_status_labels: dict[str, QLabel] = {}

        self.setStyleSheet(f"""
            * {{ font-family: {FONT}; outline: none; }}
            QMainWindow {{ background: {BG_APP}; }}
            QScrollBar:vertical {{ background: transparent; width: 8px; border: none; }}
            QScrollBar::handle:vertical {{ background: rgba(255,255,255,0.1); border-radius: 4px; min-height: 40px; margin: 2px; }}
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {{ height: 0; }}
            QScrollBar:vertical:hover::handle {{ background: rgba(255,255,255,0.2); }}
        """)

        self.stack = QStackedWidget()
        self.setCentralWidget(self.stack)

        self._build_home_view()
        self._build_organizer_view()
        self._build_tool_views()

        self._go_home()

    # ──────────────────────────────────────────────────────────────────────
    #  HOME VIEW
    # ──────────────────────────────────────────────────────────────────────
    def _build_home_view(self):
        page = QWidget()
        lay = QVBoxLayout(page)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(0)

        # 1. Hero Banner (Mountains vibe via gradient)
        hero = QFrame()
        hero.setFixedHeight(220)
        hero.setObjectName("HeroBanner")
        hero.setStyleSheet(f"""
            #HeroBanner {{
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 #3B2F0B, stop:1 {BG_APP});
                border-bottom: 1px solid {BORDER};
            }}
        """)
        h_lay = QVBoxLayout(hero)
        h_lay.setAlignment(Qt.AlignmentFlag.AlignCenter)
        h_lay.setSpacing(8)

        # We can simulate mountain peaks with some rich text or an SVG if available,
        # but large elegant typography works universally.
        title = QLabel("L!bra")
        title.setStyleSheet(
            f"font-size: 50px; font-weight: 800; color: {TXT_PRI}; letter-spacing: -2px; background: transparent;"
        )
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        h_lay.addWidget(title)

        sub = QLabel("Professional Video Organization & Modification")
        sub.setStyleSheet(
            f"font-size: 15px; font-weight: 600; color: {ACCENT}; letter-spacing: 1px; background: transparent;"
        )
        sub.setAlignment(Qt.AlignmentFlag.AlignCenter)
        h_lay.addWidget(sub)
        lay.addWidget(hero)

        # 2. Grid of Cards (Scrollable)
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setStyleSheet("background: transparent;")

        bot_section = QWidget()
        bot_section.setStyleSheet("background: transparent;")
        bot_lay = QVBoxLayout(bot_section)
        bot_lay.setContentsMargins(48, 24, 48, 24)
        bot_lay.setAlignment(Qt.AlignmentFlag.AlignTop)

        grid = QGridLayout()
        grid.setSpacing(20)

        for i, card in enumerate(CARDS):
            r = i // 3
            c = i % 3

            c_frame = ClickableFrame()
            c_frame.setCursor(Qt.CursorShape.PointingHandCursor)
            c_frame.setStyleSheet(f"""
                QFrame {{
                    background: {BG_CARD};
                    border-radius: 16px;
                    border: 1px solid {BORDER};
                }}
                QFrame:hover {{
                    background: {BG_HOVER};
                    border: 1px solid {ACCENT};
                }}
            """)
            c_frame.clicked.connect(lambda cd=card: self._on_tool_click(cd))

            cf_lay = QVBoxLayout(c_frame)
            cf_lay.setContentsMargins(20, 20, 20, 20)
            cf_lay.setSpacing(10)

            top_hl = QHBoxLayout()
            icon_lbl_l = QLabel(card["icon"])
            icon_lbl_l.setStyleSheet("font-size: 28px; background: transparent; border: none;")
            top_hl.addWidget(icon_lbl_l)

            top_hl.addStretch()

            title_lbl = QLabel(card["title"])
            title_lbl.setStyleSheet(
                f"font-size: 16px; font-weight: 800; color: {ACCENT}; background: transparent; border: none;"
            )
            top_hl.addWidget(title_lbl)

            top_hl.addStretch()

            icon_lbl_r = QLabel(card["icon"])
            icon_lbl_r.setStyleSheet("font-size: 28px; background: transparent; border: none;")
            top_hl.addWidget(icon_lbl_r)

            cf_lay.addLayout(top_hl)

            desc_lbl = QLabel(card["desc"])
            desc_lbl.setWordWrap(True)
            desc_lbl.setStyleSheet(
                f"font-size: 13px; color: {TXT_SEC}; background: transparent; border: none;"
            )
            cf_lay.addWidget(desc_lbl)

            launch_lbl = QLabel("Launch Tool →")
            launch_lbl.setStyleSheet(
                f"font-size: 11px; font-weight: 700; color: {ACCENT}; background: transparent; border: none; margin-top: 4px;"
            )
            cf_lay.addWidget(launch_lbl)

            grid.addWidget(c_frame, r, c)

        bot_lay.addLayout(grid)
        bot_lay.addStretch()
        scroll.setWidget(bot_section)
        lay.addWidget(scroll, 1)

        self.stack.addWidget(page)  # Index 0

    def _go_home(self):
        self.stack.setCurrentIndex(0)
        self.setAcceptDrops(False)
        self.current_mode = ""

    def _go_organize(self):
        self.current_mode = "organize"
        self.all_video_data = {}
        self.org_table.setRowCount(0)
        self.org_count.setText("0 files")
        self.stack.setCurrentIndex(1)
        self.setAcceptDrops(True)

    def _on_tool_click(self, card: dict):
        if card["id"] == "organizer":
            self._go_organize()
            return
        self.current_mode = card["id"]
        idx = self.tool_page_indexes.get(card["id"])
        if idx is None:
            QMessageBox.warning(self, "Unavailable Tool", f"Tool route missing: {card['id']}")
            self._go_home()
            return
        self.stack.setCurrentIndex(idx)
        self.setAcceptDrops(True)

    # ──────────────────────────────────────────────────────────────────────
    #  ORGANIZER VIEW (Index 1)
    # ──────────────────────────────────────────────────────────────────────
    def _build_organizer_view(self):
        page = QWidget()
        lay = QVBoxLayout(page)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(0)

        # Header
        head = QWidget()
        head.setFixedHeight(64)
        head.setStyleSheet(f"background: {BG_CARD}; border-bottom: 1px solid {BORDER};")
        h_lay = QHBoxLayout(head)
        h_lay.setContentsMargins(24, 0, 24, 0)

        btn_back = QPushButton("← Back to Home")
        btn_back.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_back.setStyleSheet(
            f"color: {TXT_SEC}; font-size: 14px; font-weight: 600; background: transparent; border: none;"
        )
        btn_back.clicked.connect(self._go_home)
        h_lay.addWidget(btn_back)
        h_lay.addStretch()

        title = QLabel("MAIN ORGANIZER")
        title.setStyleSheet(
            f"color: {ACCENT}; font-size: 14px; font-weight: 800; letter-spacing: 2px;"
        )
        h_lay.addWidget(title)
        lay.addWidget(head)

        # Body: Left Filters, Right Table
        body = QWidget()
        b_lay = QHBoxLayout(body)
        b_lay.setContentsMargins(0, 0, 0, 0)
        b_lay.setSpacing(0)

        # Filters (Left)
        sidebar = QWidget()
        sidebar.setFixedWidth(320)
        sidebar.setStyleSheet(f"background: {BG_APP}; border-right: 1px solid {BORDER};")
        s_lay = QVBoxLayout(sidebar)
        s_lay.setContentsMargins(24, 24, 24, 24)
        s_lay.setSpacing(24)

        # Actions
        btn_scan = QPushButton("Scan Folder")
        btn_scan.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_scan.setStyleSheet(
            f"background: {BG_CARD}; color: {TXT_PRI}; font-size: 14px; font-weight: 700; border-radius: 8px; padding: 12px; border: 1px solid {BORDER};"
        )
        btn_scan.clicked.connect(self._select_folder)
        self.org_scan_btn = btn_scan
        s_lay.addWidget(btn_scan)

        btn_run = QPushButton("Execute Rename/Move")
        btn_run.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_run.setStyleSheet(
            f"background: {ACCENT}; color: {BG_APP}; font-size: 14px; font-weight: 800; border-radius: 8px; padding: 12px; border: none;"
        )
        s_lay.addWidget(btn_run)

        self.org_progress = QProgressBar()
        self.org_progress.setVisible(False)
        self.org_progress.setStyleSheet(
            f"QProgressBar {{ border: none; background: {BG_CARD}; height: 4px; border-radius: 2px; }} QProgressBar::chunk {{ background: {ACCENT}; border-radius: 2px; }}"
        )
        s_lay.addWidget(self.org_progress)

        # Config
        lbl_conf = QLabel("CONFIGURATION")
        lbl_conf.setStyleSheet(
            f"color: {TXT_SEC}; font-size: 11px; font-weight: 800; letter-spacing: 1px;"
        )
        s_lay.addWidget(lbl_conf)

        self.org_prefix = QLineEdit()
        self.org_prefix.setPlaceholderText("Prefix (e.g. Vacay_)")
        self.org_prefix.setStyleSheet(
            f"background: {BG_CARD}; color: {TXT_PRI}; border: 1px solid {BORDER}; border-radius: 6px; padding: 10px; font-size: 13px;"
        )
        s_lay.addWidget(self.org_prefix)

        self.org_dry = self._r_checkbox("Dry Run (Safe Mode)", True)
        s_lay.addWidget(self.org_dry)

        # Filters Grid
        lbl_flt = QLabel("FILTERS")
        lbl_flt.setStyleSheet(
            f"color: {TXT_SEC}; font-size: 11px; font-weight: 800; letter-spacing: 1px; padding-top: 12px;"
        )
        s_lay.addWidget(lbl_flt)

        f_grid = QGridLayout()
        f_grid.setSpacing(12)
        self.chk_4k = self._r_checkbox("4K")
        self.chk_1080p = self._r_checkbox("1080p")
        self.chk_720p = self._r_checkbox("720p")
        self.chk_hd = self._r_checkbox("HD")
        self.chk_sd = self._r_checkbox("SD")
        self.chk_iphone = self._r_checkbox("iPhone")
        self.chk_gps = self._r_checkbox("GPS")
        self.chk_dup = self._r_checkbox("Duplicates")

        f_grid.addWidget(self.chk_4k, 0, 0)
        f_grid.addWidget(self.chk_1080p, 0, 1)
        f_grid.addWidget(self.chk_720p, 1, 0)
        f_grid.addWidget(self.chk_hd, 1, 1)
        f_grid.addWidget(self.chk_sd, 2, 0)
        f_grid.addWidget(self.chk_iphone, 2, 1)
        f_grid.addWidget(self.chk_gps, 3, 0)
        f_grid.addWidget(self.chk_dup, 3, 1)

        for c in (
            self.chk_4k,
            self.chk_1080p,
            self.chk_720p,
            self.chk_hd,
            self.chk_sd,
            self.chk_iphone,
            self.chk_gps,
            self.chk_dup,
        ):
            c.stateChanged.connect(self._apply_filters)
        s_lay.addLayout(f_grid)
        s_lay.addStretch()
        b_lay.addWidget(sidebar)

        # Table Area (Right)
        t_area = QWidget()
        t_lay = QVBoxLayout(t_area)
        t_lay.setContentsMargins(24, 24, 24, 24)
        t_lay.setSpacing(16)

        th_lay = QHBoxLayout()
        t_title = QLabel("Workspace")
        t_title.setStyleSheet(f"font-size: 20px; font-weight: 800; color: {TXT_PRI};")
        th_lay.addWidget(t_title)

        self.org_count = QLabel("0 files")
        self.org_count.setStyleSheet(
            f"font-size: 12px; font-weight: 700; color: {BG_APP}; background: {ACCENT}; padding: 4px 10px; border-radius: 10px;"
        )
        th_lay.addWidget(self.org_count)

        self.org_status = QLabel("Ready")
        self.org_status.setStyleSheet(f"font-size: 13px; color: {TXT_SEC}; margin-left: 12px;")
        th_lay.addWidget(self.org_status)
        th_lay.addStretch()

        btn_exp = QPushButton("Export CSV")
        btn_exp.setStyleSheet(
            f"background: transparent; color: {ACCENT}; text-decoration: underline; border: none;"
        )
        btn_exp.clicked.connect(self._export_csv)
        th_lay.addWidget(btn_exp)

        btn_del = QPushButton("Delete Selected")
        btn_del.setStyleSheet("background: transparent; color: #EF4444; border: none;")
        btn_del.clicked.connect(self._delete_selected)
        th_lay.addWidget(btn_del)

        t_lay.addLayout(th_lay)

        self.org_drop_zone = QFrame()
        self.org_drop_zone.setFixedHeight(70)
        self.org_drop_zone.setStyleSheet(
            f"background: {BG_CARD}; border: 2px dashed {BORDER}; border-radius: 12px;"
        )
        dz_lay = QVBoxLayout(self.org_drop_zone)
        dz_lay.setAlignment(Qt.AlignmentFlag.AlignCenter)
        dz_lbl = QLabel("Drag & Drop Video Folders Here")
        dz_lbl.setStyleSheet(f"font-size: 14px; font-weight: 600; color: {TXT_SEC}; border: none;")
        dz_lay.addWidget(dz_lbl)
        t_lay.addWidget(self.org_drop_zone)

        self.org_table = self._build_table()
        self.org_table.itemClicked.connect(self._update_inspector)
        t_lay.addWidget(self.org_table, 1)

        b_lay.addWidget(t_area, 1)
        lay.addWidget(body, 1)
        self.stack.addWidget(page)  # Index 1

    # ──────────────────────────────────────────────────────────────────────
    #  TOOL VIEWS (Indices 2-5)
    # ──────────────────────────────────────────────────────────────────────
    def _r_generic(self, lay):
        lbl = QLabel("Use drag-and-drop or the file/folder dialogs to process your inputs.")
        lbl.setWordWrap(True)
        lbl.setStyleSheet(f"color: {TXT_SEC}; font-size: 13px; text-align: center; border: none;")
        lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        lay.addWidget(lbl)

    def _build_tool_views(self):
        tools = [
            (
                "provid",
                "ProVid Renamer",
                "Rename files using resolution, orientation, FPS, and emojis.",
                self._r_generic,
            ),
            (
                "vidres",
                "VidRes Sorter",
                "Sort videos into 4K, 1080p, 720p, and SD folders.",
                self._r_generic,
            ),
            (
                "promax",
                "ProMax Sorter",
                "Sort videos by resolution and orientation combined.",
                self._r_generic,
            ),
            (
                "maxvid",
                "MaxVid Sorter",
                "Deep sort by resolution, orientation, and precise FPS.",
                self._r_generic,
            ),
            (
                "keepname",
                "KeepName Sorter",
                "Sort videos by resolution while preserving original filenames.",
                self._r_generic,
            ),
            (
                "emoji",
                "Emoji Renamer",
                "Rename videos using only relevant emojis for metadata.",
                self._r_generic,
            ),
            (
                "ogedits",
                "OG/Edits Analyzer",
                "Forensic EXIF analysis to detect originals vs re-exported files.",
                self._r_generic,
            ),
            (
                "1minvid",
                "1MinVid Adjust",
                "Shift sequential dates exactly 1 minute apart.",
                self._r_1minvid,
            ),
            (
                "metamov",
                "MetaMov Rewrite",
                "Intelligent chronological extraction and rewrite.",
                self._r_metamov,
            ),
            (
                "mutevid",
                "MuteVid Silent",
                "Remove audio streams and clean metadata.",
                self._r_mutevid,
            ),
            (
                "slomo",
                "Slo-Mo Creator",
                "Multiply frames to create smooth slow motion.",
                self._r_slomo,
            ),
        ]

        for tid, title, desc, builder in tools:
            page = QWidget()
            lay = QVBoxLayout(page)
            lay.setContentsMargins(0, 0, 0, 0)
            lay.setSpacing(0)

            # Header
            head = QWidget()
            head.setFixedHeight(64)
            head.setStyleSheet(f"background: {BG_CARD}; border-bottom: 1px solid {BORDER};")
            h_lay = QHBoxLayout(head)
            h_lay.setContentsMargins(24, 0, 24, 0)

            btn_back = QPushButton("← Back to Home")
            btn_back.setCursor(Qt.CursorShape.PointingHandCursor)
            btn_back.setStyleSheet(
                f"color: {TXT_SEC}; font-size: 14px; font-weight: 600; background: transparent; border: none;"
            )
            btn_back.clicked.connect(self._go_home)
            h_lay.addWidget(btn_back)
            h_lay.addStretch()

            t_lbl = QLabel(title.upper())
            t_lbl.setStyleSheet(
                f"color: {ACCENT}; font-size: 14px; font-weight: 800; letter-spacing: 2px;"
            )
            h_lay.addWidget(t_lbl)
            lay.addWidget(head)

            # Body (Center aligned panel)
            body = QWidget()
            b_lay = QVBoxLayout(body)
            b_lay.setAlignment(Qt.AlignmentFlag.AlignCenter)

            panel = QFrame()
            panel.setFixedSize(620, 560)
            panel.setStyleSheet(
                f"background: {BG_CARD}; border-radius: 16px; border: 1px solid {BORDER};"
            )
            p_lay = QVBoxLayout(panel)
            p_lay.setContentsMargins(40, 40, 40, 40)
            p_lay.setSpacing(18)

            title_lbl = QLabel(title)
            title_lbl.setStyleSheet(
                f"font-size: 24px; font-weight: 800; color: {TXT_PRI}; border: none;"
            )
            title_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
            p_lay.addWidget(title_lbl)

            desc_lbl = QLabel(desc)
            desc_lbl.setStyleSheet(f"font-size: 14px; color: {TXT_SEC}; border: none;")
            desc_lbl.setWordWrap(True)
            desc_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
            p_lay.addWidget(desc_lbl)

            p_lay.addSpacing(6)
            builder(p_lay)

            dz = QFrame()
            dz.setFixedHeight(110)
            dz.setStyleSheet(
                f"background: {BG_CARD}; border: 2px dashed {BORDER}; border-radius: 12px;"
            )
            dz_lay = QVBoxLayout(dz)
            dz_lay.setContentsMargins(14, 12, 14, 12)
            dz_lbl = QLabel("Drag Files Or Folders Here")
            dz_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
            dz_lbl.setStyleSheet(
                f"color: {TXT_PRI}; font-size: 14px; font-weight: 800; border: none;"
            )
            dz_lay.addWidget(dz_lbl)

            dz_sub = QLabel("Drop your input and run processing.")
            dz_sub.setAlignment(Qt.AlignmentFlag.AlignCenter)
            dz_sub.setWordWrap(True)
            dz_sub.setStyleSheet(f"color: {TXT_SEC}; font-size: 11px; border: none;")
            dz_lay.addWidget(dz_sub)
            p_lay.addWidget(dz)

            st = QLabel("Ready: drop files/folders or pick from dialog.")
            st.setWordWrap(True)
            st.setAlignment(Qt.AlignmentFlag.AlignCenter)
            st.setStyleSheet(f"font-size: 12px; color: {TXT_SEC}; border: none;")
            p_lay.addWidget(st)

            p_lay.addStretch()

            btn_exec = QPushButton("Select Folder")
            btn_exec.setCursor(Qt.CursorShape.PointingHandCursor)
            btn_exec.setStyleSheet(f"""
                QPushButton {{
                    background: {ACCENT}; color: {BG_APP}; font-size: 16px; font-weight: 800; border-radius: 8px; padding: 16px; border: none;
                }}
                QPushButton:hover {{
                    background: {ACCENT_HOVER};
                }}
            """)
            btn_exec.clicked.connect(lambda tool_id=tid: self._select_folder_for_tool(tool_id))
            p_lay.addWidget(btn_exec)

            btn_files = QPushButton("Select Files")
            btn_files.setCursor(Qt.CursorShape.PointingHandCursor)
            btn_files.setStyleSheet(f"""
                QPushButton {{
                    background: {BG_APP}; color: {TXT_PRI}; font-size: 13px; font-weight: 700; border-radius: 8px; padding: 12px; border: 1px solid {BORDER};
                }}
                QPushButton:hover {{
                    background: {BG_HOVER};
                    border: 1px solid {ACCENT};
                }}
            """)
            btn_files.clicked.connect(lambda tool_id=tid: self._select_files_for_tool(tool_id))
            p_lay.addWidget(btn_files)

            b_lay.addWidget(panel)
            lay.addWidget(body, 1)

            self.tool_drop_zones[tid] = dz
            self.tool_status_labels[tid] = st
            self.tool_page_indexes[tid] = self.stack.count()
            self.stack.addWidget(page)

    # ──────────────────────────────────────────────────────────────────────
    #  HELPERS & COMPONENTS
    # ──────────────────────────────────────────────────────────────────────
    def _r_checkbox(self, text: str, checked: bool = False) -> QCheckBox:
        chk = QCheckBox(text)
        chk.setChecked(checked)
        chk.setStyleSheet(f"""
            QCheckBox {{ color: {TXT_PRI}; font-size: 13px; font-weight: 500; font-family: {FONT}; }}
            QCheckBox::indicator {{ width: 18px; height: 18px; border-radius: 4px; border: 1px solid {BORDER}; background: {BG_CARD}; }}
            QCheckBox::indicator:checked {{ background: {ACCENT}; border: 1px solid {ACCENT}; image: none; }}
        """)
        return chk

    def _r_combo(self, items: list[str]) -> QComboBox:
        cb = QComboBox()
        cb.addItems(items)
        cb.setStyleSheet(f"""
            QComboBox {{ background: {BG_CARD}; color: {TXT_PRI}; border: 1px solid {BORDER}; border-radius: 6px; padding: 8px 12px; font-size: 13px; font-family: {FONT}; }}
            QComboBox::drop-down {{ border: none; width: 30px; }}
            QComboBox QAbstractItemView {{ background: {BG_CARD}; color: {TXT_PRI}; border: 1px solid {BORDER}; selection-background-color: {ACCENT}; selection-color: {BG_APP}; }}
        """)
        return cb

    def _build_table(self) -> QTableWidget:
        t = QTableWidget(0, 5)
        t.setHorizontalHeaderLabels(["Filename", "Resolution", "Orientation", "FPS", "Status"])
        t.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        for i in range(1, 4):
            t.horizontalHeader().setSectionResizeMode(i, QHeaderView.ResizeMode.ResizeToContents)
        t.setStyleSheet(f"""
            QTableWidget {{ background: {BG_APP}; color: {TXT_PRI}; border: 1px solid {BORDER}; border-radius: 8px; font-size: 13px; font-family: {FONT}; gridline-color: {BORDER}; }}
            QHeaderView::section {{ background: {BG_CARD}; color: {TXT_SEC}; padding: 8px; font-weight: 700; border: none; border-bottom: 1px solid {BORDER}; }}
            QTableWidget::item {{ padding: 4px 8px; border-bottom: 1px solid {BORDER}; }}
            QTableWidget::item:selected {{ background: {BG_HOVER}; color: {TXT_PRI}; }}
        """)
        t.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        t.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        t.setShowGrid(False)
        t.verticalHeader().setVisible(False)
        return t

    def _r_spin(self, prefix: str, min_v: int, max_v: int, val: int) -> QSpinBox:
        s = QSpinBox()
        s.setRange(min_v, max_v)
        s.setValue(val)
        s.setPrefix(prefix)
        s.setStyleSheet(f"""
            QSpinBox {{ background: {BG_CARD}; color: {TXT_PRI}; border: 1px solid {BORDER}; border-radius: 6px; padding: 10px; font-size: 13px; font-family: {FONT}; }}
        """)
        return s

    # Builders for tool configs
    def _r_date_group(self, lay):
        r = QHBoxLayout()
        r.setSpacing(8)
        self.d_m = self._r_spin("M ", 1, 12, 1)
        self.d_d = self._r_spin("D ", 1, 31, 1)
        self.d_y = self._r_spin("Y ", 2000, 2099, 2025)
        for s in (self.d_m, self.d_d, self.d_y):
            r.addWidget(s)
        lay.addLayout(r)

    def _r_1minvid(self, lay):
        self._r_date_group(lay)

    def _r_metamov(self, lay):
        self.mm_mode = self._r_combo(["iPhone (1-min)", "Downloaded (5-min)"])
        lay.addWidget(self.mm_mode)
        lay.addSpacing(12)
        self._r_date_group(lay)

    def _r_mutevid(self, lay):
        lbl = QLabel("No configuration needed. Audio tracks and metadata will be cleanly stripped.")
        lbl.setWordWrap(True)
        lbl.setStyleSheet(f"color: {TXT_SEC}; font-size: 13px; text-align: center; border: none;")
        lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        lay.addWidget(lbl)

    def _r_slomo(self, lay):
        lbl = QLabel("Select Target Speed:")
        lbl.setStyleSheet(f"color: {TXT_SEC}; font-size: 12px; font-weight: 700; border: none;")
        lay.addWidget(lbl)
        self.slo_speed = self._r_combo(["50% (2x)", "75% (1.25x)", "25% (4x)"])
        lay.addWidget(self.slo_speed)

    # ──────────────────────────────────────────────────────────────────────
    #  LOGIC (DRAG & DROP, SCANNING, ETC)
    # ──────────────────────────────────────────────────────────────────────
    @staticmethod
    def _sanitize_segment(text: str) -> str:
        cleaned = text.strip()
        cleaned = re.sub(r"\s+", "_", cleaned)
        cleaned = re.sub(r"[^A-Za-z0-9._-]", "_", cleaned)
        cleaned = re.sub(r"_+", "_", cleaned).strip("._-")
        cleaned = re.sub(r"_+\.", ".", cleaned)
        return cleaned or "untitled"

    @staticmethod
    def _collect_video_files(directory: Path) -> list[Path]:
        if not directory.exists() or not directory.is_dir():
            return []
        return [
            Path(root) / f
            for root, _, fnames in os.walk(directory)
            for f in fnames
            if not f.startswith("._") and Path(f).suffix.lower() in VIDEO_EXTENSIONS
        ]

    @staticmethod
    def _extract_paths_from_drop(event: QDropEvent) -> list[Path]:
        paths: list[Path] = []
        for url in event.mimeData().urls():
            p = Path(url.toLocalFile())
            if p.exists():
                paths.append(p)
        return paths

    @staticmethod
    def _dedupe_input_roots(paths: list[Path]) -> list[Path]:
        normalized = []
        for p in paths:
            try:
                resolved = p.resolve()
            except OSError:
                resolved = p
            if resolved.exists():
                normalized.append(resolved)

        roots: list[Path] = []
        for p in sorted(set(normalized), key=lambda path: len(path.parts)):
            if any(p == root or p.is_relative_to(root) for root in roots):
                continue
            roots.append(p)
        return roots

    @staticmethod
    def _resolve_unique_target(parent: Path, desired_name: str, is_dir: bool) -> Path:
        candidate = parent / desired_name
        if not candidate.exists():
            return candidate

        if is_dir:
            base = desired_name
            suffix = ""
        else:
            base, suffix = os.path.splitext(desired_name)
            if not base:
                base = "file"

        n = 1
        while True:
            next_name = f"{base}_{n}{suffix}" if suffix else f"{base}_{n}"
            candidate = parent / next_name
            if not candidate.exists():
                return candidate
            n += 1

    def _rename_to_sanitized(self, path: Path, is_dir: bool) -> tuple[Path, bool]:
        safe_name = self._sanitize_segment(path.name)
        if safe_name == path.name:
            return path, False

        target = self._resolve_unique_target(path.parent, safe_name, is_dir=is_dir)
        try:
            path.rename(target)
            return target, True
        except OSError:
            return path, False

    def _sanitize_directory_tree(self, root: Path) -> tuple[Path, int, int]:
        changed_files = 0
        changed_dirs = 0

        for current_root, dirnames, filenames in os.walk(root, topdown=False):
            current = Path(current_root)

            for filename in filenames:
                src = current / filename
                _, changed = self._rename_to_sanitized(src, is_dir=False)
                if changed:
                    changed_files += 1

            for dirname in dirnames:
                src = current / dirname
                _, changed = self._rename_to_sanitized(src, is_dir=True)
                if changed:
                    changed_dirs += 1

        new_root, changed_root = self._rename_to_sanitized(root, is_dir=True)
        if changed_root:
            changed_dirs += 1
        return new_root, changed_files, changed_dirs

    def _sanitize_inputs(self, inputs: list[Path]) -> tuple[list[Path], int, int]:
        roots = self._dedupe_input_roots(inputs)
        sanitized_roots: list[Path] = []
        changed_files = 0
        changed_dirs = 0

        for p in roots:
            if p.is_file():
                updated, changed = self._rename_to_sanitized(p, is_dir=False)
                changed_files += int(changed)
                sanitized_roots.append(updated)
                continue
            if p.is_dir():
                updated_root, f_changed, d_changed = self._sanitize_directory_tree(p)
                changed_files += f_changed
                changed_dirs += d_changed
                sanitized_roots.append(updated_root)

        return sanitized_roots, changed_files, changed_dirs

    def _collect_video_files_from_inputs(self, inputs: list[Path]) -> list[Path]:
        videos: list[Path] = []
        for p in inputs:
            if p.is_file():
                if not p.name.startswith("._") and p.suffix.lower() in VIDEO_EXTENSIONS:
                    videos.append(p)
            elif p.is_dir():
                videos.extend(self._collect_video_files(p))
        unique: dict[str, Path] = {}
        for path in videos:
            unique[str(path)] = path
        return list(unique.values())

    def _set_organizer_drop_state(self, active: bool):
        color = ACCENT if active else BORDER
        bg = BG_HOVER if active else BG_CARD
        self.org_drop_zone.setStyleSheet(
            f"background: {bg}; border: 2px dashed {color}; border-radius: 12px;"
        )

    def _set_tool_drop_state(self, tool_id: str, active: bool):
        zone = self.tool_drop_zones.get(tool_id)
        if zone is None:
            return
        color = ACCENT if active else BORDER
        bg = BG_HOVER if active else BG_CARD
        zone.setStyleSheet(f"background: {bg}; border: 2px dashed {color}; border-radius: 10px;")

    def dragEnterEvent(self, e: QDragEnterEvent):
        mode = getattr(self, "current_mode", "")
        if not e.mimeData().hasUrls():
            return
        if mode == "organize":
            e.acceptProposedAction()
            self._set_organizer_drop_state(True)
            return
        if mode in self.tool_page_indexes:
            e.acceptProposedAction()
            self._set_tool_drop_state(mode, True)

    def dragLeaveEvent(self, e):
        mode = getattr(self, "current_mode", "")
        if mode == "organize":
            self._set_organizer_drop_state(False)
        elif mode in self.tool_page_indexes:
            self._set_tool_drop_state(mode, False)

    def dropEvent(self, e: QDropEvent):
        mode = getattr(self, "current_mode", "")
        dropped_paths = self._extract_paths_from_drop(e)
        if mode == "organize":
            self._set_organizer_drop_state(False)
            files = self._collect_video_files_from_inputs(dropped_paths)
            if files:
                self._start_scan(files)
            return
        if mode in self.tool_page_indexes:
            self._set_tool_drop_state(mode, False)
            self._run_tool_for_inputs(mode, dropped_paths)

    def _select_folder(self):
        d = QFileDialog.getExistingDirectory(self, "Select Directory")
        if d:
            folder = Path(d)
            mode = getattr(self, "current_mode", "")
            if mode == "organize":
                files = self._collect_video_files(folder)
                if files:
                    self._start_scan(files)
            elif mode in self.tool_page_indexes:
                self._run_tool_for_inputs(mode, [folder])

    def _select_folder_for_tool(self, tool_id: str):
        self.current_mode = tool_id
        d = QFileDialog.getExistingDirectory(self, "Select Directory")
        if d:
            self._run_tool_for_inputs(tool_id, [Path(d)])

    def _select_files_for_tool(self, tool_id: str):
        self.current_mode = tool_id
        files, _ = QFileDialog.getOpenFileNames(self, "Select Files")
        if files:
            self._run_tool_for_inputs(tool_id, [Path(f) for f in files])

    def _run_tool_for_inputs(self, tool_id: str, inputs: list[Path]):
        status = self.tool_status_labels.get(tool_id)
        roots = self._dedupe_input_roots(inputs)
        if not roots:
            if status:
                status.setText("No valid files or folders were provided.")
            return

        sanitized_roots, renamed_files, renamed_dirs = self._sanitize_inputs(roots)
        video_files = self._collect_video_files_from_inputs(sanitized_roots)

        if status:
            status.setText(
                f"Inputs: {len(roots)} | Video files: {len(video_files)} | "
                f"Files renamed: {renamed_files} | Folders renamed: {renamed_dirs}"
            )

    def _start_scan(self, files: list[Path]):
        if self.scan_worker and self.scan_worker.isRunning():
            self.scan_worker.stop()
            self.scan_worker.wait()

        if getattr(self, "current_mode", "") == "organize":
            self.all_video_data = {}
            self.org_table.setRowCount(0)
            self.org_count.setText(f"Scanning {len(files)} files…")
            self.org_progress.setVisible(True)
            self.org_progress.setValue(0)
            self.org_scan_btn.setEnabled(False)

        self.scan_worker = ScanWorker(files)
        self.scan_worker.progress.connect(
            lambda c, t: (
                (
                    self.org_progress.setMaximum(t),
                    self.org_progress.setValue(c),
                )
                if getattr(self, "current_mode", "") == "organize"
                else None
            )
        )
        self.scan_worker.result.connect(self._on_result)
        self.scan_worker.done.connect(self._on_done)
        self.scan_worker.start()

    def _on_result(self, info: dict):
        self.all_video_data[info["filepath"]] = info
        self._add_row(info)
        self.org_count.setText(f"{len(self.all_video_data)} files")

    def _on_done(self):
        self.org_progress.setVisible(False)
        if hasattr(self, "org_scan_btn"):
            self.org_scan_btn.setEnabled(True)
        self.org_status.setText(f"{len(self.all_video_data)} videos analyzed")

    def _add_row(self, info: dict):
        if not self._passes(info):
            return
        r = self.org_table.rowCount()
        self.org_table.insertRow(r)

        name = QTableWidgetItem(info["filename"])
        name.setData(Qt.ItemDataRole.UserRole, info["filepath"])
        self.org_table.setItem(r, 0, name)
        self.org_table.setItem(r, 1, QTableWidgetItem(info["resolution"]))
        self.org_table.setItem(r, 2, QTableWidgetItem(info["orientation"]))
        self.org_table.setItem(r, 3, QTableWidgetItem(str(info["fps"])))

        dup = info["is_duplicate"]
        self.org_table.setItem(r, 4, QTableWidgetItem("Duplicate" if dup else "Unique"))
        if dup:
            for c in range(5):
                if cell := self.org_table.item(r, c):
                    cell.setBackground(ROW_DUP)
                    cell.setForeground(QBrush(QColor(STATUS_DUP)))

    def _passes(self, i: dict) -> bool:
        w, h = i.get("width", 0), i.get("height", 0)
        if (
            self.chk_4k.isChecked()
            or self.chk_1080p.isChecked()
            or self.chk_720p.isChecked()
            or self.chk_hd.isChecked()
            or self.chk_sd.isChecked()
        ):
            res_ok = False
            if self.chk_4k.isChecked() and (w >= 3840 or h >= 3840):
                res_ok = True
            elif self.chk_1080p.isChecked() and (w in (1920, 1080) or h in (1920, 1080)):
                res_ok = True
            elif self.chk_720p.isChecked() and (w in (1280, 720) or h in (1280, 720)):
                res_ok = True
            elif self.chk_hd.isChecked() and (w >= 1280 or h >= 1280):
                res_ok = True
            elif self.chk_sd.isChecked() and (w < 1280 and h < 1280):
                res_ok = True
            if not res_ok:
                return False
        if self.chk_iphone.isChecked() and not i.get("iphone"):
            return False
        if self.chk_gps.isChecked() and not i.get("has_gps"):
            return False
        if self.chk_dup.isChecked() and not i.get("is_duplicate"):
            return False
        return True

    def _apply_filters(self):
        self.org_table.setRowCount(0)
        for i in self.all_video_data.values():
            self._add_row(i)

    def _update_inspector(self, item):
        pass

    def _export_csv(self):
        if not self.all_video_data:
            return
        path, _ = QFileDialog.getSaveFileName(
            self,
            "Export CSV",
            os.path.expanduser("~/Desktop/provid_report.csv"),
            "CSV (*.csv)",
        )
        if not path:
            return
        try:
            with open(path, "w", newline="", encoding="utf-8") as f:
                w = csv.writer(f)
                w.writerow(
                    [
                        "Filename",
                        "Resolution",
                        "Orientation",
                        "FPS",
                        "Device",
                        "GPS",
                        "Status",
                        "Path",
                    ]
                )
                for fp, info in self.all_video_data.items():
                    dup_str = "Duplicate" if info["is_duplicate"] else "Unique"
                    w.writerow(
                        [
                            info["filename"],
                            info["resolution"],
                            info["orientation"],
                            info["fps"],
                            info.get("iphone", ""),
                            info.get("has_gps", ""),
                            dup_str,
                            fp,
                        ]
                    )
            QMessageBox.information(self, "Export", "CSV exported successfully.")
        except Exception as e:
            QMessageBox.warning(self, "Error", str(e))

    def _delete_selected(self):
        if (r := self.org_table.currentRow()) >= 0:
            item = self.org_table.item(r, 0)
            if not item:
                return
            fp = item.data(Qt.ItemDataRole.UserRole)
            if (
                QMessageBox.question(
                    self,
                    "Delete",
                    f"Permanently delete?\\n{os.path.basename(fp)}",
                    QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                )
                == QMessageBox.StandardButton.Yes
            ):
                try:
                    os.remove(fp)
                    self.org_table.removeRow(r)
                    del self.all_video_data[fp]
                    self.org_status.setText(f"Deleted: {os.path.basename(fp)}")
                except Exception as e:
                    QMessageBox.warning(self, "Error", f"Failed to delete: {e}")

    def _export_json(self):
        pass
