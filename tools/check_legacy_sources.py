#!/usr/bin/env python3
"""Read-only audit against the original public repository snapshot."""
import hashlib, json, sys
from pathlib import Path
repo = Path(__file__).resolve().parents[1]
manifest = json.loads((repo / 'docs' / 'legacy_source_sha256.json').read_text())
ok = True
for name, digest in manifest.items():
    path = repo / name
    actual = hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None
    same = (actual == digest)
    print(('OK' if same else 'DIFF'), name)
    ok &= same
if not ok:
    print('Files differ from original public snapshot. Inspect before proceeding.')
    sys.exit(1)
print('Original memristor/AdLIF sources match the historical baseline.')
