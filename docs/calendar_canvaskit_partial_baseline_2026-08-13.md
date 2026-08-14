# Calendar geometry program — CanvasKit-partial baseline seal

Date: 2026-08-13
Status: **sealed partial baseline; hard gate failed**

This seal is scoped to CanvasKit web at a fixed 390×844 logical viewport,
device-pixel ratio 1, and 60 Hz. It does not satisfy or waive the Android
baseline. No paint change is final without Android validation, and this result
does not authorize paint, renderer, epoch, topology, coverage, consumer, or
layout-inventory implementation work.

## Sealed identities

- Reference: `fd1d6ed493a1aa689b58510dcb859c62a0889222`
- Candidate: `5ff66008f6bd083147637ed4962db91f6ecf3f66`
- Repetitions: five per timing-only pass and five per full-probe pass
- Renderer: `FLUTTER_WEB_USE_SKIA=true`,
  `FLUTTER_WEB_USE_SKWASM=false`
- Scenario filter: empty
- Reference SHA-256:
  `a7a9aa66bd59318dd97fd22d5e853168a90002369f32fd06ffff3705d84a6a51`
- Candidate SHA-256:
  `1c9334a305cb67259ffdda0f90bc2e682e1f5393eb919a0559cd08fba27a93fd`
- Reduced comparison SHA-256:
  `f17ef06eaee6ea95583bd709b3add6ce685a587e569c1c021591f3b452cf65f9`

The one-repetition all-scenario diagnostic completed before the sealed pair.
Both five-repetition artifacts then completed with every boundary and Today
workload present.

## Gate result

The CanvasKit hard gate failed. These failures come from timing-only data:

- `details_event_heavy`: candidate build-p99 range was 7.30 ms slower than the
  reference range.
- `today/unhydrated_early`: raster p95 increased from 50.70 ms to 78.90 ms,
  `+55.62%`.
- `today/unhydrated_late`: raster p95 increased from 48.60 ms to 60.60 ms,
  `+24.69%`.
- `today/unhydrated_late`: janky-frame percentage increased from 50.00% to
  66.67%, `+16.67` percentage points.

The ordinary boundary p95 results mostly held or improved. That does not
override the named hard failures.

## Today contract

Far-past and near-target Today reached their targets in both artifacts, with
zero measured A→B and B→C movement after settle.

Unhydrated-early and unhydrated-late Today failed to reach the target in both
artifacts. Their post-interruption A/B/C samples were stable, but stability at
the wrong destination is not arrival continuity success. The overall Today
arrival contract therefore failed, as expected from the known production
hydration-preservation `jumpTo` defect.

## Isolation evidence

Full-probe values are isolation evidence only. At the candidate banner handoff,
page/body builds and layouts were zero and collector scheduled/committed counts
were zero. Body paint observations were still present: 4, 4, 3, and 1 across
compact-empty, compact-event-heavy, details-empty, and details-event-heavy.
Those observations do not satisfy a claim that handoff paint is fully isolated.

## Artifacts

Raw artifacts and the reduced JSON/Markdown report are stored under
`docs/benchmark_artifacts/calendar_geometry/2026-08-13/canvaskit-partial-baseline`.

This is the authorized stopping point. No subsequent program phase is unlocked.
