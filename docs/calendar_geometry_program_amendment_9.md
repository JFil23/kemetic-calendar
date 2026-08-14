# Calendar geometry program — Amendment 9

Status: binding clarification of the already-authorized foundation and
feasibility scope. It grants no production behavior authority.

## 1. Today is a sealed workload

The numerical baseline contains five repetitions of each:

- far-past offset to Today
- near-target offset to Today
- far-past offset with the target month unhydrated and hydration requested at
  the elapsed animation time that corresponds to 25 percent spatial travel
  under the production `Curves.easeOutCubic` Bézier
- far-past offset with the target month unhydrated and hydration requested at
  the start of the final display-frame interval of the unchanged 320 ms eased
  animation

This section supersedes the earlier progress-listener trigger contract.
Observed pixels, scroll-listener progress, and rendered-frame ordinal do not
own either treatment. The harness requests the early treatment from a
monotonic clock at the numerical inverse of the runtime production
`Curves.easeOutCubic` Bézier for 25 percent spatial travel. It requests the
late treatment at `320 ms - one display interval`. The CanvasKit diagnosis
contract owns the treatment mechanics, recorded fields, and fail-closed timing
and spatial tolerances. No repaired Today artifact counts as sealed unless it
satisfies that contract. Every repetition mounts a fresh calendar so hydrated
state cannot leak between runs.

Arrival continuity has three samples:

- A: animation/activity first becomes idle, before any later frame can hide a
  correction
- B: the first complete following layout
- C: the following frame

The target day chip's viewport coordinate must have a mathematical A-to-B and
B-to-C delta of zero. The executable tolerance is one physical device pixel
expressed in logical pixels. The report separately records whether final scroll
pixels reach the recomputed target.

The current no-epoch baseline captures A at first idle. When epoch batching is
introduced, the batch owner must expose the pre-apply boundary so A is captured
from the final old-epoch state before pending specs are installed; listener
registration order is not an acceptable substitute for that hook.

## 2. Gate timing and attribution are separate runs

Hard performance gates use Flutter's timing-only `watchPerformance` run. It has
no page/body/banner probes, collector listener, banner listener, scroll sample
listener, or frame-correlation callback.

The full-probe run is a separate repetition of the same workload. It may
attribute page/body/banner build, layout, and paint work; collector scheduling
and commits; banner publications; restoration and hydration work; anchor
continuity; and correlated frame timing. Full-probe numbers are evidence only
and cannot satisfy a hard timing gate.

The reducer reports the timing-only versus full-probe delta so probe cost is
visible rather than blended into a gate.

## 3. Dormant observer effect is measured independently

Ordinary profile/release builds compile benchmark branches out unless
`CALENDAR_BOUNDARY_BENCHMARK=true` is supplied. Before sealing baselines, run
the same no-controller observer workload twice on the same platform:

1. harness source present, compile-time flag false
2. harness source reverted, with only the independent observer target and
   driver overlaid

The present/inactive result must stay within the agreed variance envelope of
the reverted result. The run must report the compile-time flag as false.

## 4. The layout inventory is closed

The inventory must end with every extent-contributing widget, constant,
conditional, responsive environment input, and topology owner mapped to either
the canonical immutable layout inputs or a specifically named one-shot
mount-time measurement exception.

Completeness must be checkable. The current inventory uses audited source
fragments and fails closed when any fragment changes. A hash update without a
semantic re-audit does not discharge the gate.

## 5. Reproducibility and execution gate

Capture git state, lockfile hashes, resolved dependency state, Flutter/Dart,
Xcode, Java, browser/device facts, and disk state before cache cleanup. Reclaim
at least 15–20 GB of headroom before building or measuring. Project build
products and Xcode/Gradle artifacts are considered before the pub cache; the
pub cache is last because redownloads can damage reproducibility.

Goldens and all Repeated Paint Repair remain behind the numerical baseline.
Renderer, epoch, topology, consumer, coverage, and registry-deletion authority
remain locked behind their existing gates.
