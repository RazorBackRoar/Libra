#!/usr/bin/env bash
# Create fixtures and run iPhone Sorter verification against Libra core sources.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERIFY_DIR="${TMPDIR:-/tmp}/libra-iphone-verify"
INPUT="$VERIFY_DIR/input"
rm -rf "$VERIFY_DIR"
mkdir -p "$INPUT"

echo "== Creating fixtures in $INPUT =="

python3 - "$INPUT" <<'PY'
from pathlib import Path
import struct, zlib, sys
out = Path(sys.argv[1])

def write_png(path, rgb=(20, 40, 200)):
    w = h = 8
    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)
    raw = b''.join(b'\x00' + bytes(rgb) * w for _ in range(h))
    data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b'')
    Path(path).write_bytes(data)

for name in [
    "photo_both.png",
    "photo_apple_only.png",
    "photo_iphone_only.png",
    "photo_samsung.png",
    "photo_nometa.png",
    "photo_dup_a.png",
    "photo_dup_b.png",
]:
    write_png(out / name)
print("wrote png fixtures")
PY

ffmpeg -y -f lavfi -i color=c=red:s=64x64:d=0.1 -frames:v 1 "$INPUT/photo_jpeg.jpg" 2>/dev/null

if sips -s format heic "$INPUT/photo_jpeg.jpg" --out "$INPUT/photo_heic.heic" >/dev/null 2>&1; then
  echo "created HEIC via sips"
else
  cp "$INPUT/photo_jpeg.jpg" "$INPUT/photo_heic.heic"
  echo "HEIC fallback: jpeg bytes with .heic extension"
fi

ffmpeg -y -f lavfi -i color=c=blue:s=320x240:d=0.5 -c:v libx264 -pix_fmt yuv420p -t 0.5 "$INPUT/clip.mov" 2>/dev/null
echo "not media" > "$INPUT/readme.txt"
cp "$INPUT/photo_jpeg.jpg" "$INPUT/photo.jpg"

# Metadata cases
exiftool -overwrite_original -Make="Apple" -Model="iPhone 16 Pro Max" "$INPUT/photo_both.png" >/dev/null
exiftool -overwrite_original -Make="Apple" -Model= "$INPUT/photo_apple_only.png" >/dev/null
exiftool -overwrite_original -Make= -Model="iPhone 15" "$INPUT/photo_iphone_only.png" >/dev/null
exiftool -overwrite_original -Make="Samsung" -Model="Galaxy S24" "$INPUT/photo_samsung.png" >/dev/null
exiftool -overwrite_original -Make= -Model= "$INPUT/photo_nometa.png" >/dev/null
exiftool -overwrite_original -Make="Apple" -Model="iPhone 14" "$INPUT/photo_dup_a.png" >/dev/null
exiftool -overwrite_original -Make="Apple" -Model="iPhone 14" "$INPUT/photo_dup_b.png" >/dev/null
exiftool -overwrite_original -Make="Apple" -Model="iPhone 13" "$INPUT/photo.jpg" >/dev/null
exiftool -overwrite_original -Make="Apple" -Model="iPhone 12" "$INPUT/photo_heic.heic" >/dev/null
exiftool -overwrite_original -Make="Apple" -Model="iPhone 11" "$INPUT/clip.mov" >/dev/null
exiftool -overwrite_original -Make="Apple" -Model="iPhone SE" "$INPUT/photo_jpeg.jpg" >/dev/null

# Corrupt / unreadable metadata simulation: empty file with image extension
: > "$INPUT/photo_corrupt.png"

# Pre-existing destination collision for photo.jpg style output
mkdir -p "$INPUT/iPhone"
# Exact collision name depends on sort order; seed common pattern after we know pad — touch placeholder
touch "$INPUT/iPhone/collision-placeholder.txt"

UNRELATED="$VERIFY_DIR/unrelated_keep_me.txt"
echo "leave me" > "$UNRELATED"

echo "== Compiling verifier =="
BIN="$VERIFY_DIR/iphone_verify"
swiftc -O -o "$BIN" \
  -framework ImageIO \
  "$ROOT/Sources/Libra/Models.swift" \
  "$ROOT/Sources/Libra/Services/ProcessRunner.swift" \
  "$ROOT/Sources/Libra/Services/FileOps.swift" \
  "$ROOT/Sources/Libra/Services/FileNaming.swift" \
  "$ROOT/Sources/Libra/Services/MediaProbe.swift" \
  "$ROOT/Sources/Libra/Services/IPhoneSortLogic.swift" \
  "$ROOT/scripts/iphone_verify_main.swift"

echo "== Running verifier =="
"$BIN" "$VERIFY_DIR"

echo "== Unrelated file intact? =="
if [[ -f "$UNRELATED" ]] && grep -q "leave me" "$UNRELATED"; then
  echo "PASS unrelated untouched"
else
  echo "FAIL unrelated touched"
  exit 1
fi

echo "== Mode enum order check =="
python3 - "$ROOT/Sources/Libra/Models.swift" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
block = re.search(r'enum Tool:.*?\n\}', text, re.S).group(0)
cases = re.findall(r'case (\w+)', block)
expected = ['provid','vidres','keepName','promax','maxvid','iphoneSorter','slomo','oneMin','gps']
assert cases == expected, (cases, expected)
for f in ['organizer','reencode','duplicates','codec']:
    assert f not in cases, f
assert 'enum SortMode' not in text
print('PASS tool order', cases)
PY

echo "== Assert key destinations =="
python3 - "$INPUT" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
iphone = list((root / "iPhone").glob("*")) if (root / "iPhone").exists() else []
not_iphone = list((root / "Not iPhone").glob("*")) if (root / "Not iPhone").exists() else []
print("iPhone files:")
for p in sorted(iphone):
    print(" ", p.name)
print("Not iPhone files:")
for p in sorted(not_iphone):
    print(" ", p.name)

names_i = {p.name for p in iphone}
names_n = {p.name for p in not_iphone}

def has_marker(marker):
    return any(marker in n for n in names_i)

assert any("🍎📱" in n for n in names_i), names_i
assert any(n.endswith(".mov") or ".mov" in n for n in names_i) or any(n.endswith(".mov") for n in names_i)
assert any("samsung" in n.lower() or "Galaxy" in n or n.startswith("photo_samsung") for n in names_n), names_n
assert any(n.startswith("photo_samsung") for n in names_n), names_n
assert any(n.startswith("photo_nometa") for n in names_n), names_n
assert (root / "readme.txt").exists(), "unsupported readme should remain unmoved"
assert not any(n == "readme.txt" for n in names_n), names_n
print("PASS destination assertions")
PY

echo "== Tree =="
find "$INPUT" -type f | sort
echo "== Done. Artifacts at $VERIFY_DIR =="
