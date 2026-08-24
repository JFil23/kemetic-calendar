#!/usr/bin/env python3
"""Extract the V11 Follow the Sky hero PNG embedded in the HTML mockup."""

from __future__ import annotations

import base64
import os
import re
import sys
from pathlib import Path


def extract(html_path: Path, out_path: Path) -> bool:
    html = html_path.read_bytes()
    match = re.search(
        rb"data:image/(png|jpeg|webp);base64,([A-Za-z0-9+/=\n\r]+)", html
    )
    if not match:
        return False
    raw = base64.b64decode(match.group(2).replace(b"\n", b"").replace(b"\r", b""))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(raw)
    print(f"Wrote {len(raw)} bytes to {out_path}")
    return True


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    out_path = repo_root / "assets" / "follow_the_sky" / "hero.png"
    if len(sys.argv) > 1:
        html_path = Path(sys.argv[1])
    else:
        html_path = Path(
            os.environ.get(
                "FOLLOW_SKY_V11_HTML",
                "follow-the-sky-preview-v11-no-lenses.html",
            )
        )
    if not html_path.is_file():
        print(f"HTML not found: {html_path}", file=sys.stderr)
        return 1
    if not extract(html_path, out_path):
        print("No embedded image found in HTML", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
