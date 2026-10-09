# Persistence change contract

The existing populated app and the user's September 29 screen recordings are
visual/navigation references. Planner cards, nutrition scheduling, and the
five-flow Day View housing remain unchanged.

## Two distinct lifetimes

WarmSnapshotStore is an account-scoped, bounded, disposable read cache. Its
`warm_snapshot:v1:` namespace is independent of application builds. Each resource
family now has a schema version and migration path. Deployed envelope schema 1
without resourceSchema still reads as resource version 1. Unsupported payload
versions remain cache misses, never successful empty content. Row payloads are
validated before replacing confirmed snapshots.

PlannerAccountStore owns durable authored intents outside that cache. It writes
stable mutation IDs to `planner_account:v1:<account>` before publishing an edit or
making a network request. These records are not evicted or erased on logout.
Retries run at startup, after authentication/resume, and periodically while the
app is in the foreground. Browsers cannot guarantee execution while suspended;
retries resume when the app can run again.

The existing alignment_notes and nutrition_items tables remain authoritative.
Their monotonic revisions advance even for older clients. Backend mutation
receipts preserve idempotent responses and conflicting versions under owner RLS.
Every request carries its expected account and row revision. A timeout cannot
turn a retry into a duplicate creation. A stale edit cannot silently replace a
newer edit or recreate a deleted record. The user can review both versions;
choosing a version remains conditional on the version that was displayed.

Legacy local note and nutrition backups are retained. New local records receive
deterministic migration identities. A legacy value that differs from an account
row is preserved for conflict review instead of overwriting the account row.
Successful account-empty reads no longer resurrect previously synced cached rows.
Nutrition checkmarks reuse journal_badges, with atomic account-fenced replacement
instead of separate delete/insert requests. The visible checkmark changes only
after account confirmation. Existing checklist/badge domain owners are retained. Opening Planner no longer
replays cached checkmarks into journal_badges. Legacy checkmark backups are
retained unchanged locally and archived in the owner-protected account recovery
table; they do not overwrite current account truth. Recovery of an ambiguous
legacy checkmark requires choosing its intended state, not automatic replay.

The existing inline notice geometry now distinguishes pending sync, unavailable
refresh and account-preserved conflicts. A healthy state adds no notice. Read
failure is not evidence that an already saved row is device-only.

## Required evidence when changing this contract

- Old-release fixtures restored by current readers, with zero network dependency.
- Resource migration and unsupported-format behavior.
- Slow/failed refresh retains usable content; permission/account changes fence it.
- Mutation invalidation and passive background warming remain separate.
- Durable writes survive restart, lost acknowledgement, interleaved edits and logout.
- Conflicts are recoverable by a fresh client with empty local storage.
- Backend RLS, anonymous denial, explicit account fencing and atomicity tests.
- Visual inspection of changed states before persistence integration, followed by
  regression checks against existing views.

The release inventory guard tracks route ownership, persistent read boundaries,
and lifecycle integration. It catches common accidental removals and requires
review of newly added routes. It complements behavioral tests; it cannot prove
all arbitrary future code changes safe. Future schema changes must keep the old
fixtures and add new ones, not replace them.

## Verification status

Implementation is pending the complete app/backend release gates and served RC
replay. Focused restart, retry, conflict, migration, warm-upgrade and notice tests
pass. Disposable backend smoke verifies concurrent updates, duplicate requests,
deletes, privacy boundaries and nutrition badge retry/reset. No physical-device
background execution or offline-to-online browser replay is claimed from those
tests alone.

## September 30 event editor corrections

The full event editor continues to use its existing DaySheet restoration owner.
`NoteDraftInvitations` adds optional account-fenced invitee selections to that
editor payload; older payloads without `invitations` restore an empty selection.
Selecting people and cancelling the picker perform no sharing writes. Save uses
the existing UserEventsRepo note writer, waits for its acknowledgement, and then
uses ShareRepo's event invitation boundary. A confirmed target is retained for
manual retries so a partial invitation failure cannot create another note.
Repeating notes retain the acknowledged hidden-flow identity while their first
occurrence is being materialized. The editor locks acknowledged note fields
and offers Retry for unconfirmed invitations. This is an editor draft, not an
automatic background invitation queue. Existing account repositories remain the
owners of saved notes and invitations; no warm namespace, resource schema,
old-release fixture, inventory minimum, or backend contract changes.

The obsolete AI generation modal and its launcher are removed. Pure prompt
normalization helpers now live in `ai_flow_prompt_input.dart`; the existing
Flow Studio Compose screen owns generation. Legacy modal UI tests are migrated
to Compose: keyboard/rotation, Build color controls, calendar switching,
Gregorian/Kemetic Cancel/Done/reopen, deterministic 23-note itinerary import,
and generic generation with inferred duration. Assertions about the retired
modal's hidden color picker and Cupertino styling are replaced by checks for
Compose's established spectrum and absence of the old screen/launcher. The
existing Compose save/failure/planned-note tests remain in place.

Focused invitation tests cover selection restore, account changes, save
acknowledgement, concurrent Save, failed saves, partial sends, lost invitation
acknowledgement and retries after restoration. Layout checks cover full sheet
background coverage with short reminders and the complete Gregorian label at
phone width. Capture-only checks write new evidence to `/tmp`; approved visual
references are not regenerated.


## October 1 Pages and sheet navigation retention

Pages remains mounted behind a pushed utility sheet, with its existing search,
collection selection and scroll controllers. Flow Studio submode changes update
only the active sheet URL using GoRouter.replace, preserving its page key and
nested Navigator. The active route is read from router.state; the configuration
base URI can still belong to Pages. A stale sheet callback cannot replace a
newly active non-Studio route. Hub return follows the same ownership rule.

Planner decan details use the existing detail push boundary rather than a root
go command. The Planner sheet and its unsaved fields remain underneath the
detail, and Pages remains underneath Planner. No repository owner, account
write, cache key, payload schema or restoration namespace changes.

Regression coverage uses the actual Flow Studio and Planner route builders. It
checks normal and submode entry, nested Back and sheet Close, retained Pages
State/scroll, and Planner draft plus Pages search/collection state. The prior
implementation fails these tests because root go removes the parent routes.
The former source guard required the destructive hub go command. It now
requires state-preserving replace and explicitly rejects that go command; the
new behavioral round trips provide evidence for the stronger parent-retention
contract.


## October 1 wellness repair

The reflection archive retains independent reflection and opening snapshots.
A successful source read, including a confirmed empty list, replaces only that
source. A transient failure retains that source's known content. Access denial
and account departure discard private cached presentation. A cancelled same-account
refresh does not replace confirmed content.
Account changes start a new load generation and reject late results from the
previous account. Existing repositories remain the persistence owners; schemas,
cache keys, old-release fixtures and inventory thresholds do not change.

The established populated archive is the visual reference. Offline retention
must produce identical pixels; partial refresh preserves the same rows,
spacing and typography. Cold failure retains the existing retry view.
Scheduler requests now clear the tracked completion future and fence callback
and throttle state to the initiating account. No guidance kind is retired by
this bug repair; backend nudge retirement requires separate coordination.

The legacy nutrition format helper and Follow the Sky visual specimen move to
test fixtures with their assertions retained; an additional test restores that
historical nutrition format through PlannerAccountStore. Date-picker tests
exercise EventCreateDatePicker, the existing replacement. Reflection response
metadata assertions exercise the existing model reader, retaining legacy response
IDs in its raw envelope. Inbox routing checks follow the active Pages launcher;
the obsolete chooser's route exception is removed, strengthening the route guard.


## October 1 authenticated calendar keyboard ownership

The signed-in root AuthGate delegates presentation directly to its existing
SessionTrackedRoute and CalendarPage. Removing the redundant outer Scaffold
prevents a second keyboard resize above the landscape modal. SessionTrackedRoute
continues to own route observation; CalendarPage and the modal keep their
existing presentation ownership. No repository, write boundary, cache namespace,
persisted payload, or account lifecycle changes. Regression coverage now includes
the real signed-in root around the established keyboard/draft/rotation checks.

## October 2 startup recovery

Startup now paints the existing branded surface before plugin, auth, cache or
restoration initialization. Required initialization remains ordered and bounded;
a failed attempt exposes recovery without mounting account routes. Retrying on
web reloads the page, retaining auth and authored storage instead of starting a
second initializer against a partially initialized Supabase singleton. Late I/O
completion cannot advance into routing or background warmups. The authenticated
calendar keeps its existing single Scaffold/keyboard owner.

The route restoration controller and account repositories retain ownership.
There are no new routes, persistence boundaries, payload schemas, cache keys or
pending-write cleanup paths. Valid compiled release configuration no longer waits
for the optional env.json fallback; incomplete configuration still passes the
existing validation before auth starts. Browser cleanup keeps the existing three
legacy Flutter cache names and preserves the push worker, with a deadline that
prevents a late cleanup reload after the app starts.

Behavioral fault tests hold or reject every startup stage and the actual browser
bootstrap scripts, including late completion, engine failure and recovery retry.
The former source assertion that routing precedes runApp now requires routing to
precede returning the ready MyApp: the independent startup surface must mount
first. Equivalent explicit-intent/restoration ordering assertions remain. Visual
captures cover the existing launch branding and recovery in portrait, landscape
and enlarged text; approved app references are unchanged.

