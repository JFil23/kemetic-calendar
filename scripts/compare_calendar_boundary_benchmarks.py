#!/usr/bin/env python3
"""Reduce and compare calendar boundary profile benchmark artifacts."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from statistics import median
from typing import Any


SCENARIOS = (
    "compact_empty",
    "compact_event_heavy",
    "details_empty",
    "details_event_heavy",
)

TODAY_SCENARIOS = (
    "far_past",
    "near_target",
    "unhydrated_early",
    "unhydrated_late",
)


class BenchmarkFormatError(ValueError):
    """Raised when a benchmark artifact does not satisfy the harness schema."""


def _mapping(value: Any, context: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise BenchmarkFormatError(f"{context} must be an object")
    return value


def _number_list(value: Any, context: str) -> list[float]:
    if not isinstance(value, list) or not value:
        raise BenchmarkFormatError(f"{context} must be a non-empty array")
    result: list[float] = []
    for index, item in enumerate(value):
        if not isinstance(item, (int, float)):
            raise BenchmarkFormatError(f"{context}[{index}] must be numeric")
        result.append(float(item))
    return result


def _count(value: Any, context: str) -> int:
    if not isinstance(value, int):
        raise BenchmarkFormatError(f"{context} must be an integer")
    return value


def _number(value: Any, context: str) -> float:
    if not isinstance(value, (int, float)):
        raise BenchmarkFormatError(f"{context} must be numeric")
    return float(value)


def _optional_number(value: Any, context: str) -> float | None:
    if value is None:
        return None
    return _number(value, context)


def _boolean(value: Any, context: str) -> bool:
    if not isinstance(value, bool):
        raise BenchmarkFormatError(f"{context} must be a boolean")
    return value


def _percentile(values: list[float], percentile: float) -> float:
    ordered = sorted(values)
    index = math.floor(((len(ordered) - 1) * percentile) + 0.5)
    return ordered[index]


def _timing_summary(values_us: list[float]) -> dict[str, float]:
    values_ms = [value / 1000.0 for value in values_us]
    return {
        "mean_ms": sum(values_ms) / len(values_ms),
        "p50_ms": _percentile(values_ms, 0.50),
        "p95_ms": _percentile(values_ms, 0.95),
        "p99_ms": _percentile(values_ms, 0.99),
        "max_ms": max(values_ms),
    }


def _timing_run_summary(
    build_times: list[float],
    raster_times: list[float],
    *,
    frame_budget_ms: float,
) -> dict[str, Any]:
    frame_count = max(len(build_times), len(raster_times))
    frame_budget_us = frame_budget_ms * 1000.0
    budget_misses = sum(
        max(
            build_times[index] if index < len(build_times) else 0.0,
            raster_times[index] if index < len(raster_times) else 0.0,
        )
        > frame_budget_us
        for index in range(frame_count)
    )
    return {
        "frame_count": frame_count,
        "build": _timing_summary(build_times),
        "raster": _timing_summary(raster_times),
        "frame_budget_miss_count": budget_misses,
        "janky_frame_percentage": (budget_misses / frame_count) * 100.0,
    }


def _performance_timing_summary(
    performance: dict[str, Any],
    *,
    context: str,
    frame_budget_ms: float,
) -> dict[str, Any]:
    build_times = _number_list(
        performance.get("frame_build_times"), f"{context}.frame_build_times"
    )
    raster_times = _number_list(
        performance.get("frame_rasterizer_times"),
        f"{context}.frame_rasterizer_times",
    )
    return {
        **_timing_run_summary(
            build_times,
            raster_times,
            frame_budget_ms=frame_budget_ms,
        ),
        "new_gen_gc_count": performance.get("new_gen_gc_count"),
        "old_gen_gc_count": performance.get("old_gen_gc_count"),
    }


def _probe_timing_summary(
    value: Any,
    *,
    context: str,
    frame_budget_ms: float,
) -> dict[str, Any]:
    if not isinstance(value, list) or not value:
        raise BenchmarkFormatError(f"{context} must be a non-empty array")
    timings = [
        _mapping(item, f"{context}[{index}]") for index, item in enumerate(value)
    ]
    build_times = [
        _number(item.get("build_duration_us"), f"{context}[{index}].build_duration_us")
        for index, item in enumerate(timings)
    ]
    raster_times = [
        _number(
            item.get("raster_duration_us"),
            f"{context}[{index}].raster_duration_us",
        )
        for index, item in enumerate(timings)
    ]
    return _timing_run_summary(
        build_times,
        raster_times,
        frame_budget_ms=frame_budget_ms,
    )


def _observer_effect(
    timing_only: dict[str, Any], full_probe: dict[str, Any]
) -> dict[str, float | None]:
    return {
        f"{thread}_{metric}_change_percent": _percent_change(
            timing_only[thread][metric], full_probe[thread][metric]
        )
        for thread in ("build", "raster")
        for metric in ("mean_ms", "p50_ms", "p95_ms", "p99_ms", "max_ms")
    }


def _probe_counts(value: Any, context: str) -> dict[str, int]:
    counts = _mapping(value, context)
    return {
        name: _count(counts.get(name), f"{context}.{name}")
        for name in ("builds", "layouts", "paints")
    }


def _counter_delta(
    current: dict[str, int], previous: dict[str, int]
) -> dict[str, int]:
    return {name: current[name] - previous[name] for name in current}


def _sample_analysis(
    samples_value: Any, frame_timings_value: Any, context: str
) -> dict[str, Any]:
    if not isinstance(samples_value, list) or len(samples_value) < 2:
        raise BenchmarkFormatError(f"{context} must contain at least two samples")

    samples = [_mapping(sample, f"{context}[{index}]") for index, sample in enumerate(samples_value)]
    if not isinstance(frame_timings_value, list) or not frame_timings_value:
        raise BenchmarkFormatError(f"{context}.frame_timings must be non-empty")
    frame_timings = [
        _mapping(timing, f"{context}.frame_timings[{index}]")
        for index, timing in enumerate(frame_timings_value)
    ]
    first_sample_timestamp = _count(
        samples[0].get("frame_timestamp_us"), f"{context}[0].frame_timestamp_us"
    )
    first_vsync_timestamp = _count(
        frame_timings[0].get("vsync_start_us"),
        f"{context}.frame_timings[0].vsync_start_us",
    )
    residuals: list[float] = []
    handoffs: list[dict[str, Any]] = []

    for index in range(1, len(samples)):
        previous = samples[index - 1]
        current = samples[index]
        previous_scroll = previous.get("scroll_pixels")
        current_scroll = current.get("scroll_pixels")
        previous_anchor = previous.get("body_anchor_viewport_y")
        current_anchor = current.get("body_anchor_viewport_y")
        if all(
            isinstance(value, (int, float))
            for value in (
                previous_scroll,
                current_scroll,
                previous_anchor,
                current_anchor,
            )
        ):
            residuals.append(
                abs(
                    (float(current_anchor) - float(previous_anchor))
                    + (float(current_scroll) - float(previous_scroll))
                )
            )

        previous_banner = (
            previous.get("banner_year"),
            previous.get("banner_month"),
        )
        current_banner = (
            current.get("banner_year"),
            current.get("banner_month"),
        )
        if previous_banner == current_banner:
            continue

        handoff = {
            "sample_index": index,
            "from": {"year": previous_banner[0], "month": previous_banner[1]},
            "to": {"year": current_banner[0], "month": current_banner[1]},
        }
        for subtree in ("page", "body", "banner"):
            current_counts = _probe_counts(
                current.get(subtree), f"{context}[{index}].{subtree}"
            )
            previous_counts = _probe_counts(
                previous.get(subtree), f"{context}[{index - 1}].{subtree}"
            )
            handoff[subtree] = _counter_delta(current_counts, previous_counts)
        for counter in (
            "banner_publications",
            "restoration_schedules",
            "restoration_writes",
            "hydration_schedules",
        ):
            handoff[counter] = _count(
                current.get(counter), f"{context}[{index}].{counter}"
            ) - _count(
                previous.get(counter), f"{context}[{index - 1}].{counter}"
            )
        sample_timestamp = _count(
            current.get("frame_timestamp_us"),
            f"{context}[{index}].frame_timestamp_us",
        )
        sample_elapsed = sample_timestamp - first_sample_timestamp
        matched_timing = min(
            frame_timings,
            key=lambda timing: abs(
                (_count(timing.get("vsync_start_us"), "frame timing vsync")
                - first_vsync_timestamp)
                - sample_elapsed
            ),
        )
        matched_elapsed = (
            _count(matched_timing.get("vsync_start_us"), "frame timing vsync")
            - first_vsync_timestamp
        )
        handoff["build_ms"] = (
            _count(matched_timing.get("build_duration_us"), "frame timing build")
            / 1000.0
        )
        handoff["raster_ms"] = (
            _count(
                matched_timing.get("raster_duration_us"), "frame timing raster"
            )
            / 1000.0
        )
        handoff["timing_match_error_ms"] = (
            abs(matched_elapsed - sample_elapsed) / 1000.0
        )
        handoffs.append(handoff)

    if not residuals:
        raise BenchmarkFormatError(
            f"{context} has no consecutive samples with a body anchor"
        )
    if not handoffs:
        raise BenchmarkFormatError(f"{context} contains no banner handoff")

    return {
        "sample_count": len(samples),
        "continuity_residual_p95_px": _percentile(residuals, 0.95),
        "continuity_residual_max_px": max(residuals),
        "continuity_residual_over_half_pixel_count": sum(
            residual > 0.5 for residual in residuals
        ),
        "handoffs": handoffs,
        "handoff_page_builds": sum(item["page"]["builds"] for item in handoffs),
        "handoff_body_builds": sum(item["body"]["builds"] for item in handoffs),
        "handoff_body_layouts": sum(item["body"]["layouts"] for item in handoffs),
        "handoff_body_paints": sum(item["body"]["paints"] for item in handoffs),
        "handoff_banner_builds": sum(item["banner"]["builds"] for item in handoffs),
        "handoff_frame_build_max_ms": max(item["build_ms"] for item in handoffs),
        "handoff_frame_raster_max_ms": max(item["raster_ms"] for item in handoffs),
        "handoff_timing_match_error_max_ms": max(
            item["timing_match_error_ms"] for item in handoffs
        ),
        "handoff_restoration_schedules": sum(
            item["restoration_schedules"] for item in handoffs
        ),
        "handoff_restoration_writes": sum(
            item["restoration_writes"] for item in handoffs
        ),
        "handoff_hydration_schedules": sum(
            item["hydration_schedules"] for item in handoffs
        ),
    }


def _reduce_run(
    performance: dict[str, Any],
    harness: dict[str, Any],
    *,
    context: str,
    frame_budget_ms: float,
) -> dict[str, Any]:
    timing = _performance_timing_summary(
        performance,
        context=context,
        frame_budget_ms=frame_budget_ms,
    )
    probe_timing = _probe_timing_summary(
        harness.get("frame_timings"),
        context=f"{context}.frame_timings",
        frame_budget_ms=frame_budget_ms,
    )
    return {
        **timing,
        "full_probe_timing": probe_timing,
        "full_probe_observer_effect": _observer_effect(timing, probe_timing),
        "idle_frame_count": _count(
            harness.get("idle_frame_count"), f"{context}.idle_frame_count"
        ),
        "banner_transition_count": _count(
            harness.get("banner_transition_count"),
            f"{context}.banner_transition_count",
        ),
        "banner_publication_count": _count(
            harness.get("banner_publication_count"),
            f"{context}.banner_publication_count",
        ),
        "collector_scheduled_publication_count": _count(
            harness.get("collector_scheduled_publication_count"),
            f"{context}.collector_scheduled_publication_count",
        ),
        "collector_committed_publication_count": _count(
            harness.get("collector_committed_publication_count"),
            f"{context}.collector_committed_publication_count",
        ),
        "restoration_schedule_count": _count(
            harness.get("restoration_schedule_count"),
            f"{context}.restoration_schedule_count",
        ),
        "restoration_write_count": _count(
            harness.get("restoration_write_count"),
            f"{context}.restoration_write_count",
        ),
        "hydration_schedule_count": _count(
            harness.get("hydration_schedule_count"),
            f"{context}.hydration_schedule_count",
        ),
        "page": _probe_counts(harness.get("page"), f"{context}.page"),
        "body": _probe_counts(harness.get("body"), f"{context}.body"),
        "banner": _probe_counts(harness.get("banner"), f"{context}.banner"),
        **_sample_analysis(
            harness.get("samples"),
            harness.get("frame_timings"),
            f"{context}.samples",
        ),
    }


def _arrival_samples(value: Any, context: str) -> list[dict[str, Any]]:
    if not isinstance(value, list) or len(value) != 3:
        raise BenchmarkFormatError(f"{context} must contain exactly A/B/C samples")
    samples = [
        _mapping(item, f"{context}[{index}]") for index, item in enumerate(value)
    ]
    labels = [sample.get("label") for sample in samples]
    if labels != ["A", "B", "C"]:
        raise BenchmarkFormatError(f"{context} labels must be A, B, C")
    timestamps = []
    for index, sample in enumerate(samples):
        timestamps.append(
            _count(
                sample.get("frame_timestamp_us"),
                f"{context}[{index}].frame_timestamp_us",
            )
        )
        _number(sample.get("scroll_pixels"), f"{context}[{index}].scroll_pixels")
        _number(sample.get("target_offset"), f"{context}[{index}].target_offset")
        _optional_number(
            sample.get("target_viewport_y"),
            f"{context}[{index}].target_viewport_y",
        )
    if timestamps != sorted(timestamps):
        raise BenchmarkFormatError(f"{context} timestamps must be ordered")
    return samples


def _reduce_today_run(
    performance: dict[str, Any],
    harness: dict[str, Any],
    *,
    context: str,
    frame_budget_ms: float,
) -> dict[str, Any]:
    timing = _performance_timing_summary(
        performance,
        context=context,
        frame_budget_ms=frame_budget_ms,
    )
    probe_timing = _probe_timing_summary(
        harness.get("frame_timings"),
        context=f"{context}.frame_timings",
        frame_budget_ms=frame_budget_ms,
    )
    trigger = harness.get("today_hydration_trigger")
    if trigger not in {"none", "early", "late"}:
        raise BenchmarkFormatError(f"{context}.today_hydration_trigger is invalid")
    return {
        **timing,
        "full_probe_timing": probe_timing,
        "full_probe_observer_effect": _observer_effect(timing, probe_timing),
        "idle_frame_count": _count(
            harness.get("idle_frame_count"), f"{context}.idle_frame_count"
        ),
        "banner_publication_count": _count(
            harness.get("banner_publication_count"),
            f"{context}.banner_publication_count",
        ),
        "collector_scheduled_publication_count": _count(
            harness.get("collector_scheduled_publication_count"),
            f"{context}.collector_scheduled_publication_count",
        ),
        "collector_committed_publication_count": _count(
            harness.get("collector_committed_publication_count"),
            f"{context}.collector_committed_publication_count",
        ),
        "restoration_schedule_count": _count(
            harness.get("restoration_schedule_count"),
            f"{context}.restoration_schedule_count",
        ),
        "restoration_write_count": _count(
            harness.get("restoration_write_count"),
            f"{context}.restoration_write_count",
        ),
        "hydration_schedule_count": _count(
            harness.get("hydration_schedule_count"),
            f"{context}.hydration_schedule_count",
        ),
        "page": _probe_counts(harness.get("page"), f"{context}.page"),
        "body": _probe_counts(harness.get("body"), f"{context}.body"),
        "banner": _probe_counts(harness.get("banner"), f"{context}.banner"),
        "today_hydration_trigger": trigger,
        "today_hydration_trigger_progress": _optional_number(
            harness.get("today_hydration_trigger_progress"),
            f"{context}.today_hydration_trigger_progress",
        ),
        "today_hydration_commit_count": _count(
            harness.get("today_hydration_commit_count"),
            f"{context}.today_hydration_commit_count",
        ),
        "today_start_offset": _number(
            harness.get("today_start_offset"), f"{context}.today_start_offset"
        ),
        "today_initial_target_offset": _number(
            harness.get("today_initial_target_offset"),
            f"{context}.today_initial_target_offset",
        ),
        "today_final_target_offset": _number(
            harness.get("today_final_target_offset"),
            f"{context}.today_final_target_offset",
        ),
        "today_final_scroll_pixels": _number(
            harness.get("today_final_scroll_pixels"),
            f"{context}.today_final_scroll_pixels",
        ),
        "today_reached_target": _boolean(
            harness.get("today_reached_target"), f"{context}.today_reached_target"
        ),
        "arrival_tolerance_logical_px": _number(
            harness.get("arrival_tolerance_logical_px"),
            f"{context}.arrival_tolerance_logical_px",
        ),
        "arrival_a_to_b_delta_px": _number(
            harness.get("arrival_a_to_b_delta_px"),
            f"{context}.arrival_a_to_b_delta_px",
        ),
        "arrival_b_to_c_delta_px": _number(
            harness.get("arrival_b_to_c_delta_px"),
            f"{context}.arrival_b_to_c_delta_px",
        ),
        "arrival_continuity_passed": _boolean(
            harness.get("arrival_continuity_passed"),
            f"{context}.arrival_continuity_passed",
        ),
        "arrival_samples": _arrival_samples(
            harness.get("arrival_samples"), f"{context}.arrival_samples"
        ),
    }


def _median_range(values: list[float | int]) -> dict[str, float]:
    numeric = [float(value) for value in values]
    return {
        "median": float(median(numeric)),
        "min": min(numeric),
        "max": max(numeric),
    }


def _aggregate_runs(runs: list[dict[str, Any]]) -> dict[str, Any]:
    aggregate: dict[str, Any] = {"run_count": len(runs), "runs": runs}
    for thread in ("build", "raster"):
        aggregate[thread] = {}
        for metric in ("mean_ms", "p50_ms", "p95_ms", "p99_ms", "max_ms"):
            values = [run[thread][metric] for run in runs]
            spread = _median_range(values)
            aggregate[thread][metric] = spread["median"]
            aggregate[thread][f"{metric}_range"] = [spread["min"], spread["max"]]

    aggregate["full_probe_timing"] = {}
    aggregate["full_probe_observer_effect"] = {}
    for thread in ("build", "raster"):
        aggregate["full_probe_timing"][thread] = {}
        for metric in ("mean_ms", "p50_ms", "p95_ms", "p99_ms", "max_ms"):
            values = [run["full_probe_timing"][thread][metric] for run in runs]
            spread = _median_range(values)
            aggregate["full_probe_timing"][thread][metric] = spread["median"]
            aggregate["full_probe_timing"][thread][f"{metric}_range"] = [
                spread["min"],
                spread["max"],
            ]
            observer_key = f"{thread}_{metric}_change_percent"
            observer_values = [
                run["full_probe_observer_effect"][observer_key] for run in runs
            ]
            observer_numeric = [
                value for value in observer_values if value is not None
            ]
            aggregate["full_probe_observer_effect"][observer_key] = (
                float(median(observer_numeric)) if observer_numeric else None
            )

    for metric in (
        "frame_count",
        "frame_budget_miss_count",
        "janky_frame_percentage",
        "idle_frame_count",
        "banner_transition_count",
        "banner_publication_count",
        "collector_scheduled_publication_count",
        "collector_committed_publication_count",
        "restoration_schedule_count",
        "restoration_write_count",
        "hydration_schedule_count",
    ):
        spread = _median_range([run[metric] for run in runs])
        aggregate[metric] = spread["median"]
        aggregate[f"{metric}_range"] = [spread["min"], spread["max"]]

    for subtree in ("page", "body", "banner"):
        aggregate[subtree] = {
            metric: float(median([run[subtree][metric] for run in runs]))
            for metric in ("builds", "layouts", "paints")
        }

    # Continuity and isolation are safety properties, so retain the worst run.
    for metric in (
        "continuity_residual_p95_px",
        "continuity_residual_max_px",
        "continuity_residual_over_half_pixel_count",
        "handoff_page_builds",
        "handoff_body_builds",
        "handoff_body_layouts",
        "handoff_body_paints",
        "handoff_banner_builds",
        "handoff_frame_build_max_ms",
        "handoff_frame_raster_max_ms",
        "handoff_timing_match_error_max_ms",
        "handoff_restoration_schedules",
        "handoff_restoration_writes",
        "handoff_hydration_schedules",
    ):
        aggregate[metric] = max(run[metric] for run in runs)
    return aggregate


def _aggregate_today_runs(runs: list[dict[str, Any]]) -> dict[str, Any]:
    aggregate: dict[str, Any] = {"run_count": len(runs), "runs": runs}
    for timing_source in (None, "full_probe_timing"):
        target = aggregate if timing_source is None else aggregate.setdefault(
            timing_source, {}
        )
        for thread in ("build", "raster"):
            target[thread] = {}
            for metric in ("mean_ms", "p50_ms", "p95_ms", "p99_ms", "max_ms"):
                values = [
                    run[thread][metric]
                    if timing_source is None
                    else run[timing_source][thread][metric]
                    for run in runs
                ]
                spread = _median_range(values)
                target[thread][metric] = spread["median"]
                target[thread][f"{metric}_range"] = [
                    spread["min"],
                    spread["max"],
                ]

    for metric in (
        "frame_count",
        "frame_budget_miss_count",
        "janky_frame_percentage",
        "idle_frame_count",
        "banner_publication_count",
        "collector_scheduled_publication_count",
        "collector_committed_publication_count",
        "restoration_schedule_count",
        "restoration_write_count",
        "hydration_schedule_count",
        "today_hydration_commit_count",
    ):
        spread = _median_range([run[metric] for run in runs])
        aggregate[metric] = spread["median"]
        aggregate[f"{metric}_range"] = [spread["min"], spread["max"]]

    for subtree in ("page", "body", "banner"):
        aggregate[subtree] = {
            metric: float(median([run[subtree][metric] for run in runs]))
            for metric in ("builds", "layouts", "paints")
        }

    for thread in ("build", "raster"):
        for metric in ("mean_ms", "p50_ms", "p95_ms", "p99_ms", "max_ms"):
            key = f"{thread}_{metric}_change_percent"
            values = [run["full_probe_observer_effect"][key] for run in runs]
            numeric = [value for value in values if value is not None]
            aggregate.setdefault("full_probe_observer_effect", {})[key] = (
                float(median(numeric)) if numeric else None
            )

    aggregate["today_hydration_trigger"] = runs[0]["today_hydration_trigger"]
    aggregate["arrival_continuity_passed"] = all(
        run["arrival_continuity_passed"] for run in runs
    )
    aggregate["today_reached_target"] = all(
        run["today_reached_target"] for run in runs
    )
    aggregate["arrival_a_to_b_abs_max_px"] = max(
        abs(run["arrival_a_to_b_delta_px"]) for run in runs
    )
    aggregate["arrival_b_to_c_abs_max_px"] = max(
        abs(run["arrival_b_to_c_delta_px"]) for run in runs
    )
    trigger_progress = [
        run["today_hydration_trigger_progress"]
        for run in runs
        if run["today_hydration_trigger_progress"] is not None
    ]
    aggregate["today_hydration_trigger_progress_range"] = (
        [min(trigger_progress), max(trigger_progress)] if trigger_progress else None
    )
    return aggregate


def reduce_artifact(
    artifact: dict[str, Any], *, frame_budget_ms: float | None
) -> dict[str, Any]:
    root = _mapping(artifact, "artifact")
    if root.get("platform") == "web" and (
        root.get("web_renderer_use_skia") is not True
        or root.get("web_renderer_use_skwasm") is not False
    ):
        raise BenchmarkFormatError(
            "artifact web renderer must be explicitly CanvasKit"
        )
    repetitions = _count(root.get("repetitions"), "artifact.repetitions")
    refresh_rate_hz = _number(root.get("refresh_rate_hz"), "artifact.refresh_rate_hz")
    if refresh_rate_hz <= 0:
        raise BenchmarkFormatError("artifact.refresh_rate_hz must be positive")
    if frame_budget_ms is not None and frame_budget_ms <= 0:
        raise BenchmarkFormatError("frame budget override must be positive")
    resolved_frame_budget_ms = frame_budget_ms or (1000.0 / refresh_rate_hz)
    if repetitions < 3:
        raise BenchmarkFormatError(
            "artifact.repetitions must be at least 3 to establish variance"
        )
    result: dict[str, Any] = {
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
        "frame_budget_ms": resolved_frame_budget_ms,
        "instrumentation_contract": root.get("instrumentation_contract"),
        "scenarios": {},
        "today_scenarios": {},
    }
    if result["benchmark"] != "calendar_banner_boundary":
        raise BenchmarkFormatError("artifact benchmark identity is missing or wrong")
    if (
        result["instrumentation_contract"]
        != "timing_only_gates_full_probe_isolation"
    ):
        raise BenchmarkFormatError("artifact instrumentation contract is missing or wrong")

    for scenario in SCENARIOS:
        runs: list[dict[str, Any]] = []
        for repetition in range(1, repetitions + 1):
            performance_key = f"performance_{scenario}_r{repetition}"
            harness_key = f"harness_{scenario}_r{repetition}"
            performance = _mapping(root.get(performance_key), performance_key)
            harness = _mapping(root.get(harness_key), harness_key)
            runs.append(
                _reduce_run(
                    performance,
                    harness,
                    context=harness_key,
                    frame_budget_ms=resolved_frame_budget_ms,
                )
            )
        result["scenarios"][scenario] = _aggregate_runs(runs)
    for scenario in TODAY_SCENARIOS:
        runs = []
        for repetition in range(1, repetitions + 1):
            performance_key = f"performance_today_{scenario}_r{repetition}"
            harness_key = f"harness_today_{scenario}_r{repetition}"
            performance = _mapping(root.get(performance_key), performance_key)
            harness = _mapping(root.get(harness_key), harness_key)
            runs.append(
                _reduce_today_run(
                    performance,
                    harness,
                    context=harness_key,
                    frame_budget_ms=resolved_frame_budget_ms,
                )
            )
        expected_trigger = {
            "far_past": "none",
            "near_target": "none",
            "unhydrated_early": "early",
            "unhydrated_late": "late",
        }[scenario]
        for run in runs:
            if run["today_hydration_trigger"] != expected_trigger:
                raise BenchmarkFormatError(
                    f"today/{scenario} must use the {expected_trigger} trigger"
                )
            expected_commit_count = 0 if expected_trigger == "none" else 1
            if run["today_hydration_commit_count"] != expected_commit_count:
                raise BenchmarkFormatError(
                    f"today/{scenario} must commit hydration "
                    f"{expected_commit_count} time(s)"
                )
            progress = run["today_hydration_trigger_progress"]
            if expected_trigger == "none" and progress is not None:
                raise BenchmarkFormatError(
                    f"today/{scenario} must not publish trigger progress"
                )
            if expected_trigger != "none" and progress is None:
                raise BenchmarkFormatError(
                    f"today/{scenario} must publish trigger progress"
                )
        result["today_scenarios"][scenario] = _aggregate_today_runs(runs)
    return result


def _percent_change(reference: float, candidate: float) -> float | None:
    if reference == 0:
        return None if candidate != 0 else 0.0
    return ((candidate - reference) / reference) * 100.0


def compare_reductions(
    reference: dict[str, Any], candidate: dict[str, Any]
) -> dict[str, Any]:
    comparison: dict[str, Any] = {
        "reference_revision": reference.get("revision"),
        "candidate_revision": candidate.get("revision"),
        "platform_match": reference.get("platform") == candidate.get("platform"),
        "repetitions_match": reference.get("repetitions")
        == candidate.get("repetitions"),
        "refresh_rate_match": math.isclose(
            reference.get("refresh_rate_hz"),
            candidate.get("refresh_rate_hz"),
            rel_tol=0.01,
        ),
        "scenarios": {},
        "today_scenarios": {},
    }
    hard_regressions: list[str] = []

    for scenario in SCENARIOS:
        reference_scenario = reference["scenarios"][scenario]
        candidate_scenario = candidate["scenarios"][scenario]
        timing_changes: dict[str, float | None] = {}
        for thread in ("build", "raster"):
            for metric in ("mean_ms", "p50_ms", "p95_ms", "p99_ms", "max_ms"):
                key = f"{thread}_{metric}_change_percent"
                change = _percent_change(
                    reference_scenario[thread][metric],
                    candidate_scenario[thread][metric],
                )
                timing_changes[key] = change
                if metric == "p95_ms" and change is not None and change > 10.0:
                    hard_regressions.append(f"{scenario}: {key}={change:.2f}%")
                if metric in ("p95_ms", "p99_ms"):
                    reference_max = reference_scenario[thread][f"{metric}_range"][1]
                    candidate_min = candidate_scenario[thread][f"{metric}_range"][0]
                    nonoverlap_ms = candidate_min - reference_max
                    timing_changes[f"{thread}_{metric}_nonoverlap_ms"] = nonoverlap_ms
                    if nonoverlap_ms > 0.5:
                        hard_regressions.append(
                            f"{scenario}: {thread}_{metric} candidate range is "
                            f"{nonoverlap_ms:.2f} ms slower than the reference range"
                        )

        miss_delta = (
            candidate_scenario["frame_budget_miss_count"]
            - reference_scenario["frame_budget_miss_count"]
        )
        jank_percentage_delta = (
            candidate_scenario["janky_frame_percentage"]
            - reference_scenario["janky_frame_percentage"]
        )
        if jank_percentage_delta > 1.0:
            hard_regressions.append(
                f"{scenario}: janky_frame_percentage_delta="
                f"{jank_percentage_delta:.2f} points"
            )

        comparison["scenarios"][scenario] = {
            **timing_changes,
            "frame_budget_miss_count_delta": miss_delta,
            "janky_frame_percentage_delta": jank_percentage_delta,
            "continuity_residual_max_px_delta": (
                candidate_scenario["continuity_residual_max_px"]
                - reference_scenario["continuity_residual_max_px"]
            ),
            "collector_scheduled_publication_count_delta": (
                candidate_scenario["collector_scheduled_publication_count"]
                - reference_scenario["collector_scheduled_publication_count"]
            ),
            "collector_committed_publication_count_delta": (
                candidate_scenario["collector_committed_publication_count"]
                - reference_scenario["collector_committed_publication_count"]
            ),
            "handoff_body_builds_delta": (
                candidate_scenario["handoff_body_builds"]
                - reference_scenario["handoff_body_builds"]
            ),
            "handoff_body_layouts_delta": (
                candidate_scenario["handoff_body_layouts"]
                - reference_scenario["handoff_body_layouts"]
            ),
            "handoff_body_paints_delta": (
                candidate_scenario["handoff_body_paints"]
                - reference_scenario["handoff_body_paints"]
            ),
            "handoff_frame_build_max_ms_delta": (
                candidate_scenario["handoff_frame_build_max_ms"]
                - reference_scenario["handoff_frame_build_max_ms"]
            ),
            "handoff_frame_raster_max_ms_delta": (
                candidate_scenario["handoff_frame_raster_max_ms"]
                - reference_scenario["handoff_frame_raster_max_ms"]
            ),
            "handoff_restoration_writes_delta": (
                candidate_scenario["handoff_restoration_writes"]
                - reference_scenario["handoff_restoration_writes"]
            ),
            "handoff_hydration_schedules_delta": (
                candidate_scenario["handoff_hydration_schedules"]
                - reference_scenario["handoff_hydration_schedules"]
            ),
        }

    for scenario in TODAY_SCENARIOS:
        reference_scenario = reference["today_scenarios"][scenario]
        candidate_scenario = candidate["today_scenarios"][scenario]
        timing_changes = {}
        for thread in ("build", "raster"):
            for metric in ("mean_ms", "p50_ms", "p95_ms", "p99_ms", "max_ms"):
                key = f"{thread}_{metric}_change_percent"
                change = _percent_change(
                    reference_scenario[thread][metric],
                    candidate_scenario[thread][metric],
                )
                timing_changes[key] = change
                if metric == "p95_ms" and change is not None and change > 10.0:
                    hard_regressions.append(
                        f"today/{scenario}: {key}={change:.2f}%"
                    )
                if metric in ("p95_ms", "p99_ms"):
                    reference_max = reference_scenario[thread][
                        f"{metric}_range"
                    ][1]
                    candidate_min = candidate_scenario[thread][
                        f"{metric}_range"
                    ][0]
                    nonoverlap_ms = candidate_min - reference_max
                    timing_changes[
                        f"{thread}_{metric}_nonoverlap_ms"
                    ] = nonoverlap_ms
                    if nonoverlap_ms > 0.5:
                        hard_regressions.append(
                            f"today/{scenario}: {thread}_{metric} candidate "
                            f"range is {nonoverlap_ms:.2f} ms slower than the "
                            "reference range"
                        )

        jank_percentage_delta = (
            candidate_scenario["janky_frame_percentage"]
            - reference_scenario["janky_frame_percentage"]
        )
        if jank_percentage_delta > 1.0:
            hard_regressions.append(
                f"today/{scenario}: janky_frame_percentage_delta="
                f"{jank_percentage_delta:.2f} points"
            )
        comparison["today_scenarios"][scenario] = {
            **timing_changes,
            "frame_budget_miss_count_delta": (
                candidate_scenario["frame_budget_miss_count"]
                - reference_scenario["frame_budget_miss_count"]
            ),
            "janky_frame_percentage_delta": jank_percentage_delta,
            "reference_arrival_continuity_passed": reference_scenario[
                "arrival_continuity_passed"
            ],
            "candidate_arrival_continuity_passed": candidate_scenario[
                "arrival_continuity_passed"
            ],
            "reference_reached_target": reference_scenario[
                "today_reached_target"
            ],
            "candidate_reached_target": candidate_scenario[
                "today_reached_target"
            ],
            "arrival_a_to_b_abs_max_px_delta": (
                candidate_scenario["arrival_a_to_b_abs_max_px"]
                - reference_scenario["arrival_a_to_b_abs_max_px"]
            ),
            "arrival_b_to_c_abs_max_px_delta": (
                candidate_scenario["arrival_b_to_c_abs_max_px"]
                - reference_scenario["arrival_b_to_c_abs_max_px"]
            ),
        }

    if not comparison["platform_match"]:
        hard_regressions.append("benchmark platforms do not match")
    if not comparison["repetitions_match"]:
        hard_regressions.append("benchmark repetition counts do not match")
    if not comparison["refresh_rate_match"]:
        hard_regressions.append("benchmark display refresh rates do not match")
    comparison["hard_regressions"] = hard_regressions
    comparison["hard_gate_passed"] = not hard_regressions
    comparison["candidate_today_arrival_contract_passed"] = all(
        candidate["today_scenarios"][scenario]["arrival_continuity_passed"]
        and candidate["today_scenarios"][scenario]["today_reached_target"]
        for scenario in TODAY_SCENARIOS
    )
    return comparison


def markdown_report(
    reference: dict[str, Any],
    candidate: dict[str, Any],
    comparison: dict[str, Any],
) -> str:
    lines = [
        "# Calendar boundary benchmark comparison",
        "",
        f"Reference: `{reference.get('revision')}`  ",
        f"Candidate: `{candidate.get('revision')}`  ",
        f"Platform: `{candidate.get('platform')}`  ",
        f"Repetitions: `{candidate.get('repetitions')}`  ",
        f"Refresh rate: `{candidate.get('refresh_rate_hz'):.2f} Hz`  ",
        f"Frame budget: `{candidate.get('frame_budget_ms'):.3f} ms`  ",
        f"Hard gate: **{'PASS' if comparison['hard_gate_passed'] else 'FAIL'}**",
        "",
        "| Scenario | Build p95 | Raster p95 | Jank | Anchor max | Handoff b/r | Collector s/c | Handoff body b/l/p | Probe p95 effect |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for scenario in SCENARIOS:
        ref = reference["scenarios"][scenario]
        cand = candidate["scenarios"][scenario]
        lines.append(
            "| "
            + scenario
            + f" | {_format_metric(ref, 'build', 'p95_ms')} → {_format_metric(cand, 'build', 'p95_ms')}"
            + f" | {_format_metric(ref, 'raster', 'p95_ms')} → {_format_metric(cand, 'raster', 'p95_ms')}"
            + f" | {ref['janky_frame_percentage']:.2f}% → {cand['janky_frame_percentage']:.2f}%"
            + f" | {ref['continuity_residual_max_px']:.3f} → {cand['continuity_residual_max_px']:.3f} px"
            + f" | {cand['handoff_frame_build_max_ms']:.2f}/{cand['handoff_frame_raster_max_ms']:.2f} ms"
            + " | "
            + f"{cand['collector_scheduled_publication_count']:.1f}/{cand['collector_committed_publication_count']:.1f}"
            + " | "
            + f"{cand['handoff_body_builds']}/{cand['handoff_body_layouts']}/{cand['handoff_body_paints']}"
            + " | "
            + f"{_format_optional_percent(cand['full_probe_observer_effect']['build_p95_ms_change_percent'])}/"
            + f"{_format_optional_percent(cand['full_probe_observer_effect']['raster_p95_ms_change_percent'])}"
            + " |"
        )
    lines.extend(
        [
            "",
            "## Today",
            "",
            "| Scenario | Build p95 | Raster p95 | Jank | Reached | A→B max | B→C max | Probe build/raster p95 effect |",
            "| --- | ---: | ---: | ---: | :---: | ---: | ---: | ---: |",
        ]
    )
    for scenario in TODAY_SCENARIOS:
        ref = reference["today_scenarios"][scenario]
        cand = candidate["today_scenarios"][scenario]
        observer = cand["full_probe_observer_effect"]
        lines.append(
            "| "
            + scenario
            + f" | {_format_metric(ref, 'build', 'p95_ms')} → {_format_metric(cand, 'build', 'p95_ms')}"
            + f" | {_format_metric(ref, 'raster', 'p95_ms')} → {_format_metric(cand, 'raster', 'p95_ms')}"
            + f" | {ref['janky_frame_percentage']:.2f}% → {cand['janky_frame_percentage']:.2f}%"
            + f" | {'yes' if cand['today_reached_target'] else 'no'}"
            + f" | {cand['arrival_a_to_b_abs_max_px']:.3f} px"
            + f" | {cand['arrival_b_to_c_abs_max_px']:.3f} px"
            + " | "
            + f"{_format_optional_percent(observer['build_p95_ms_change_percent'])}/"
            + f"{_format_optional_percent(observer['raster_p95_ms_change_percent'])}"
            + " |"
        )
    lines.extend(
        [
            "",
            "Today arrival contract: **"
            + (
                "PASS"
                if comparison["candidate_today_arrival_contract_passed"]
                else "FAIL"
            )
            + "**",
        ]
    )
    if comparison["hard_regressions"]:
        lines.extend(["", "Hard regressions:"])
        lines.extend(f"- {item}" for item in comparison["hard_regressions"])
    lines.append("")
    return "\n".join(lines)


def _format_metric(scenario: dict[str, Any], thread: str, metric: str) -> str:
    value = scenario[thread][metric]
    lower, upper = scenario[thread][f"{metric}_range"]
    return f"{value:.2f} [{lower:.2f}, {upper:.2f}] ms"


def _format_optional_percent(value: float | None) -> str:
    return "n/a" if value is None else f"{value:+.1f}%"


def load_artifact(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as source:
        value = json.load(source)
    return _mapping(value, str(path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--json-out", type=Path, required=True)
    parser.add_argument("--markdown-out", type=Path, required=True)
    parser.add_argument(
        "--frame-budget-ms",
        type=float,
        help="Override the display-derived frame budget for both artifacts",
    )
    args = parser.parse_args()

    reference = reduce_artifact(
        load_artifact(args.reference), frame_budget_ms=args.frame_budget_ms
    )
    candidate = reduce_artifact(
        load_artifact(args.candidate), frame_budget_ms=args.frame_budget_ms
    )
    comparison = compare_reductions(reference, candidate)
    output = {
        "reference": reference,
        "candidate": candidate,
        "comparison": comparison,
    }

    args.json_out.parent.mkdir(parents=True, exist_ok=True)
    args.markdown_out.parent.mkdir(parents=True, exist_ok=True)
    args.json_out.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    args.markdown_out.write_text(
        markdown_report(reference, candidate, comparison), encoding="utf-8"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
