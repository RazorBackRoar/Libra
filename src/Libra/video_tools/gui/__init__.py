"""GUI entrypoints for the video tools suite."""

from .apple_organizer import main as run_apple_organizer
from .duplicate_finder import main as run_duplicate_finder
from .video_sorter import main as run_video_sorter

__all__ = ["run_apple_organizer", "run_duplicate_finder", "run_video_sorter"]
