"""Pytest configuration for L!bra tests."""

import os
import sys
import tempfile
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
SRC_PATH = PROJECT_ROOT / "src"
if str(SRC_PATH) not in sys.path:
    sys.path.insert(0, str(SRC_PATH))

os.environ.setdefault(
    "HYPOTHESIS_STORAGE_DIRECTORY",
    str(Path(tempfile.gettempdir()) / "hypothesis-examples"),
)

try:
    from hypothesis import settings
except ModuleNotFoundError:
    settings = None


# Disable Hypothesis example DB writes to avoid creating local .hypothesis/
if settings is not None:
    settings.register_profile("no_local_db", database=None)
    settings.load_profile("no_local_db")
