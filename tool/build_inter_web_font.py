#!/usr/bin/env python3
"""Reproduce the web-only Inter face; requires fonttools==4.60.1."""
import hashlib
from pathlib import Path

import fontTools
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import OverlapMode, instantiateVariableFont

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "ios/Runner/Fonts/Inter-Variable.ttf"
OUTPUT = SOURCE.with_name("Inter-Regular.ttf")
SOURCE_SHA256 = "29160a80ff49ddcab2c97711247e08b1fab27a484a329ce8b813d820dc559031"


def main():
    if fontTools.__version__ != "4.60.1":
        raise SystemExit("Use fonttools==4.60.1 for reproducible font output")
    if hashlib.sha256(SOURCE.read_bytes()).hexdigest() != SOURCE_SHA256:
        raise SystemExit("Inter source differs from the reviewed reference")
    source = TTFont(SOURCE, recalcTimestamp=False)
    result = instantiateVariableFont(
        source,
        {"opsz": 14, "wght": 400},
        optimize=False,
        overlap=OverlapMode.KEEP_AND_DONT_SET_FLAGS,
    )
    if result["glyf"].compile(result) != source["glyf"].compile(source):
        raise SystemExit("Default glyph outlines or flags changed")
    if result["hmtx"].metrics != source["hmtx"].metrics:
        raise SystemExit("Default advance widths changed")
    if result.getBestCmap() != source.getBestCmap():
        raise SystemExit("Unicode coverage changed")
    result.save(OUTPUT)
    print(hashlib.sha256(OUTPUT.read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
