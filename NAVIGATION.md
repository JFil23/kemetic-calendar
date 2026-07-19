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

### Approved Drawer Resolution Rules

The following rules were approved on 2026-07-17. Visual section selection and
navigation dispatch are separate decisions: prefix/section matching may style a
row as selected, but it must not make a detail route behave like an exact
canonical root.

1. **Exact primary root.** Selecting the same drawer row while its exact
   canonical primary root is visible closes the drawer in place. It issues no
   route request, mutates no router, browser, drawer, or durable history, and
   preserves the mounted element and viewport. This applies to every primary
   root, not only Calendar.
2. **Matching primary detail.** Selecting the matching primary row from a
   same-section detail or subroute resolves in one of two ways:
   - When the matching canonical primary base is already mounted beneath the
     detail, pop every detail/overlay above that base and expose that same
     element with its scroll position and mounted state intact. Do not rebuild
     it merely to obtain the canonical URL.
     Matching-base resolution records the explicit primary selection and
     canonical durable surface.
   - When no matching base exists, including a genuine deep link or a detail
     pushed over a foreign primary, use the centralized primary-replacement
     authority, resolve to the selected canonical root, and record the explicit
     primary selection durably. A foreign base is never a matching base.
3. **Different primary.** Selecting another primary row replaces the primary
   base through the centralized authority, records the explicit primary
   selection durably, and discards obsolete detail or utility state from the
   previous primary.
4. **X and back.** X/back preserves history, removes only the top applicable
   surface, and exposes the mounted route beneath it. It never automatically
   resets to Calendar while valid history exists.
5. **Utility child.** Flows, Calendars, and Profile are history-preserving
   utilities, not primary replacements. Selecting a matching utility row from
   one of its children canonicalizes only the top overlay, preserves the
   mounted primary base, and does not duplicate the utility. Canonical utility
   locations are `/flows`, `/calendars`, and `/profile/me`. Profile remains
   technically a detail route opened through `openDetailRoute`, but the Profile
   drawer row follows Rule 5's history-preserving utility-overlay resolution
   semantics.
6. **Utility without a local stack.** A utility with no valid local stack
   returns to the last identity-matching durable primary. Reject foreign-
   identity state and never adopt a detail or utility as the primary fallback.
   Calendar is the fallback only when no valid identity-matching primary
   exists. This rule does not change broad restoration precedence.
7. **Post-resolution app-stack, durable, and browser history.** Jarale's
   2026-07-18 product decision makes browser history authoritative when the user
   explicitly traverses it. The following platform-scoped semantics apply:
   - **App-stack back.** Native platform back, a visible X, and
     `routerDelegate.popRoute()` operate on the current app stack. When Rule 2
     finds the matching mounted primary base, it removes every app detail or
     overlay above that base while preserving that base's `State`, `Element`,
     scroll offset, page, and other mounted state. A later app-stack pop cannot
     return a detail that Rule 2 removed from the current app stack.
   - **Durable restoration.** Rule 2 records the explicit primary selection and
     canonical durable surface. Refresh or relaunch immediately after Rule 2
     restores the canonical primary root; a removed detail is not an automatic
     launch destination.
   - **Browser Back and Forward on web.** These controls explicitly navigate
     historical browser entries and may restore a detail that Rule 2 removed
     from the current app stack. `RouteInformation.state` can differ even when
     the address URI is the same, and not every browser entry must have a
     distinct URL. NAV-IMPL-001 does not erase browser entries. This deliberate
     platform asymmetry is not a Rule 2 defect.
   - **Browser-restored detail.** A detail restored by browser history must be a
     coherent, valid routed surface: never blank, mixed, duplicated, partial, or
     paired with an invalid underlying primary selection. After the restored
     detail finishes building, it becomes durable through the normal policy and
     a subsequent refresh restores that detail normally. The address URI alone
     does not identify an imperative detail when it shares the primary URI.
     The last valid visible surface is authoritative: Library may remain the
     durable primary selection while a valid Library detail such as Cosmic
     Order is the durable visible surface. Relaunch restores Cosmic Order when
     it was last visible, and restores Library when the user returns to and
     leaves from Library. Never automatically reset a valid durable detail to
     its primary root or to Calendar during relaunch. This restoration rule is
     locked for later navigation and restoration tickets.
   - **Deferred strict erasure.** Erasing browser history requires separate
     product and systems authority. `BROWSER-HISTORY-AUTH-001` is deferred and
     not funded; it is outside NAV-IMPL-001 and must not be implemented
     incidentally by another ticket.

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
  the destination before it starts the independent close animation. Primary
  replacement must not leave an obsolete page visible after close.
- `UX-DRAWER-007`: Every drawer row uses one centralized, generation-guarded
  dispatcher. Calendar, Planner, Library, Journal, Inbox, Reflections, and
  Settings are canonical primary replacements; Calendars, Flows, and Profile
  are history-preserving pushes. Never mix root `Navigator` stack operations
  with router commands. Only the latest competing selection may request or
  commit a route; closing the drawer never navigates. Selecting any exact,
  already-visible canonical primary root only closes the drawer. A visually
  selected detail still resolves through Rule 2.
- `UX-DRAWER-008`: Drawer history persists a valid base route plus its utility
  and detail stack. Closing an X pops exactly the top stacked surface and
  reveals the same mounted base state. A cold launch restores the base before
  replaying valid stacked utilities; it must not reset to Calendar while valid
  history exists.

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
`openUtilityRoute(context, location)` and close by preserving a valid local
stack first. Without one, Rule 6 selects the identity-matching durable primary;
`/` is only the final fallback when no valid primary is available.

Locked utility routes:

- `/flows`
- `/calendars`

Utility routes are not primary selection state. They are durable surfaces while
they are real routes. From inside the app they should be pushed so back/close
returns to the previous real surface. Direct loads follow Rule 6.

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
- The last valid visible surface controls relaunch independently of primary
  selection. A valid detail above Library may restore while Library remains the
  selected primary; returning to Library makes Library the durable surface.
  Restoration must not automatically replace either valid surface with
  Calendar.
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
