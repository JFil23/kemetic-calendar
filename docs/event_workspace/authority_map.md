# Event Workspace authority map (PR 0 census)

Re-derived from source on this PR. Do not treat later PRs as authorized until this cut is the **served production** mobile SHA.

Defining product rule: Event Workspace may present, derive, request, and observe. It may not own event identity, event time, completion, navigation, restoration, or persistence.

```text
Workspace code may request an event-time mutation. It may not perform one.
```

`requestEndChange` **does not exist**. Do not call `UserEventsRepo` or `_moveEventInDayView` as-is.

## Compact matrix

| Concern | Canonical reader | Canonical writer | Trigger | Notes |
|---|---|---|---|---|
| Occurrence identity | `eventMatchesDetailRestorationState` / `eventDetailTargetFromRestorationState` (`day_view.dart`) | `eventDetailRestorationStateForTarget` | open / persist / restore | Encoder prefers cid → id → reminderId. Live match prefers id → cid → reminderId. Push encoder prefers cid → reminderId → id. |
| Resource | `_dayViewExternalActionForEvent` (`day_view.dart`) | none (derived) | detail sheet build | Precedence: `behaviorPayload` keys → detail URLs → location. Duplicate incomplete sniff: `calendar_flow_pages.dart` `contains('youtu')` on location only. |
| Detail presentation | `CalendarEventDetailSheet` | four `showModalBottomSheet` hosts + `CalendarEventDetailSheetCoordinator` mutex | tap, restore, handoff | Day View, Main Calendar overlay restore, portrait chip, Landscape. |
| Real schedule | `_Note.start`/`end`, `UserEvent.startsAt`/`endsAt` | `upsertByClientId` / `update` / `replace` / repeating persist | day-sheet save, `_moveEventInDayView` | All-day: `_Note` times are **null**. `endsAt` nullable. |
| Paint schedule | `_eventItemFromNote` → `EventItem.startMin`/`endMin` | none (derived) | Note → EventItem | All-day paints 09:00–17:00. Missing timed start/end also fall back to 9/17. **Not a deadline.** |
| Clock / resume | `RestorationCoordinator` last lifecycle; `SessionResumeService` prefs | `SessionLifecycleBridge.didChangeAppLifecycleState` | app pause/resume | **No subscribable resume listenable.** Do not add another `WidgetsBindingObserver`. PR 3 may add the smallest notifier on `RestorationCoordinator.noteLifecycleState` resumed. |
| Time mutation | — | **no end-only silent API** | drag move (start+duration); day-sheet save (interactive) | `_moveEventInDayView` preserves duration, bails all-day and reminders. |
| Recurrence | `_repeatingNoteFlowForId` | `_applyRepeatingNoteEditScope` | scope sheet | `CalendarRecurringMutationScope`: this / thisAndFuture / entireSeries. |
| Optimistic calendar | `_notes` | `_publishCalendarNoteMutation` | `_addNote`, move, save | Day view rebuilds via `_notifyDayViewDataChanged` → `_dayViewDataVersion++`. |
| Notifications | Notify rows | `_scheduleAlertForEvent` | save / move | `_addNote` does not schedule. |
| Completion | `user_event_completions` + local store | `_recordEventCompletion` via `onRecordCompletion` | detail completion UI | Workspace must not call these. |
| Restoration | overlay `calendar.eventDetail` + nested `DayViewRestorationState.eventDetail` | `_saveCalendarEventDetailOverlayState` / day-view persist | target change / close | `EventDetailRestorationState` has **no** `mode` or `presentation` field. Flow Studio already uses overlay `mode`. |
| Hydration of open sheet | `resolveCurrentEventTarget` inside sheet `ValueListenableBuilder` | `_dayViewDataVersion` | data mutation | Three resolver copies (day view, calendar page, landscape). |

## 1. Event identity

**Files:** `lib/services/app_restoration_service.dart`, `lib/features/calendar/day_view.dart`, `lib/features/calendar/calendar_page.dart`, `lib/features/calendar/calendar_flow_studio_models.dart`

Types: `clientEventId`, `eventId` (`EventItem.id`), `reminderId`. Overlay kind `_kCalendarOverlayKindEventDetail = 'calendar.eventDetail'`.

Live occurrence is `DayViewSheetEventTarget` (`ky`/`km`/`kd` + `EventItem`).

## 2. Resource

**Authority:** `_dayViewExternalActionForEvent` in `lib/features/calendar/day_view.dart`.

