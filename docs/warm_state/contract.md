# App-wide warm state

Implementation authority: app-only RC checkout, branch rc. Starting source
68e8be450ecb1a00318a50fbc5644693e1b0db56, verified against the served RC receipt.

## Visual contract established before integration

The September 29 recordings identify interruptions, not replacement designs.
The current canonical widgets, Pages layout, and existing golden references
remain the visual authority. Baseline runs before implementation passed Pages
geometry/responsiveness, Notes/Reminders/Flows list rendering, and social flow
artifacts. Temporary captures: /private/tmp/haw-warm-pages-before.png and
/private/tmp/haw-warm-lists-before.png. The social-flow golden also passed.

Warm, refreshing, and failed-refresh states keep the populated layout, artwork,
selection and scroll position. A confirmed empty dataset uses the existing empty
state. Unknown content may show the existing cold loading state; never fabricate
content. Pagination may show progress without removing the preceding page.
Account changes and confirmed access revocation must not retain private content.
The five-flow Ma'at Day View housing and its extents remain unchanged.

## Data contract

Repositories own resource identities, serialization, coverage and mutations.
Shared infrastructure owns bounded persistence, request coalescing, scheduling,
and account-generation checks. It is not a new backend or calendar authority.
Calendar keeps its existing lossless snapshot/overlay owner. Journal keeps dirty
editor conflict resolution. Library keeps its canonical catalog/progress owner.
Passive warming must not mark read, join, create, upload pending changes or
trigger analytics. It must not instantiate hidden pages.

Distinguish absent, complete-empty, populated, stale, and failed refresh. A partial
list is complete only for its recorded page/window. Never infer complete flow
events from a dashboard summary or interpret a failed fetch as successful empty.
Publish live data before best-effort persistence; storage failure cannot block UI.
Restore a bounded local working set; do not await all-network warmup at launch.
Warm primary destinations first, then recently used details, with bounded work.

## Coverage and acceptance ledger

Every row needs implementation evidence and verification before completion.

| Surface | Existing owner/reference | Status |
|---|---|---|
| Calendar and Day View | Existing CalendarSnapshotStore and canonical five-flow widgets | Preserved; calendar/Day View regression suite |
| Pages cards | PagesReadRepository / AccountViewCache | Durable passive reads, restored projections, background refresh; resource tests and pre-change pixel comparison |
| Notes / Reminders / Flows collections | EventFilingRepo / FlowsRepo | Cached first pages with existing pagination and date boundaries; collection tests |
| Owned and shared flow details | SharedFlowDetailsPage / canonical flow renderer | Seed complete events with the flow; retain content during refresh; pagination, runtime, visual and expansion tests |
| Profile, Feed and post details | ProfileRepo | Reuse existing profile caches; durable feed and complete post reads; preserve selected post across refresh |
| Inbox, invitations and conversations | ShareRepo and Inbox repositories | Reuse existing inbox/invite restoration; add cached DM summaries/messages and a stable message stream |
| Planner and tracker | RhythmRepo and existing local stores | Restore passive reads and local nutrition/notes first; keep newer local edits; rhythm tests |
| Journal, archive and entry details | JournalController / JournalRepo | Apply local draft before server read; preserve dirty conflict guard; durable archive/detail reads; journal tests |
| Library and reader progress | LibraryReadProgressStore | Restore existing local progress and scroll before remote merge/recordOpened; reader tests |
| Calendars and calendar details | SharedCalendarsRepo | Preserve cached lists; cache complete event windows and member rosters; calendar tests |
| Reflections and guidance | DecanReflectionRepo / MaatGuidanceRepo | Cached archives/details; paint before ancillary links and acknowledgements; reflection/guidance tests |
| Settings | SettingsPrefs | Local controls no longer wait for native calendar status |
| Artwork | FlowAppearanceStore | Retain existing eight-image memory cache; persist eligible images under account scope; images yield space to primary pages |
| Lifecycle, edits, deletion, account switch and day boundaries | AppWarmState / WarmWorkQueue / existing mutation owners | Foreground scheduling, generation fences, scoped invalidation, day/timezone expiry and retry recovery; warm-state tests |

Verification must cover slow/offline requests, repeat navigation, process restart,
empty versus failed reads, mutation races, account switches, bounded work, and
visual fidelity. Unit tests alone do not prove live latency or visual completeness.
No deployment or release is implied by implementation verification.

## Operational boundaries

The coordinator starts after the first frame and runs at most two jobs at once.
It schedules primary resources before up to six recently used detail resources,
pauses new jobs in the background, and refreshes on account entry, foreground
resume, calendar invalidation, date/timezone changes, and a five-minute foreground
sweep. A refresh cycle resets the existing capped view retry budget. Warming
calls passive repository reads, never hidden widgets or the screens' write-bearing
loaders. The tests inspect outbound requests to enforce this boundary.

Snapshots have explicit repository keys, account identity, schema version,
update time and confirmed JSON data. The working set is capped at 96 entries and
2 MiB per account; individual payloads over 1 MiB are not retained. Artwork is
lower priority than primary destinations. Persistence is best effort when device
storage is unavailable. Missing, evicted, or never-fetched data can still require
a cold read. Existing authentication refresh gates remain intact. This does not
promise zero network latency for unknown content or an infinite offline archive.

Mutation boundaries invalidate before and after writes, fencing older requests.
Account departure clears these snapshots and artwork. A confirmed null result
removes detail content; explicit permission denial evicts the corresponding
snapshot. Temporary read failures retain the last successful data. Journal's
existing draft conflict owner remains authoritative. No backend schema, routing
geometry, Day View housing extent, release authority or deployment changed.

## Four-law check

1. Shared persistence and scheduling have one owner, with domain codecs and
   mutations remaining in their existing repositories.
2. Existing calendar snapshots, profile/share/calendar caches, journal drafts,
   library progress, image LRU and canonical detail widgets are reused.
3. Existing visuals were established before integration. Pages matches its
   pre-change capture, collection captures are byte-identical, and canonical
   flow layout/expansion regressions pass without replacing golden references.
4. The coverage ledger accounts for the app-wide scope and the cold/storage/auth
   boundaries above. Automated checks do not substitute for a live device/network
   acceptance run on a deployed candidate; this change has not been deployed.
