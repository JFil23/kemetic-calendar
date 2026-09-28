# Navigation lifecycle and calendar anchor repair

Date: 2026-09-28. Base source: `fc00d6f2887363b855566b8c6925caf0a4c940fa`.
Implementation authority: `/Users/jaralephillips/dev/kemetic-calendar-rc`, branch `rc`.
This report records pre-release implementation validation. Deployment identity
is determined by the live version receipt and the sealed release evidence.

## Acceptance and implementation

The authoritative reference is the existing canonical app, the recorded
Pages/social return symptom, and the three reproduced failures. Preserve the
existing visuals, expanded modes, Today, swipe/history navigation, and existing
Studio hosts. Do not change speculative keyboard/status-bar behavior or redefine
Studio return destinations without an established behavioral contract.

1. Pages now releases its pending-open ownership when the covering route is
   popped, including browser history restoration. Each open has its own token;
   a late completion from a removed route cannot release a newer open. Covered
   Pages and rapid repeated taps remain guarded. No timeout or polling is used.
2. `_MonthCard` receives optional current-decan anchor keys from its caller.
   The main calendar supplies its original global keys. Shared previews reuse
   the same rendering without claiming those main-calendar identities.
3. The layout-correction mailbox selects and retains one render anchor before
   layout. The viewport measures that same object's coordinate after layout;
   it never re-enters geometry-dependent widget selection during `performLayout`.
   Removed anchors produce no correction. Existing same-layout correction and
   fractional pinch behavior are preserved.

These are ownership changes at existing boundaries, not new navigation or
calendar implementations. No app debug prints, feature-disabling switches,
catch-and-ignore handlers, or replacement UI were added.

## Verification

- Before fixes: normal pop and the standalone visual reference passed; history
  restoration, route replacement, both direct Pages/Calendar entry cases, and
  simultaneously mounted previews failed (five failures total).
- After fixes: all 14 initial focused cases passed, including details-mode Today,
  every expansion level, keyboard show/hide, repeated orientation changes,
  route coverage/return, and direct Pages entry.
- Final targeted run: eight tests passed, including the extent inventory,
  rapid repeated taps, late completion of a removed route, anchor selection
  outside layout, missing/removed anchors, and fractional pinch preservation.
- Complete app suite: 3,025 passed, one skipped, and one failure for the
  stale extent-manifest hash. After its documented re-audit/update, the guard
  passed in the eight-test targeted rerun. The full suite was not rerun after
  that metadata-only correction; no runtime source changed afterward.
- Static analysis: zero errors or warnings; six pre-existing
  `library_private_types_in_public_api` informational notices remain in
  `calendar_active_maat_flows.dart`.
- Eight calendar preview images, rendered with app fonts across four expansion
  levels at 393x852 and 852x393, are byte-identical before and after.
- Actual Chrome history Back followed by real pane clicks opened Planner,
  Journal, Studio, Inbox, Calendars, Library, and Feed. The combined run then
  invoked the actual Calendar pane handler, completed six rotation cycles,
  tapped Today, and completed three Calendar/Pages return cycles. It ended with
  no captured Flutter errors, JavaScript page errors, or browser crashes.
- A separate fresh direct-Pages browser run passed the same Calendar checks.
- Simulator Safari history Back followed by a Planner pane tap opened the
  expected sheet. Attempted edge drags did not trigger history in this run;
  the post-fix gesture itself is not claimed as verified. The simulator was
  returned to Home.

The browser harness used real Pages, Calendar, profile, and Studio code, mocked
account data, and fixture bodies for unrelated destinations. Its synthetic
account was marked as having completed onboarding to match an existing user's
navigation flow. Early runner selector failures and an unset onboarding fixture
were corrected; their interrupted Calendar runs are not counted as passes.
The benchmark flag was already enabled in debug mode; account fixture state,
not that flag, needed correction. No production onboarding behavior was changed.

The extent hash guard initially rejected the changed month-renderer fragment.
The contributor list and equations were re-audited, the geometry-neutral key
ownership change was documented in `calendar_extent_contributor_inventory.md`,
and only the affected fragment hash was updated. Both the inventory script and
its widget-suite guard now pass.

## Limits and cleanup

The fixes resolve the three reproducible defects. They do not prove the cause
of the recorded iPhone process termination, nor establish a fix for persistent
status-icon disappearance or the unconfirmed viewport/keyboard classification
incident. No physical-device termination log was obtained in this change.

Temporary browser source, compiled probe output, and local server were removed.
Only permanent regression tests remain. Production and live deployments were
not modified; no branches, repositories, or worktrees were created. The changes were prepared on the existing RC branch for its release gate.