Payload keys: `url`, `uri`, `href`, `link`, `external_url`, `external_link`, `action_url`, `meeting_url`, `video_url`, `watch_url`, `document_url`, `map_url` (compact forms too).

Launch: `_buildDetailExternalActionButton` → `launchExternalTarget` in `lib/utils/external_link_utils.dart`. YouTube hosts `youtube.com` / `youtu.be` are in `_nativePreferredHosts` (native app first).

**Not the authority:** `calendar_flow_pages.dart` `_contentForDashboardDay` labels location with `contains('youtu')` and does not walk payload or detail. PR 1 must replace that fork with a shared `EventResourceSource { behaviorPayload, detail, location }` resolver. Do not force callers to manufacture `EventItem`.

`EventItem` has `detail` / `location` / `behaviorPayload` and **no** `actionId`. `FlowEventRow` has those plus `actionId` and UTC times.

## 3. Detail presentation

**Surface:** `CalendarEventDetailSheet`. **Mutex:** `CalendarEventDetailSheetCoordinator`.

Hosts:

- `day_view.dart` `_showEventDetail`
- `calendar_page.dart` `_openCalendarEventDetailSheet`
- `calendar_grid_widgets.dart` `_showEventDetailFromNote`
- `landscape_month_view.dart` `_showEventDetail`

Do not add a second coordinator or overlay kind.

## 4. Real vs paint time

Durable: `UserEvent.startsAt` (required), `endsAt` (nullable), `allDay`.

In-memory real: `_Note.start` / `end` (`calendar_note_model.dart`). All-day stores **null** times.

Paint: `_eventItemFromNote` (and copies in landscape, `CalendarPageState._noteToEventItem`, grid). All-day → 9:00–17:00. Workspace session eligibility must use real `_Note` / `UserEvent` ends, never `EventItem.endMin` for all-day or missing-end events.

```text
workspacePresentable  = resolved EventResource exists
sessionGovernable     = presentable && timed && real start && real end
```

## 5. Clock / resume

`SessionLifecycleBridge` (`lib/services/session_resume_service.dart`) is the app-wide `WidgetsBindingObserver`. It calls `RestorationCoordinator.noteLifecycleState`, touches `SessionResumeService` on pause, and `Notify.syncLocalDeliveryMode()` on resume.

`SessionResumeService` is **persistence**, not a clock.

`RestorationCoordinator.noteLifecycleState` records `_lastLifecycleState` and has **no listeners**.

Existing observers (do not add another): `CalendarPageState`, `_FlowStudioPageState`, `_ProfilePageState`, `_ProfileDayCycleBackdropState`, `_KemeticNodeListPageState`, `_KemeticKeyboardHostState` (metrics), `_SessionLifecycleBridgeState`, `_GlobalOverlayShellState`, `_JournalRoutePageState`, `_AuthGateState`.

**PR 3 specification (do not implement in PR 0):** smallest `ValueNotifier`/`ChangeNotifier` fired from `RestorationCoordinator.noteLifecycleState` on `AppLifecycleState.resumed`. Workspace listens to that.

## 6. Time mutation (requestEndChange)

**Does not exist.**

| Path | Shape | Silent? | Workspace may call? |
|---|---|---|---|
| `_moveEventInDayView` | preserves duration from `endMin - startMin`; bails all-day and reminders; may prompt repeating scope; imported detach | yes (except scope sheet) | **No** (wrong shape) |
| `_editNoteByEvent` | opens day sheet | no | **No** |
| `_saveSingleNoteOnly` / `_updateSingleNoteOnly` | start+end together, interactive save | no | **No** as-is |
| `_applyRepeatingNoteEditScope` | occurrence vs series | after scope | **No** as-is |
| `UserEventsRepo.update` | optional `startsAt`/`endsAt` patch by id | storage sink | **No** |

**PR 5-prep extract FROM (if census still holds at that PR):** persist + `_publishCalendarNoteMutation` + `_scheduleAlertForEvent` / `Notify.scheduleAlertWithPersistenceResult` + `_notifyDayViewDataChanged` used by `_moveEventInDayView`, using `UserEventsRepo.update`'s optional `endsAt`, without drag/bail/scope UI. Own production cut. RC through **existing calendar UI**, not Workspace. No workspace caller in that PR.

Birthday: `_isBirthdayOccurrence` is read-only in `_editNoteByEvent`. Imported device: `isImportedDeviceCalendarEvent` detaches on move/update.

## 7. Optimistic state, notifications, completion, hydration

