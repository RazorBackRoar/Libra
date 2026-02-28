"""Root launcher for fast local preview runs."""

import sys
from pathlib import Path


def run() -> int:
    """Load and execute the app entry point."""
    src_dir = Path(__file__).resolve().parent / "src"
    if str(src_dir) not in sys.path:
        sys.path.insert(0, str(src_dir))
    from Libra.main import main as libra_main

    return libra_main()

if __name__ == "__main__":
    raise SystemExit(run())
