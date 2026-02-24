"""Unified launcher for Libra video tools."""

from __future__ import annotations

import argparse

from .cli.batch_processor import process_folder


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="python -m Libra.video_tools")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("sorter", help="Launch the metadata video sorter GUI")
    sub.add_parser("duplicates", help="Launch the duplicate finder GUI")
    sub.add_parser("apple", help="Launch the Apple organizer GUI")

    batch = sub.add_parser("batch", help="Run headless batch video analysis")
    batch.add_argument("folder", help="Folder path containing videos")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    if args.command == "sorter":
        from .gui.video_sorter import main as run_sorter

        return run_sorter()
    if args.command == "duplicates":
        from .gui.duplicate_finder import main as run_duplicates

        return run_duplicates()
    if args.command == "apple":
        from .gui.apple_organizer import main as run_apple

        return run_apple()

    process_folder(args.folder)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
