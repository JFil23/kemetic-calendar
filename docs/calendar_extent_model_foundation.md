# Calendar Extent Model foundation and numerical baseline

Status: foundation harness implemented; CanvasKit-partial baseline sealed with
a hard-gate failure; Android baseline owed.

This document records the executable foundation for Amendment 8. It does not
authorize a renderer, epoch, topology, paint, coverage, or production-consumer
change.

## Fixed revision identities

- Regression comparator: `fd1d6ed493a1aa689b58510dcb859c62a0889222`
- Implementation parent: `5ff66008f6bd083147637ed4962db91f6ecf3f66`

`fd1d6ed` is the direct parent of `5ff6600`. The two revisions have identical
`calendar_page.dart` files. The latter changes the banner resolver, geometry
collector/snapshot, and grid markers to hand the banner off at the final day
block. This is the delta the first numerical comparison must preserve.

## Harness contract

The profile integration test mounts the real `CalendarPage`, including its
production `_YearSection`, `CalendarGeometryCollector`,
`CalendarScrollCoordinator`, banner, restoration scheduling, and viewport
hydration scheduling. It does not reproduce their layout or banner logic. The
application never supplies the benchmark controller. With no controller, every
benchmark branch is inert and the normal widget tree is unchanged.

Every artifact contains two physically separate passes. Timing-only is the
only source for hard build/raster and jank gates. Full-probe repeats the
workload for attribution and is never substituted into those gates.

Both passes contain five repetitions by default for each boundary case:

- compact, empty content
- compact, event-heavy content
- details, empty content
- details, event-heavy content

Each repetition finds the real Hathor-to-Paopi handoff dynamically, begins 40
logical pixels before it, scrubs forward and backward across it, and then
flings through a multi-month range. The scan does not assume a hard-coded
offset, so the same harness can measure both pinned revisions.

The artifact also contains five fresh-mount repetitions of each Today case:

- far-past to Today
- near-target to Today
- far-past with target hydration committed at 25 percent travel progress
- far-past with target hydration committed at the start of the final display
  frame interval before settle

Today records A/B/C target-day viewport positions, target offset, final scroll
pixels, trigger progress, and commit count. A-to-B and B-to-C must be zero,
within one physical device pixel expressed as logical pixels. The current
hydration-preservation `jumpTo` remains present in the baseline on purpose; an
interrupted Today animation must be exposed, not normalized away.

The host sanity workload has already established one named pre-existing
defect: a visible hydration commit captures the current offset and posts a
`ScrollPosition.jumpTo` after layout. That competing scroll write terminates an
active Today `animateTo`; in the deterministic early-hydration case the travel
ended near offset `1002` instead of the target near `3635`. The future epoch
contract must therefore own both extent publication and hydration's viewport
preservation write. Freezing specs while leaving that `jumpTo` live does not
fix Today.

The full-probe pass records:

- per-frame build and raster durations from Flutter `FrameTiming`
- normalized frame timestamps that associate banner handoff samples with their
  build/raster frame rather than only reporting whole-run percentiles
- the display refresh rate and physical viewport
- scroll position and a body-anchor viewport coordinate
- active banner month and transition count
- geometry-collector scheduled and committed publication counts
- cumulative build, layout, and paint counts for page, body, and banner probes
- restoration schedule/write and viewport-hydration schedule counts
- frames produced during a two-second post-workload idle interval

Direct `jumpTo` calls are confined to unmeasured fixture positioning. The
measured slow scrub uses real pointer gestures. Nothing in the harness changes
production scroll activity or correction behavior.

Ordinary profile/release builds require the compile-time opt-in
`CALENDAR_BOUNDARY_BENCHMARK=true`; otherwise benchmark branches are compiled
out. `integration_test/calendar_dormant_observer_performance_test.dart` is an
independent no-controller workload for comparing harness-present/inactive with
harness-reverted source. It must run without that define.

## Comparison contract

`scripts/compare_calendar_boundary_benchmarks.py` reduces raw artifacts into
per-run and median/range results. Unless an explicit positive frame-budget
override is supplied, the jank budget is `1000 / refresh_rate_hz`.

The comparison fails closed when:

- platforms, refresh rates, or repetition counts differ
- median build or raster p95 regresses by more than 10 percent
- median janky-frame percentage increases by more than one percentage point
- the candidate's entire p95/p99 range is more than 0.5 ms slower than the
  reference's entire range

The report also preserves body-anchor residuals, idle frames, collector work,
and handoff-time subtree counters. Those are evidence, not permission to call
the recording fixed merely because aggregate timing passes.

Today timing uses the same hard caps. Arrival continuity and arrival at the
recomputed target are reported as a separate semantic completion contract; a
baseline may record the current defect, but the final program cannot pass while
that contract fails.

