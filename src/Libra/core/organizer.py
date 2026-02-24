import re
from enum import Enum
from pathlib import Path

from .video_metadata import VideoMetadata


class SortMode(Enum):
    ProVid = "ProVid"
    VidRes = "VidRes"
    ProMax = "ProMax"
    MaxVid = "MaxVid"
    KeepName = "KeepName"
    EmojiVid = "EmojiVid"


class VideoClassifier:
    @staticmethod
    def classify(metadata: VideoMetadata) -> tuple[str, str, int]:
        w, h = metadata.width, metadata.height
        if w >= 3840 or h >= 3840 or w >= 2160 or h >= 2160:
            res = "4K"
        elif w == 1920 or h == 1920 or w == 1080 or h == 1080:
            res = "1080p"
        elif w == 1280 or h == 1280 or w == 720 or h == 720:
            res = "720p"
        elif w > 1080 or h > 1080:
            res = "HD"
        else:
            res = "SD"

        orient = "V" if h > w else "W"
        fps_bucket = 60 if metadata.fps > 45 else 30

        return res, orient, fps_bucket


class Organizer:
    def __init__(self, mode: SortMode, prefix: str = "", base_dir: Path = Path(".")):
        self.mode = mode
        self.prefix = prefix
        self.base_dir = base_dir
        self.counters: dict[str, int] = {}

    def get_destination(self, file_path: Path, metadata: VideoMetadata) -> Path:
        res, orient, fps = VideoClassifier.classify(metadata)

        emojis = ""
        if metadata.iphone_model:
            emojis += "📱"
        if metadata.has_camera_lens:
            emojis += "📷"
        if metadata.has_gps:
            emojis += "🌍"
        if metadata.is_edited:
            emojis += "✂️"

        # Determine subfolder
        if self.mode in (SortMode.VidRes, SortMode.KeepName):
            subfolder = res
        elif self.mode == SortMode.MaxVid:
            subfolder = f"{res} {orient} {fps}"
        elif self.mode == SortMode.ProMax:
            subfolder = f"{res} {orient}"
        else:  # ProVid, EmojiVid
            subfolder = ""

        dest_dir = self.base_dir / subfolder
        dest_dir.mkdir(parents=True, exist_ok=True)

        format_key = f"{res}|{orient}|{fps}"

        # Extension
        ext = "".join(c for c in file_path.suffix.lower() if c.isalnum())
        if not ext:
            ext = "mov"

        counter = self.counters.get(format_key, 0) + 1

        while True:
            counter_str = f"{counter:03d}"

            if self.mode == SortMode.KeepName:
                name_base = f"{file_path.stem}_{counter_str}.{ext}"
            elif self.mode == SortMode.EmojiVid:
                parts = []
                if self.prefix:
                    parts.append(self.prefix)
                if emojis:
                    parts.append(emojis)
                parts.append(f"{counter_str}.{ext}")
                name_base = " ".join(parts)
            else:
                parts = []
                if self.prefix:
                    parts.append(self.prefix)
                parts.append(f"{res} {orient}{fps}")
                if emojis:
                    parts.append(emojis)
                parts.append(f"{counter_str}.{ext}")
                name_base = " ".join(parts)

            name_base = self._sanitize_filename(name_base)
            dest_path = dest_dir / name_base

            if not dest_path.exists():
                self.counters[format_key] = counter
                return dest_path

            counter += 1

    @staticmethod
    def _sanitize_filename(name: str, max_len: int = 200) -> str:
        # Replace forbidden chars
        name = re.sub(r"[\/\\\:\*\?\"\<\>\|]", "_", name)
        # Collapse whitespace
        name = re.sub(r"\s+", " ", name)
        # Collapse underscores
        name = re.sub(r"_+", "_", name)
        # Trim
        name = name.strip(" _")

        if len(name) > max_len:
            parts = name.rsplit(".", 1)
            if len(parts) == 2 and len(parts[1]) < 10:
                base, ext = parts
                base = base[: max_len - len(ext) - 1]
                name = f"{base}.{ext}"
            else:
                name = name[:max_len]
        return name
