# WEB-RESTORE-DURABILITY-001 scoping note

## Proven failure

The remote Linux fresh-process gate observed the current Planner route and the
latest Calendar anchor in the live Flutter process, terminated Chrome, and
then read an older route and Calendar anchor from a distinct neutral Chrome
process using the same profile and origin. This proves that the existing live
storage readback is not a process-durability acknowledgement.

The preserved red observation was:

- live route and Calendar: Planner, `5-3-4`;
- neutral fresh-process route and Calendar: Calendar root, `2-11-4`.

This ticket does not change which route or Calendar position wins. It changes
only when web persistence is allowed to report that the already-selected
snapshot is durable.

## Current authority and write paths

`AppRestorationSnapshot` is the logical snapshot unit. It contains the active
principal and window, provenance time, visible/durable route metadata, durable
primary selection, Calendar logical anchor and relative placement, day view,
surfaces, overlay stack, editors, and cache hints.

`AppRestorationService._mutateNow` serializes mutations through
`_mutationQueue`, selects a baseline, applies the requested mutation, binds the
current principal/window, assigns a monotonic `updatedAtMs`, and calls
`_persistRawSnapshotLocally`.

`_persistRawSnapshotLocally` currently writes the same JSON snapshot to five
logical targets:

1. per-window critical storage;
2. per-principal latest critical storage;
3. per-window `SharedPreferences`;
4. per-principal latest `SharedPreferences`;
5. last-active-principal `SharedPreferences`/platform storage.

On web, both critical stores are direct `window.localStorage` writes in
`app_window_platform_web.dart`. The web `SharedPreferences` implementation is
also browser local storage. The returned Futures and synchronous readbacks
prove only that the live renderer can observe its writes; neither reports a
Chromium profile transaction or disk durability boundary.

`recordPrimaryTabSelectionCriticalSnapshot` is a second, synchronous fast
path. It writes the per-window and latest critical localStorage values, reads
them back in the same renderer, and logs `critical primary route committed`
when the strings match. `app_window_platform_web.dart` advertises
`supportsSynchronousCriticalSnapshotStorage = true`, so this same-process
readback is currently treated as a durable commit. The remote red disproves
that claim.

`AppNavigationRestorationController.recordPrimaryTabSelection` invokes the
synchronous fast path and starts the queued full-snapshot write.
`openPrimarySection` discards the returned Future and changes the GoRouter
location immediately. Planner can therefore become the accepted visible route
before either the latest Calendar mutation or the Planner route snapshot has a
process-durable acknowledgement.

Lifecycle handlers (`visibilitychange`, `pagehide`, `beforeunload`, and
`freeze`) repeat the current localStorage snapshot as best-effort work. They do
not provide a completion acknowledgement and cannot make an already-visible
Planner transition termination-safe.

## Read precedence and principal binding

Reads currently consider per-window preferences, per-window critical storage,
per-principal latest preferences, per-principal latest critical storage, and
optionally remote snapshots. Candidates are validated through
`AppRestorationSnapshot.fromJson`; the snapshot principal must match the
requested principal, and current-window candidates must also match the current
window. Newer `updatedAtMs` wins, with explicit source precedence only for a
same-timestamp content collision.

The principal checks prevent a decoded user-A snapshot from being selected for
user B, but no independently acknowledged generation or integrity envelope
exists for the web local snapshot. Legacy localStorage can therefore appear
newer in the live renderer even when a new process still has an older related
route/Calendar state.

## Scheduling and false durability claims

- Calendar and route mutations are serialized in `_mutationQueue`.
- Remote Supabase persistence is separately queued and is not the local launch
  boundary.
- Calendar viewport capture may be coalesced before it reaches the restoration
  service; `flushPendingWrites` waits queued service work but cannot force a
  browser profile durability acknowledgement.
- The synchronous primary-route fast path bypasses the queued Calendar write
  and reports a same-renderer localStorage readback as durable.
- The awaited web `SharedPreferences` setters report API completion, not an
  IndexedDB transaction completion or other browser durability primitive.

## Web/native divergence

The native platform stub advertises no synchronous critical storage. Native
restoration remains based on awaited platform `SharedPreferences`; the
physical-iPhone Calendar and Today gates are already accepted. The behaviorally
proven defect is the web renderer/profile boundary, so native persistence must
remain unchanged unless later evidence proves it shares the defect.

## Smallest correction boundary

Use one web-only acknowledged snapshot store whose success resolves only after
the browser reports completion of the actual transaction. Persist one
principal-bound, schema-bound, monotonically generated, integrity-checked
envelope containing the complete logical snapshot so route and Calendar state
cannot come from different generations.

The acknowledged store is authoritative on web. Existing localStorage and
`SharedPreferences` values remain a controlled migration/fallback input only;
they may seed the acknowledged store when no valid acknowledged snapshot
exists, but they must never overwrite a newer acknowledged generation.

Before a web primary route such as Planner becomes visible, the existing
Calendar mutation queue must settle and the resulting route-plus-Calendar
snapshot must receive the acknowledged-store completion. A failed, denied, or
quota-exhausted transaction must return a truthful failure and must not allow
the transition to claim durability. No fixed delay, raw LevelDB polling,
application-side localStorage synchronization, or restoration-precedence
change is in scope.

IndexedDB is the smallest existing browser primitive available through the
project's current `package:web` dependency. Its read-write transaction
`complete` event supplies the missing acknowledgement without adding a package
or altering native storage.
