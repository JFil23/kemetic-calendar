# Navigation Contract

This app uses routes, sheets, one-shot intents, restoration, browser history,
native back, and local swipe gestures. New navigation code must choose one
category first and use the matching helper. When a surface does not clearly fit
a category, classify it as a utility route until product behavior proves
otherwise.

## Route Categories

### Primary Sections

Primary sections are app-level destinations selected from the main app chrome.
They use `openPrimarySection(context, section)`.

Approved durable primary sections:

- `/` Calendar
- `/rhythm/today` Planner
- `/nodes` Library
- `/journal` Journal
- `/inbox` Inbox
- `/settings` Settings
- `/reflections` Reflections

Primary section changes may record primary selection state only when
`navigation_persistence_policy.dart` returns `canRecordPrimarySelection`.
Primary sections are also durable surfaces when the policy returns
`canRestoreAsSurface`.

`/reflections` is primary selection state and a durable surface.
`/reflections/:reflectionId` is a pushed detail route: it can restore as the
last visible surface, but it must not record primary selection.

## Global Navigation

The side drawer is the only global navigation path. The app chrome exposes a
floating bottom-left menu bubble that opens a partial-width left drawer. Do not
reintroduce a bottom-centered global glyph menu, a 3x3 global navigation grid,
primary-section page swiping, or swipe-open drawer behavior.

The drawer rows are Calendar, Planner, Library, Journal, Inbox, Calendars,
Flows, Reflections, Profile, and Settings.

Drawer destinations follow the route categories above:

- Calendar, Planner, Library, Journal, Inbox, Reflections, and Settings use
  `openPrimarySection`.
- Profile is a drawer entry but opens `/profile/me` with `openDetailRoute`; it
  is not a durable primary section and must not record primary selection.
- Flows and Calendars use `/flows` and `/calendars` with `openUtilityRoute`.

Drawer state is local app chrome state. It is not restoration-backed and should
not be persisted.

Drawer composition is a reveal/push interaction, not an overlay interaction:

- `UX-DRAWER-001`: The drawer is an opaque surface behind the application
  foreground. It must not be translucent and must not be painted over a
  stationary Calendar.
- `UX-DRAWER-002`: Opening the drawer translates the entire foreground,
  including its header, routed surface, overlays, and menu chrome, to the right
  as one intact panel by exactly the drawer width.
- `UX-DRAWER-003`: Opening and closing use the shared drawer transition of
  approximately 250 ms. The foreground must remain continuously mounted for the
  full transition; drawer state changes must not reconstruct the routed page.
- `UX-DRAWER-004`: Closing the drawer returns the foreground to its original
  geometry and the exact pre-open Calendar offset, without a loading surface,
  paint gap, or restoration replay.
- `UX-DRAWER-005`: Drawer composition must not delay or reorder the existing
  destination dispatch and primary-route persistence contracts.
- `UX-DRAWER-006`: The single `GlobalMenuBubble` remains mounted inside the
  translated foreground throughout drawer open, close, and destination
  replacement. A drawer-row tap records its critical route state and requests
  the destination before it starts the independent close animation; the old
  page must not be visible again after the drawer has closed.
- `UX-DRAWER-007`: Every drawer row uses the one centralized, generation-
  guarded `GoRouter.go` dispatcher as a canonical replacement. Never mix root
  `Navigator` stack operations with router commands. Only the latest explicit
  drawer selection may request or commit a route; closing the drawer never
  navigates. Selecting the already-visible Calendar only closes the drawer.

Deterministic drawer coverage must prove closed, midpoint, open, and reclosed
geometry; fully opaque drawer material; shared translation of the header and
Calendar; preservation of the routed element identity; and exact scroll-offset
return. The Calendar scroll, stationary, background/resume, and drawer-stress
matrix must be replayed after any drawer-composition change because translating
the foreground can change compositor behavior without changing route state.

Back behavior:

- Primary route + drawer open: close the drawer.
- Primary route + drawer closed: open the drawer.
- Detail or utility route: keep the route's normal close/back behavior.

### Utility Routes

Utility routes are real app surfaces that should feel temporary. They use
`openUtilityRoute(context, location)` and close with `closeOrReturn(context, '/')`
unless a more specific fallback is required.

Locked utility routes:

- `/flows`
- `/calendars`

