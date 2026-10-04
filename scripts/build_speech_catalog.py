#!/usr/bin/env python3
"""Validate the complete local corpus and generate its Dart asset lookup.

No network, credentials, synthesis, or pronunciation substitutions. The manifest
records the app catalog and generation provenance; re-audition changed audio.
"""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT / "config/speech_library.v1.json").read_text())
phrases = manifest["phrases"]
assets = manifest["asset_sha256"]
assert len(phrases) == 84
assert len({p["id"] for p in phrases}) == 84
expected = {f"speech/library/{voice}/{p['id']}.m4a"
            for voice in ("G", "H") for p in phrases}
expected.update(f"speech/previews/{voice}.mp3" for voice in ("G", "H"))
assert set(assets) == expected, "Incomplete or unexpected speech assets"
for asset, digest in assets.items():
    data = (ROOT / "assets" / asset).read_bytes()
    assert data and hashlib.sha256(data).hexdigest() == digest, asset

def dart(value):
    return json.dumps(value, ensure_ascii=False).replace("$", "\\$")

lines = ["// Generated from config/speech_library.v1.json after checksum verification.",
         "// Regenerate with scripts/build_speech_catalog.py.",
         "const speechClipIds = <String, String>{"]
lines += [f"  {dart(p['text'])}: {dart(p['id'])}," for p in phrases]
lines += ["};", "const speechAssetDigests = <String, String>{"]
lines += [f"  {dart(path)}: {dart(digest)}," for path, digest in sorted(assets.items())]
lines += ["};", ""]
(ROOT / "lib/services/speech/speech_catalog.g.dart").write_text("\n".join(lines))
print(f"Verified {len(phrases)} phrases per voice and {len(assets)} audio assets.")
