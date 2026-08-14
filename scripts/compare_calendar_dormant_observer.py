#!/usr/bin/env python3
"""Compare harness-present/inactive with the harness-reverted CalendarPage."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from statistics import median
from typing import Any

import compare_calendar_boundary_benchmarks as boundary


def _reduce(path: Path, frame_budget_ms: float | None) -> dict[str, Any]:
    root = boundary.load_artifact(path)
    if root.get("benchmark") != "calendar_dormant_observer":
        raise boundary.BenchmarkFormatError(
            f"{path}: dormant observer benchmark identity is missing or wrong"
        )
    if root.get("benchmark_define_enabled") is not False:
        raise boundary.BenchmarkFormatError(
            f"{path}: CALENDAR_BOUNDARY_BENCHMARK must be false"
        )
    if root.get("platform") == "web" and (
        root.get("web_renderer_use_skia") is not True
        or root.get("web_renderer_use_skwasm") is not False
    ):
        raise boundary.BenchmarkFormatError(
            f"{path}: web observer artifact is not explicitly CanvasKit"
        )
    repetitions = boundary._count(root.get("repetitions"), f"{path}.repetitions")
    if repetitions < 3:
        raise boundary.BenchmarkFormatError(
            f"{path}: at least three repetitions are required"
        )
    refresh_rate_hz = boundary._number(
        root.get("refresh_rate_hz"), f"{path}.refresh_rate_hz"
    )
    budget = frame_budget_ms or (1000.0 / refresh_rate_hz)
    runs = []
    for repetition in range(1, repetitions + 1):
        key = f"performance_dormant_r{repetition}"
        performance = boundary._mapping(root.get(key), f"{path}.{key}")
        runs.append(
            boundary._performance_timing_summary(
                performance,
                context=f"{path}.{key}",
                frame_budget_ms=budget,
            )
        )

    reduced: dict[str, Any] = {
        "benchmark": root.get("benchmark"),
        "revision": root.get("revision"),
        "platform": root.get("platform"),
        "repetitions": repetitions,
        "refresh_rate_hz": refresh_rate_hz,
        "device_pixel_ratio": root.get("device_pixel_ratio"),
        "physical_width": root.get("physical_width"),
        "physical_height": root.get("physical_height"),
        "web_renderer_use_skia": root.get("web_renderer_use_skia"),
        "web_renderer_use_skwasm": root.get("web_renderer_use_skwasm"),
        "frame_budget_ms": budget,
        "runs": runs,
    }
    for thread in ("build", "raster"):
        reduced[thread] = {}
        for metric in ("mean_ms", "p50_ms", "p95_ms", "p99_ms", "max_ms"):
            values = [run[thread][metric] for run in runs]
            reduced[thread][metric] = float(median(values))
            reduced[thread][f"{metric}_range"] = [min(values), max(values)]
    for metric in (
        "frame_budget_miss_count",
        "janky_frame_percentage",
        "frame_count",
    ):
        values = [run[metric] for run in runs]
        reduced[metric] = float(median(values))
        reduced[f"{metric}_range"] = [min(values), max(values)]
    return reduced


def _compare(reverted: dict[str, Any], present: dict[str, Any]) -> dict[str, Any]:
    problems: list[str] = []
    platform_match = reverted["platform"] == present["platform"]
    refresh_rate_match = math.isclose(
        reverted["refresh_rate_hz"], present["refresh_rate_hz"], rel_tol=0.01
    )
    viewport_match = all(
        reverted.get(field) == present.get(field)
        for field in ("device_pixel_ratio", "physical_width", "physical_height")
    )
    if not platform_match:
        problems.append("platforms do not match")
    if not refresh_rate_match:
        problems.append("refresh rates do not match")
    if not viewport_match:
        problems.append("viewports do not match")
    if reverted["repetitions"] != present["repetitions"]:
        problems.append("repetition counts do not match")

    changes: dict[str, float | None] = {}
    for thread in ("build", "raster"):
        for metric in ("mean_ms", "p50_ms", "p95_ms", "p99_ms", "max_ms"):
            key = f"{thread}_{metric}_change_percent"
            changes[key] = boundary._percent_change(
                reverted[thread][metric], present[thread][metric]
            )
        paired_p95_changes = [
            boundary._percent_change(
                reverted_run[thread]["p95_ms"],
                present_run[thread]["p95_ms"],
            )
            for reverted_run, present_run in zip(
                reverted["runs"], present["runs"], strict=False
            )
        ]
        valid_paired_p95_changes = [
            value for value in paired_p95_changes if value is not None
        ]
        paired_p95_change = (
            float(median(valid_paired_p95_changes))
            if valid_paired_p95_changes
            else None
        )
        changes[f"{thread}_paired_p95_ms_change_percent"] = paired_p95_change
        if paired_p95_change is None:
            problems.append(f"{thread} paired p95 change is undefined")
        elif abs(paired_p95_change) > 10.0:
            problems.append(
                f"{thread} paired p95 changed by {paired_p95_change:.2f}%"
            )
        for metric in ("p95_ms", "p99_ms"):
            nonoverlap = (
                present[thread][f"{metric}_range"][0]
                - reverted[thread][f"{metric}_range"][1]
            )
            changes[f"{thread}_{metric}_nonoverlap_ms"] = nonoverlap
            if nonoverlap > 0.5:
                problems.append(
                    f"{thread} {metric} present range is {nonoverlap:.2f} ms "
                    "slower than the reverted range"
                )
    jank_delta = (
        present["janky_frame_percentage"] - reverted["janky_frame_percentage"]
    )
    paired_jank_deltas = [
        present_run["janky_frame_percentage"]
        - reverted_run["janky_frame_percentage"]
        for reverted_run, present_run in zip(
            reverted["runs"], present["runs"], strict=False
        )
    ]
    paired_jank_delta = float(median(paired_jank_deltas))
    if abs(paired_jank_delta) > 1.0:
        problems.append(
            f"paired jank changed by {paired_jank_delta:.2f} percentage points"
        )
    return {
        "platform_match": platform_match,
        "refresh_rate_match": refresh_rate_match,
        "viewport_match": viewport_match,
        **changes,
        "janky_frame_percentage_delta": jank_delta,
        "paired_janky_frame_percentage_delta": paired_jank_delta,
        "meaningful_observer_effects": problems,
        "observer_check_passed": not problems,
    }


def _markdown(
    reverted: dict[str, Any], present: dict[str, Any], comparison: dict[str, Any]
) -> str:
    lines = [
        "# Calendar dormant-harness observer check",
        "",
        f"Harness reverted: `{reverted['revision']}`  ",
        f"Harness present/inactive: `{present['revision']}`  ",
        f"Result: **{'PASS' if comparison['observer_check_passed'] else 'FAIL'}**",
        "",
        "| Metric | Reverted | Present/inactive | Change |",
        "| --- | ---: | ---: | ---: |",
    ]
    for thread in ("build", "raster"):
        for metric in ("p95_ms", "p99_ms"):
            change = comparison[f"{thread}_{metric}_change_percent"]
            change_text = "n/a" if change is None else f"{change:+.2f}%"
            lines.append(
                f"| {thread} {metric} | {reverted[thread][metric]:.3f} ms | "
                f"{present[thread][metric]:.3f} ms | {change_text} |"
            )
    lines.append(
        f"| janky frames | {reverted['janky_frame_percentage']:.2f}% | "
        f"{present['janky_frame_percentage']:.2f}% | "
        f"{comparison['janky_frame_percentage_delta']:+.2f} pp |"
    )
    lines.extend(
        [
            "",
            "Paired-median gate statistics: "
            f"build p95 {comparison['build_paired_p95_ms_change_percent']:+.2f}%, "
            f"raster p95 {comparison['raster_paired_p95_ms_change_percent']:+.2f}%, "
            "jank "
            f"{comparison['paired_janky_frame_percentage_delta']:+.2f} pp.",
        ]
    )
    if comparison["meaningful_observer_effects"]:
        lines.extend(["", "Meaningful observer effects:"])
        lines.extend(
            f"- {problem}"
            for problem in comparison["meaningful_observer_effects"]
        )
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--harness-reverted", type=Path, required=True)
    parser.add_argument("--harness-present", type=Path, required=True)
    parser.add_argument("--json-out", type=Path, required=True)
    parser.add_argument("--markdown-out", type=Path, required=True)
    parser.add_argument("--frame-budget-ms", type=float)
    args = parser.parse_args()

    reverted = _reduce(args.harness_reverted, args.frame_budget_ms)
    present = _reduce(args.harness_present, args.frame_budget_ms)
    comparison = _compare(reverted, present)
    output = {
        "harness_reverted": reverted,
        "harness_present": present,
        "comparison": comparison,
    }
    args.json_out.parent.mkdir(parents=True, exist_ok=True)
    args.markdown_out.parent.mkdir(parents=True, exist_ok=True)
    args.json_out.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    args.markdown_out.write_text(
        _markdown(reverted, present, comparison), encoding="utf-8"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
