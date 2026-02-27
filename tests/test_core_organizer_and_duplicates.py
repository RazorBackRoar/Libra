from __future__ import annotations

from pathlib import Path

from Libra.core.duplicate_finder import DuplicateFinder
from Libra.core.organizer import Organizer, SortMode
from Libra.core.video_metadata import VideoMetadata


def _sample_metadata() -> VideoMetadata:
    return VideoMetadata(
        width=1920,
        height=1080,
        rotation=0,
        fps=59.94,
        iphone_model="15",
        has_gps=True,
        is_edited=False,
        has_camera_lens=True,
    )


def test_organizer_keepname_mode_generates_stable_incrementing_names(tmp_path: Path) -> None:
    organizer = Organizer(mode=SortMode.KeepName, prefix="Trip", base_dir=tmp_path)
    metadata = _sample_metadata()

    first = organizer.get_destination(Path("my:file?.mov"), metadata)
    first.parent.mkdir(parents=True, exist_ok=True)
    first.write_bytes(b"first")

    second = organizer.get_destination(Path("my:file?.mov"), metadata)

    assert first.name.startswith("my_file_")
    assert first.name != second.name
    assert second.name.endswith(".mov")


def test_duplicate_finder_detects_duplicates_and_tracks_original(tmp_path: Path) -> None:
    finder = DuplicateFinder()
    original = tmp_path / "a.mov"
    duplicate = tmp_path / "b.mov"
    original.write_bytes(b"same-content")
    duplicate.write_bytes(b"same-content")

    assert finder.is_duplicate(original) is False
    assert finder.is_duplicate(duplicate) is True
    assert finder.get_original(duplicate) == original


def test_duplicate_finder_ignores_missing_files(tmp_path: Path) -> None:
    finder = DuplicateFinder()
    missing = tmp_path / "missing.mov"

    assert finder.is_duplicate(missing) is False
    assert finder.get_original(missing) == missing