## October 2 fresh external calendar import

ExternalCalendarRepository owns passive external projection reads in the new
externalCalendar. resource family (schema 1). Keys include the explicit release
lane and requested range; the existing warm_snapshot:v1: namespace stays stable.
Connections, selections and projections are account/lane scoped in separate
backend tables. Authored events remain owned by UserEventsRepo. No pending write
is stored in a warm cache. External reads never hold authored calendar hydration
on a network request: confirmed copies display while the projection refreshes.
Failed/incomplete reads retain the last complete snapshot. Account changes and
acknowledged source changes fence pending reads; disconnect invalidates only the
external lane. Imported events keep exact provider identities and remain read-only.

Settings uses explicit consent and acknowledged revision-fenced mutations.
Foreground automatic imports and selected-range requests begin only after auth;
calendar availability cannot prevent the root UI from mounting. Server scheduled
Google refresh and device-only native observation retain separate owners.
New controller/repository/Settings tests cover cold/warm reads, restart, failures,
timeouts, retry/resume, account changes, consent, selection and disconnect.
Full release and live acceptance remain pending while implementation proceeds.

External projections in combined calendar snapshots carry an additive
externalCalendarLane field. Calendar and search reconstruction reject external
rows from another lane, an unknown build lane, or a missing lane. Authored and
legacy native row payloads keep their established behavior; the deployed account
cache namespace, old fixtures, and pending-write ownership remain unchanged.
The field is also present in the existing generational snapshot because that
snapshot uses the same note serializer and decoder. The external repository's
explicit build-lane mapping remains the single source for this discriminator.

Regression coverage exercises the actual calendar and search codecs in staging,
production, and unconfigured builds, including unchanged old authored/native
rows and matching-lane round trips. Actual DayView workspace tests confirm
Google/device imported copies and legacy native copies expose no Extend action;
source ordering guards require imported rejection before CalendarPage lookup or
any authored writer. Existing authored Extend behavior remains covered by its
next-day canonical-end widget test. The full App gate and live acceptance remain
required before deployment.

Canonical end remains adapter-owned. The page, sheet, and grid adapters continue
to omit a cached authored note's canonicalEnd, leaving its existing canonical
schedule lookup/edit path authoritative. Only external: projections forward their
provider-owned end through these adapters, because an external event has no
authored-event lookup. The existing main DayView adapter is unchanged. The
projection contract retains all prior minute, color, payload, and optional-field
assertions; a focused seam invokes all three real adapters to prove authored,
legacy-native, and missing identities still omit the end while external provider
ends survive. This changes no authored snapshot format or writer.

The grid's existing authored placeholder cleanup remains in place. External
provider titles, including a time-only title or the literal title "Event", bypass
that cleanup. The same real-adapter seam checks the grid label for both imported
and authored cases; truncation and visual styling remain unchanged.

Calendar consent return feedback is ephemeral presentation, not connection or
auth authority. Settings receives only recognized outcome values, reads status
from the account-owned controller, and removes the consumed callback query after
the calendar child receives it. Passive refresh retains the notice; explicit
user actions, dismissal, and account change clear it. A forged `connected` query
cannot create a connection or modify authentication. Cold/delayed mounting and
warm callback tests cover this existing-route change without adding cache keys
or a new persistence owner.

## October 2 calendar lifetime correction

Google and device import controllers belong to MyApp, above the replaceable
router pages. AuthGate no longer starts, stops, or disposes those shared owners.
The real Calendar/Profile-to-Settings route replacement previously attached
Settings listeners before AuthGate disposed their controllers, which left the
release panel permanently loading and triggered locked-tree notifications in
debug. Direct Settings entry alone did not exercise that path.

Account change, sign-out, and password recovery synchronously stop and fence
previous-account work. The current authenticated account starts once after a
frame, with generation/account/recovery checks; ordinary navigation leaves its
controllers intact. Native calendar return navigation is owned by the existing
root link listener with the same fences. Auth exchange and authored writes are
unchanged. The root alone disposes the shared controllers at app shutdown.
No cache namespace, resource schema, stored payload, migration, or pending-write
ownership changes. Real-route tests cover replacement, retained listeners and
retry behavior; startup wiring guards retain the post-paint contract.

## October 2 imported calendar publication and presentation

ExternalCalendarRepository remains the owner of passive imported projection
reads; UserEventsRepo retains authored-event ownership. Typed data invalidations
reread the event lanes even when the flow fingerprint and coverage match, while
catalog-only startup checks retain their promotion shortcut. New invalidations
cannot share an in-flight read that already captured old rows. Catalog rebases
preserve fresh-catalog data requests and external range requests. Foreground
preemption requeues both kinds with their waiting callers intact; account/session
changes still cancel all work. An event-data refresh binds its lane read to the
current viewport commit token after the catalog await, so navigation cannot
certify a new viewport using rows fetched for the previous window.

Confirmed external reads publish their exact account/lane windows through the
existing scheduler. These off-screen refreshes reuse the current fresh catalog
and atomic lane/merge/presentation commit without moving the viewport. Observing
a newer server import timestamp invalidates projection reads without issuing a
second provider import. Failed reads retain the last complete visible snapshot.

Acknowledged source removal matches both external:<source UUID> calendar identity
and external: event identity in the active account/lane. It prunes off-screen
copies and both existing snapshot representations while retaining authored rows,
legacy native rows, other sources, flows and pending overlays. The page retires
old hydration jobs and queues a final prune after both cache write queues drain,
without delaying live hydration. Prepared generational writes and legacy warm
snapshot writes, including rollback restoration, apply the current removal
filter before serialization. Cleanup survives route disposal while the same
account/lane remains active; the repository also prunes without a mounted page.
Disconnect, remote device status changes and device replacement now share
`_acceptServerStatus` after an acknowledged server response. The removed
set is the difference of selected, device-owned source IDs before and after
that response; account/generation fences still govern subsequent work. The
retained authority guard follows this call chain instead of requiring a direct
blanket invalidation inside `disconnect`. A delayed-acknowledgement regression
proves no early cleanup, exactly scoped removal after acknowledgement, and
retention of authored rows, other imports and pending overlays in both caches.
Only a successful current-generation read can restore an explicitly reselected
source. Cache namespaces, payload formats, old fixtures and write owners remain
unchanged; no pending write is stored or removed through this cache cleanup.

Mounted search observes the existing DayView projection notifier and reads the
current flow catalog. Detached search keeps its account-owned snapshot boundary,
rechecking the opening account after loading and before result navigation. The
existing auth broadcast rebuilds open results/suggestions; every result render
and row tap checks that account too. No new persistence owner or global listener
is introduced.

Imported timeline, detail and search labels use the source calendar name, with
"Imported calendar" as fallback; stored external_calendar/native_sync values
remain classification data. Imported copies expose no authored Edit, End, Share
or Extend action. Stale menus re-resolve the target before invoking a callback
or dismissing detail; CalendarPage rejects edits, deletion and authored invitation
lookup at its boundaries. Fresh external: descriptions preserve literal provider
text instead of stripping authored reminder/CID/flow metadata. Existing link
presentation and bounded search snippets remain, as does authored/legacy-native
metadata cleanup.

The real CalendarPage regression uses delayed external reads, an unchanged flow
catalog and coalesced flow invalidation. It verifies authored content retention,
once-only imported identities, off-screen publication, open-search refresh,
failed-read retention, source removal/reselection and literal provider search.
Scheduler/controller tests cover interrupted data/range work, retained waiters,
account cancellation and an A-to-B viewport change with a changed catalog.
No-page durable-cache fixtures cover source/lane/account isolation and preserved
overlays. Actual search tests cover account changes during warm loading, visible
queries and stale taps before the next frame, closure followed by further auth
changes, unchanged authored cleanup and zero repository requests. DayView tests
cover fresh/legacy/category-only import identities, missing source names, literal
descriptions, absent/stale imported actions and retained authored actions.
Navigation guards retain stable result-identity checks and require account
validation before dispatch.

Static captures use production fonts/theme in portrait and landscape at 1x/2x.
The 2x detail fixture excludes the underlying timeline: the existing generic
timeline has a separate 6px overflow at 2x, and the portrait footer clips its
Make to-do label at 2x. These shared-layout limits remain unrepaired by this
scoped change. Approved visual references and inventory guards are unchanged;
the complete App gate and served RC acceptance remain required.


## October 2 imported event description cleanup

Imported event presentation removes only the confirmed Google-generated app
promotion and Gmail provenance sentences. The event-specific email URL feeds the
existing event resource action; genuine provider notes, title, time and location
remain intact. The same description transform drives detail link selection, body
copy and search snippets so the generic calendar-app link cannot displace the
actual event source. Authored and legacy metadata behavior stays unchanged.

This is a display-only transform. Provider descriptions, projection rows, cache
payloads/namespaces, sync permissions and all persistence owners are unchanged.
Existing production-font static captures establish the link-only event block
before raw-provider wiring. Focused checks cover the raw Google template,
wrapped sentences, unchanged real notes, retained literal provider metadata,
link selection, and portrait/landscape at 1x/2x. Approved references are unchanged.