Utility routes are not primary selection state. They are durable surfaces while
they are real routes. From inside the app they should be pushed so back/close
returns to the previous real surface. Direct loads fall back cleanly to `/`.

Flow Studio and Calendars currently use route-backed sheet presentation: `/flows`
and `/calendars` remain real durable utility routes, but the route page renders
as a temporary sheet-shaped surface. This is different from contextual
`showModalBottomSheet` ownership. The route-backed sheet chrome owns its
outside-tap, close-button, and handle pull-down dismissal; the sheet body must
not dismiss on scroll unless scroll-position coordination is added explicitly.
If these become true contextual sheets later, durability must move from route
restoration into sheet/overlay restoration.

### Detail Routes

Detail routes show a profile, record, message, post, editor, or other temporary
surface. They use `openDetailRoute(context, location)`.

Examples:

- `/profile/:id`
- `/nodes/:nodeId`
- `/journal/entry/:id`
- `/flow-post/:id`
- `/insight-post/:id`
- `/inbox/conversation/:id`
- `/shared-flow/:id`
- `/event-invite/:id`
- `/maat-guidance/:id`
- `/reflections/:reflectionId`
- `/flows/:flowId/edit`

Detail routes should push from an existing app surface and use `closeOrReturn`
for close/back. Direct deep links should have a safe fallback. Detail routes are
not primary selection state. They can restore as durable surfaces when they are
real direct-loadable pages.

### Contextual Sheets

Sheets are owned by the currently visible surface and must open from that
surface's stable context.

Examples:

- Calendar event detail
- Calendar quick add
- Calendar-local Flow Studio
- Calendar-local Calendars
- Day View sheets

Sheets close with local modal pop behavior. Sheet persistence is best effort:
storage or restoration errors must not block sheet opening.

Do not open Calendar-owned sheets from temporary app-shell contexts. The drawer
opens Flows and Calendars through `/flows` and `/calendars` with route-backed
sheet presentation.

### One-Shot Intents

One-shot intents are commands, not history and not durable launch state.

Examples:

- Notification opens Day View
- Today button
- Calendars event/date opens Day View
- Search result opens Day View or event detail
- Shared calendar event opens Day View

The owner queues the intent, routes to the owning surface only if needed,
consumes once, and clears immediately after consume or failure. One-shot intent
handling must beat normal restoration.

## Helper Usage

- `openPrimarySection(context, section)`: primary app section switch, records
  primary selection only if policy allows.
- `openUtilityRoute(context, location)`: temporary app-level utility surface,
  pushed when possible, durable as a visible surface.
- `openDetailRoute(context, location)`: pushed detail or record surface,
  durable as a visible surface when it direct-loads safely.
- `closeOrReturn(context, fallback)`: pop real history first, then go to the
  fallback.
- Calendar intent helpers: queue command data, route to Calendar only when
  Calendar owns the target, consume once inside `CalendarPage`.

Raw `context.go`, `context.push`, `Navigator.of`, and `Navigator.pop` should be
rare. Allowed raw call sites are router setup, central navigation helpers, local
modal/sheet close code, or a call site with a short comment explaining why the
helper is not appropriate.

App-level GoRouter pages use calm route pages with no side-to-side slide
transition. Do not reintroduce right-to-left route slides for normal primary,
utility, or detail navigation without a product decision. Route-backed utility
sheets may use a short bottom-up/fade transition; contextual modal and sheet
animations are separate and are not governed by the route-page rule.

## Persistence Rules

Durable restoration is not browser history and not back history. It has two
separate layers:

- Primary selection: the app chrome/menu's selected primary section.
- Durable surface: the actual real route restored after app restart.

- Primary route changes may persist primary selection through
  `recordPrimaryTabSelection`.
- `SessionTrackedRoute` records real visible routes as durable surfaces after
  routing has built the page.
- Utility routes and detail routes must not overwrite primary selection.
- Query/action parameters are stripped or rejected before durability unless a
  parameter is explicitly approved as stable route state.
- Generic navigation attempts are logged for diagnosis but do not write durable
  state before a page becomes visible.
- User back/close and explicit user navigation should suppress restoration so a
  stored snapshot does not override the user's current action.
- Back/close from a pushed utility/detail route should update durable surface to
  the newly visible route or fallback.
- One-shot intents never write durable state until they resolve into a real
  visible route.

### Termination-Safe Primary Route Restoration

