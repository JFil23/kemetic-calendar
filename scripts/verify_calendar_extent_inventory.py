#!/usr/bin/env python3
"""Fail closed when an extent-owning source fragment changes without re-audit."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


MOBILE_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST = MOBILE_ROOT / "docs/calendar_extent_inventory_manifest.json"


class InventoryError(ValueError):
    pass


def _mapping(value: Any, context: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise InventoryError(f"{context} must be an object")
    return value


def _extract(entry: dict[str, Any], context: str) -> str:
    relative_path = entry.get("file")
    if not isinstance(relative_path, str) or not relative_path:
        raise InventoryError(f"{context}.file must be a path")
    path = MOBILE_ROOT / relative_path
    source = path.read_text(encoding="utf-8")
    start = entry.get("start")
    end = entry.get("end")
    if start is not None:
        if not isinstance(start, str) or not start:
            raise InventoryError(f"{context}.start must be a non-empty string")
        if source.count(start) != 1:
            raise InventoryError(
                f"{context}.start must occur exactly once in {relative_path}"
            )
        source = source[source.index(start) :]
    if end is not None:
        if not isinstance(end, str) or not end:
            raise InventoryError(f"{context}.end must be a non-empty string")
        if source.count(end) != 1:
            raise InventoryError(
                f"{context}.end must occur exactly once after start in {relative_path}"
            )
        source = source[: source.index(end)]
    return source


def current_hashes(manifest: dict[str, Any]) -> dict[str, str]:
    fragments = manifest.get("fragments")
    if not isinstance(fragments, list) or not fragments:
        raise InventoryError("manifest.fragments must be a non-empty array")
    result: dict[str, str] = {}
    for index, raw_entry in enumerate(fragments):
        entry = _mapping(raw_entry, f"manifest.fragments[{index}]")
        name = entry.get("name")
        if not isinstance(name, str) or not name:
            raise InventoryError(f"manifest.fragments[{index}].name is invalid")
        if name in result:
            raise InventoryError(f"duplicate fragment name: {name}")
        fragment = _extract(entry, f"manifest.fragments[{index}]")
        result[name] = hashlib.sha256(fragment.encode("utf-8")).hexdigest()
    return result


def verify(manifest: dict[str, Any]) -> list[str]:
    if manifest.get("schema") != 1:
        raise InventoryError("manifest.schema must be 1")
    expected = {}
    fragments = manifest["fragments"]
    for index, raw_entry in enumerate(fragments):
        entry = _mapping(raw_entry, f"manifest.fragments[{index}]")
        name = entry.get("name")
        digest = entry.get("sha256")
        if not isinstance(digest, str) or len(digest) != 64:
            raise InventoryError(f"manifest.fragments[{index}].sha256 is invalid")
        expected[name] = digest
    current = current_hashes(manifest)
    return [
        f"{name}: expected {expected[name]}, found {digest}"
        for name, digest in current.items()
        if expected.get(name) != digest
    ]


def load_manifest(path: Path) -> dict[str, Any]:
    return _mapping(json.loads(path.read_text(encoding="utf-8")), str(path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--print-current", action="store_true")
    args = parser.parse_args()

    manifest = load_manifest(args.manifest)
    if args.print_current:
        print(json.dumps(current_hashes(manifest), indent=2))
        return 0
    mismatches = verify(manifest)
    if mismatches:
        print("Calendar extent inventory is stale:")
        for mismatch in mismatches:
            print(f"- {mismatch}")
        print("Re-audit the closed contributor list before updating hashes.")
        return 1
    print("Calendar extent inventory matches its audited source fragments.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