## October 2 public publishing pages

Public information, privacy, terms, support and deletion documents live at
https://haw-info.pages.dev, independently of both application origins. Their
static source is public-site/, outside Flutter's web/ payload. The standalone
public-site seal and served verifier own document hashes and canonical routing.
The app artifact rejects these retired public HTML files and verifies only exact
compatibility redirects to the public site, without fetching the separate site's
contents. This replaces the initial same-origin public-page ownership model.

Login and Settings link directly to the public site. These links and HTTP
compatibility redirects do not mount Flutter routes, read account repositories,
write account content or use warm storage. Existing application routes retain
their persistence owners; native Pages SPA fallback, root/app-route body hashes,
asset identity checks, and the existing inert app-domain verification tag remain.
No cache keys, payload schemas, account lifecycles, old-release fixtures or
inventory thresholds change. The calendar feature rollout is separate work.


## October 3 startup failure diagnostics

The existing recovery screen now exposes a fixed-label startup stage, session
storage operation, allowlisted error category and compiled release identity.
The session adapter annotates failed initialization/open/check/read operations
without changing the sb_session box, session key, stored payload or persistence
owner. Auth writes, deletion, reload-only retry and account-route gating remain
unchanged. No fallback storage, automatic reset, new route or migration is added.
Synchronous router/restoration/background setup receives explicit stage labels
without adding awaits or changing ordering. Raw exceptions and unknown names
never enter the recovery text, including in debug builds.

Production-font captures verify portrait/landscape at 1x and 2x text. Tests cover
all observed storage operations, retained cause/stack, unchanged session writes
and removal, no deletion/reinitialization on failure, and safe diagnostic text.
A disposable browser-only test creates an IndexedDB version conflict, executes
the real pinned Hive adapter, and reads the resulting openSessionBox/VersionError
diagnostic. It does not access either deployed origin or a user's browser data.

## October 3 saved navigation under storage quota

AppRestorationService remains the navigation snapshot owner. A validated local
snapshot can be restored when persisting its migration is rejected with
QuotaExceededError. A validated remote snapshot can likewise be restored when
its local copy cannot be written. The original stored payload and account-owned
content are retained; no namespace, schema, eviction or pending-write path changes.
Other read-repair errors still propagate. Ordinary mutations still report local
persistence failure and do not acknowledge a remote save after that failure.

When a new device identity cannot be persisted, remote window lookup is skipped
while the account-scoped latest snapshot remains available. Failed identity
initialization is retryable after storage recovers, and the preferences cache is
reloaded after failed writes to avoid adopting an optimistic, unpersisted ID.

Regression coverage includes both migration paths, remote adoption, device identity
retry, account isolation, preserved authored data, unrelated errors, and honest
mutation failure followed by recovery. A disposable Chrome origin is filled until
real localStorage writes throw QuotaExceededError; the existing boot coordinator
must still reach ready with the restored route and unchanged original storage.
The existing recovery UI and visual references are unchanged.


## October 3 bundled G/H pronunciation recordings

SpeechService owns the existing device preference `speech:preferredVoiceId`.
Retired device/browser voice IDs resolve to G under that same key; G/H choices
persist locally and do not become account content. SpeechResolver continues to
own the app's pronunciation text and English cue variants.

The immutable public corpus in `assets/speech/` contains 84 phrases per voice and
the two approved previews. Native packages contain the files. On web,
BundledSpeechAssetStore saves SHA-256-verified bytes in the stable Hive box
`speech_audio_v1`, keyed by asset path and content digest. No build identifier,
account ID, user text, authored data, pending writes, or provider credential enters
this cache. An unchanged recording remains reusable across releases and accounts;
a changed digest selects a new recording. Old entries are not erased on logout.

Entering Settings prepares the complete public corpus with four bounded workers;
readiness is reported only after every asset has been verified and saved. Partial
failure keeps verified clips and offers retry. Individual pronunciation taps also
load/cache their recording. Corrupt cache entries are repaired from the bundled
asset; failed storage writes do not claim offline readiness. Browser eviction can
require downloading the public corpus again. No runtime synthesis service or
new account repository/read/write boundary is introduced.

Tests cover selection migration/restart, exact catalog coverage, checksums,
interrupted playback, completion isolation, cold/warm reads, offline store restart,
corrupt cache repair, partial download retry and storage failure. Static Settings
captures use existing fonts/theme at portrait/landscape and 1x/2x. The local web
verification surface exercises the same production service with asset reads
explicitly disabled after the first save. Commercial release also requires
licensed audio: this initial corpus was generated on ElevenLabs' free plan and
is for noncommercial use with elevenlabs.io attribution in the recordings title.
The user confirmed that the app is not commercially released and is noncommercial,
and authorized this production-lane cutover. The approved G/H audio and attribution
are preserved; this confirmation does not create a commercial audio license.


## October 3 Library exit responsiveness

The Library reader's Back and system-back actions capture the existing node
and scroll position, then navigate without awaiting reading-progress storage
or remote synchronization. LibraryReadProgressStore remains the persistence
owner; no cache key, account scope, saved schema, bookmark write, or authored
content changes. Failed background progress saves are handled without an
unhandled asynchronous error. An unavailable save is not reported as saved.

The supplied Rekh-Wer screen recording and existing Library visuals remain the
reference. Restored readers still return to the focused Library row, pushed
readers preserve their parent route, and internal node history still unwinds
before leaving. Regression tests hold and reject progress writes while exiting
both pushed and restored readers, close the Library, then settle the late write
and verify that navigation stays at the chosen destination. Existing history,
bookmark, scroll restoration, and shared navigation tests remain in force.

Queued Library progress and bookmark mutations capture their account owner at
enqueue time, before waiting for earlier synchronization. An account switch or
logout after leaving the reader therefore cannot place that queued progress in
the next account or anonymous cache. Account-change/logout regression tests
hold the first remote write, queue bookmark/exit progress, switch accounts, then
verify the original account's remote targets and local key with no foreign data.
The existing backend authorization, remote boundary, and cache schemas remain
unchanged; no backend operation or deployment is part of this correction.


## October 4 intention-based onboarding

The supplied `correct onboard.mov` is the opening, typography, brightness and
closing-animation reference. The existing overlay remains the visual owner.
The optional calendar offer reuses ExternalCalendarSettings and
DeviceCalendarSettings; their existing consent, source selection and controller
owners remain authoritative. Entering the offer performs no permission request.
The existing /settings callback resumes only the account with a saved unfinished
calendar checkpoint. A declined or failed provider connection can continue.

OnboardingProgressStorage keeps `onboarding_v2_progress:<account>` and adds
optional hawSlide, entryIntent and calendarConnectionPending fields. Missing
fields retain old enrollment, completion and helper history. Required checkpoint
writes are serialized per account, report failure, and reload the preferences
memory after a rejected write. Another account never waits on that queue.
This is resumable presentation state, not a warm cache or a new flow repository.
OnboardingStorage still owns the existing profile completion column and local
completion flag; the closing seal waits for the completion write acknowledgment.
Account checks fence late callbacks and a changed account removes the old overlay.

Each intention resolves to one of the five current joinable catalog entries.
The embedded recommendation calls the same canonical detail-page builder as
My Flows and discovery. There are no onboarding copies of flow pages, schedules
or join adapters. The existing production detail surfaces and FlowJoinService
create events;
ReadingHouseAuthority remains the Reading House owner. Its existing held versus
scheduled distinction is retained: onboarding waits for a dated sitting before
leaving that editor. Confirmed enrollment identity is retained before event
navigation, and retries reuse that identity. The staged-flow lifecycle exposes
its existing persistence result to onboarding, without starting a second write.
The existing flow repository and calendar range scheduler hydrate a saved flow's
start window when it is outside the mounted viewport. There is no today fallback
for a missing first occurrence. The saved event CID identifies the Day View block.

Automatic helper presentation is retired through the central visibility gate;
helper IDs, aliases, local/cloud completion histories and sync behavior remain.
Historical visibility assertions now require hidden while retaining completion,
account-isolation and synchronization evidence. Source guards now verify the
shared production glyph surfaces and conditional enrollment observer, replacing
references to the removed wizard and unconditional staging flag. The obsolete first-flow wizard
and obsolete recommendation products are removed; five-choice catalog tests
replace the retired recommendation tests. No old fixture or approved visual
reference is rewritten and no inventory threshold is reduced.

The five-flow Day View housing and opening extents remain .58/.71. The closing
card sits above that housing. Text-scaling captures exposed the Kꜣr detail's
independently estimated calendar height; its existing shared calendar now sizes
itself. Kꜣr and Follow the Sky preview event blocks grow with enlarged text. The
shared detail shell opts the five authored heroes into enlarged text geometry;
user-created flow heroes retain their separate contract. Carry buttons size to
their text, and short onboarding
viewports scroll without compressing those surfaces. The dissolved closing card
retains finite geometry through its completion frame. Normal-size styling,
flow instruments, event writers, cache namespaces and backend contracts remain.

Verification includes the seven-slide sequence, five-way catalog mapping,
production-font static captures, calendar callback/rejection/account-switch
routes, legacy checkpoint restoration, rejected storage writes, confirmation
retry, and retained persistence observers. The complete App gate remains required
before deployment; live provider grants and production accounts are not test data.