- Optimistic writer: `_publishCalendarNoteMutation`
- Day-view trigger: `_notifyDayViewDataChanged` → `_dayViewDataVersion`
- Alerts: `_scheduleAlertForEvent`
- Completion: `_recordEventCompletion` / `onRecordCompletion` — Workspace must not call
- Open sheet refresh: `ValueListenableBuilder` on `dataVersion` then `resolveCurrentEventTarget`

## 8. Restoration

`EventDetailRestorationState`: `kYear`, `kMonth`, `kDay`, `identityType`, `identityValue`, optional `parentSurface`, optional `updatedAtMs`. **No `mode`. No `presentation`.**

Later workspace restore may add field **`presentation`** (never overlay `mode`; Flow Studio owns `mode`). Persist identity only; re-derive resource and deadline.

If day view is open, overlay `calendar.eventDetail` is cleared; nested day-view `eventDetail` wins.

There is no `lib/features/calendar/event_workspace/` directory yet. No `HtmlElementView` in the repo. No `enableEventWorkspace` flag yet (Activation PR adds `true`; earlier product PRs may add `false` when they first gate UI — not PR 0).

## Per-PR allowed-delta contract

Exact envelopes. One unexplained runtime file in a production cut is a stop. Tests/docs listed may accompany the same cut.

### PR 0 (this cut)

Runtime: **none**.

Allowed:

- `docs/event_workspace/authority_map.md`
- `docs/event_workspace/release_cutover.md`
- `test/features/calendar/event_workspace_authority_guard_test.dart`

### PR 1 — Resource authority

New runtime (prefix): `lib/features/calendar/event_resource*.dart` (or equivalent single extractor library).

Existing call-site seams only:

- `lib/features/calendar/day_view.dart` (`_dayViewExternalActionForEvent` and helpers / `_buildDetailExternalActionButton`)
- `lib/features/calendar/calendar_flow_pages.dart` (`_contentForDashboardDay` `youtu` fork)

Forbidden: `lib/utils/external_link_utils.dart` behavior change; `UserEventsRepo`; new coordinator.

### PR 2 — Presentation

New runtime prefix: `lib/features/calendar/event_workspace/` (presentation + placeholder renderer only).

Seams:

- `lib/features/calendar/day_view.dart` (`CalendarEventDetailSheet`, coordinator remains the mutex)
- `lib/services/app_restoration_service.dart` (`presentation` field on `EventDetailRestorationState` only if restore is in this PR)

Forbidden: paging remaining active in workspace; `HtmlElementView` in timeline files; clock; mutation.

### PR 3 — Derived clock

Prefix: `lib/features/calendar/event_workspace/` clock derivation.

Seam: `lib/services/restoration_coordinator.dart` (smallest resume listenable) and/or `lib/services/session_resume_service.dart` (`SessionLifecycleBridge` already observes). **No new `WidgetsBindingObserver` class.**

### PR 4 — Expiry

Prefix: `lib/features/calendar/event_workspace/` expiry predicate + renderer pause. No calendar mutation files.

### PR 5-prep — End-only mutation extract

`lib/features/calendar/calendar_page.dart` mutation machinery only (`_moveEventInDayView` persist path, `_publishCalendarNoteMutation`, `_scheduleAlertForEvent`, `_notifyDayViewDataChanged`). **No `event_workspace` caller.** Own production cut.

### PR 5 — Workspace request

`lib/features/calendar/event_workspace/` request call + the already-shipped seam. Do not bundle with 5-prep.

### PR 6 — YouTube renderer

`lib/features/calendar/event_workspace/` renderer path only. `HtmlElementView` only there. Do not change `lib/utils/external_link_utils.dart`.

### PR 7 — Hostile tests

`test/` first. Product defects become 7a/7b each with one production cut.

### Activation

Runtime: `lib/core/feature_flags.dart` only (`enableEventWorkspace = true`). RC-test the compiled artifact.

## Event Workspace RC implementation (this branch)

Integrated on `codex/event-workspace-youtube-rc` from PR 1 (`3159b9b`). Census above remains the PR 0 snapshot.

- `enableEventWorkspace` gates inset YouTube. Flag-off still uses `launchExternalTarget`.
- Presentation field on `EventDetailRestorationState` is `presentation` (`detail` | `workspace`), never overlay `mode`.
- `RestorationCoordinator.resumeListenable` is the resume seam. No new `WidgetsBindingObserver`.
- `CalendarPageState.requestEndChange` is the end-only request seam. Workspace does not call `UserEventsRepo`.
- `HtmlElementView` lives only under `lib/features/calendar/event_workspace/`.
- Session deadline uses canonical timed start/end, never all-day paint `EventItem.endMin`.