The reducer also reports timing-only versus full-probe p95 deltas. Those deltas
quantify active instrumentation cost; they are not application regressions.

## Dormant observer check

Before the two pinned numerical baselines, run the independent observer target
with harness source present/inactive and with the harness source reverted. The
same observer test and driver are overlaid on both worktrees; no harness symbol
is imported by the target.

```sh
./scripts/run_calendar_dormant_observer_benchmark.sh \
  <device-id> harness-reverted <artifact-directory>/observer/reverted
./scripts/run_calendar_dormant_observer_benchmark.sh \
  <device-id> harness-present <artifact-directory>/observer/present
python3 scripts/compare_calendar_dormant_observer.py \
  --harness-reverted <reverted-artifact.json> \
  --harness-present <present-artifact.json> \
  --json-out <observer-comparison.json> \
  --markdown-out <observer-comparison.md>
```

Do not obtain the reverted side by mutating the implementation worktree. Use a
clean pinned worktree. If the present/inactive run meaningfully changes timing,
the numerical baseline is not sealable until the observer effect is removed.
Observer hard gates use the median of matched repetition deltas, which controls
the repeat-position warm-up curve. A change greater than 10 percent in either
direction for build/raster p95, or greater than one jank percentage point in
either direction, fails parity. A large apparent improvement is an observer
effect too.

## Closed layout inventory

`docs/calendar_extent_contributor_inventory.md` is the closed enumeration that
feeds the go/no-go gate. It classifies every vertical contributor, immutable
input, responsive branch, Heriu case, range owner, and pinch geometry consumer.
`scripts/verify_calendar_extent_inventory.py` fails closed if any audited
source fragment changes without re-audit.

## Required execution

Apply the exact same foundation-instrumentation change to clean worktrees at
both pinned revisions. On each worktree, verify that every production-source
addition is gated by the nullable benchmark controller: the test-only
constructor input, deterministic startup branch, probes, and diagnostic
counters. With a null controller, the existing `CalendarPage` path and widget
tree must be unchanged.

Run both revisions on the same physical Android device without changing its
refresh-rate setting:

```sh
export CALENDAR_BENCHMARK_REPETITIONS=5
./scripts/run_calendar_boundary_benchmark.sh \
  <android-device-id> fd1d6ed <artifact-directory>/android/fd1d6ed
./scripts/run_calendar_boundary_benchmark.sh \
  <android-device-id> 5ff6600 <artifact-directory>/android/5ff6600
```

Run the same pair in Chrome at the fixed RC viewport. The runner explicitly
sets `FLUTTER_WEB_USE_SKIA=true` and `FLUTTER_WEB_USE_SKWASM=false`; the artifact
records both values and the reducer rejects a web artifact that is not
explicitly CanvasKit:

```sh
./scripts/run_calendar_boundary_benchmark.sh \
  chrome fd1d6ed <artifact-directory>/canvaskit/fd1d6ed 390x844@1
./scripts/run_calendar_boundary_benchmark.sh \
  chrome 5ff6600 <artifact-directory>/canvaskit/5ff6600 390x844@1
```

Run the same pair on the same physical iPhone, without changing its refresh
rate or display settings:

```sh
./scripts/run_calendar_boundary_benchmark.sh \
  <iphone-device-id> fd1d6ed <artifact-directory>/iphone/fd1d6ed
./scripts/run_calendar_boundary_benchmark.sh \
  <iphone-device-id> 5ff6600 <artifact-directory>/iphone/5ff6600
```

Reduce each same-platform pair:

```sh
python3 scripts/compare_calendar_boundary_benchmarks.py \
  --reference <fd1d6ed-artifact.json> \
  --candidate <5ff6600-artifact.json> \
  --json-out <comparison.json> \
  --markdown-out <comparison.md>
```

Do not compare Android with Chrome or devices with different refresh rates.
Record device model, OS/browser version, build mode, viewport, thermal state,
and power state alongside the artifacts.

## Current execution state — 2026-08-13

- Boundary and Today harness sanity, collector, coordinator, both Python
  reducers, the closed-inventory verifier, and static-analysis checks pass.
- Timing-only and full-probe runs are structurally separate. The compile-time
  benchmark opt-in excludes all benchmark branches from ordinary
  profile/release builds.
- Today includes far, near, early-hydration, and late-hydration cases with
  progress triggers and A/B/C arrival evidence.
- The source inventory is closed and currently finds no required mount-time
  measurement exception.
- No Android device is attached (`adb devices -l` returned no devices).
- The workspace volume has less than 1 GiB free.
- A macOS profile smoke build was attempted only to validate driver output; it
  stopped during dependency/build setup with `No space left on device` and
  produced no measurement. Its generated Xcode project changes were removed.

Therefore neither required numerical baseline is sealed. No later production
gate is unlocked by this foundation work.