Settings' Replay onboarding row uses the existing compact action style and the
same calendar-hosted onboarding overlay. Its acknowledged account checkpoint
adds replayActive (absent means false), resets only presentation choices, and
retains completion/helper history and existing enrollment identity. Completed
accounts can explicitly replay until Skip or the final seal clears the flag.
Cold startup and retained calendar hosts consume the same checkpoint; calendar
OAuth return honors an active replay. No completion timestamp is erased, no
flow or event is deleted, and no calendar permission or connection is reset.
Settings checks the initiating account before and after its write, disables
repeat taps, and stays in Settings on failed persistence. This uses the deployed
onboarding key and existing root route, without a new cache or route owner.

Replay verification covers the actual Settings row at normal and doubled text
size, cold and retained-host launches into the existing overlay, Skip ending
replay, failed checkpoint writes, repeated taps, account changes during writes,
and completed-account calendar callbacks. The launch resolves its calendar
host after the navigation frame so a cold route does not miss the request.


## October 4 onboarding detail correction

The recommendation window renders the existing five detail surfaces for both
new and already enrolled users. A host-supplied primary action adapts their
shared dock to Go to flow; the detail content, editors and enrollment writers
stay with their existing owners. Confirmed enrollment IDs and first occurrence
IDs retain the deployed onboarding checkpoint and acknowledgement path.

When a recovered enrollment is absent from the calendar's in-memory catalog,
FlowsRepo.getFlowById owns the read, using its existing flow.detail.<id> resource. Recovery restores that account’s
confirmed warm row first; a cache miss uses the existing live read. Go to flow
retains the host’s existing occurrence revalidation before advancing.
HawSavedFlowDetail only holds the pending presentation future. Its account/flow
key discards old results; the host also checks the initiating account after the
read. Failure offers retry for that same identity, never fresh enrollment. No
cache namespace, schema, backend contract, approved fixture or inventory
threshold changes.

Behavioral coverage exercises cold loading, retained successful presentation,
failed-read retry, account and flow changes, disposal during a read, preserved
replay checkpoints, and existing account-scoped warm reads/refreshes. Visual
coverage uses all five existing detail pages in new and enrolled states, at
phone and landscape sizes with normal and doubled text. Go to flow invokes the
continuation without invoking enrollment. Approved detail goldens are retained.


### Explicit replay navigation

Settings Replay uses the existing `openPrimarySection` Calendar command after
its account checkpoint is acknowledged. This records the explicit Calendar
selection and suppresses pending launch restoration, so a saved Settings surface
cannot reopen over the requested onboarding. Navigation persistence remains with
AppNavigationRestorationController and AppRestorationService; no route, cache
key or payload schema is added. The real Settings route tests cover cold and
retained Calendar hosts with a pending Settings restore, alongside checkpoint
failure and account-change fencing. The navigation-controller tests preserve
the saved-Settings-above-another-primary-tab persistence assertions; these
run at the persistence owner rather than across disposable widget clocks.


## October 4 decan description and Pages completion

The onboarding description now reads the same immutable authored text as the
Calendar decan detail. Moving that existing data from a Calendar library part
to an importable module changes no content, account reads, keys or models.
All 36 descriptions and the separate epagomenal description retain their source;
tests cover every civil day and prove each ten-day interval uses one description.
The old daily-question display assertions are replaced with full shared-decan
description assertions, with the historical-claim boundary still explicit.

After the acknowledged completion write and final seal, the existing event sheet
finishes dismissal before the Calendar host pushes the existing `/pages` route
through `openDetailRoute`. The initiating account is checked before and after
dismissing onboarding. Pages retains its existing controller, account repository,
cache namespace and restoration policy. Skip keeps its existing behavior.
Cold/retained Calendar-host tests exercise the actual completion callback and
Pages route. Existing held/failed completion, account-change, Pages navigation,
and warm-read tests remain in place. The complete App gate and served walkthrough
remain required for deployment.


## October 4 compact onboarding copy correction

The supplied original screenshot replaces the full decan essay as the onboarding
copy reference. The existing DecanCompassCopyRepo load/fallback boundary remains
the presentation owner. Its original theme, associated reflection line and
question are reused across each ten-day interval; the display model only removes
the old month/star-name preamble and attributes the theme to ḥꜣw. No repository
query, write, route, cache key, payload schema, or completion ordering changes.
All-day and historical-attribution evidence is retained with compact-copy checks
in place of the rejected full-essay expectations. Existing Pages completion,
replay, account-fencing and failed-write tests remain in the complete App gate.


## October 4 approved onboarding production cutover

The user approved served RC af99146c6f4111f0f2ac515f4e618987c39c6cbe and
requested production cutover. The prior served production source is
b77ddde54913fb378bd581a295eb06bd5206cb06. The promotion joins the existing
branch histories and preserves production's documented noncommercial speech
permission and purpose metadata. All application source, assets, tests, dependency
locks, release scripts and environment configuration match the approved RC.
Both existing lanes use the resulting source identity for sealed environment
comparison; no branch, worktree, repository or backend authority is added.
The complete production App gate, closed staging/production artifact comparison,
served-file verification and live onboarding replay are required before this
cutover is reported complete. The account/cache contracts above remain intact.


## October 4 unified profile Posts carousel

ProfilePage presents the existing flow-post and insight-post snapshots in one
Posts carousel, ordered by createdAt descending with ID as a deterministic tie
break. Publication time, not insight entry date or community ranking, owns the
order. ProfileRepo retains both read/cache owners and all acknowledged writers;
no query, cache namespace, resource schema or approved fixture changes.

The existing profile surface restoration retains activePostIndex and adds an
optional activeProfilePostKey (kind plus post ID) so refreshes and re-entry keep
the selected card when newer posts arrive. Legacy flow-only indices resolve to
their flow in the merged sequence. Missing/removed selections clamp to a
surviving card. The retired insight-only pager index is safely ignored.

Real ProfilePage tests cover mixed ordering from cold and warm reads, single and
empty states, delayed/failed refresh, removal, selection retention and legacy
restoration. Capture-only checks use the existing cards and fonts; approved
visual references are unchanged. The full App gate remains required for any
deployment.


## October 4 profile insight composition

The supplied insight and flow screenshots establish the flow post as the visual
reference. Both profile post types now use the same author/excerpt/card/actions
composition and the same card geometry, typography and border treatment. An
insight's excerpt comes from the existing immutable KemeticNodeLibrary and
extractOpeningLine adapter; its personal reflection remains in the card. Unknown
nodes retain their posted title and glyph without inventing a Library quotation.
The card remains 236 points at normal text size; both post types grow their text
regions together for larger accessibility text.

ProfileRepo still owns the same post snapshots, reads and acknowledged removal.
Chronological ordering, typed selection restoration, routes, account fencing,
cache keys and payload schemas do not change. No additional network read or
persistence owner is introduced. The existing flow golden is retained exactly.
Static and real-profile checks compare card dimensions and placement across both
types, node text ownership, action access, ordering and restoration. The gesture
inventory follows the existing flow menu into the shared profile frame; its
behavior and inventory count remain unchanged.


## October 5 approved Library rewrite

The active Library now contains the approved 61-node selection. Its 165 named
sections, opening hooks, and 12 distinct restored tables are bound to the user's
final draft by `test/fixtures/library/approved_library_rewrite.v2.json`. The
previous 71-node fixture remains immutable. Article bodies are bundled app
content; they are not copied into the warm cache.

The ten removed entries remain resolvable, under their original IDs and frozen
copy, solely for existing routes and account-owned links. They carry an archive
notice and are omitted from the canon, ordinary article search, and new-link
picker. Search can still find a user's insight attached to an archived entry.
No archived subject is silently renamed or merged into a related subject. The
account insight repository and LibraryReadProgressStore keep their existing
owners, keys, payload schemas, bookmarks, scroll positions, and mutation paths.
Archived progress is preserved without marking a different active chapter read.

Active article and Calendar clickthroughs use reviewed surviving targets. Labels
with no corresponding retained subject remain plain text. Exact article titles
resolve before overlapping thematic aliases. In the reader, complete names take
priority over shorter overlapping names; skipped short matches can still link a
later standalone occurrence. Table cells share the same reading-order link
tracking as prose. A column cannot exceed the available reader width, and table
panning must not unwind article history.

The established reader/list styling, history, exit responsiveness, account
switching, and saved-progress contracts remain in force. Coverage includes exact
copy and table equality, retired identity and insight search, restart bookmarks,
link-picker omission/unlinking, direct archived routes, overlapping link taps,
rotation, table gestures, and every restored table in portrait and landscape.
Approved visual references and old-release persistence fixtures are unchanged.


## October 5 profile detail identity and acknowledged removal

The October 5 screen recording and the served RC at
`f2e862122eee4b06d4ee700d933fafc831aabd3a` are the behavior and visual
references for this repair. Profile post cards, the shared detail sheet, its
Remove from profile action, and the Calendars sheet retain their existing
composition. A profile post detail must display the selected post's own snapshot
when a warm single-post render expands into the full pager. The selected identity
and the visible pager position must agree. The existing action dock is also
carried through canonical Ma’at details, including the archived Dawn House Rite,
so profile-owner removal remains available without changing flow lifecycle
authority. The former archived-payload test also suppressed the social-post
removal action; that assertion now follows the requested profile ownership
contract. It continues to verify archived history and the absence of join/import
actions, with an explicit visitor-policy regression preventing flow revival.
Only the typed profile-post removal action crosses this boundary.

