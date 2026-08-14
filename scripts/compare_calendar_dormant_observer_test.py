#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import compare_calendar_boundary_benchmarks as boundary
import compare_calendar_dormant_observer as observer


def _artifact(revision: str, scale: float = 1.0) -> dict:
    value = {
        "benchmark": "calendar_dormant_observer",
        "revision": revision,
        "platform": "android",
        "repetitions": 3,
        "refresh_rate_hz": 60.0,
        "device_pixel_ratio": 2.0,
        "physical_width": 780.0,
        "physical_height": 1688.0,
        "benchmark_define_enabled": False,
    }
    for repetition in range(1, 4):
        value[f"performance_dormant_r{repetition}"] = {
            "frame_build_times": [1000 * scale, 2000 * scale, 3000 * scale],
            "frame_rasterizer_times": [2000 * scale, 3000 * scale, 4000 * scale],
        }
    return value


class CalendarDormantObserverTest(unittest.TestCase):
    def _write(self, directory: Path, name: str, value: dict) -> Path:
        path = directory / name
        path.write_text(json.dumps(value), encoding="utf-8")
        return path

    def test_comparison_accepts_equivalent_runs(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            reverted = observer._reduce(
                self._write(directory, "reverted.json", _artifact("reverted")),
                None,
            )
            present = observer._reduce(
                self._write(directory, "present.json", _artifact("present")),
                None,
            )
            comparison = observer._compare(reverted, present)
            self.assertTrue(comparison["observer_check_passed"])

    def test_enabled_benchmark_define_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            malformed = _artifact("enabled")
            malformed["benchmark_define_enabled"] = True
            path = self._write(directory, "enabled.json", malformed)
            with self.assertRaises(boundary.BenchmarkFormatError):
                observer._reduce(path, None)

    def test_comparison_rejects_large_apparent_improvement(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            reverted = observer._reduce(
                self._write(directory, "reverted.json", _artifact("reverted")),
                None,
            )
            present = observer._reduce(
                self._write(
                    directory,
                    "present.json",
                    _artifact("present", scale=0.7),
                ),
                None,
            )
            comparison = observer._compare(reverted, present)
            self.assertFalse(comparison["observer_check_passed"])
            self.assertTrue(
                any(
                    "p95 changed" in problem
                    for problem in comparison["meaningful_observer_effects"]
                )
            )

    def test_web_artifact_requires_explicit_canvaskit(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            malformed = _artifact("web")
            malformed["platform"] = "web"
            path = self._write(directory, "web.json", malformed)
            with self.assertRaisesRegex(
                boundary.BenchmarkFormatError,
                "not explicitly CanvasKit",
            ):
                observer._reduce(path, None)


if __name__ == "__main__":
    unittest.main()
