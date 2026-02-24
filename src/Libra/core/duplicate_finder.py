import hashlib
from pathlib import Path


class DuplicateFinder:
    """Detects duplicate files using file size and a partial SHA-256 hash."""

    def __init__(self):
        # Maps "{size}_{hash}" -> file_path
        self._file_hashes: dict[str, Path] = {}

    def is_duplicate(self, file_path: Path) -> bool:
        """Returns True if the file is a duplicate of a previously checked file."""
        if not file_path.is_file():
            return False

        try:
            file_size = file_path.stat().st_size
        except OSError:
            return False

        partial_hash = self._compute_partial_hash(file_path)
        if not partial_hash:
            return False

        file_key = f"{file_size}_{partial_hash}"

        if file_key in self._file_hashes:
            return True
        else:
            self._file_hashes[file_key] = file_path
            return False

    @staticmethod
    def _compute_partial_hash(file_path: Path, chunk_size: int = 1048576) -> str:
        """Computes SHA-256 of the first chunk of the file."""
        sha256 = hashlib.sha256()
        try:
            with open(file_path, "rb") as f:
                chunk = f.read(chunk_size)
                if chunk:
                    sha256.update(chunk)
                    return sha256.hexdigest()
        except OSError:
            pass
        return ""

    def get_original(self, file_path: Path) -> Path:
        """Returns the path to the original file that this file duplicates."""
        if not file_path.is_file():
            return file_path

        try:
            file_size = file_path.stat().st_size
        except OSError:
            return file_path

        partial_hash = self._compute_partial_hash(file_path)
        file_key = f"{file_size}_{partial_hash}"

        return self._file_hashes.get(file_key, file_path)