ProfileRepo continues to own profile posts and the existing acknowledged
`is_hidden` removal. Hidden posts must be excluded from profile reads and
restored snapshots. A confirmed removal updates the existing memory and
persistent profile caches; failed writes retain the post. Late reads cannot
replace that confirmed removal, and returning from the detail refreshes the
profile without losing the retained parent view. Removing a social post does
not delete its source flow.

SharedCalendarsRepo retains accepted-calendar ownership and the existing
`leave_shared_calendar` mutation. Only an acknowledged removal prunes the
account's memory and persistent accepted-calendar lists. Reads started before
that acknowledgement cannot restore the removed calendar, failed refreshes
retain the corrected snapshot, and account changes fence publication. Cache
keys, payload schemas, immutable fixtures, and inventory thresholds do not
change. No pending mutation is placed in a disposable cache.

The cascade-to-event-trash foreign-key repair belongs to the backend checkout
and gate. It retains the original calendar identity in the archived event's
row payload while allowing a nullable live calendar reference after the parent
is deleted. The app does not bypass the existing owner/member deletion RPC.

Regression evidence covers distinct posted-flow snapshots, warm pager selection,
acknowledged and failed removal, cold/warm reopening, stale refreshes and account
changes. Capture-only detail evidence is written outside approved references.
The complete App and backend gates remain required for deployment.


## October 5 profile flow picker read ownership

The profile flow picker now resolves a selection from FlowsRepo's existing
account-scoped filed-flow snapshot. The canonical My Flows viewer remains the
single owner of initial refresh and its existing Retry presentation; the
picker no longer starts a duplicate, unhandled background refresh. If that
snapshot has been cleared before selection, the picker uses the same repository
refresh, reports failure, and rejects a result after the initiating account
changes, including departure and return to the same account. The existing
account-operation fence also covers the open caption. ProfileRepo remains the
publishing owner. No route, cache key,
payload schema, pending-write store, or backend contract changes.

Regression checks cover cold failure and Retry, successful selection/publishing,
warm selection during slow refresh, selection after cache invalidation, and
account changes while selection is waiting. The iPad caption checks exercise
keyboard reachability and rotation without changing the established composer.


Publishing now requires UserEventsRepo.getFlowDetailEvents's complete paged
refresh through the existing `flow.events.<id>` resource. The publisher sorts
its own copy chronologically, preserving the existing serialized event order
without changing the detail reader's cache. Its default warm read refreshes (or joins an in-flight refresh); a failed read preserves the prior
cache but cannot publish that cache as current data or replace events with an
empty list. The existing account-operation fence also rejects account departure
and return before the write and suppresses a late result after departure.
ProfileRepo remains the acknowledged publisher; there is no new route, key,
schema, write store, or backend contract.

Repository regressions cover cold and warm event-read timeouts without an
insert, snapshots over 1,000 events, a later-page failure without a partial post,
and account departure or departure-and-return without an insert.


## October 5 iPad Flow Studio image editing and keyboard dismissal

The user's October 5 iPad screenshots and the served app at
`9859f6d8ab7d767fabafa8ed7af67440240a0982` are the visual and behavioral
references. Flow Studio keeps its existing image row, preview, sheet and Save
placement. Reopening an eventful flow must restore its saved appearance. A
pending save has one owner; an image upload or definition acknowledgement
failure retains the editor and its selected appearance for retry.

UserEventsRepo remains the owner of flow definitions and occurrences. Editing
an existing flow requires its complete, fresh paged event snapshot. Failed or
partial reads expose Retry and cannot authorize a save from incomplete data.
An appearance-only edit of a successfully loaded existing flow preserves its
exact scheduled event set and raw server rules. The comparison uses the complete
loaded editor projection, excluding appearance; any change to dates, recurrence,
event content or order, alerts, calendar, active state, name, overview or color
continues through the existing replacement path. New-flow completion never uses
preservation. Both mounted and headless persistence skip event replacement for
this result, and mounted rule scheduling also skips it. The original server
notes, dates and saved state survive editor display normalization. Image bytes
and owned object paths remain with FlowAppearanceStore and the existing editor
draft. Regression coverage compares complete event rows (including IDs,
client IDs, times, titles and count), raw rules and nullable metadata before and
after appearance saves in both persistence paths. It also changes a note title
and start time to prove that real edits still replace and persist occurrences.
The notification source guard recognizes the new preservation condition while
retaining its replacement, cleanup, deferred-write and alert ordering checks.
No new route, cache namespace, resource schema, pending-write store or backend
contract is introduced. Approved visual references and old-release fixtures are
unchanged.

The shared keyboard owner uses its existing focused editable when interpreting
browser viewport shrinkage. A retained Safari viewport measurement after the
editor closes does not hide Today, Calendars or Inbox. Native keyboard insets,
custom keyboard ownership, and remaining-occlusion geometry remain intact.
Regression evidence includes editor cancellation, failed-save dismissal, photo
picker return, rotation and reopening on iPad and phone.

Image upload and imported-image copy operations are fenced to the initiating
account through acknowledgement, including departure and return to that account.
A late upload cannot populate another account's image cache. The existing owned
storage object policy and cache keys do not change.

Background reminder synchronization must confirm its existing flow owner before
reading, pruning or materializing occurrences. A successful lookup with no owner
skips the obsolete cached rule; a failed lookup retains it for later refresh and
also performs no occurrence writes. The existing lookup is reused, without a new
read boundary or pending-write cleanup. Account departure clears the transient
reminder registry and fences in-flight sync and event-upsert work. Authored drafts
and pending account writes remain with their existing owners.


## October 5 posted-flow appearance and canonical details

The user's 18:23 and 18:25 iPad recordings are the visual and behavioral
references. The existing My Flows detail is the custom-flow presentation owner;
the existing canonical Ma’at detail remains the owner for each Ma’at kind.
Profile and timeline entry reuse those components, including the three-dot
menu and actual source-flow actions when ownership is confirmed. The canonical
640-pixel maximum and full available width on narrower phones apply in
portrait and landscape. The parent Notes/Reminders/Flows tabs remain parent navigation.
No new detail design replaces the established hero, content or Manage Flow
control, and the five-flow Day View housing contract is unchanged. Custom-flow
heroes provide a measured content minimum to the existing shared geometry
boundary, keeping captions and long titles below fixed controls in short phone
landscape windows. The existing scrolling-hero path preserves access to the
content and action dock without changing normal portrait or tablet geometry.

A posted flow retains its published content snapshot, but its appearance follows
its same-author source flow. The backend migration
`20261006013056_sync_posted_flow_appearance.sql` projects only
`ai_metadata.payload.appearance` in the same transaction as the owner's source
appearance update. Image removal uses the same boundary. Publication and stale
caption updates normalize appearance against the current same-author source;
source/post lock ordering prevents older appearance from winning a concurrent
save. The narrow idempotent backfill repairs already-stale linked posts.
Post IDs, creation dates, captions, event snapshots, rules, unknown metadata and
engagement remain intact. Missing sources, mismatched authors, direct shares and
imported copies retain their snapshots. Existing shared-calendar editor RLS is
unchanged; this owner-update projection does not grant collaborators authority
over the owner's social posts.

UserEventsRepo remains the source writer. Its acknowledgement contains the
server-returned appearance; there is no second app-side social write. ProfileRepo
reconciles that appearance into existing same-author/source memory and disk
snapshots, preserving both payload representations. Social feed/detail, posted
cards and Pages activity reads are invalidated through existing resource keys.
Versioned reads, ordered disk writes and account-operation fences prevent stale
results or an A-to-B-to-A account change from restoring an older image. Retained
profile, timeline and detail views refresh through the existing source-save
invalidation signal. Failed saves retain the previous confirmed social state.
Cache namespaces, resource schemas, immutable fixtures, inventory thresholds and
pending-write ownership do not change.

Owned post details require an actual owner-matching FlowRow and complete event
read before enabling source actions. They reuse existing edit, share, journal,
saved-state and lifecycle boundaries; a synthetic posted ID cannot authorize a
source write. The profile-post removal action stays separate in the context
menu and removes only the social post. Visitors keep snapshot share, save and
safety actions. A failed, deleted or inaccessible source falls back to the
published snapshot. Account changes fence pending source loads and actions.
Detached journal actions use the existing JournalController and JournalRepo
ownership with the initiating account fixed for the operation.

Regression evidence includes exact posted-payload preservation, replacement and
removal of images, all linked posts, concurrent saves/caption edits/publication,
viewer image access, cold and warm caches, stale reads and account changes.
Detail checks cover canonical phone/tablet layouts, post/pager identity,
owner/visitor/missing-source actions and Ma’at presentation. Capture-only visual
evidence lives outside approved references. Complete App and backend gates are
required before release; the backend migration must precede an app deployment
that relies on its acknowledgement contract.


## October 6 Commons followed rhythm and public answers

