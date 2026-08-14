#!/usr/bin/env python3
from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import compare_calendar_boundary_benchmarks as benchmark


def artifact(revision: str, *, timing_scale: float = 1.0) -> dict:
    result = {
        "benchmark": "calendar_banner_boundary",
        "revision": revision,
        "platform": "android",
        "repetitions": 3,
        "refresh_rate_hz": 60.0,
        "instrumentation_contract": "timing_only_gates_full_probe_isolation",
    }
    for scenario in benchmark.SCENARIOS:
        for repetition in range(1, 4):
            result[f"performance_{scenario}_r{repetition}"] = {
                "frame_build_times": [
                    round(value * timing_scale)
                    for value in (1000, 2000, 3000, 20000)
                ],
                "frame_rasterizer_times": [
                    round(value * timing_scale)
                    for value in (2000, 3000, 4000, 5000)
                ],
                "new_gen_gc_count": 1,
                "old_gen_gc_count": 0,
            }
            result[f"harness_{scenario}_r{repetition}"] = {
                "idle_frame_count": 0,
                "banner_transition_count": 1,
                "banner_publication_count": 1,
                "collector_scheduled_publication_count": 4,
                "collector_committed_publication_count": 3,
                "restoration_schedule_count": 1,
                "restoration_write_count": 1,
                "hydration_schedule_count": 1,
                "page": {"builds": 0, "layouts": 0, "paints": 2},
                "body": {"builds": 0, "layouts": 1, "paints": 3},
                "banner": {"builds": 1, "layouts": 1, "paints": 1},
                "frame_timings": [
                    {
                        "vsync_start_us": 100000,
                        "build_duration_us": 1000,
                        "raster_duration_us": 2000,
                    },
                    {
                        "vsync_start_us": 110000,
                        "build_duration_us": 2000,
                        "raster_duration_us": 3000,
                    },
                    {
                        "vsync_start_us": 120000,
                        "build_duration_us": 20000,
                        "raster_duration_us": 5000,
                    },
                ],
                "samples": [
                    {
                        "frame_timestamp_us": 500000,
                        "scroll_pixels": 0.0,
                        "body_anchor_viewport_y": 100.0,
                        "banner_year": 2027,
                        "banner_month": 2,
                        "banner_publications": 0,
                        "restoration_schedules": 0,
                        "restoration_writes": 0,
                        "hydration_schedules": 0,
                        "page": {"builds": 0, "layouts": 0, "paints": 0},
                        "body": {"builds": 0, "layouts": 0, "paints": 0},
                        "banner": {"builds": 0, "layouts": 0, "paints": 0},
                    },
                    {
                        "frame_timestamp_us": 510000,
                        "scroll_pixels": 10.0,
                        "body_anchor_viewport_y": 90.0,
                        "banner_year": 2027,
                        "banner_month": 2,
                        "banner_publications": 0,
                        "restoration_schedules": 0,
                        "restoration_writes": 0,
                        "hydration_schedules": 0,
                        "page": {"builds": 0, "layouts": 0, "paints": 1},
                        "body": {"builds": 0, "layouts": 0, "paints": 1},
                        "banner": {"builds": 0, "layouts": 0, "paints": 0},
                    },
                    {
                        "frame_timestamp_us": 520000,
                        "scroll_pixels": 20.0,
                        "body_anchor_viewport_y": 82.0,
                        "banner_year": 2027,
                        "banner_month": 3,
                        "banner_publications": 1,
                        "restoration_schedules": 1,
                        "restoration_writes": 1,
                        "hydration_schedules": 1,
                        "page": {"builds": 0, "layouts": 0, "paints": 2},
                        "body": {"builds": 0, "layouts": 0, "paints": 2},
                        "banner": {"builds": 1, "layouts": 1, "paints": 1},
                    },
                ],
            }
    for scenario in benchmark.TODAY_SCENARIOS:
        for repetition in range(1, 4):
            result[f"performance_today_{scenario}_r{repetition}"] = {
                "frame_build_times": [
                    round(value * timing_scale)
                    for value in (1000, 2000, 3000, 20000)
                ],
                "frame_rasterizer_times": [
                    round(value * timing_scale)
                    for value in (2000, 3000, 4000, 5000)
                ],
                "new_gen_gc_count": 1,
                "old_gen_gc_count": 0,
            }
            trigger = {
                "far_past": "none",
                "near_target": "none",
                "unhydrated_early": "early",
                "unhydrated_late": "late",
            }[scenario]
            result[f"harness_today_{scenario}_r{repetition}"] = {
                "idle_frame_count": 0,
                "banner_transition_count": 2,
                "banner_publication_count": 2,
                "collector_scheduled_publication_count": 4,
                "collector_committed_publication_count": 3,
                "restoration_schedule_count": 1,
                "restoration_write_count": 1,
                "hydration_schedule_count": 1,
                "page": {"builds": 3, "layouts": 1, "paints": 2},
                "body": {"builds": 3, "layouts": 1, "paints": 3},
                "banner": {"builds": 2, "layouts": 2, "paints": 2},
                "frame_timings": [
                    {
                        "vsync_start_us": 100000,
                        "build_duration_us": 1100,
                        "raster_duration_us": 2200,
                    },
                    {
                        "vsync_start_us": 110000,
                        "build_duration_us": 2200,
                        "raster_duration_us": 3300,
                    },
                    {
                        "vsync_start_us": 120000,
                        "build_duration_us": 22000,
                        "raster_duration_us": 5500,
                    },
                ],
                "samples": [],
                "today_hydration_trigger": trigger,
                "today_hydration_trigger_progress": (
                    None if trigger == "none" else (0.25 if trigger == "early" else 0.999)
                ),
                "today_hydration_commit_count": 0 if trigger == "none" else 1,
                "today_start_offset": 100.0,
                "today_initial_target_offset": 1000.0,
                "today_final_target_offset": 1000.0,
                "today_final_scroll_pixels": 1000.0,
                "today_reached_target": True,
                "arrival_tolerance_logical_px": 0.5,
                "arrival_a_to_b_delta_px": 0.0,
                "arrival_b_to_c_delta_px": 0.0,
                "arrival_continuity_passed": True,
                "arrival_samples": [
                    {
                        "label": label,
                        "frame_timestamp_us": 500000 + index * 10000,
                        "scroll_pixels": 1000.0,
                        "target_viewport_y": 300.0,
                        "target_offset": 1000.0,
                    }
                    for index, label in enumerate(("A", "B", "C"))
                ],
            }
    return result


