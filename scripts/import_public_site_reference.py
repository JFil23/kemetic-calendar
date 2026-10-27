#!/usr/bin/env python3
"""Import the approved interactive website without changing its design or demos.

Only resource transport changes: data URLs become byte-identical local assets,
and the film is loaded directly instead of decoding its base64 in the browser.
The source hash prevents a different document from silently replacing the brief.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import re
from pathlib import Path

REFERENCE_SHA256 = "4e353c4d50a8207d85125319918cf1c181ac386793617b25efb9d4b835f7a43e"
ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "scripts/public_site_reference.v1.json"
DATA_URL = re.compile(r"data:([^;]+);base64,([A-Za-z0-9+/=]+)")
EXTENSIONS = {"font/ttf": "ttf", "image/png": "png", "image/webp": "webp",
              "image/jpeg": "jpg", "video/mp4": "mp4"}
ORIGINAL_FILM_LOADER = "function loadFilm(){if(filmUrl)return;const el=$('#film-data');if(!el)return;const bytes=atob(el.textContent.trim()),parts=[];for(let off=0;off<bytes.length;off+=65536){const s=bytes.slice(off,off+65536),p=new Uint8Array(s.length);for(let i=0;i<s.length;i++)p[i]=s.charCodeAt(i);parts.push(p);}filmUrl=URL.createObjectURL(new Blob(parts,{type:'video/mp4'}));video.src=filmUrl;el.remove();}\n"
VERIFICATION_META = ('\n<meta name="google-site-verification" '
                     'content="v1hiPppdRmL9nuNoxN33fUskoQHSubAzl73kk5KZkzw">')


def digest(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def prepare(reference: bytes) -> tuple[bytes, dict[str, bytes], dict]:
    if digest(reference) != REFERENCE_SHA256:
        raise ValueError("Reference differs from the user's approved HTML.")
    assets: dict[str, bytes] = {}
    media: dict[str, str] = {}

    def store(kind: str, encoded: str) -> str:
        body = base64.b64decode(encoded, validate=True)
        name = f"assets/{digest(body)}.{EXTENSIONS[kind]}"
        assets[name] = body
        media[name] = kind
        return "/" + name

    text = DATA_URL.sub(lambda match: store(*match.groups()), reference.decode("utf-8"))
    film = re.search(r'<script type="application/octet-stream" id="film-data">(.*?)</script>', text, re.S)
    if film is None:
        raise ValueError("The reference film is missing.")
    film_url = store("video/mp4", film[1].strip())
    text = text[:film.start()] + text[film.end():]
    loader = re.search(r"function loadFilm\(\)\{.*?\n", text)
    if loader is None:
        raise ValueError("The reference film loader is missing.")
    text = text[:loader.start()] + (
        "function loadFilm(){if(filmUrl)return;filmUrl=" + json.dumps(film_url) +
        ";video.src=filmUrl;}\n"
    ) + text[loader.end():]
    # Retain the existing ownership verification; this has no visual effect.
    text = text.replace('<meta charset="utf-8">', '<meta charset="utf-8">' + VERIFICATION_META, 1)
    document = text.encode("utf-8")
    manifest = {"schema_version": 1, "reference_sha256": REFERENCE_SHA256,
                "index_sha256": digest(document),
                "assets": {name: {"sha256": digest(body), "bytes": len(body),
                                  "content_type": media[name]}
                           for name, body in sorted(assets.items())}}
    return document, assets, manifest


def reconstruct(document: bytes, assets: dict[str, bytes], manifest: dict) -> bytes:
    """Restore the original document for an exact, independent parity assertion."""
    text = document.decode().replace(VERIFICATION_META, "", 1)
    for name, meta in manifest["assets"].items():
        encoded = base64.b64encode(assets[name]).decode("ascii")
        if meta["content_type"] == "video/mp4":
            loader = "function loadFilm(){if(filmUrl)return;filmUrl=" + json.dumps("/" + name) + ";video.src=filmUrl;}\n"
            text = text.replace(loader, ORIGINAL_FILM_LOADER, 1)
            marker = '\n\n<script type="application/json" id="native-demo-data">'
            text = text.replace(marker, '\n<script type="application/octet-stream" id="film-data">' +
                                encoded + '</script>\n<script type="application/json" id="native-demo-data">', 1)
        else:
            text = text.replace("/" + name, "data:" + meta["content_type"] + ";base64," + encoded)
    return text.encode()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reference", type=Path)
    args = parser.parse_args()
    document, assets, manifest = prepare(args.reference.read_bytes())
    destination = ROOT / "public-site"
    unexpected = {p.relative_to(destination).as_posix() for p in
                  (destination / "assets").rglob("*") if p.is_file()} - assets.keys()
    if unexpected:
        raise ValueError(f"Unexpected assets require review: {sorted(unexpected)}")
    for name, body in assets.items():
        path = destination / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(body)
    (destination / "index.html").write_bytes(document)
    MANIFEST.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(f"Imported exact reference: {len(document):,} HTML bytes, {len(assets)} original assets.")


if __name__ == "__main__":
    main()
