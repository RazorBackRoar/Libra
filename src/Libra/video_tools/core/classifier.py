#!/usr/bin/env python3
"""
video_classifier.py - Video Classification Module
==================================================
Analyzes video files and extracts metadata using ffprobe.
Implements the complete provid.zsh classification logic.

Resolution Categories: 4K, 1080p, 720p, HD, SD
Framerate Categories: 30, 60
Orientation: W (Wide/Landscape), V (Vertical/Portrait)
"""

import subprocess
import json
from typing import Dict, Tuple, Optional, List


# ============================================================================
# RESOLUTION CLASSIFICATION
# ============================================================================


def classify_resolution(width: int, height: int) -> str:
    """
    Classify video resolution into one of 5 categories.

    Args:
        width: Video width in pixels
        height: Video height in pixels

    Returns:
        Resolution category: "4K", "1080p", "720p", "HD", or "SD"

    Priority Order (checked top to bottom):
        1. 4K   - width ≥ 3840 OR height ≥ 3840 OR width ≥ 2160 OR height ≥ 2160
        2. 1080p - width == 1920 OR height == 1920 OR width == 1080 OR height == 1080
        3. 720p - width == 1280 OR height == 1280 OR width == 720 OR height == 720
        4. HD   - width > 1080 OR height > 1080 (but not matching above)
        5. SD   - Everything else
    """
    # 1. CHECK FOR 4K FIRST
    if width >= 3840 or height >= 3840 or width >= 2160 or height >= 2160:
        return "4K"

    # 2. CHECK FOR 1080p
    elif width == 1920 or height == 1920 or width == 1080 or height == 1080:
        return "1080p"

    # 3. CHECK FOR 720p
    elif width == 1280 or height == 1280 or width == 720 or height == 720:
        return "720p"

    # 4. CHECK FOR HD (in-between resolutions)
    elif width > 1080 or height > 1080:
        return "HD"

    # 5. EVERYTHING ELSE IS SD
    else:
        return "SD"


# ============================================================================
# FRAME RATE CLASSIFICATION
# ============================================================================


def classify_framerate(fps: float) -> int:
    """
    Classify frame rate into 30fps or 60fps category.

    Args:
        fps: Actual frame rate (can be float like 29.97, 59.94, etc.)

    Returns:
        Frame rate category: 30 or 60

    Logic:
        - If fps > 45: return 60
        - Otherwise: return 30 (default)

    Examples:
        24.00 → 30
        29.97 → 30
        30.00 → 30
        50.00 → 60
        59.94 → 60
        60.00 → 60
        120.00 → 60
    """
    if fps > 45:
        return 60
    return 30


# ============================================================================
# ORIENTATION CLASSIFICATION
# ============================================================================


def classify_orientation(width: int, height: int) -> str:
    """
    Classify video orientation.

    Args:
        width: Video width in pixels (after rotation correction)
        height: Video height in pixels (after rotation correction)

    Returns:
        Orientation: "W" (Wide/Landscape) or "V" (Vertical/Portrait)
    """
    if height > width:
        return "V"  # Vertical/Portrait
    return "W"  # Wide/Landscape


# ============================================================================
# ROTATION CORRECTION
# ============================================================================


def apply_rotation_correction(width: int, height: int, rotation: int) -> Tuple[int, int]:
    """
    Swap width/height if video has 90° or 270° rotation.

    Args:
        width: Original video width
        height: Original video height
        rotation: Rotation value from metadata (0, 90, 180, 270)

    Returns:
        Tuple of (corrected_width, corrected_height)
    """
    if rotation in (90, 270):
        return height, width
    return width, height


# ============================================================================
# FOLDER STRUCTURE GENERATION
# ============================================================================


def generate_folder_structure(mode: str = "MaxVid") -> List[str]:
    """
    Generate folder structure based on sorting mode.

    Args:
        mode: Sorting mode
            - "VidRes" or "NameKeep": Resolution only
            - "ProMax": Resolution + Orientation
            - "MaxVid": Resolution + Orientation + FPS
            - "ProVid": No subfolders

    Returns:
        List of folder names to create
    """
    resolutions = ["4K", "1080p", "720p", "HD", "SD"]
    orientations = ["W", "V"]
    framerates = ["30", "60"]

    folders = []

    if mode in ("VidRes", "NameKeep"):
        # Resolution only
        folders = resolutions.copy()

    elif mode == "ProMax":
        # Resolution + Orientation
        for res in resolutions:
            for orient in orientations:
                folders.append(f"{res} {orient}")

    elif mode == "MaxVid":
        # Resolution + Orientation + FPS
        for res in resolutions:
            for orient in orientations:
                for fps in framerates:
                    folders.append(f"{res} {orient} {fps}")

    elif mode == "ProVid":
        # No subfolders - everything in root
        folders = []

    return folders