CommonsRepo retains account ownership of public question reads and acknowledged
answer edits/deletes. The backend's canonical Commons home now calculates rhythm
from explicitly public, visible activity by accounts the viewer follows, with
blocks in either direction excluded. People and observed/partial steps are
counted separately. Fragments count published posts; open practices count public
groups hosted by followed accounts that the viewer may request to join. Private
journals and completion records are not a social source.

Question answers remain public across the Commons independently of follows.
The existing daily question identity is unchanged. The home includes the first
bounded answer page; CommonsRepo owns subsequent commons.answers. reads using
an immutable created_at/ID cursor, retaining the raw timestamp for web precision.
The shared question component renders every loaded answer with the existing
card styling and an explicit Show more answers control. Retry preserves loaded
content; a fresh home replaces the paginated list. Public answer mutations and
follow/block changes invalidate the existing Commons/Pages domains. Account
and load-generation fences reject obsolete results. Returning to Commons and
foreground resume refresh the current home without clearing confirmed content.

No cache namespace, resource schema, old fixture, or pending-write owner changes.
Additive has-more/scope fields preserve old payload readability. Old unscoped
rhythm payloads retain their decoded data but display unavailable marks until a
following-scoped refresh; they must never masquerade as followed totals. Failed
home reads no longer synthesize global fallback counts or a successful empty
answer list. The new read uses the registered commons. resource family. Authored
private journal entries remain with JournalRepo and are never auto-published.

Evidence: commons_repo_test covers cold/cached reads, raw cursor identity,
failed/malformed refresh retention, mutation and unfollow invalidation, access
denial and A/B/A account departure. commons_public_answers_test exercises more
than six answers and the unchanged card hierarchy; captures go to /tmp rather
than replacing approved references. The backend's transactional Commons smoke
covers all four followed metrics, public/private/hidden/skipped distinctions,
both block directions, more than 24 public answers, publication/edit/delete,
empty follows, and anonymous denial. Full release gates remain required before
deployment.


## October 6 sent flow preview and snapshot preservation

The user's October 6 conversation screenshot and existing posted-flow header
are the references. Conversation flow messages use the existing appearance
renderer: header image or empty accent treatment, then the title. Capture-only
evidence at phone and landscape widths lives in /tmp/haw-flow-preview. Event
invites and text messages keep their existing renderer and detail routes.
The current active import identity controls the recipient's Added label.

ShareRepo remains the send/inbox owner. Posted-flow Inbox sharing sends the
readable published snapshot through create_flow_share. Direct shares use complete
paged events, sender-local civil times, and fail without sending on read errors.
The existing database trigger and Storage RLS retain appearance snapshot ownership.
The optional end_offset_days field preserves overnight/multiday timed events;
old snapshots and both 12-hour and 24-hour times remain readable. No cache key,
resource namespace, old fixture, inventory minimum, or route is replaced.

ProfileRepo keeps Save dormant and copies event action metadata. Repeated Save
taps for the same account and post share one in-flight operation; this is not a
cache or a background write queue. It records the saved reference only after
event acknowledgements and marks its initially inactive, unsaved template saved
only after all writes succeed. Incomplete copies remain inactive and unsaved;
no broad calendar-deletion path runs on save failure. Hidden means deleted in
the database, so it is never used as a staging flag. Continuation is fenced to
the initiating account. Incomplete and hidden copies are excluded from both
duplicate lookups, and failed lookups stop Save. Image-copy failures fail
Save/Add instead of clearing the image.
The existing staged calendar persistence and completion owner continues to own
Add. Complete release gates and live replay are required before deployment.


## October 6 built-in flow Inbox heroes

The 4:26 PM RC screenshot exposed a missing presentation path: built-in flows
have bundled hero artwork rather than a Storage image path. Inbox previews
resolve the existing Ma’at identity from the shared name/notes and reuse the
existing discovery hero asset and crop. An uploaded appearance still wins;
user-created flows without an image keep the empty accent block. Existing
shares receive the fix without rewriting snapshots or sending them again.

ShareRepo still owns the account-scoped conversation on both RC and production;
the configured Supabase project and server records are shared, while browser
sessions and disposable warm caches are origin-local. No namespace, storage
owner, route, mutation or backend boundary changes. The route regression opens
a real Inbox row, loads the conversation through ShareRepo, checks the bundled
and uploaded heroes, follows the share detail route, and reopens from the warm
cache during an unavailable refresh. Captures are evidence, not replacement
goldens.

## October 6 — universal full flow details

Full flow details have one presentation owner per kind across every entry. The
My Flows custom surface and the five authored Ma'at surfaces are reused in their
entirety. The shared source adapter resolves a verified owner/imported row with
complete flow events; otherwise it keeps the published/shared snapshot and its
permissions. It never substitutes another personal instance by matching a name.
Snapshot configuration is display data, not an owned flow ID. The old opt-in
layout flags and unused Inbox detail page are removed. The canonical gateway owns
kind dispatch. Archived details retain their existing non-enrollment contract.

`FlowDetailCalendarScope` supplies viewer-owned calendar context to the existing
custom and Ma'at renderers, including Inbox invitations. It reads EventFilingRepo's
complete, ordered, paged live cabinet and existing birthday projection, FlowsRepo
metadata and ExternalCalendarRepository; hidden-calendar preferences retain their
SharedCalendarsRepo owner. There is no new event store, pending-write owner, cache
namespace, release/version suffix, or mutation path. The deployed filing resource
keys and schemas remain unchanged. Cached reads paint before refresh; cold misses
and failures do not certify an empty calendar. The boundary refreshes after
acknowledged calendar invalidations, external background reads and app resume.
Account departure clears displayed rows and fences outstanding reads, including
A -> B -> A. Access denial removes stale context. The shared dock preserves import
start-date selection and uses the existing acknowledged import/save/add actions.

Release evidence includes the structural authority guard, complete rendered
image comparison across actual registered Inbox/profile/feed/Pages routes,
1002-row pagination, cold/warm reads, background refresh, account change and
access-denial behavior. Existing per-kind and My Flows visual references remain
unchanged; the full App gate is still required.

## October 6 Library familiar-wisdom integration

The approved wording pass updates the same 61 bundled articles. The new
`approved_library_rewrite.v3.json` fixture binds their bodies to the approved
editorial source; the v2 and earlier fixtures remain unchanged. Opening hooks,
165 section headings, and 12 distinct tables are preserved. Hathor's existing
Ma'at clickthrough follows the revised curly-apostrophe spelling and retains
its target. The reader, routes, retired entries, account-owned insights,
bookmarks, cache keys, and persistence owners are unchanged.


## October 7 — end-of-decan review, Journal and optional publication

The approved uploaded decan HTML is the visual authority. Calendar keeps the
existing floating badge and local day-ten 20:00 gate. The scheduler now sends an
invitation rather than generating interpretations. Every entry reuses the
reflection detail owner; legacy generated histories retain their reader.

DecanReflectionRepo owns additive schema-1 review context and bounded activity
pages (twelve items per source), with optional Journal/private-margin selection.
Eight authored questions replace phrase-matrix generation for new reviews. Small
catalog-based flow/Library continuations use existing permission-checked detail
owners and bounded membership/progress reads. No full-history recommendation job
or automatic joining is introduced.

JournalRepo owns acknowledged CAS/idempotent writes for all callers. Journal row
revisions and the account/date tombstone ledger prevent stale saves from reviving
removed documents. A stable source paragraph is merged atomically into Journal;
all unrelated blocks and metadata are retained. JournalController retains its
existing document keys, adds a base-revision sidecar, serializes local writes,
and does not clear newer typing when an earlier request is acknowledged. Archive
writes bind to their displayed revision. JournalOverlay and JournalArchivePage retain their established layouts and
editors; direct source entries reuse the archive entry view. JournalController
owns source writes and recovery without replacing the host presentation. Source removal
requires an explicit add-back action before it can be restored.

Durable intents use `journal:user:<account>:mutation:<date>`, the existing Journal
document keys, `decan_review:user:<account>:<period-start>`, and the post-detail
removal key `profile:decan_remove:<account>:<post>`. They are independent of warm
cache eviction/logout. Exact retries preserve mutation identity even if an
attempt timestamp changes. Acknowledgements are checked against current server
revisions/visibility before publishing a warm row. Conflict receipts keep both
versions under owner RLS; a fresh device can discover bounded recovery records.
Routine Journal reads return descriptors only; full preserved bodies are fetched
on explicit comparison. Selecting a recovery stages writing, never publishes it.

ProfileRepo owns the new decan insight snapshot. The established profile tile,
feed/Commons cards and InsightPostDetailPage render it in their existing layouts. It has a real reflection identity and no dummy
Library record. Posting, editing and removal are separate acknowledged actions;
Journal updates cannot silently change the public copy. Existing member and
bidirectional block rules apply. The original profile cache keys remain; a viewer
sidecar prevents new member-only decan data from crossing viewer accounts.

Existing warm resource families and old-release fixtures remain unchanged.
Optional model fields are backward compatible, so existing schema-1 payloads need
no destructive migration. New reflection activity/source resources are excluded
from passive reflection-ID warming. Account-operation fences reject late A-B-A
responses and clear private presentation on departure. Pending writes never enter
disposable snapshots.

