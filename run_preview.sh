#!/usr/bin/env zsh
set -euo pipefail

if [[ ! -d ".venv" ]]; then
  python3 -m venv .venv
fi

source .venv/bin/activate

if ! python3 -c "import PySide6" >/dev/null 2>&1; then
  python3 -m pip install --no-user --disable-pip-version-check PySide6
fi

exec python3 main.py