- `UX-RESTORE-001`: A durable primary-route selection must update the
  termination-safe critical snapshot synchronously in the same task as the user
  action and before the route request.
- `UX-RESTORE-002`: Shared mutation queues, cloud persistence, and secondary
  local writes may run asynchronously, but cannot gate, delay, or reorder the
  critical route snapshot.
- `UX-RESTORE-003`: If the process terminates immediately after the target route
  becomes visible, the next launch must restore that target without requiring
  any pending future to complete.
- `UX-RESTORE-004`: Only `recordPrimaryTabSelection(AppSection)` may write
  durable primary navigation state.
- `UX-RESTORE-005`: Restoration must not paint default Calendar as an
  intermediate or fallback when the critical snapshot identifies another valid
  primary destination.

`UX-NAV-001` still applies: synchronous critical recording plus route dispatch
must keep `tap_up → route_requested` p95 at or below 20 ms.

#### Deterministic Regression Test

The termination-safety regression test must:

1. Seed Calendar as the stored destination.
2. Block the shared asynchronous mutation queue.
3. Open Planner through the real production handler.
4. Do not await the persistence future or settle queued work.
5. Read the critical snapshot or instantiate a fresh restoration service.
6. Assert that Planner is already durable and restores.
7. Release the blocked queue only after the assertion.

This test must be red on `ac0780c`. A test that awaits the write is invalid.

#### Device Gate

Run five consecutive Planner → immediate swipe-termination → relaunch cycles.
Planner must restore five out of five times, with no Calendar fallback and no
loading-wheel-to-wrong-route sequence. Record the full build identity at the
beginning and end of the gate.

Smoke caveat: the deployed schema currently does not expose
`user_onboarding_helper_completions`, so onboarding helper overlays can appear
for the disposable PWA smoke account. Dismiss them manually per device during
smoke; do not suppress them in code for navigation persistence work.

## Swipe Policy

Do not add custom page-to-page swipe navigation. Visible app controls, global
navigation, close buttons, and system/browser/native back are the supported ways
to move between routes.

Internal full-body swipes are allowed only for isolated local content, such as
Node reader internal history, and must not conflict with system edge back. New
swipe systems need tests for gesture zones, thresholds, and outcomes.

Documented gesture systems:

- Node reader may use a body-zone right swipe for internal node history, but it
  must exclude the navigation edge zone so system/app back can win there.
- Journal archive and Inbox may use row-local `Dismissible` controls for
  destructive row actions.
- Calendar month/day/event detail, Planner cards, Profile carousels,
  onboarding slides, and similar `PageView` instances are local content paging,
  not route navigation.
- `flow_post_detail_page.dart` currently uses a detail-route `PageView` to page
  related flow posts. Keep it documented and monitored because it spans a route
  detail surface.
- `PinchGestureSurface` is a two-finger scale surface and is not swipe
  navigation.

There is no active Journal page-level swipe navigation. Do not reintroduce one
without a documented exception and tests.

There is no active Calendar page-to-page swipe navigation. Do not reintroduce
Calendar edge swipes or other route-changing page swipes without a documented
product decision and tests.

## Examples

Add a primary section:

1. Add a route.
2. Add an `AppSection`.
3. Add a durable policy entry only after product approval.
4. Open with `openPrimarySection`.

Add a utility route:

1. Add a real route page, not a dummy page.
2. Classify it as `NavigationRouteClass.utility`.
3. Open with `openUtilityRoute`.
4. Close with `closeOrReturn`.
5. If it should feel temporary, use route-backed sheet presentation instead of
   `showModalBottomSheet` from global/app-shell contexts.
5. Allow `canRestoreAsSurface`; do not allow `canRecordPrimarySelection`.

Add a detail route:

1. Add a route that can direct-load safely.
2. Open from app surfaces with `openDetailRoute`.
3. Close with `closeOrReturn`.
4. Allow `canRestoreAsSurface` when the page is real.
5. Keep it out of `canRecordPrimarySelection`.

Add a sheet:

1. Keep the sheet owned by its visible surface.
2. Open from that surface's stable context.
3. Use local modal close behavior.
4. Persist overlay state only when safe and best effort.

Add a one-shot intent:

1. Define the command payload.
2. Queue it without writing durable state.
3. Route to the owner only if needed.
4. Consume and clear it in the owner before normal restoration can override it.
