import os
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtWidgets import QApplication

from Libra.gui.main_window import MainWindow


def _app() -> QApplication:
    app = QApplication.instance()
    if app is None:
        app = QApplication([])
    return app


def test_tool_folder_preview_reports_sanitization_counts(tmp_path: Path):
    _app()
    window = MainWindow()

    folder = tmp_path / "bad__folder"
    folder.mkdir()
    (folder / "__clip__.mp4").write_bytes(b"")
    (folder / "normal.mov").write_bytes(b"")

    window._run_tool_for_inputs("provid", [folder])
    status_text = window.tool_status_labels["provid"].text()

    assert "Inputs: 1" in status_text
    assert "Video files: 2" in status_text
    assert "Files renamed:" in status_text
    assert "Folders renamed:" in status_text


def test_tool_file_input_auto_sanitizes_filename(tmp_path: Path):
    _app()
    window = MainWindow()

    raw_file = tmp_path / "weird file @ name!!.mp4"
    raw_file.write_bytes(b"")

    window._run_tool_for_inputs("provid", [raw_file])
    sanitized_file = tmp_path / "weird_file_name.mp4"

    assert not raw_file.exists()
    assert sanitized_file.exists()
