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

Primary section changes may record durable launch state only when
`navigation_persistence_policy.dart` accepts the route as `durablePrimary` for
`NavigationSource.userPrimaryTab`.

`/reflections` is durable primary state. `/reflections/:reflectionId` is a
pushed detail route and must not become durable launch state.

### Utility Routes

Utility routes are real app surfaces that should feel temporary. They use
`openUtilityRoute(context, location)` and close with `closeOrReturn(context, '/')`
unless a more specific fallback is required.

Locked utility routes:

- `/flows`
- `/calendars`

Utility routes are not durable launch state. From inside the app they should be
pushed so back/close returns to the previous real surface. Direct loads fall
back cleanly to `/`.

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
not durable launch state unless explicitly approved.

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

Do not open Calendar-owned sheets from temporary global menu or app-shell
contexts. Global menu Flow Studio and Calendars use `/flows` and `/calendars`.

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

- `openPrimarySection(context, section)`: primary app section switch, durable
  only if policy allows.
- `openUtilityRoute(context, location)`: temporary app-level utility surface,
  pushed when possible, never durable.
- `openDetailRoute(context, location)`: pushed detail or record surface, never
  durable by default.
- `closeOrReturn(context, fallback)`: pop real history first, then go to the
  fallback.
- Calendar intent helpers: queue command data, route to Calendar only when
  Calendar owns the target, consume once inside `CalendarPage`.

Raw `context.go`, `context.push`, `Navigator.of`, and `Navigator.pop` should be
rare. Allowed raw call sites are router setup, central navigation helpers, local
modal/sheet close code, or a call site with a short comment explaining why the
helper is not appropriate.

## Persistence Rules

Durable restoration is not browser history and not back history. It is only the
approved primary launch destination after app restart.

- Primary route changes may persist through `recordPrimaryTabSelection`.
- Utility routes, detail routes, modal routes, and query/fragment routes must
  not persist as launch destinations.
- Generic navigation attempts are logged for diagnosis but do not write durable
  state.
- User back/close and explicit user navigation should suppress restoration so a
  stored snapshot does not override the user's current action.
- One-shot intents never write durable launch state.

## Swipe Policy

Calendar may keep primary-section swipes as a documented exception:

- Calendar left edge opens Planner.
- Calendar right edge opens Profile.

Other pages should use edge swipe for back or no custom edge swipe. Internal
full-body swipes are allowed only for isolated local content, such as Node
reader internal history, and must not conflict with system edge back. New swipe
systems need tests for gesture zones, thresholds, and outcomes.

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

Add a detail route:

1. Add a route that can direct-load safely.
2. Open from app surfaces with `openDetailRoute`.
3. Close with `closeOrReturn`.
4. Keep it out of durable launch policy.

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
