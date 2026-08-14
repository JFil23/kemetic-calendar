# CanvasKit gate diagnosis contract — 2026-08-13

Status: diagnosis-only authorization. The umbrella program remains STOP.
Nothing in this document authorizes production paint, renderer, extent-model,
epoch, topology, coverage, consumer, correction, or registry-deletion work.

## Fixed evidence

The reference is `fd1d6ed493a1aa689b58510dcb859c62a0889222` and the
candidate is its direct child
`5ff66008f6bd083147637ed4962db91f6ecf3f66`.

For `details_event_heavy`, timing-only build p99 ranges do not overlap:
reference `5.5–6.1 ms`, candidate `13.4–18.7 ms`. Every reference run has one
`174–190 ms` build stall followed by a `16–18 ms` frame. Every candidate run
has two `153–182 ms` stalls followed by a `13–19 ms` frame.

Full-probe independently reproduces the shape in five of five runs: reference
one `159–175 ms` frame followed by `14–21 ms`; candidate two `157–179 ms`
frames followed by `13–14 ms`. This permits a separate marker-equipped
localization pass. Marker timing is attribution evidence only and never
replaces timing-only gate data.

## Track 1 — predefined localization windows

The marker overlay is identical on both pinned worktrees and is active only
for full-probe benchmark controllers. Timing-only remains marker-free.

The initial marker set records these workload intervals and instantaneous
events:

- slow scrub and each forward/reverse segment
- scrub settle
- fling dispatch and fling settle
- scroll activity start and end
- banner and geometry publications
- restoration schedule and write
- viewport-hydration schedule

An interval window starts at its `start` marker and ends one display interval
after its `end` marker. An instantaneous event owns the closest frame whose
vsync is at or after the event and has a window of plus or minus one display
interval. Event and frame clocks are compared as elapsed monotonic durations
from the beginning of full-probe capture; absolute clock origins are not
compared.

Before marker timing is used, the marker-equipped pair must still show two
catastrophic candidate frames in five of five runs and one reference frame in
five of five runs. Every marker-set revision repeats that reproduction check.
If the signature disappears, that marker revision is invalid.

Localization succeeds only when the extra candidate stall falls in the same
predefined event window in five of five candidate runs and the matching
reference event has no equivalent stall in five of five reference runs. The
reference event itself may exist. Temporal association localizes; it does not
name a cause.

Naming a cause requires a controlled ablation in a disposable candidate
worktree. The suspected component is the only intentional source difference
from the candidate marker overlay, the workload event must remain present,
and the extra catastrophic frame must disappear in five of five runs. Without
that result, the report is `localized, cause unproven` and diagnosis stops.

### Marker-v3 localization result and sealed ablation

Marker v3 replaced the browser-dependent diagnostic clock with a monotonic
stopwatch. The identical overlay retained the prerequisite signature: all five
reference repetitions contain one greater-than-100-ms build frame, while all
five candidate repetitions contain two. The candidate-only frame falls inside
the predefined `fling_settle` interval in five of five repetitions; no
reference repetition has a greater-than-100-ms build frame in that interval.

The cumulative probes provide a narrower correlation. The reference performs
one page/body build during the workload. The candidate performs two, and its
second page/body build occurs on the candidate-only catastrophic frame during
`fling_settle`. The candidate also records one additional centered-month
restoration schedule in every repetition. This localizes the extra stall to a
second centered-month transition and page-wide rebuild; it does not yet prove
that rebuild caused the stall.

The one authorized ablation is therefore sealed before its run: in the
disposable candidate worktree, `_setView` will retain its state mutation,
restoration schedule, hydration schedule, and all workload behavior, but omit
only its page-wide `setState`. No marker, fixture, scroll, resolver, geometry,
or content code changes. The `fling_settle` interval and the additional
centered-month/restoration event must remain present. Cause is established only
if the candidate-only greater-than-100-ms build frame disappears in all five
repetitions while the common post-workload stall may remain. Otherwise the
result is `localized, cause unproven` and Track 1 stops.

### Ablation result

The sealed ablation passed. Its artifact is
`calendar-boundary-5ff6600-marker-v3-ablate-page-rebuild-chrome.json`.
All five repetitions retained four restoration schedules, including the
candidate-only centered-month transition, while page and body build counts
fell to zero. No timing-only or full-probe repetition contained a
greater-than-100-ms build frame. Timing-only worst frames were `29.0`, `5.3`,
`5.2`, `5.8`, and `5.3 ms`; full-probe worst frames were `15.0`, `5.401`,
`7.3`, `5.9`, and `4.3 ms`.

