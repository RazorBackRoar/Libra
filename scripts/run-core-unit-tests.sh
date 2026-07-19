#!/usr/bin/env bash
# Compile and run deterministic unit checks for Libra core logic (no XCTest).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${TMPDIR:-/tmp}/libra-core-unit-verify"

echo "== Compiling core unit verifier =="
swiftc -O -o "$BIN" \
  -framework ImageIO \
  "$ROOT/Sources/Libra/Models.swift" \
  "$ROOT/Sources/Libra/Services/ProcessRunner.swift" \
  "$ROOT/Sources/Libra/Services/FileOps.swift" \
  "$ROOT/Sources/Libra/Services/FileNaming.swift" \
  "$ROOT/Sources/Libra/Services/IPhoneSortLogic.swift" \
  "$ROOT/Sources/Libra/Services/MediaProbe.swift" \
  "$ROOT/scripts/core_unit_verify_main.swift"

echo "== Running core unit verifier =="
"$BIN"
echo "== Core unit tests complete =="
