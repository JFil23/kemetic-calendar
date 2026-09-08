# Unchanged-baseline guard proof

The two guard failures reported during this visual pass are reproduced on the
unchanged mobile baseline, not introduced by the mockup-fidelity edits.

- Baseline mobile commit: `662b313114a2ae0cb928ccc9f494d91918a8503a`
- Method: temporarily remove the visual working-tree delta, run each exact
  named test at that commit, then restore the delta. No baseline file was
  edited and no commit was created.

## Shared-calendar callback count

```sh
flutter test \
  test/features/calendar/shared_calendar_event_tap_navigation_guard_test.dart \
  --plain-name 'CalendarPage and Inbox pass the event tap callback into the sheet'
```

Unchanged-baseline result: failure at line 469. The guard requires at least
four matching Inbox callback sites; the baseline contains three.

## Gesture allowlist

```sh
flutter test \
  test/services/restoration_architecture_guard_test.dart \
  --plain-name 'custom gesture systems stay documented and allowlisted'
```

Unchanged-baseline result: failure. The expected allowlist has 40 files; the
baseline scan returns 41, with
`lib/features/calendar/the_reading_house/presentation/reading_house_detail_page.dart`
as the extra match.

These failures remain visible in verification. This document proves their
provenance; it does not waive, rewrite, or mark either guard as accepted debt.
