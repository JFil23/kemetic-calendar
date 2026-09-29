# Warm-state implementation verification — September 29, 2026

Implemented locally in the app-only RC checkout on branch `rc`, starting at
`68e8be450ecb1a00318a50fbc5644693e1b0db56`. This starting identity was verified
against the served RC receipt before implementation. No deployment was performed.

## Results

- Full Flutter regression suite: **3,080 passed, 1 skipped** using
  `flutter test --no-pub --concurrency=8`.
- The existing skip is `test/dst_fix_test.dart`: its DST expectation depends on
  the test timezone. No tests were skipped to accommodate this implementation.
- Final targeted checks after the Journal/DM/Planner boundary review: **70 passed**
  for Journal/conversation behavior and **42 passed** for Planner, conversations,
  persistence and scheduling.
- Storage and calendar integration checks: **24 passed**. These cover snapshot
  retention priority, complete flow pagination, passive warming, account fencing,
  permission denial, and existing calendar behavior.
- Flow layout and expansion regression checks: **27 passed**.
- Appearance ownership and populated-card failed-refresh checks: **4 passed**.
- Static analysis: no new errors, warnings or notices. Six existing
  `library_private_types_in_public_api` notices remain in the unchanged
  `calendar_active_maat_flows.dart`.
- `git diff --check` passes.

The counts above describe separate runs and overlap; they must not be added.

## Visual evidence

The populated Pages geometry was captured before integration. The final Pages
render passed comparison against that same image without updating the reference.
The before/after Notes/Reminders/Flows collection images are byte-identical:

`ca5e2638807ded4e07e94ee2e617b5ae255a11b8b7b00f718f1b6efc527b61c5`

Existing social-flow golden checks and canonical flow-detail/expansion contracts
also pass. The five-flow Day View housing and its opening extents are unchanged.

## Behavioral evidence

Tests verify successful empty snapshots versus cache misses, restoration into a
fresh store, failed refresh preservation, complete multi-page flow coverage,
request coalescing, bounded storage, account departure and mutation race fences,
explicit access denial, capped foreground recovery, and the scheduler's passive
request boundary. A populated Journal card stays ready during a delayed refresh
and after failure. Conversation mount/identity changes and Journal/message
mutation boundaries have dedicated regressions.

See [contract.md](contract.md) for the app-wide coverage ledger, four-law check,
and the 96-entry / 2 MiB working-set policy.

## Acceptance boundary

This is implementation and automated verification, not a deployed-device latency
receipt. Live RC/iOS cold-launch, process-kill/relaunch and network-throttling
acceptance remain deployment/device checks. First-ever, evicted or oversized
content can still require a cold read; existing authentication gates remain.
The system keeps known content visible while refreshing and does not invent
content when no usable snapshot exists.