# ============================================================================
# FILENAME GENERATION
# ============================================================================


def generate_filename(
    resolution: str,
    orientation: str,
    framerate: int,
    counter: int,
    prefix: str = "",
    emoji_indicators: str = "",
    extension: str = "mov",
) -> str:
    """
    Generate standardized filename based on video properties.

    Args:
        resolution: "4K", "1080p", "720p", "HD", or "SD"
        orientation: "W" or "V"
        framerate: 30 or 60
        counter: Sequential number (will be zero-padded to 3 digits)
        prefix: Optional prefix text
        emoji_indicators: Optional emoji string (📱🌍📷✂️)
        extension: File extension (default: "mov")

    Returns:
        Formatted filename

    Format:
        [PREFIX ]RESOLUTION ORIENTATION+FPS [EMOJIS ]COUNTER.extension

    Examples:
        "4K W30 📱🌍 001.mov"
        "My Video 1080p V60 📱📷✂️ 042.mp4"
        "720p W30 001.mov"
    """
    # Zero-pad counter to 3 digits
    counter_str = f"{counter:03d}"

    # Build filename components
    parts = []

    if prefix:
        parts.append(prefix)

    parts.append(f"{resolution} {orientation}{framerate}")

    if emoji_indicators:
        parts.append(emoji_indicators)

    parts.append(counter_str)

    return " ".join(parts) + f".{extension}"


# ============================================================================
# COMPLETE VIDEO CLASSIFICATION (FILE-BASED)
# ============================================================================


def classify_video(file_path: str) -> Dict:
    """
    Analyzes a video file and extracts metadata.

    Args:
        file_path: Path to the video file

    Returns:
        Dictionary with resolution, orientation, framerate, device info, and more.
    """
    # Step 1: Get raw metadata
    metadata = _get_video_metadata(file_path)

    if not metadata["success"]:
        return {
            "resolution": "SD",
            "orientation": "W",
            "framerate_category": 30,
            "actual_fps": 0.0,
            "width": 0,
            "height": 0,
            "make": None,
            "model": None,
            "has_camera": False,
            "has_gps": False,
            "success": False,
            "error": metadata["error"],
        }

    # Step 2: Extract and process properties
    width = metadata["width"]
    height = metadata["height"]
    fps = metadata["fps"]
    rotation = metadata["rotation"]

    # Step 3: Apply rotation for correct display dimensions
    actual_width, actual_height = apply_rotation_correction(width, height, rotation)

    # Step 4: Classify using the provid.zsh logic
    return {
        "resolution": classify_resolution(actual_width, actual_height),
        "orientation": classify_orientation(actual_width, actual_height),
        "framerate_category": classify_framerate(fps),
        "actual_fps": round(fps, 2) if fps else 0.0,
        "width": actual_width,
        "height": actual_height,
        "make": metadata.get("make"),
        "model": metadata.get("model"),
        "has_camera": metadata.get("has_camera", False),
        "has_gps": metadata.get("has_gps", False),
        "success": True,
        "error": None,
        "filepath": file_path,
    }


# ============================================================================
# QUICK CLASSIFICATION (WITHOUT FILE I/O)
# ============================================================================


def classify_video_properties(width: int, height: int, fps: float, rotation: int = 0) -> Dict:
    """
    Classify video properties without reading a file.
    Useful for testing or when metadata is already available.

    Args:
        width: Video width in pixels
        height: Video height in pixels
        fps: Frame rate (can be float)
        rotation: Rotation metadata (default: 0)

    Returns:
        Dictionary with classification results.
    """
    # Apply rotation correction first
    width, height = apply_rotation_correction(width, height, rotation)

    return {
        "resolution": classify_resolution(width, height),
        "orientation": classify_orientation(width, height),
        "framerate_category": classify_framerate(fps),
        "actual_fps": round(fps, 2) if fps else 0.0,
        "width": width,
        "height": height,
    }


