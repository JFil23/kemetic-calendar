# Fresh external calendar import contract — October 2, 2026

## Authority and provenance

App source: current verified app-only RC baseline 70e99527, existing rc checkout.
Backend source: current main baseline 4ab3337, existing backend checkout.
Production stays served on 70e99527 during RC development. No new checkout or branch.
Failed calendar implementations are research evidence only. No merge, cherry-pick,
restoration or copied implementation from those attempts is permitted.
Current Settings housing and existing calendar rendering are the visual references.
The new import panel must be rendered and inspected before behavior is wired.

## Acceptance

- External Google/Apple/device events appear inside the existing Hꜣw calendar.
  Hꜣw never creates, edits or deletes provider events.
- Google authorization is a separate connection; Hꜣw authentication never changes.
  Credentials remain server-only, with stable provider account identity.
- Users choose calendars. One selected source owns an imported occurrence; native
  and Google paths must not silently duplicate the same calendar.
- Provider edits, moved recurring exceptions, cancellations, deletion, all-day
  exclusive ends and time-zone changes reconcile with stable occurrence identity.
- Initial import, repeating import, access-token refresh, revoked access, reconnect,
  explicit account replacement, pause/resume/disconnect and offline/restart are
  independently verified. Incomplete provider pages never authorize deletions.
- Connection/status/import operations have deadlines. Timed-out work cannot apply
  late UI results or overwrite a newer selection, account or connection. A failed
  first request cannot disable retry on resume or leave permanent busy state.
- Calendar failures remain within calendar status. No calendar request is required
  to mount the root, establish the Hꜣw session or show authored content.
- Native availability is stated only after actual packaging and device checks.
  Existing speech playback and recent keyboard/navigation fixes remain intact.

## Single ownership and RC isolation

Fresh external-calendar tables own provider connections, selected calendars and
read-only projections. They never write, delete or attach a trigger to user_events,
planner stores, flow data, or Hꜣw authentication. Every connection, lease and event
is owned by the authenticated account and an explicit staging/production lane.
The current production app does not read these tables. Future production reads
only its own lane; RC connection actions cannot modify production projections.
Google snapshot application is callable only by the trusted server adapter.
Native snapshots will have a distinct permission boundary, never Google authority.

The app external-calendar repository maps projections into existing calendar
presentation types. It does not gain authority to mutate Hꜣw-authored content.
The warm cache is disposable acceleration with a registered resource family;
existing namespaces and old fixtures remain unchanged. Failed reads retain known
external content independently of authored event freshness. Account changes fence
both pending operations and private cached presentation.

## Backend contract

Edge function external_calendar: action + lane; status, connect, sources,
select_sources, pause, resume, refresh, disconnect. OAuth callback returns to
existing /#/settings with a safe external_calendar status, never codes or tokens.
Status: available, nullable connection (id/provider/account_label/status/automatic/
last_synced_at/error_code), sources array (id/label/selected/color/read_only/
last_synced_at/error_code), syncing and retry_at. Source IDs are server UUIDs.
Connect returns authorization_url. Failures use error.code and error.retryable.
Read RPC read_external_calendar_events_v1(p_lane,p_from,p_until) returns typed
projection rows. IDs are separate from authored event IDs, with external: client
identity. Date-only all-day values remain date-only until local presentation.

Complete paginated snapshots are the first provider strategy. A complete selected
calendar window is applied atomically under a generation, selection revision and
expiring refresh lease. Global operation deadlines bound serial page processing.
The periodic server worker owns refresh when the app is closed; foreground and
manual requests supplement it. Scheduler configuration is explicit and verified,
not inferred from an active-app timer.

## Verification and deployment

Static panel states: disconnected, connecting, calendar selection, connected,
refreshing, paused, offline/retained, reconnect required and unavailable. Phone,
landscape and enlarged text must retain the current housing and readable controls.
Fault, account/lane isolation, storage, source-identity and pagination tests precede
live account connection. Full App/backend gates and served artifact verification
remain mandatory for deployments. Public Google launch also requires production
OAuth publishing and working homepage/privacy-policy requirements.

## Local review receipt — October 2, 2026

The fresh candidate is implemented locally in the canonical RC and backend
checkouts. No failed branch or implementation was imported. No commit, push,
hosted migration, function deployment, secret change, or OAuth-client creation
has occurred for this candidate. Production remains unchanged.

