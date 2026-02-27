from __future__ import annotations

import json
from pathlib import Path

from Libra.video_tools import __main__ as video_tools_main
from Libra.video_tools.cli import batch_processor


def test_build_parser_supports_expected_subcommands() -> None:
    parser = video_tools_main.build_parser()

    assert parser.parse_args(["sorter"]).command == "sorter"
    assert parser.parse_args(["duplicates"]).command == "duplicates"
    assert parser.parse_args(["apple"]).command == "apple"
    assert parser.parse_args(["batch", "/tmp"]).command == "batch"


def test_main_batch_path_routes_to_process_folder(monkeypatch) -> None:
    seen: dict[str, str] = {}

    monkeypatch.setattr(
        "sys.argv",
        ["python", "batch", "/tmp/videos"],
    )
    monkeypatch.setattr(video_tools_main, "process_folder", lambda folder: seen.setdefault("folder", folder))

    result = video_tools_main.main()

    assert result == 0
    assert seen["folder"] == "/tmp/videos"


def test_batch_processor_writes_report_for_supported_video_extensions(
    monkeypatch, tmp_path: Path
) -> None:
    video_file = tmp_path / "clip.mp4"
    ignored_file = tmp_path / "notes.txt"
    video_file.write_bytes(b"video")
    ignored_file.write_text("ignore", encoding="utf-8")

    monkeypatch.chdir(tmp_path)
    monkeypatch.setattr(
        batch_processor.os,
        "walk",
        lambda folder: [(str(folder), [], [video_file.name, ignored_file.name])],
    )
    monkeypatch.setattr(
        batch_processor,
        "classify_video",
        lambda filepath: {
            "success": True,
            "make": "Apple",
            "has_camera": True,
            "has_gps": False,
            "filepath": filepath,
        },
    )

    batch_processor.process_folder(str(tmp_path))

    report_path = tmp_path / "batch_analysis_report.json"
    report = json.loads(report_path.read_text(encoding="utf-8"))
    assert len(report) == 1
    assert report[0]["filepath"].endswith("clip.mp4")