This proves that `_setView`'s page-wide `setState`, not restoration scheduling
itself, causes the catastrophic build stalls in this workload. The direct
commit moves the measured banner transition from offset `1633.55` to
`1289.55`. Starting the same sealed scrub/fling at that new semantic boundary
crosses a second centered-month transition, so the candidate pays the
pre-existing page-wide rebuild twice where the reference pays it once. The
final-day handoff exposed the ownership defect; removing the handoff or merely
suppressing one transition is not the durable repair.

The disposable ablation was restored immediately after artifact capture. It
is evidence only and is not a proposed production change.

## Track 2 — Today treatment authority

The existing meaning of early hydration remains **25 percent spatial travel**.
It is not amended to 25 percent elapsed time. Host proof found that the earlier
closed-form inverse was invalid: Flutter's `Curves.easeOutCubic` is the cubic
Bézier `Cubic(0.215, 0.61, 0.355, 1.0)`, not the polynomial
`1 - (1 - t)^3`. The harness numerically inverts the production curve itself.
The harness uses the runtime transform as authority; on the pinned Flutter SDK
the rounded request is approximately `28.6 ms` of the unchanged 320-ms
animation.

Late hydration is requested at the start of the final display interval:

`t = 320 ms - (1000 / refreshRate) ms`.

The harness controls animation time explicitly; neither trigger is driven by
observed pixels or rendered-frame ordinal. Host proof established that
`DrivenScrollActivity` creates the transaction synchronously but establishes
the curve's elapsed-time epoch on its first ticker frame. The harness therefore
captures the exact `animateTo` future, pumps that first ticker frame, and starts
controlled elapsed time there. The original Today transaction is active only
while that specific future has not completed or been cancelled.
Harness-listener state and generic `isScrollingNotifier` state are not
substitutes for that definition.

The timing-only artifact records, for every repetition:

- requested elapsed trigger time
- actual harness-controlled elapsed trigger time
- actual spatial progress immediately before commit
- hydration commit count
- whether the original Today animation was active at commit
- initial and recomputed target offsets
- final scroll pixels
- whether the recomputed target was reached

The pump schedule, timing tolerance, spatial tolerance, event-window metric,
and repetition count are sealed before the corrected A/B runs. A run whose
actual trigger misses the sealed timing or spatial tolerance is invalid and
fails closed. The 320 ms production duration does not change.

The first CanvasKit smoke proved that widget-test pumps do not own live browser
animation time: while the test awaited a nominal `28.568 ms` pump, the real
activity advanced to 62 percent and the wall clock advanced `54.9 ms`. The
smoke is invalid evidence and is quarantined. The treatment is therefore
requested by a monotonic timer installed at the ticker epoch. The third smoke
showed that assigning timer expiry to a harness-driven next frame added an
extra interval (`28.6 ms` requested, `67 ms` actual), so that smoke is also
quarantined. The timer now commits directly between frames, matching real async
hydration; it is never triggered by pixel progress or frame ordinal.

The sealed live tolerances are:

- requested time is the numerical inverse of the runtime production curve
- actual monotonic commit time may be at most `1 ms` early and no more than one
  display interval late; a delayed event loop fails closed
- actual spatial progress must fall inside the production curve's one-display-
  interval quantization bracket around actual commit time
- commit count is exactly one while the original `animateTo` future is still
  unresolved

The timing-only hydration event window is a separate matched mount in each
repetition. Capture starts with the production Today transaction, includes the
timer-requested commit, and ends after exactly two post-commit display
intervals. Per repetition, the primary event-window metrics are maximum build
time and maximum raster time. The five per-repetition values are compared as
ranges; raw frames are not pooled into a synthetic sample. The whole-Today
timing-only workload remains a separate report and is not replaced by this
window.

Each repetition remains the experimental unit. The primary metric is a
predeclared fixed event window around the hydration commit. Pooled raw frames
are supporting evidence only.

The repaired harness overlay must be byte-identical on the two pinned
worktrees. A Today-only A/B is not run until focused host tests prove early and
late treatment timing, activity state, commit count, and final-outcome
serialization.

## Epoch / preservation-write amendment

Freeze-until-settle is insufficient while hydration can post an independent
`ScrollPosition.jumpTo`. Viewport preservation is part of the epoch commit.
Production implementation must either replace that write with the already
authorized layout-coupled correction or remove it because the semantic epoch
anchor already preserves the viewport. This is a recorded contract only; no
production epoch work is authorized in this diagnosis slice.

## Android and stop rules

Marker-free ordinary-boundary measurements may run on Android independently.
An Android seal may PASS or FAIL and grants no landing authority. Today is
added only after the repaired harness is valid. Manual RC feel is correctness
and gross-regression evidence only, never a performance-gate result.

