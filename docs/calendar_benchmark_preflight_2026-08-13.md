# Calendar benchmark preflight — 2026-08-13

Status: CanvasKit-partial baseline sealed with a hard-gate failure; Android
baseline remains owed.

The pre-cleanup capture is at
`/tmp/calendar-benchmark-environment-20260813-final`. It contains git status and
worktrees, Flutter/Dart and Apple toolchain versions, connected-device facts,
lockfile copies and hashes, and the resolved `flutter pub deps --json` graph.
No cache or build product was deleted.

Key facts from the capture:

- Flutter 3.35.2 / Dart 3.9.2
- macOS 15.7.4 / Xcode 26.3 / CocoaPods 1.16.2
- physical iPhone `00008110-0004058E0A2A801E`, iOS 26.2.1
- Chrome 151.0.7922.109
- no Android device attached
- approximately 19 GiB binary free (about 21 GB decimal) after the approved
  cleanup; temporary profile work later left 18 GiB binary while preserving
  the agreed headroom range

Read-only disk inventory found:

- Xcode DerivedData: 1.6 GiB
- CoreSimulator data: 12 GiB
- Gradle caches: 6.2 GiB
- current mobile `build/`: 1.1 GiB
- pub cache: 806 MiB
- iOS DeviceSupport: empty

The headroom gate is discharged. The Gradle and pub caches were not used as
benchmark cleanup targets. Temporary web build output and the exact 951 MiB
Xcode DerivedData folder created by the failed iPhone benchmark attempt were
removed after their runs; shared Xcode module data was retained.

CanvasKit dormant-observer parity passed in clean detached `5ff6600`
worktrees with the benchmark define false and the renderer defines recorded as
`FLUTTER_WEB_USE_SKIA=true` and `FLUTTER_WEB_USE_SKWASM=false`. Matched
repetition medians were build p95 `+0.00%`, raster p95 `-1.73%`, and jank
`+0.38` percentage points. Raw artifacts and the reduced report are in
`docs/benchmark_artifacts/calendar_geometry/2026-08-13/canvaskit-observer`.

`git worktree list` also reports numerous prunable records whose target
directories no longer exist. They do not account for the large disk use and
should not be confused with live worktrees or used as a reason for broad
deletion.

Remaining execution blockers:

1. deploy the eventual RC for user-led Android validation; the Android
   numerical baseline is still owed and no paint result is final without it
2. restore usable Apple signing for the app and widget extension, then prove
   observer parity and run the baseline on the physical iPhone

The identical foundation overlay is already present in clean detached
`fd1d6ed` and `5ff6600` worktrees with matching `pubspec.lock` hashes. All four
boundary matrices and all four Today workloads completed in the all-scenario
diagnostic. The five-repetition CanvasKit pair is sealed as a partial baseline
in `docs/calendar_canvaskit_partial_baseline_2026-08-13.md`. Its hard gate
failed; that failure grants no production implementation authority.

Goldens and every production behavior track remain locked while these steps are
open.
