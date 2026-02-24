import subprocess
import json
import hashlib
import os

# --- 1. METADATA ENGINE ---
def get_video_details(filepath):
    """Extracts metadata including Make, Model, and GPS."""
    cmd = [
        'ffprobe', '-v', 'quiet', '-print_format', 'json',
        '-show_format', '-show_streams', filepath
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        data = json.loads(result.stdout)
        
        # Video Stream Info
        stream = next((s for s in data.get('streams', []) if s['codec_type'] == 'video'), None)
        if not stream: return None

        width = int(stream.get('width', 0))
        height = int(stream.get('height', 0))
        
        # Tags (where Make/Model/GPS live)
        tags = data.get('format', {}).get('tags', {})
        # Normalize keys to lowercase for easier searching
        tags_lower = {k.lower(): v for k, v in tags.items()}

        # Extract specific Apple data
        make = tags_lower.get('make') or tags_lower.get('com.apple.quicktime.make') or ""
        model = tags_lower.get('model') or tags_lower.get('com.apple.quicktime.model') or ""
        
        # GPS Detection (Look for coordinates or location keys)
        has_gps = any(k in str(tags).lower() for k in ['location', 'gps', 'coordinates', 'latitude'])

        return {
            'filepath': filepath,
            'filename': os.path.basename(filepath),
            'resolution': f"{width}x{height}",
            'make': make,
            'model': model,
            'has_gps': has_gps,
            'size_mb': round(os.path.getsize(filepath) / (1024 * 1024), 2)
        }
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
        return None

# --- 2. HASHING ENGINE ---
def get_file_hash(filepath):
    """MD5 for exact duplicates."""
    hash_md5 = hashlib.md5()
    try:
        with open(filepath, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_md5.update(chunk)
        return hash_md5.hexdigest()
    except: return None

# --- 3. SIMILARITY ENGINE ---
try:
    from videohash import VideoHash
    def get_visual_hash(filepath):
        try: return VideoHash(path=filepath).hash_hex
        except: return None
except ImportError:
    def get_visual_hash(filepath): return None