# ============================================================================
# METADATA EXTRACTION (INTERNAL)
# ============================================================================


def _get_video_metadata(file_path: str) -> Dict:
    """Runs ffprobe to extract metadata JSON."""
    cmd = [
        "ffprobe",
        "-v",
        "quiet",
        "-print_format",
        "json",
        "-show_streams",
        "-show_format",
        file_path,
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        data = json.loads(result.stdout)

        video_stream = next(
            (s for s in data.get("streams", []) if s.get("codec_type") == "video"), None
        )
        if not video_stream:
            return {"success": False, "error": "No video stream found"}

        # Extract basic info
        width = int(video_stream.get("width", 0))
        height = int(video_stream.get("height", 0))

        # FPS calculation
        fps_str = video_stream.get("r_frame_rate", "0/1")
        num, den = map(int, fps_str.split("/"))
        fps = num / den if den != 0 else 0.0

        # Rotation
        rotation = 0
        if "tags" in video_stream and "rotate" in video_stream["tags"]:
            try:
                rotation = int(video_stream["tags"]["rotate"])
            except ValueError:
                pass

        # Device Metadata from container tags
        tags = data.get("format", {}).get("tags", {})
        norm_tags = {k.lower(): v for k, v in tags.items()}

        make = norm_tags.get("make") or norm_tags.get("com.apple.quicktime.make")
        model = norm_tags.get("model") or norm_tags.get("com.apple.quicktime.model")

        # Check for camera/GPS indicators
        has_camera = any(k in str(tags).lower() for k in ["camera", "lens", "focal", "iso"])
        has_gps = any(k in str(tags).lower() for k in ["location", "gps", "coordinates"])

        return {
            "success": True,
            "width": width,
            "height": height,
            "fps": fps,
            "rotation": rotation,
            "make": make,
            "model": model,
            "has_camera": has_camera,
            "has_gps": has_gps,
        }

    except FileNotFoundError:
        return {"success": False, "error": "ffprobe not found. Install FFmpeg."}
    except Exception as e:
        return {"success": False, "error": str(e)}


# ============================================================================
# PRIVATE ALIASES (For backward compatibility)
# ============================================================================

# Keep these for any code that uses the old private function names
_classify_resolution = classify_resolution
_classify_framerate = classify_framerate
_get_orientation = classify_orientation
_apply_rotation = apply_rotation_correction


# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1:
        # Analyze a video file
        result = classify_video(sys.argv[1])
        print(json.dumps(result, indent=4))
    else:
        # Show usage and run examples
        print("Usage: PYTHONPATH=src python -m Libra.video_tools.core.classifier <video_path>\n")
        print("=" * 60)
        print("CLASSIFICATION EXAMPLES")
        print("=" * 60)

        examples = [
            (3840, 2160, 60.0, 0, "4K Landscape 60fps"),
            (1080, 1920, 29.97, 0, "1080p Portrait 30fps"),
            (1920, 1080, 60.0, 90, "1080p with 90° rotation"),
            (640, 480, 30.0, 0, "SD video"),
            (1440, 1080, 30.0, 0, "HD in-between resolution"),
            (1280, 720, 59.94, 0, "720p 60fps"),
        ]

        for width, height, fps, rotation, desc in examples:
            result = classify_video_properties(width, height, fps, rotation)
            print(f"\n{desc}:")
            print(f"  Input: {width}x{height} @ {fps}fps (rotation: {rotation}°)")
            print(f"  → Resolution: {result['resolution']}")
            print(f"  → Orientation: {result['orientation']}")
            print(f"  → Framerate: {result['framerate_category']}")

        print("\n" + "=" * 60)
        print("FOLDER STRUCTURES")
        print("=" * 60)

        for mode in ["VidRes", "ProMax", "MaxVid"]:
            folders = generate_folder_structure(mode)
            print(f"\n{mode} mode ({len(folders)} folders):")
            for f in folders[:6]:
                print(f"  {f}")
            if len(folders) > 6:
                print(f"  ... and {len(folders) - 6} more")

        print("\n" + "=" * 60)
        print("FILENAME EXAMPLES")
        print("=" * 60)

        print(f"\n  {generate_filename('4K', 'W', 60, 42)}")
        print(f"  {generate_filename('1080p', 'V', 30, 1, prefix='My Video')}")
        print(f"  {generate_filename('720p', 'W', 60, 99, emoji_indicators='📱🌍📷')}")