class CalendarBoundaryBenchmarkTest(unittest.TestCase):
    def test_reducer_reports_timing_jank_continuity_and_handoff(self) -> None:
        reduced = benchmark.reduce_artifact(artifact("fd1d6ed"), frame_budget_ms=16.667)
        scenario = reduced["scenarios"]["compact_empty"]

        self.assertEqual(scenario["build"]["p95_ms"], 20.0)
        self.assertEqual(scenario["frame_budget_miss_count"], 1)
        self.assertEqual(scenario["janky_frame_percentage"], 25.0)
        self.assertEqual(scenario["continuity_residual_max_px"], 2.0)
        self.assertEqual(scenario["continuity_residual_over_half_pixel_count"], 1)
        self.assertEqual(scenario["handoff_body_builds"], 0)
        self.assertEqual(scenario["handoff_body_layouts"], 0)
        self.assertEqual(scenario["handoff_body_paints"], 1)
        self.assertEqual(scenario["handoff_banner_builds"], 1)
        self.assertEqual(scenario["handoff_frame_build_max_ms"], 20.0)
        self.assertEqual(scenario["handoff_frame_raster_max_ms"], 5.0)
        self.assertEqual(scenario["handoff_timing_match_error_max_ms"], 0.0)
        self.assertEqual(scenario["handoff_restoration_writes"], 1)
        self.assertEqual(scenario["handoff_hydration_schedules"], 1)

        today = reduced["today_scenarios"]["unhydrated_late"]
        self.assertEqual(today["today_hydration_trigger"], "late")
        self.assertEqual(today["today_hydration_commit_count"], 1)
        self.assertTrue(today["arrival_continuity_passed"])
        self.assertTrue(today["today_reached_target"])
        self.assertEqual(today["arrival_a_to_b_abs_max_px"], 0.0)
        self.assertGreater(
            today["full_probe_observer_effect"]["build_p95_ms_change_percent"],
            0.0,
        )

    def test_comparison_enforces_ten_percent_and_one_jank_caps(self) -> None:
        reference = benchmark.reduce_artifact(
            artifact("fd1d6ed"), frame_budget_ms=16.667
        )
        candidate_artifact = artifact("5ff6600", timing_scale=1.2)
        candidate = benchmark.reduce_artifact(
            candidate_artifact, frame_budget_ms=16.667
        )

        comparison = benchmark.compare_reductions(reference, candidate)

        self.assertFalse(comparison["hard_gate_passed"])
        self.assertTrue(
            any("build_p95_ms_change_percent" in item for item in comparison["hard_regressions"])
        )

    def test_missing_scenario_fails_closed(self) -> None:
        malformed = copy.deepcopy(artifact("broken"))
        del malformed["harness_details_event_heavy_r2"]

        with self.assertRaisesRegex(
            benchmark.BenchmarkFormatError, "harness_details_event_heavy_r2"
        ):
            benchmark.reduce_artifact(malformed, frame_budget_ms=16.667)

    def test_web_artifact_requires_explicit_canvaskit(self) -> None:
        malformed = artifact("web")
        malformed["platform"] = "web"

        with self.assertRaisesRegex(
            benchmark.BenchmarkFormatError,
            "explicitly CanvasKit",
        ):
            benchmark.reduce_artifact(malformed, frame_budget_ms=16.667)


if __name__ == "__main__":
    unittest.main()