Evidence is maintained in `docs/reflections/decan_review_refactor.md`. The old
prompt source guard now requires an invitation and prohibits the retired engine;
no-LLM and interaction-order protections remain. Journal and owned-flow mocks
follow the shared acknowledged RPC while retaining content, account, badge and
invalidation assertions. No guard threshold, historical fixture, approved golden
or full-detail owner allowlist was relaxed. Backend migrations and functions must
pass their release gate and be applied before the app is deployed; local tests
alone are not a served-RC or physical-device release receipt.


## October 7 — manual reflection invitation in Settings

The Settings control reuses its existing section card and gold button. Actual
Settings renders at 320/402/768 widths were inspected before wiring. “Show
reflection badge” navigates through openPrimarySection, then asks the existing
Calendar host to show its canonical badge for the latest available completed
decan. It can reopen a previously seen period without clearing interaction
history, creating duplicate reviews, or touching Journal/public content.

The invitation is process-local and account-fenced, including departure during
an in-flight read. It waits for an existing automatic prompt read and remains
visible until opened; subsequent automatic checks cannot erase it. The shared
DecanReflectionRepo and detail route retain all persistence ownership. No new
route, cache key, saved model, backend write, or background job is introduced.
Date selection reuses the existing Kemetic calculation. UTC-tagged civil dates
are kept as civil dates when calculating the intended local day-ten 20:00 gate.
Before that time, the manual button uses the preceding available decan.

Tests cover the actual Settings button, repeated badge-to-saved-review navigation,
no creation writes, failure feedback, departure during a delayed read, and every
civil date in normal/leap Kemetic years including supplementary days and DST.
The full App gate, sealed lane artifacts and canonical served checks remain
required for the authorized RC-to-production promotion.

## October 7 Inbox sharing and keyboard continuity

The user's 14:16 recording and the existing Inbox flow-card and Kemetic keyboard
renders are the reference. The conversation retains a single stream for its
account and recipient, just as the group DM already does. Its first frame uses
ShareRepo's synchronous account snapshot, including the full existing flow
payload and appearance. Refresh remains in the background. Neither keyboard
resizing nor message-like updates restart the subscription. Shared chat scroll
physics retain the latest-message anchor through resizing without moving someone
who is reading older messages. The existing card hierarchy and top alignment of
short chats remain unchanged. The browser keyboard owner applies input suppression
and re-enters each DOM editor once, preserving selection; subsequent focus events
do not repeat the handoff, and system mode restores the original attributes.

ShareRepo retains inbox:shares:v1:<account>; no cache namespace or payload schema
changes. Existing FlowAppearanceStore and bundled hero assets retain image
ownership. Concurrent identical Inbox reads share a single account-fenced
request. Bounded reads merge into the existing snapshot rather than truncating
older conversation previews. A full refresh can replace a confirmed snapshot;
failed refreshes retain it. Acknowledged item mutations invalidate older in-flight
reads. Account departure, including A-B-A, fences publication and subscription
emissions. Confirmed permission denial removes cached private previews and does
not bypass denial through the legacy view. Passive refresh performs no send,
mark-viewed, import or draft writes. Existing account mutation and editor
restoration owners remain unchanged.

Evidence includes the real conversation with delayed and failed HTTP reads,
warm first paint, new-chat typing, system/custom keyboard transitions, caret
movement, latest-message and older-history scroll positions, concurrent reads,
bounded refreshes, old cache restoration, account changes and access denial.
The DOM handoff runs in the browser gate. Capture-only images remain outside
approved visual references. The complete App gate is required before release;
these automated checks do not measure physical iPhone frame timing.

## October 7 Inbox message actions

The user's 15:43 Instagram recording is the interaction reference: lifted
message, blurred conversation, nearby action list and no emoji strip. The
existing Hꜣw bubble typography/color are preserved. InboxMessageActions owns
bounded phone/wide layouts, dismissal and action presentation; the shared
InboxMessageActionHost connects direct/group route identities to the existing
repositories. No separate detail page or new message storage authority is added.
Core actions are Reply, Forward, Copy, Delete for me and sender-only Unsend.
Failed local sends expose copy/discard without claiming they can be unsent.

ShareRepo and DmConversationRepo remain the account write owners. The backend
resolves reply quotes from readable messages and persists them in the existing
optional payload_json.reply_to field. Old snapshots remain valid. Forwarding
uses the existing text or complete-flow delivery boundary and recipient picker.
Private deletion is an acknowledged account mutation, separate from global
sender unsending. ShareRepo patches the existing inbox:shares:v1:<account>
snapshot only after acknowledgement; failures retain confirmed content. Group
writes invalidate the existing dm.* snapshots. Account fences prevent departed
writes from publishing into a new account, and reply/composer state is cleared
on account changes. Warm caches never contain queued writes or own deletion.

Visual tests cover 320/390/844 widths, dismissal/action dispatch, and the real
Inbox route replying with source identity through its existing keyboard. Cache
tests cover acknowledged hide persistence/reopen and failed-write retention;
existing cold/warm, refresh, account-change and keyboard tests remain required.
The backend gate additionally verifies real account ownership, first-time sends,
recipient/member/outsider permissions, private hiding after a fresh client,
server-validated quotes, unsending and complete flow snapshot forwarding.

The real Reply-to-Send test also caught the floating keyboard toggle covering
Send. The canonical keyboard toggle now defaults above the focused editor's
control row when they overlap; user-dragged positions retain their existing
clamp behavior. It guards stale/unmounted editor geometry. This changes neither
keyboard occlusion authority nor focus/DOM input ownership. The real route asserts
that the controls do not overlap, taps Send, and verifies quoted source metadata.

## October 7 Inbox response and background work

The approved Inbox, lifted menu, flow previews, and direct/group message styles
remain the visual references. The keyboard's shared pointer boundary now defers
outside dismissal until pointer-up; collapsing on pointer-down moved Send by
312 pixels during the reproduced held tap. The same fix applies to all routes
using KemeticKeyboardHost. Cancelled pointers do not dismiss a later gesture.
InboxMessageActions hit-tests its whole existing bounds. Group bubble rendering
is moved unchanged into the existing inbox_message_bubble owner, with constrained
incoming rows so the lifted preview also fits tablet and landscape widths.

Group messages paint a transient Sending state immediately. The composer remains
usable for the next draft. The existing send_dm_message_v2 owner must acknowledge
an identity-matching message before it is shown as confirmed. Failed sends retain
their bubble and reply identity; Retry uses the same client_message_id. Confirmed
responses and Realtime rows deduplicate by server/client identity. Account or
conversation changes fence late completions and clear their private presentation.
Pending messages never enter WarmSnapshotStore or its logout/eviction cleanup.

DmConversationRepo reads existing dm.messages.<conversation> and dm.summaries
snapshots synchronously for first paint and refreshes through the existing warm
reader in the background. Summary detail reuses the summaries read. Send
and message-action invalidation happens after acknowledgement, scoped to the
affected chat and summaries. Pending or failed writes preserve confirmed warm
content, including other chats. Read receipts invalidate summaries only after
a successful response. The existing warm-store change stream publishes completed reads; concurrent
message refreshes coalesce, transient errors retain confirmed content, and access
denial clears it. No cache keys, schemas, durable message owner, migration, or
old-release fixtures change. Conversation Back never awaits read acknowledgement;
the visible conversation remains the read-receipt owner. Direct Back suppresses
restoration synchronously and retains acknowledged local resume cleanup before
popping, preventing stale conversation restoration. It performs no network wait.

Delete/Unsend temporarily hide only the mounted row after the existing user
confirmation. Failure restores the row; existing repositories still update or
invalidate persistent reads only at their acknowledged mutation boundary. Search
retains selectable results during refresh, executes independent lookups together,
and rejects superseded/account-departed responses. Shared-flow routing seeds its
existing canonical detail with the already-present matching share snapshot.

Behavioral evidence includes the original held-pointer regression, slow and
failed refresh, immediate pending send, draft preservation, stable retry identity,
server/Realtime deduplication, Back during held read acknowledgement, deletion
rollback, account switching, search response ordering, and the complete preview
hit target. The same delayed-network scenarios have widget and iOS simulator
entry points; they use injected HTTP fixtures and never send live messages.

Native landscape verification exposed two height constraints absent from the
portrait screenshots. The existing keyboard host now computes one panel height
for both its rendered panel and published custom inset, reserving 152 logical
pixels for the editable viewport on short screens. Its existing glyph grid
remains scrollable; no new occlusion or focus owner is introduced. Profile search
keeps its existing padding, fields, chips and rows in one scrollable body so
native-keyboard occlusion cannot make the results inaccessible. The original
Scaffold-resize/padding assertions remain unchanged. The delayed-send scenario
also runs at 844×390 with the phone's bottom safe area, alongside native portrait
and landscape execution and the existing Calendar keyboard ownership suite.

The native transition also reproduced overlapping native/custom reports. The
shared KeyboardInsetConsumption boundary now resolves the additional custom
page clearance after Scaffold's native reservation. The editable surface only
consumes that clearance and retains scoped custom focus reveal; it does not
acquire native resizing, raw MediaQuery mutation, or input ownership. Modal
boundaries continue to consume the larger obstruction once. Existing structural
assertions are retained, with real delayed-native-dismissal and boundary geometry
tests proving that this ownership refactor removes double reservation.


