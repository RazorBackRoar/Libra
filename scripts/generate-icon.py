#!/usr/bin/env python3
"""Build AppIcon.icns from Libra.png on the standard 844x844 macOS icon grid."""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Libra.png"
ICNS_OUT = ROOT / "Sources/Libra/Resources/AppIcon.icns"
ICNS_ROOT = ROOT / "Libra.icns"

def main() -> int:
    if not SOURCE.exists():
        raise SystemExit(f"Missing {SOURCE}")

    master = Image.open(SOURCE).convert("RGBA")
    
    iconset_dir = tempfile.mkdtemp(suffix=".iconset")
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    for s in sizes:
        r = master.resize((s, s), Image.Resampling.LANCZOS)
        r.save(os.path.join(iconset_dir, f"icon_{s}x{s}.png"))
        if s <= 512:
            r2 = master.resize((s*2, s*2), Image.Resampling.LANCZOS)
            r2.save(os.path.join(iconset_dir, f"icon_{s}x{s}@2x.png"))

    ICNS_OUT.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", str(ICNS_OUT)], check=True)
    import shutil
    shutil.copy2(str(ICNS_OUT), str(ICNS_ROOT))
    print(f"Icon written: {ICNS_OUT} and {ICNS_ROOT}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