| Requirement | Status and evidence |
| --- | --- |
| Current Settings visual contract | Verified locally in portrait, landscape and 2x text, including source selection, recovery, disconnect and device ownership states; representative captures are in `/tmp/haw-fresh-calendar-visuals/` and `/tmp/haw-fresh-device-calendar-visuals/`. |
| One-way ownership and read-only UI | Verified in account/lane/provider SQL smoke assertions, domain tests, real DayView widget tests and mutation-order guards. Provider projections never enter authored-event storage. |
| Google consent, refresh, reconciliation and recovery | Implemented; provider/domain fault tests pass. Real Google consent, expired-token refresh, revocation and unattended scheduler acceptance remain incomplete until RC configuration/deployment. |
| Apple/device path | Fresh Swift/Kotlin bridge and controller implemented. iOS simulator build, Android debug build, and actual simulator channel smoke passed. The final normal RC simulator app was rebuilt and installed over the test harness; startup visibly reached sign-in. Its notification prompt was left unanswered and the app was closed after inspection. Physical-device permission, real calendar queries and Android runtime acceptance remain incomplete. Apple import connects through the installed app; its uploaded account projection is also readable in the PWA. |
| Auth, startup and account isolation | Local fault/retry tests pass; import recovery starts after a rendered frame and does not await unrelated auth warmups. Calendar callback tokens never enter Hꜣw sign-in. Consent failure notices are transient and account-bound; callback query consumption, warm return, forged connected outcomes and unknown outcomes have widget/app-link evidence (40 focused tests). Combined calendar/search warm snapshots reject another lane. |
| Dates, recurrence and identity | Complete provider snapshots and stable occurrence identity have unit/SQL evidence. Local multi-day display, exclusive midnight, civil DST boundaries and repeated-hour ledger ordering have regression coverage. Real provider recurrence edits/cancellations remain live acceptance. |
| Backend gates | 605 Deno tests and 72 Python source contracts passed; new migration plus smoke assertions passed inside a rolled-back local PostgreSQL transaction, including an authored-event checksum. The complete clean-database CI gate remains pending remote publication. |
| App release gate | Complete local app suite passed: 3,451 tests, one pre-existing skipped DST test, zero failures. Whole-app analysis has zero errors/warnings and the same six pre-existing informational notices. Bootstrap, release pipeline, visual inventory, warm-state, deep-link and served-artifact verifier contracts passed. The closed extent digest was updated only after an explicit source/equation audit and 20 passing rendered-bounds comparisons; approved visual references were not regenerated. Exact-commit remote App CI and named RC artifact build/served verification remain pending publication. |
| Legacy imported copies | Preserve the 15 old Android copies. Their opaque legacy IDs cannot reliably match fresh Google identities; one is upcoming. No fuzzy deduplication or shared-row deletion is authorized. Evaluate the copies during real import acceptance. |
| Production rollout | Incomplete and outside this RC publication. Production Google publishing/verification and required public legal pages must be resolved before claiming a durable public Google connection. Testing-mode Google calendar refresh grants expire after seven days. |

Automatic approval review rejected the attempted backend main-branch publication
before any commit or push, stating that explicit authorization was required for
the shared main-branch mutation. Local preparation continued. The user then explicitly authorized canonical
RC/backend publication, their required CI gates, additive backend/RC deployment,
and dedicated RC OAuth configuration/testing with “do it.” No production app
deployment is included. The local review receipt above records the pre-publication
state; remote gate and deployment receipts must establish the published state.


Final app evidence: `/tmp/haw-fresh-release-candidate-app-tests.log`,
`/tmp/haw-fresh-release-candidate-analyze.log`, and
`/tmp/haw-fresh-final-static-gates.log`. Backend evidence:
`/tmp/haw-fresh-calendar-backend-tests.log` and
`/tmp/haw-fresh-calendar-sql-proof.log`. Simulator bridge evidence:
`/tmp/haw-fresh-native-simulator-smoke.log`. These are local validation receipts,
not a substitute for exact-commit remote gates or live provider acceptance.

Served identities rechecked after implementation: RC remains
`staging-70e9952-43547ecd2e36`; production remains
`production-70e9952-ae6fa63bee4a`, both at app commit `70e99527`.

Normal RC simulator startup capture:
`/tmp/haw-fresh-calendar-normal-startup.png`. No calendar or notification
permission was granted during the smoke check; this verifies visible normal
startup, not signed-in physical-device import acceptance.


Pre-deployment acceptance review corrections: device calendar source selection
now preserves an existing pause; only explicitly created setup starts automatic
import after its first successful snapshot. Denied permission guidance directs
users to device Settings and offers Retry calendar access in the same panel.
Forty controller/authority tests and 56 panel/binding tests passed; portrait and
landscape at 1x/2x text were inspected. The corrected backend passes 607 Deno
tests on the exact CI toolchain plus the expanded real SQL smoke, including
paused manual imports, worker scheduling, and invalidation by later pauses.
These corrections require fresh exact-commit remote gates before deployment.
