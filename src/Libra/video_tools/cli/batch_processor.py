#!/usr/bin/env python3
"""
batch_processor.py - Batch Video Analysis Tool
A headless script to process videos using the classifier library.
Based on 'Pro Tips' from the Video Duplicate Finder guide (Page 58).
"""

import json
import os

from ..core.classifier import classify_video


def process_folder(video_folder):
    print(f"Scanning folder: {video_folder}...")
    results = []

    # Supported extensions
    valid_exts = {".mp4", ".mov", ".avi", ".mkv", ".m4v", ".mts", ".flv", ".wmv"}

    # Walk through the folder
    for root, _, files in os.walk(video_folder):
        for filename in files:
            if os.path.splitext(filename)[1].lower() in valid_exts:
                filepath = os.path.join(root, filename)
                print(f"Analyzing: {filename}...", end=" ", flush=True)

                result = classify_video(filepath)

                if result["success"]:
                    print("✅")
                    results.append(result)
                else:
                    print(f"❌ ({result.get('error')})")

    # Filter results (Example: Apple videos)
    apple_videos = [r for r in results if r["make"] == "Apple"]
    camera_videos = [r for r in results if r["has_camera"]]
    gps_videos = [r for r in results if r["has_gps"]]

    print("\n" + "=" * 40)
    print(f"Total Videos Processed: {len(results)}")
    print(f"Apple Devices: {len(apple_videos)}")
    print(f"With Camera Data: {len(camera_videos)}")
    print(f"With GPS Data: {len(gps_videos)}")
    print("=" * 40)

    # Save full report
    with open("batch_analysis_report.json", "w") as f:
        json.dump(results, f, indent=4)
    print("\nFull report saved to 'batch_analysis_report.json'")


if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1:
        process_folder(sys.argv[1])
    else:
        print(
            "Usage: PYTHONPATH=src python -m Libra.video_tools.cli.batch_processor <path_to_video_folder>"
        )
