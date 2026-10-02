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
