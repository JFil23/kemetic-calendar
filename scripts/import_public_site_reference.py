#!/usr/bin/env python3
"""Import the approved interactive website without changing its design or demos.

Data URLs become byte-identical local assets and the film loads directly.
An explicit film replacement changes only its source and duration labels; the
original media remain immutable so the complete reference can still be restored.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import math
import re
import subprocess
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
FILM_STATUS_NOTE = '<span>Work in progress · voice-over to come</span>'
FILM_STATUS_STYLE = '.film-caption span:last-child{color:#a28f74}'


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


def film_labels(duration: float) -> tuple[str, str]:
    if not math.isfinite(duration) or duration <= 0:
        raise ValueError("Film duration must be a positive, finite number.")
    minutes, seconds = divmod(round(duration), 60)
    return f"{minutes:02d}:{seconds:02d}", f"{minutes} minutes {seconds} seconds"


def replace_film(document: bytes, assets: dict[str, bytes], manifest: dict,
                 film: bytes, filename: str, duration: float) -> tuple[bytes, dict[str, bytes], dict]:
    originals = [name for name, meta in manifest["assets"].items() if meta["content_type"] == "video/mp4"]
    if len(originals) != 1 or "film_replacement" in manifest:
        raise ValueError("Apply a film replacement to the immutable reference import.")
    original = originals[0]
    name = f"assets/{digest(film)}.mp4"
    label, aria = film_labels(duration)
    text = document.decode()
    for before, after in [(f'filmUrl="/{original}"', f'filmUrl="/{name}"'),
                          ('WATCH THE FILM &nbsp; 02:20', f'WATCH THE FILM &nbsp; {label}'),
                          ('Play the film, 2 minutes 20 seconds', f'Play the film, {aria}')]:
        if text.count(before) != 1:
            raise ValueError("Film replacement no longer matches the approved page boundary.")
        text = text.replace(before, after, 1)
    assets[name] = film
    manifest["assets"][name] = {"bytes": len(film), "sha256": digest(film), "content_type": "video/mp4"}
    manifest["film_replacement"] = {"reference_asset": original, "asset": name,
                                    "source_filename": Path(filename).name, "duration_seconds": duration}
    document = text.encode()
    manifest["index_sha256"] = digest(document)
    return document, assets, manifest


def reconstruct(document: bytes, assets: dict[str, bytes], manifest: dict) -> bytes:
    """Restore the original document for an exact, independent parity assertion."""
    text = document.decode().replace(VERIFICATION_META, "", 1)
    if manifest.get("film_status_note_removed"):
        text = re.sub(r'(<div class="film-caption">.*?)(</div>)',
                      lambda m: m[1] + FILM_STATUS_NOTE + m[2], text, count=1, flags=re.S)
        text = re.sub(r'(\.film-caption\{[^}]+\})',
                      lambda m: m[1] + FILM_STATUS_STYLE, text, count=1)
    replacement = manifest.get("film_replacement")
    if replacement:
        label, aria = film_labels(replacement["duration_seconds"])
        text = text.replace(f'filmUrl="/{replacement["asset"]}"',
                            f'filmUrl="/{replacement["reference_asset"]}"', 1)
        text = text.replace(f'WATCH THE FILM &nbsp; {label}', 'WATCH THE FILM &nbsp; 02:20', 1)
        text = text.replace(f'Play the film, {aria}', 'Play the film, 2 minutes 20 seconds', 1)
    for name, meta in manifest["assets"].items():
        if replacement and name == replacement["asset"]:
            continue
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


def remove_film_status_note(document: bytes, manifest: dict) -> bytes:
    text = document.decode()
    for original in (FILM_STATUS_NOTE, FILM_STATUS_STYLE):
        if text.count(original) != 1:
            raise ValueError("Film status note differs from the approved reference.")
        text = text.replace(original, "", 1)
    document = text.encode()
    manifest["film_status_note_removed"] = True
    manifest["index_sha256"] = digest(document)
    return document


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reference", type=Path)
    parser.add_argument("--film", type=Path, help="Use an approved replacement MP4 without re-encoding it.")
    parser.add_argument("--remove-film-status-note", action="store_true",
                        help="Remove the obsolete work-in-progress/voice-over caption.")
    args = parser.parse_args()
    document, assets, manifest = prepare(args.reference.read_bytes())
    if args.film:
        probe = json.loads(subprocess.check_output([
            "ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "json", str(args.film)]))
        document, assets, manifest = replace_film(document, assets, manifest, args.film.read_bytes(),
                                                 args.film.name, float(probe["format"]["duration"]))
    if args.remove_film_status_note:
        document = remove_film_status_note(document, manifest)
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
