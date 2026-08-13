#!/usr/bin/env python3
"""Build AppIcon.icns from Libra.png on the standard 824x824 macOS icon grid.

Libra.png is a 1024x1024 RGBA export whose squircle body sits off-grid at
~779x777. This rescales the artwork (including its baked shadow) so the solid
body lands at 824x824 centred at (100,100) — matching 4Charm / Looper /
MetaBurn / Nexus / Rusty. The existing colours and shadow are preserved;
nothing is re-graded.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Libra.png"
ICNS_OUT = ROOT / "Sources/Libra/Resources/AppIcon.icns"

CANVAS = 1024
BODY = 824  # Apple's macOS grid: an 824x824 body inside a 1024 canvas.
MARGIN = (CANVAS - BODY) // 2  # 100


def find_bbox(im: Image.Image, threshold: int) -> tuple[int, int, int, int]:
    """Bounding box of pixels with alpha above ``threshold``."""
    w, h = im.size
    px = im.load()
    minx, miny, maxx, maxy = w, h, 0, 0
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > threshold:
                minx = min(minx, x)
                miny = min(miny, y)
                maxx = max(maxx, x)
                maxy = max(maxy, y)
    if maxx < minx:
        raise ValueError("icon artwork is empty")
    return minx, miny, maxx, maxy


def master_from_source(path: Path) -> Image.Image:
    src = Image.open(path).convert("RGBA")

    # Solid body (alpha>200) — what must hit the 824x824 grid.
    bx0, by0, bx1, by1 = find_bbox(src, 200)
    body_w = bx1 - bx0 + 1

    # Full alpha extent (alpha>0) — includes the baked shadow.
    ax0, ay0, ax1, ay1 = find_bbox(src, 0)
    crop = src.crop((ax0, ay0, ax1 + 1, ay1 + 1))

    # Scale so the solid body width becomes 824 (uniform — no distortion).
    scale = BODY / body_w
    new_w = max(1, int(crop.width * scale))
    new_h = max(1, int(crop.height * scale))
    scaled = crop.resize((new_w, new_h), Image.Resampling.LANCZOS)

    # Offset from crop origin to solid body, after scaling.
    body_offset_x = (bx0 - ax0) * scale
    body_offset_y = (by0 - ay0) * scale

    # Paste so the solid body lands at (MARGIN, MARGIN).
    paste_x = round(MARGIN - body_offset_x)
    paste_y = round(MARGIN - body_offset_y)

    master = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    master.paste(scaled, (paste_x, paste_y), scaled)
    return master


def write_png(img: Image.Image, size: int, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    out = img if img.width == size else img.resize((size, size), Image.Resampling.LANCZOS)
    out.save(path, optimize=True)


def main() -> int:
    if not SOURCE.exists():
        raise SystemExit(f"Missing {SOURCE}")

    master = master_from_source(SOURCE)

    iconset = Path("/tmp/Libra.iconset")
    iconset.mkdir(parents=True, exist_ok=True)
    for name, px in {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }.items():
        write_png(master, px, iconset / name)

    ICNS_OUT.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(ICNS_OUT)], check=True)
    print(f"Icon written: {ICNS_OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
