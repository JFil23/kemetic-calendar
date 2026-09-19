#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import json
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
CONTRACT_PATH = (
    REPO_ROOT
    / "test/visual_reference/maat_flows/day_view_contract.v1.json"
)
MANIFEST_PATH = (
    REPO_ROOT
    / "test/visual_reference/maat_flows/evidence/manifest.json"
)


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class MaatVisualContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contract = load_json(CONTRACT_PATH)
        cls.manifest = load_json(MANIFEST_PATH)

    def test_five_flow_extents_are_explicit(self) -> None:
        flows = {
            item["id"]: item["initial_extent"]
            for item in self.contract["flows"]
        }
        self.assertEqual(
            flows,
            {
                "follow_sky": 0.58,
                "offering_table": 0.71,
                "reading_house": 0.58,
                "djed": 0.58,
                "kar": 0.71,
            },
        )

    def test_frozen_authority_bytes_match_contract(self) -> None:
        for flow in self.contract["flows"]:
            for authority in flow["authority"]["files"]:
                with self.subTest(flow=flow["id"], path=authority["path"]):
                    path = REPO_ROOT / authority["path"]
                    self.assertTrue(path.is_file(), f"missing authority: {path}")
                    self.assertEqual(sha256(path), authority["sha256"])

    def test_manifest_and_tracked_golden_inventory_are_identical(self) -> None:
        registered = {
            item["golden"] for item in self.manifest["pairs"]
        } | {
            item["golden"]
            for item in self.manifest["supplemental_product_states"]
        }
        root = Path(self.contract["platform_directories"][0])
        tracked = {
            path.name for path in (REPO_ROOT / root).glob("*.png")
        }
        self.assertEqual(registered, tracked)

    def test_every_platform_has_the_complete_registered_inventory(self) -> None:
        manifest_names = {
            item["golden"] for item in self.manifest["pairs"]
        } | {
            item["golden"]
            for item in self.manifest["supplemental_product_states"]
        }
        for relative in self.contract["platform_directories"]:
            with self.subTest(platform=relative):
                directory = REPO_ROOT / relative
                actual = {path.name for path in directory.glob("*.png")}
                self.assertEqual(actual, manifest_names)

    def test_each_flow_registers_lowered_and_raised_housing(self) -> None:
        registered = {
            item["golden"] for item in self.manifest["pairs"]
        } | {
            item["golden"]
            for item in self.manifest["supplemental_product_states"]
        }
        for flow in self.contract["flows"]:
            with self.subTest(flow=flow["id"]):
                required = set(flow["required_housing_goldens"])
                self.assertEqual(len(required), 2)
                self.assertLessEqual(required, registered)


if __name__ == "__main__":
    unittest.main()
