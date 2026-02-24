import subprocess
from datetime import datetime, timedelta
from pathlib import Path
from typing import Callable


class VideoTools:
    """Implementations for 1MinVid, MetaMov, MuteVid, and Slo-Mo."""

    @staticmethod
    def fixvid(
        files: list[Path],
        start_date: datetime,
        progress_callback: Callable[[int, int, str], None] = lambda c, t, s: None,
    ) -> None:
        """1MinVid: Sets creation date incrementally by 1 minute, starting at 12:00 PM."""
        total = len(files)
        current_time = start_date.replace(hour=12, minute=0, second=0, microsecond=0)

        for i, file_path in enumerate(files):
            progress_callback(i, total, f"Fixing {file_path.name}")
            date_str = current_time.strftime("%Y:%m:%d %H:%M:%S")
            try:
                subprocess.run(
                    [
                        "exiftool",
                        "-overwrite_original",
                        "-ExtractEmbedded",
                        f"-QuickTime:CreateDate={date_str}",
                        str(file_path),
                    ],
                    check=True,
                    capture_output=True,
                )
            except subprocess.CalledProcessError:
                pass
            current_time += timedelta(minutes=1)

        progress_callback(total, total, "Done")

    @staticmethod
    def metamov(
        files: list[Path],
        start_date: datetime,
        mode: str,  # 'iphone' or 'downloaded'
        progress_callback: Callable[[int, int, str], None] = lambda c, t, s: None,
    ) -> None:
        """MetaMov: Fixes dates in 1-min (chrono) or 5-min (filename) increments."""
        total = len(files)
        current_time = start_date.replace(hour=12, minute=0, second=0, microsecond=0)
        increment = timedelta(minutes=1) if mode == "iphone" else timedelta(minutes=5)

        # Sort files based on mode
        if mode == "iphone":
            # Sort chronologically by attempting to read existing creation dates
            def get_mtime(p: Path) -> float:
                try:
                    return p.stat().st_mtime
                except OSError:
                    return 0.0

            sorted_files = sorted(files, key=get_mtime)
        else:
            sorted_files = sorted(files, key=lambda p: p.name)

        for i, file_path in enumerate(sorted_files):
            progress_callback(i, total, f"MetaMov processing {file_path.name}")
            date_str = current_time.strftime("%Y:%m:%d %H:%M:%S")
            try:
                subprocess.run(
                    [
                        "exiftool",
                        "-overwrite_original",
                        "-ExtractEmbedded",
                        f"-QuickTime:CreateDate={date_str}",
                        str(file_path),
                    ],
                    check=True,
                    capture_output=True,
                )
            except subprocess.CalledProcessError:
                pass
            current_time += increment

        progress_callback(total, total, "Done")

    @staticmethod
    def mutevid(
        files: list[Path],
        output_dir: Path,
        progress_callback: Callable[[int, int, str], None] = lambda c, t, s: None,
    ) -> None:
        """MuteVid: Removes audio and metadata using ffmpeg."""
        total = len(files)
        output_dir.mkdir(parents=True, exist_ok=True)

        for i, file_path in enumerate(files):
            progress_callback(i, total, f"Muting {file_path.name}")
            new_file = output_dir / f"MUTED_{file_path.name}"

            # Ensure output file ends in .mov for QuickTime compatibility
            if new_file.suffix.lower() != ".mov":
                new_file = new_file.with_suffix(".mov")

            try:
                subprocess.run(
                    [
                        "ffmpeg",
                        "-y",
                        "-i",
                        str(file_path),
                        "-c:v",
                        "copy",
                        "-an",
                        "-map_metadata",
                        "-1",
                        "-f",
                        "mov",
                        str(new_file),
                    ],
                    check=True,
                    capture_output=True,
                )
            except subprocess.CalledProcessError:
                pass

        progress_callback(total, total, "Done")

    @staticmethod
    def slomov(
        files: list[Path],
        output_dir: Path,
        speed_factor: float,  # e.g., 0.5 for 50%
        progress_callback: Callable[[int, int, str], None] = lambda c, t, s: None,
    ) -> None:
        """Slo-Mo: Creates slow motion videos using ffmpeg."""
        total = len(files)
        # E.g. 50% speed = 0.5. PTS factor = 1 / 0.5 = 2.0
        pts_factor = 1.0 / speed_factor
        output_dir.mkdir(parents=True, exist_ok=True)

        # Check for hardware encoder
        has_hw = False
        try:
            res = subprocess.run(
                ["ffmpeg", "-hide_banner", "-encoders"], capture_output=True, text=True
            )
            if "h264_videotoolbox" in res.stdout:
                has_hw = True
        except FileNotFoundError:
            pass

        encoder = "h264_videotoolbox" if has_hw else "libx264"
        bitrate_arg = ["-b:v", "5000k"] if has_hw else ["-crf", "23"]

        for i, file_path in enumerate(files):
            progress_callback(i, total, f"Slowing down {file_path.name}")
            speed_str = f"{int(speed_factor * 100)}%"
            new_file = output_dir / f"SLOMO_{speed_str}_{file_path.name}"

            if new_file.suffix.lower() != ".mov":
                new_file = new_file.with_suffix(".mov")

            cmd = [
                "ffmpeg",
                "-y",
                "-i",
                str(file_path),
                "-filter:v",
                f"setpts={pts_factor}*PTS",
                "-c:v",
                encoder,
                *bitrate_arg,
                "-an",
                str(new_file),
            ]

            try:
                subprocess.run(
                    cmd,
                    check=True,
                    capture_output=True,
                )
            except subprocess.CalledProcessError:
                pass

        progress_callback(total, total, "Done")