Any production change, marker leakage into timing-only, trigger driven by
pixels or frame index, changed Today duration, unsealed primary statistic, or
causal claim without the required ablation stops this slice.

## Diagnosis-slice result

Track 1 is complete. Marker v3 localized the candidate-only catastrophic build
frame to `fling_settle` in five of five candidate runs with no equivalent
reference stall in that window. The sealed `_setView` ablation retained the
extra centered-month/restoration event and removed every greater-than-100-ms
build frame in five of five runs. The causal finding is therefore proven:
scroll-derived centered-month changes rebuild the entire calendar page, and
the final-day handoff makes the sealed workload cross that ownership boundary
twice instead of once.

The disposable reference ablation also passed its intervention-integrity gate.
Its artifact is
`calendar-boundary-fd1d6ed-marker-v3-ablate-page-rebuild-reference-chrome.json`.
All five repetitions retained the sealed `1633.55` transition offset, one
banner transition, and three centered-month restoration schedules. Page and
body build counts fell to zero. No timing-only or full-probe repetition
contained a greater-than-100-ms build frame. Timing-only worst frames were
`32.6`, `5.399`, `5.2`, `5.0`, and `5.3 ms`; full-probe worst frames were
`16.401`, `5.701`, `6.0`, `5.8`, and `4.701 ms`.

The single approximately `180 ms` reference stall on `fd1d6ed` is therefore
promoted from inference to proof of the same `_setView` page-wide rebuild owner
paid once. The candidate crosses the same ownership boundary twice; these are
not two unrelated catastrophic-scroll defects. The disposable reference
ablation was restored immediately after artifact capture and is evidence only.

Track 2 fails closed before A/B. The final matched reference smoke requested
early hydration at `28,568 us` but committed at `48,901 us`, more than one
display interval late, while the original animation future was still active.
The timing contract is invalid, so the five-repetition reference/candidate
Today pair was not run. Earlier candidate smoke artifacts used superseded
driver mechanics and remain quarantined; none is gate evidence. Thresholds
were not relaxed.

The delay diagnosis is now closed on a named branch. The first diagnostic
artifact is quarantined because `dart:developer` exposed an epoch-millisecond
clock on web while `FrameTiming` used the CanvasKit performance clock. The
corrected diagnostic uses `FlutterTimeline.now`, the same monotonic microsecond
source as the frame timings.

In
`calendar-boundary-fd1d6ed-today-delay-diagnostic-v2-chrome.json`, the timer
deadline was `2,972,268 us` and callback entry was `2,991,899 us`, `19,631 us`
late. The deadline fell inside a driver-controlled ticker pump and a CanvasKit
raster interval from `2,944,399 us` through `2,990,099 us`. The timer entered
at the first post-frame event-loop opportunity. The catastrophic `_setView`
build began later, after hydration committed, so it did not delay this
treatment.

The first driver-isolation attempt is also quarantined: the integration binding
was still using its pump-owned frame policy, so no live frame ran and the
transaction timed out. The corrected isolation confines
`LiveTestWidgetsFlutterBindingFramePolicy.fullyLive` to the diagnostic block
and restores the prior policy in `finally`.

The fully-live result is
`calendar-boundary-fd1d6ed-today-delay-isolated-v4-chrome.json`. With no tester
pump around the transaction, the `2,947,768 us` deadline still fell inside the
first CanvasKit raster interval, `2,919,799–2,964,399 us`. Timer entry was
`2,966,200 us`, `18,432 us` late and at the first event-loop opportunity after
raster. The later `_setView` build started at `2,966,799 us`. This classifies
the delay as renderer-side event-loop contention: not ticker granularity, not
driver pumping, and not the build stall that hydration subsequently triggers.

The isolated treatment remained invalid: actual spatial progress was zero,
timing exceeded one display interval, and the target was not reached. This
named branch has not yielded a valid treatment design or a live smoke inside
sealed tolerances. The threshold was not relaxed, no Today A/B ran, and Today
A/B remains blocked.

The production `calendar_hydration_engine.dart`/benchmark preservation
`jumpTo` remains an empirically identified transaction-breaking writer.
Freeze-until-settle alone is not an adequate production fix: preservation must
be absorbed into the layout-coupled epoch correction or removed when semantic
anchoring makes it redundant.

Android remains owed. No device was attached during this slice, and no
CanvasKit result is promoted to an Android conclusion.

Umbrella status remains **STOP**. This document authorizes no production
implementation. The next production design review should replace the
page-wide `_setView` ownership contract rather than revert the final-day
handoff or land the disposable no-`setState` ablation.