## October 8 Inbox backdrop and practice warm entry

The user's 07:28 recording and the approved Reading House Inbox captures are the
visual references. Main Calendar no longer treats every non-current route as
fully hidden. It follows Navigator's TickerMode visibility beneath transparent
sheets, retaining the existing opaque-route and hidden-landscape work suppression.
The canonical Inbox sheet housing and all practice row renderers stay unchanged.

SupabaseReadingHouseRoomRepository reconstructs summaries synchronously from
readingHouse.summaries, then restores disk data and refreshes in the background.
The existing summary stream also observes warm-store publication. Confirmed empty
and populated snapshots are distinct from a cache miss. Slow or failed reads keep
confirmed presentation; denial removes it. AccountOperationFence rejects departed
results, including A-B-A, and account departure clears mounted private rows.

SharedPracticeRepo owns a complete schema-1 social.together.inbox.<limit> snapshot
of its existing Inbox/quote-approval/request-decision reads. It cannot reuse the
smaller pages.together payload as complete Inbox evidence. A complete empty result
suppresses the repeated Practice Together spinner visible above Reading House.
Acknowledged Together mutations invalidate that resource and fence older reads;
failed mutations retain the snapshot. No queued write, new backend contract,
build-specific namespace, rewritten old fixture or lowered inventory is added.
The page-wide cold-loading flag also yields to confirmed cached practice content.

Regression evidence covers the actual Inbox route over Calendar, reopen,
transparent-sheet rotation and opaque coverage, first-frame cached rows, cold
arrival, passive background publication, failed refresh, denial, account departure,
A-B-A reads, old-envelope restoration without network, and acknowledged/failed
mutation invalidation. Existing Reading House visual references are compared
unchanged. The complete App gate and served replay remain required for deployment.


## October 8 — one reflection experience for existing accounts

The user's October 8 recording reproduced a saved pre-review period choosing
the retired generated badge and modal. The approved uploaded HTML and existing
DecanReview views remain the visual reference. Calendar now supplies only period
identity to one badge and the canonical detail route; it never reads generation
metadata or selects a legacy renderer. The detail owner opens DecanReviewScreen
for both old and current rows, including archive, restored URLs and push entries.
The old reader and badge exist only as historical test fixtures outside lib; no
application entry imports them. Their fixture assertions remain, alongside new
real-route and universal-entry regressions. Archive previews use the saved review
question or a neutral invitation, never the old generated interpretation.

DecanReflectionRepo still owns saved periods. On deliberate opening, the controller
loads the same bounded activity and authored question used for new reviews, then
converts a context-less row through apply_decan_review_v1 with its existing UUID
and revision 0. The backend checks ownership, immutable period identity, revision
and mutation receipts. Updates preserve reflection_text as compatibility history;
review_context.question alone drives the current experience. Conversion creates
no duplicate, Journal entry or public post. The normal Journal/post owners and
explicit actions remain unchanged.

Warm keys, schema envelopes, account fences and durable draft keys are unchanged.
Late account reads cannot publish; denial clears private presentation; failed
conversion retains the same pending mutation for retry. Older cache envelopes
remain readable and are converted only after acknowledged save. The complete App
and backend gates, unchanged approved visuals, live seeded older-row replay and
served artifact verification are required before reporting this fix released.


## October 8 reflection interaction repair

The existing reflection identity now uses UtilitySheetRouteScaffold, retaining
its launching route and the account draft when dismissed by Close, backdrop,
or drag. The shared sheet consumes remaining keyboard occlusion exactly once;
its editable descendants do not add a second native/custom inset. The reflection
canvas retains field elements and focus while it temporarily tucks surrounding
copy away during editing. Material fields keep the shared Flutter scroll-padding
defaults. Done restores the prior review scroll position and explicit save/post
actions. Below 120 logical pixels of remaining keyboard space, the shared sheet
compacts its dismiss header and uses the available height; the reflection field
reduces internal padding without adding a scroll or inset owner. Native Safari
landscape checks include its compact toolbar. Expanded browser chrome can leave
less room than a single input line and remains a browser constraint.
The approved type, colors, moments and public/private composition remain.

Owned-flow moments push the existing by-flow detail route; that route resolves
account data and dispatches the canonical My Flows or authored Ma’at full detail.
Ma’at suggestions use the existing template route, and books retain the existing
Library route. A pending source navigation cannot open duplicate destinations.
No detail renderer or persistence owner is added. Reflection writes reuse the
existing auth retry with an account fence and the exact durable mutation request.

Regression evidence includes complete canonical flow entry parity, reflection to
flow and back, sheet close/reopen with an unsaved draft, the manual badge and old
period upgrade, and full focused-field bounds in portrait/landscape for native,
web layout-sized, web visual-sized and custom keyboards. Existing warm namespace,
resource schemas, old-release fixtures and inventory minimums are preserved.

The served first-open replay also exposed a cancelled coalesced warm read in the
existing canonical flow detail. SharedFlowDetailsPage now takes over that read
under its own route generation and AccountOperationFence, matching the existing
FlowDetailCalendarScope recovery. It retains the loading/full-detail visuals,
retries only WarmReadCancelled for a still-current signed-in owner, and keeps
network/denial errors distinct. Cache-only reads do not fetch; route closure and
A-B-A account departure cannot restart or publish old work. Real-route tests
reproduce a departed warm owner and verify recovery plus both departure fences.

## October 8 authored daily reflection replacement

Rekh-Nedjes has one authored source in `kemetic_day_data_rekhnedjes.dart`.
Calendar, Journal, Commons, Pages, guidance payloads, and generated widget data
resolve the same absolute month-day flow row through `KemeticDayData`. Current
Commons question copy comes from that calendar source even when an existing
snapshot has older editorial text for the same identity. Answers, answer paging,
and acknowledged writes retain their existing account repository ownership.
The iOS widget likewise prefers its bundled authored question over a stored
snapshot's copy. Web widgets retain their existing network-first day table.

No cache key, resource schema, account write, old-release fixture, or inventory
threshold changes. The 30 approved card fingerprints, all 30 solar dates,
stale-snapshot answer preservation, real Journal/Commons views, generated
widget parity, and all three guidance decans are covered by app tests.


## October 8 — confine the reflection presentation to its approved scope

The October 7 document-kind switches incorrectly replaced the established
Journal and social layouts when a reflection was present. Those switches and
the duplicate JournalDocumentView/DecanInsightPost owners are removed. The
existing Journal editor, archive entry view, profile artifact frame, feed/Commons
cards and insight detail remain the visual authorities. Reflection contributes
source paragraphs or a typed public snapshot, never a replacement host screen.

Journal source editing/removal retains JournalController's durable pending
writes, revision checks and conflict recovery. Paragraph identity selects the
existing editor's target; other blocks and metadata are preserved. Archive saves
fence account departure and A-B-A before publishing feedback or links. Closing
the shared rich text editor cancels its deferred formatting notifications.

No cache key, schema, repository owner, old-release fixture, approved golden or
inventory threshold changes. Real-route tests retain private/public independence,
acknowledged edits, warm reads and account-departure evidence. Host regression
checks retain Journal controls and social geometry at phone/landscape sizes and
enlarged text; a scope guard rejects reflection presentation imports in other
features. Existing reflection visual fixtures remain intact.


## October 9 Day’s Rhythm automatic-display preference

The card-header toggle and Settings Calendar Content row share SettingsPrefs and
its deployed `settings:dailyCosmicContextBadgeEnabled` device-local preference.
Missing values remain enabled. Disabling suppresses future automatic cards
across restarts; enabling restores the existing once-per-local-day schedule.
The visible card stays open while the user toggles either way, including on
preference reevaluation and resume. Only X dismisses the current card; outside
taps and system Back do not. Account departure and existing authentication/setup
suppression still clear private presentation. Closing remains a one-day dismissal.
Account-specific last-shown dates retain their existing keys.
No account content, warm key, resource schema or backend writer changes.

Both entry points use the same serialized writer and publish acknowledged changes
to the mounted Settings page and global card host. Unrelated Settings bulk saves
no longer rewrite this preference. Rejected writes reload the preference cache,
keep the prior switch value and offer retry. Visual captures preserve the supplied
card’s housing, text and close action with the new switch immediately to its left;
phone, narrow and landscape layouts include enlarged text. Route-level regression
checks exercise the real Settings page and global overlay shell, persisted opt-out,
re-enable, separate dismissal and rejected/throwing writes without changing
approved visual references.

The corrected compact switch paints a capsule track and silver capsule thumb at
their actual dimensions instead of flattening a native control. The thumb is
20x10px, twice its original width with the same height. Its polished silver
finish uses a curved light gleam, shaded face and beveled rim based on the
supplied metallic-button reference. The track stays 52px
wide and 12px tall beside X, with a 60x40px tap area, green on and gray off.
Static on/off captures cover both platforms, phone/landscape and enlarged text.
Real-shell tests verify repeated toggles, outside taps, Back, X, restart,
Settings restoration and failed saves; account changes retain their fence.
