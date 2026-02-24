import re
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


@dataclass
class VideoMetadata:
    width: int
    height: int
    rotation: int
    fps: float
    iphone_model: Optional[str]
    has_gps: bool
    is_edited: bool
    has_camera_lens: bool


class MetadataExtractor:
    """Extracts video metadata using exiftool, mediainfo, and ffprobe."""

    @staticmethod
    def extract(file_path: Path) -> VideoMetadata:
        exif_out = MetadataExtractor._run_exiftool(file_path)

        # Mediainfo fallbacks
        mi_width = MetadataExtractor._run_mediainfo(file_path, "Width")
        mi_height = MetadataExtractor._run_mediainfo(file_path, "Height")
        mi_fps = MetadataExtractor._run_mediainfo(file_path, "FrameRate")

        width = MetadataExtractor._parse_exif_int(exif_out, "ImageWidth", mi_width)
        height = MetadataExtractor._parse_exif_int(exif_out, "ImageHeight", mi_height)
        rotation = MetadataExtractor._parse_exif_int(exif_out, "Rotation", 0)
        fps = MetadataExtractor._parse_exif_float(exif_out, "VideoFrameRate", mi_fps)

        # Handle rotation swap
        if rotation in (90, 270):
            width, height = height, width

        iphone_model = MetadataExtractor._extract_iphone_model(exif_out)

        has_gps = bool(
            re.search(
                r"GPS(Coordinates|Position|Latitude|Longitude)\s*:.*[0-9]",
                exif_out,
                re.IGNORECASE,
            )
        )
        has_camera_lens = bool(
            re.search(r"LensModel\s*:.*[A-Za-z0-9]", exif_out, re.IGNORECASE)
        )
        is_edited = MetadataExtractor._is_edited_fps(file_path)

        return VideoMetadata(
            width=width,
            height=height,
            rotation=rotation,
            fps=fps,
            iphone_model=iphone_model,
            has_gps=has_gps,
            is_edited=is_edited,
            has_camera_lens=has_camera_lens,
        )

    @staticmethod
    def _run_exiftool(file_path: Path) -> str:
        try:
            result = subprocess.run(
                [
                    "exiftool",
                    "-a",
                    "-G1",
                    "-s",
                    "-api",
                    "QuickTimeUTC=1",
                    str(file_path),
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            return result.stdout
        except FileNotFoundError:
            return ""

    @staticmethod
    def _run_mediainfo(file_path: Path, param: str) -> str:
        try:
            result = subprocess.run(
                ["mediainfo", f"--Inform=Video;%{param}%", str(file_path)],
                capture_output=True,
                text=True,
                check=False,
            )
            return result.stdout.strip()
        except FileNotFoundError:
            return ""

    @staticmethod
    def _parse_exif_int(exif_out: str, field: str, fallback: str) -> int:
        match = re.search(rf"{field}\s*:\s*(\d+)", exif_out, re.IGNORECASE)
        val = match.group(1) if match else fallback
        try:
            return int(val) if val else 0
        except ValueError:
            return 0

    @staticmethod
    def _parse_exif_float(exif_out: str, field: str, fallback: str) -> float:
        match = re.search(rf"{field}\s*:\s*([\d.]+)", exif_out, re.IGNORECASE)
        val = match.group(1) if match else fallback
        try:
            return float(val) if val else 0.0
        except ValueError:
            return 0.0

    @staticmethod
    def _extract_iphone_model(exif_out: str) -> Optional[str]:
        has_lens_iphone = bool(re.search(r"LensModel.*iPhone", exif_out, re.IGNORECASE))
        has_make_apple = bool(re.search(r"Make.*Apple", exif_out, re.IGNORECASE))
        has_model_iphone = bool(re.search(r"Model.*iPhone", exif_out, re.IGNORECASE))
        has_any_iphone = bool(re.search(r"iPhone", exif_out, re.IGNORECASE))
        has_any_apple = bool(re.search(r"Apple", exif_out, re.IGNORECASE))

        full_device_model = ""
        if has_lens_iphone:
            match = re.search(r"LensModel\s*:\s*(.*)", exif_out, re.IGNORECASE)
            if match:
                full_device_model = match.group(1).strip()
        elif has_make_apple and has_model_iphone:
            make_match = re.search(
                r"^\[.*?Make\s*:\s*(.*)", exif_out, re.IGNORECASE | re.MULTILINE
            )
            model_match = re.search(
                r"^\[.*?Model\s*:\s*(.*)", exif_out, re.IGNORECASE | re.MULTILINE
            )
            make = make_match.group(1).strip() if make_match else ""
            model = model_match.group(1).strip() if model_match else ""
            full_device_model = f"{make} {model}".strip()
        elif has_any_iphone:
            match = re.search(r".*iPhone.*:\s*(.*iPhone.*)", exif_out, re.IGNORECASE)
            if match:
                full_device_model = match.group(1).strip()
            else:
                full_device_model = "iPhone"
        elif has_any_apple:
            full_device_model = "Apple Device"

        if not full_device_model:
            return None

        # Simplified extraction logic
        model_lower = full_device_model.lower()
        mapping = {
            "iphone 16": "16",
            "iphone 15": "15",
            "iphone 14": "14",
            "iphone 13": "13",
            "iphone 12": "12",
            "iphone 11": "11",
            "iphone xs": "XS",
            "iphone xr": "XR",
            "iphone x": "X",
            "iphone 8": "8",
            "iphone 7": "7",
            "iphone 6s": "6s",
            "iphone 6": "6",
            "iphone se": "SE",
            "iphone 5s": "5s",
            "iphone 5c": "5c",
            "iphone 5": "5",
            "iphone 4s": "4S",
            "iphone 4": "4",
            "iphone 3g": "3G",
        }
        for key, val in mapping.items():
            if key in model_lower:
                return val

        if "iphone" in model_lower:
            match = re.search(r"iPhone\s*([0-9XRS]+)", full_device_model, re.IGNORECASE)
            if match:
                return match.group(1)
            return "📱"

        return None

    @staticmethod
    def _is_edited_fps(file_path: Path) -> bool:
        try:
            result = subprocess.run(
                [
                    "ffprobe",
                    "-v",
                    "error",
                    "-select_streams",
                    "v:0",
                    "-show_entries",
                    "stream=avg_frame_rate",
                    "-of",
                    "csv=p=0",
                    str(file_path),
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            fraction = result.stdout.strip()
            if "/" in fraction:
                num, den = map(float, fraction.split("/"))
                if den > 0:
                    exact_fps = round(num / den, 6)
                    if exact_fps in (30.000000, 60.000000):
                        return True
            return False
        except (FileNotFoundError, ValueError):
            return False
