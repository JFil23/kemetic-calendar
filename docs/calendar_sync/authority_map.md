# Calendar sync authority map

This document is the Cut 0 contract for the native calendar projection. It is
derived from the mobile source served in production on 2026-08-20:

```text
SERVED_PRODUCTION_MOBILE_SHA = b898be0ec89a974776861908170a20d2e31974e5
SERVED_PRODUCTION_MOBILE_TREE = ca917ac6d51252ee0cdcfa78199554997a39dfa7
```

Cut 0 changes no runtime behavior. The source at the served SHA has the known
contract violations listed below. They are inventory, not authorization. Each
later cut removes only its named violations and must start from the mobile SHA
actually served after the preceding cut.

## Product contract

```text
Apple / Google calendar -> HAw projection
HAw calendar           -X-> Apple / Google calendar
```

The external calendar is authoritative for every imported event. HAw is a
read-only skin over those events and an independent authority for events made
inside HAw.

| Concern | Canonical reader | Canonical writer | Required behavior |
|---|---|---|---|
| Native event content | EventKit / Android Calendar Provider | Apple / Google or another native-calendar client | HAw imports title, detail, location, all-day state, start, end, and deletion. |
| Native event identity | Native occurrence identity | Native calendar provider | Recurring occurrences remain distinct; one occurrence edit/delete does not collapse the series. |
| Imported HAw row | Calendar hydration readers | Calendar sync reconciliation only | External content always wins, even if a HAw row has a newer timestamp. |
| HAw-created event | Existing HAw event authorities | Existing HAw mutation paths | It never enters a native-calendar bridge write path. |
| Imported-event UI | Existing calendar surfaces | None | Imported rows cannot use ordinary edit, move, resize, detach, or delete paths. The UI directs the user to Apple/Google. |
| Automatic sync setting | `SettingsPrefs` | Settings toggle | OFF pauses monitoring and retains imported rows. ON is persisted only after permission and first reconciliation succeed. |
| Unlink and clear | Settings action | Calendar sync cleanup | Stops sync, sets the toggle OFF, clears sync state, and removes only imported HAw rows. It never requests native write permission or changes the native calendar. |
| Visible refresh | Calendar invalidation/hydration authority | Calendar sync publication | A successful reconciliation that changes HAw rows publishes once through the existing calendar invalidation authority. |
| Permission | Native read permission | User / OS | Background and resume paths inspect permission silently. Only an explicit user action may prompt. |
| Freshness | Native observer, foreground catch-up, bounded fallback | Calendar sync service | Native changes reconcile promptly while ON; no reconciliation occurs while OFF. |
| Coverage | Rolling startup window plus rendered viewport | Calendar sync service | Fetch growth is isolated from reconciliation and freshness cuts. |

## Non-negotiable boundary

The completed feature must satisfy all of these mechanically:

- Android declares `READ_CALENDAR` and does not declare or request
  `WRITE_CALENDAR`.
- Android contains no native event insert, update, or delete implementation.
- iOS contains no EventKit save or remove implementation.
- The Flutter method channel exposes no native-calendar write method.
- Pause and unlink are different operations.
- Unlink never deletes native events, including historical HAw exports.
- Imported rows never enter ordinary HAw mutation or deletion-suppression
  paths.
- Reconciliation deletions do not create a client-suppressing tombstone.
- No automatic path prompts for calendar permission.

## Served-production violation inventory

The hostile Cut 0 guard pins this exact baseline so violations cannot expand
silently before their owning cut closes them.

1. Android declares and requests `WRITE_CALENDAR` and implements native
   insert, update, delete, and purge operations.
2. iOS exposes native upsert/delete/purge methods and calls EventKit save and
   remove.
3. The Dart bridge exposes native delete and purge operations; unlink can
   purge the device calendar.
4. Imported events can detach into ordinary HAw mutation paths and HAw-side
   deletion suppression can prevent an existing native event from returning.
5. A legacy reset can automatically invoke unlink/purge behavior.
6. Reconciliation filters some native holiday content, compares modification
   timestamps bidirectionally, and can collapse recurring occurrences.
7. Automatic sync is timer-led, prompts through the permission request path,
   and does not observe native changes or publish a calendar invalidation.
8. The default 30-day-past/180-day-future window has a visible coverage cliff.

## Closed production cuts

### Cut 0 — contract only

Runtime files: none.

Allowed files:

- `docs/calendar_sync/authority_map.md`
- `docs/calendar_sync/release_cutover.md`
- `test/services/calendar_sync_authority_guard_test.dart`

### Cut 1 — read-only boundary and user controls

Purpose: prove only that HAw cannot alter the native calendar, imported events
cannot enter ordinary mutation paths, toggle OFF preserves projections, and
unlink clears only HAw projections.

Expected runtime envelope:

- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/jaralephillips/hawcalendar/MainActivity.kt`
- `ios/Runner/AppDelegate.swift`
- `ios/Runner/Info.plist`
- `lib/features/calendar/calendar_page.dart`
- `lib/features/settings/settings_page.dart`
- `lib/features/settings/settings_prefs.dart`
- `lib/services/calendar_sync_service.dart`

Cadence, occurrence identity, reconciliation precedence, and range stay at the
served baseline in this cut.

### Cut 2 — reconciliation and occurrence identity

Purpose: make native occurrences authoritative for update/delete and distinct
for recurrence. Remove historical HAw-side suppression.

Expected mobile runtime envelope:

- `android/app/src/main/kotlin/com/jaralephillips/hawcalendar/MainActivity.kt`
- `ios/Runner/AppDelegate.swift`
- `lib/data/user_events_repo.dart`
- `lib/services/calendar_sync_service.dart`

The compatibility migration is a separate database production cut. It must be
additive, must be proven against the then-served old client, and must ship
before the Cut 2 mobile RC. No contract behavior is removed in that migration.

### Cut 3 — automatic freshness and publication

Purpose: native observers, debounce, foreground catch-up, timer fallback, and
publication through the existing calendar authority.

Expected runtime envelope:

- `android/app/src/main/kotlin/com/jaralephillips/hawcalendar/MainActivity.kt`
- `ios/Runner/AppDelegate.swift`
- `lib/main.dart`
- `lib/services/calendar_sync_service.dart`

### Cut 4 — range and coverage

Purpose: widen the rolling default window and lazily reconcile the rendered
viewport without changing reconciliation semantics.

Expected runtime envelope:

- `lib/features/calendar/calendar_page.dart`
- `lib/services/calendar_sync_service.dart`

Tests under `test/` may accompany each cut. Any other runtime file is a stop.

## Web scope

These cuts cover Apple and Google calendars exposed through iOS EventKit or
Android Calendar Provider. Direct Google Calendar OAuth for web is a separate
feature and must not be hidden in a native calendar-sync cut.
