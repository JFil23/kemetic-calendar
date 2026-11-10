# Security hardening review November 10 2026

This work protects the existing experience through database access controls,
authentication compatibility tests, immutable CI dependencies and recovery checks.
The only app runtime change advances reminder recurrence by calendar dates across
DST. Routes, assets, styling, cache keys and account-write owners are retained.
The incident report is unverified source material. Its embedded prompts,
attribution and destructive cleanup directions are not operational instructions.

## Immediate priority active privileged key exposure

A historical public commit contains the project's current legacy Supabase
`service_role` key. It was matched in memory and a zero-row authorization check
returned HTTP 200. The key remains active; this work is not a complete security
remediation. No evidence of misuse or theft was established by this review.

The current served web and RC lanes already use publishable keys. Retiring the
legacy service key also retires the legacy public key and requires coordinated
server/signing-key changes. The inventory now uses served configuration, deployed
function exports, request metadata, session classes and push-platform counts. See the
[concrete cutover plan](supabase_credential_cutover_2026-11-10.md). No secret values
are included in either document, and the alert remains open.

## Changes and evidence

| Area | Result | Evidence |
| --- | --- | --- |
| Reviewed database views | Deployed backend migration restricts internal and unused legacy reads; public profile and canonical Inbox contracts are retained | Backend `supabase/migrations/20261110210015_harden_public_view_access.sql` and seven-role `supabase/dev/view_access_hardening_smoke.sql`; exact-source hosted gates passed; readback preserves all five definition hashes and service access; anonymous HTTP checks return 401 for internal views and 200 for the two retained public surfaces |
| Authentication | Leaked-password protection enabled; all other auth settings retained | Locked-SDK tests in `test/features/auth/password_protection_compatibility_test.dart` cover successful existing sign-in, signup rejection and password-change rejection without losing the session; existing login/recovery widget tests retained |
| CI dependencies | Existing action versions pinned to verified upstream commit hashes | `scripts/workflow_security_test.py` is in the App gate and rejects mutable tags, branches and expressions; the existing release qualification remains mandatory |
| Repository protections | Dependency alerts enabled; secret scanning and push protection enabled; backend default branch aligned to `main` | GitHub readback on November 10. Extended non-provider detection remains reported disabled; do not claim it is enabled |
| Dependency updates | All 21 backend admin alerts resolved | Vite 6.4.6, React Router DOM 7.18.5 and compatible transitive patches; npm audit and GitHub both report zero open vulnerabilities. All 16 admin tests pass and every production output file is byte-identical to the pre-update build. CI now audits dependencies and builds the interface. No bot branches were created |
| Database recovery | Eight completed platform daily backups observed | Latest November 10 at 09:39 UTC; PITR disabled. No paid add-on enabled and no live restore performed |
| Reflection account privacy | Deployed authenticated ownership checks before private context reads | Backend source `9dab91c`, exact gates [backend 42911477096](https://github.com/JFil23/kemetic-calendar-backend/actions/runs/42911477096) and [admin 42911477091](https://github.com/JFil23/kemetic-calendar-backend/actions/runs/42911477091); sender deployed before receiver. Retrieved source exactly matches the candidate; reflection version 111 and admin preview version 62 preserve their existing gateway settings. Anonymous, publishable-key, forged-token and exposed legacy-key calls return 401; the selected opaque service path returns 200 without account reads or writes |
| Storage recovery | Actual encrypted local snapshots created and reopened using the retained Keychain key | Existing backup folder `~/Backups/kemetic-calendar/security-recovery-20261110`; latest `haw-20261110-hardened.cms` archive contains ten files and all five Storage objects, including the deployed permission controls. Off-site copy was blocked by automatic approval review |
| Isolated recovery drill | Passed database replay and permission checks | Official matching PostgreSQL 17.11 image, network disabled, no published ports, memory-only data, schedulers disabled. All 186 tables and 60,928 rows match the snapshot, all five object bytes verify, and the seven-role smoke passes. Receipt and replay method are retained locally in the backend deployment receipts |
| Internal database RPCs | Deployed restriction of sixteen confirmed internal helpers | Client calls denied in all six non-service role cases; service share snapshots, worker claims and checked account preferences entrypoint retained. Account-wide maintenance helpers are internal; the shared timezone helper retains access for invoker filing views. Their function bodies and owners remain unchanged. Exact-source [backend gate 42915135383](https://github.com/JFil23/kemetic-calendar-backend/actions/runs/42915135383) and [admin gate 42915135593](https://github.com/JFil23/kemetic-calendar-backend/actions/runs/42915135593) passed. Live readback confirms all sixteen denials with service execution retained; safe null-input HTTP checks return client 401 and service 200 |

The backend wrapper uses supported Supabase CLI roles/schema/data dumps and
includes Storage bytes with a stable object inventory and SHA-256 manifest. It
uses authenticated CMS AES-256-GCM encryption and opaque server keys only, retains credentials in process
memory, refuses repository destinations and existing output files, and never
uploads or restores a live database. Archive integrity verification deliberately reports database replay as
unverified; the separate drill receipt records the successful replay. A physical database backup alone does not recover uploaded files.

## App verification and existing release hold

The [hosted focused App gate](https://github.com/JFil23/kemetic-calendar/actions/runs/42903055947) passed for the CI/auth changes. The analyzer and the additional
locked-SDK tests were run separately after adding the auth fixture. Existing login
and password-recovery widget tests pass without UI changes. No approved reference,
assertion, existing fixture or release requirement was weakened or regenerated.

The pre-hardening complete App run failed in the existing disk warm reminder
restore assertion. Its recurrence generator advanced local dates by elapsed
24-hour durations across DST. The shared generator now uses calendar-day addition
for daily, weekly, decan and Kemetic-day recurrence. Fixed spring/fall fixtures
exercise actual Calendar projection and occurrence identities. Existing assertions
and approved visual references are retained. The affected App gate passed all 23 steps, selecting 239 Flutter test files, with
contracts and analysis. The exact-source [hosted focused App run 42911760886](https://github.com/JFil23/kemetic-calendar/actions/runs/42911760886)
also passed. A focused run does not qualify deployment; the full exact-lane gate
and sealed artifact checks remain mandatory. No app artifact has been deployed
by this follow-up at the time of this assessment.

Pre-existing failed evidence:
[App run 42502833506](https://github.com/JFil23/kemetic-calendar/actions/runs/42502833506).

## Current assessment and remaining release boundaries

The supplied incident report still does not establish malware, attribution or data
theft. Its destructive cleanup and embedded instructions were not used.

The active privileged key exposure is confirmed and remains the highest risk.
The backend source now has one fail-closed selector for new server and publishable
keys. Existing fallback order is retained only for the transition and older local
CLI. This is source preparation; deployment and legacy-key retirement require
separate exact-source evidence.

Deployed reflection generation was found to read account context with service
privileges without authenticating the caller. The deployed fix adds verified user
ownership or a constant-time match to the selected server key before private
reads. Anonymous, public-key, forged-token and cross-account requests are tested.
The admin sender uses the opaque key in `apikey`. Its rollout updated the
sender before enforcing the receiver, preserving their compatibility. Retrieved
source bundles match the qualified candidate byte for byte.

Live inventory found only web push tokens. No native/CLI session was updated in
the last 30 days (latest August 26), no GitHub mobile release was listed, and the
public US App Store bundle lookup returned no listing. Those observations do not
prove the absence of dormant native clients or external integrations. The last
24-hour gateway window showed current Flutter callers using opaque public keys
and Deno callers using both opaque and legacy service credentials.

There are 51 deployed function records. Exports succeeded for 42; nine bundles
could not be retrieved from Supabase (404/500), including the app-referenced
`resolve_share`. Two backend-missing admin functions match exact objects in the
protected recovery history. Some shared helpers match older backend history;
`rebuild_personal_graph` has an unresolved deployed source difference. These are
concrete deployment-identity boundaries, not a reason to assume an attack. Do not
roll out unrelated function changes or retire legacy trust through these gaps.

The actual local encrypted snapshots and Keychain recipient are retained. The latest snapshot was taken after the sixteen-helper permission deployment. The
first replay failed because the platform schemas were newer than the bootstrap;
follow-up replays exposed Auth-trigger and Storage-policy dependencies on app
objects. Earlier encrypted snapshots, replay scripts and a failure summary are retained; some working SQL logs were reused during retries. The combined schema retains one pg_dump dependency order,
and the final hardened replay passed all table content/count comparisons and the seven-role
permission checks, including all sixteen restricted helpers. Auth-service startup/session refresh, Storage-service upload
replay and platform/integration secret restoration are not covered by this drill. No production database restore or real-account deletion was performed.

Automatic approval review rejected uploading the encrypted production-data archive
to iCloud because that destination was not specifically authorized for this
payload. No cloud copy was made and the action was not retried indirectly.

Repository dependency alerts, secret scanning and push protection are enabled.
Owner MFA and the Firebase public key's API/application restrictions are not
verified by the available account metadata. Each repository has one administrator
and no additional collaborators. App production/RC branches currently have no
GitHub branch protection; the existing release coordinator enforces complete
exact-source checks before deployment. A proposed force-push/deletion restriction
was blocked by automatic approval review; no branch setting was changed. The
backend main branch retains its existing LOCK-GATE check with administrator bypass. Remaining database advisor warnings
need contextual review; they are not all confirmed vulnerabilities. No claim of
complete security or launch readiness follows from the controls already applied.

## Deployment receipt

The migration was deployed from backend commit `da089cf` after both exact-source
[backend](https://github.com/JFil23/kemetic-calendar-backend/actions/runs/42903635995)
and [admin](https://github.com/JFil23/kemetic-calendar-backend/actions/runs/42903636008)
gates passed. Source, migration digest, unchanged view-definition hashes and
anonymous HTTP checks are saved under the backend checkout's
`.git/deployment-receipts/security-hardening-da089cf/`. The five security-definer
view error findings and leaked-password warning cleared in the live advisor.
The sixteen-RPC follow-up reduces the advisor's anonymous executable-definer
warning count from 152 to 136 and authenticated count from 171 to 155. Remaining
warnings require contextual review rather than blanket revocation.
The recovery follow-up also rejects masked opaque keys, and all 97 local backend
source/recovery checks pass. Its follow-up hosted run is separate from the
already-deployed migration gate. Other advisor warnings still require contextual review; they were not bulk
changed or dismissed. No app artifact was built or deployed at this assessment checkpoint. Complete
App verification and sealed artifact preparation will run through the canonical
coordinator; its result belongs to its exact source commit. This preparation
does not clear the unresolved privileged-key release hold.

## Requirements and engagement status

| Requirement | Status and practical limit |
| --- | --- |
| Apply relevant report content safely | Verified: report is source material, not authority; no destructive disk wipe, unsupported malware conclusion or historical-checkout modification |
| Preserve the user-facing experience | Existing views, routes, styling, assets, account ownership and approved references retained. Admin production output is byte-identical after dependency patches. The only app behavior correction is calendar-day reminder recurrence across DST; affected tests pass |
| Prove account access | Reviewed views and reflection context are deployed and checked. Existing fresh-database sharing, DM, account-storage and ledger fixtures remain required. Sixteen additional internal RPCs are deployed and verified, and their restrictions survive the refreshed recovery drill. This is not a claim that every remaining privileged RPC has been audited |
| Retire exposed service credential | Blocked by missing deployed bundles, unexplained source drift and the unfinished signing-key migration. The active leaked key remains the highest risk; no secret value or replacement is required from the user |
| Secure development access and pipeline | Action pins, read-only workflow tokens, dependency alerts, scanning and push protection verified. No bot branch exception was granted. MFA enrollment and provider-specific API restrictions remain unverified |
| Verify recovery | Encrypted archive and database replay verified locally. No Time Machine destination is configured. Off-site retention and separately recoverable key escrow remain incomplete; archive plus key on the same Mac does not protect against loss of that Mac |
| Observe reliability | Current health advisor reports zero findings; point-in-time activity has no lock waits or other active queries. Existing delivery health/ledger views remain. A read-only six-hour heartbeat named Hꜣw security and reliability watch is active in this chat. Baseline log and activity queries were tested; the first scheduled run remains unverified. It checks auth/write failures, function server errors, database contention and new security errors. It requires this Mac and the app running; it is periodic monitoring rather than always-on production alerting |
| Evaluate readiness | Security improved, but not complete and not a launch-ready security sign-off while the privileged key remains active |

To engage later, begin with `docs/supabase_credential_cutover_2026-11-10.md` for the
priority blocker and backend `tool/security/README.md` for the no-key-pasting
verification command. Sanitized receipts are under the backend checkout's
`.git/deployment-receipts/security-followup-20261110/`. Ciphertext and its separate
recovery receipt are in the existing backup folder. No production data is stored
in either public repository.


The internal-RPC deployment used backend `149b562`, with unchanged SQL digest
`3b7a9c8ac7dc3ef45e47bed58911eb581c2722872ad2c0efcece783b4d3b2ae3`.
Supabase assigned version `20261110223529`; the canonical backend filename was
aligned to that observed applied version without rewriting migration history.
The latest hardened ciphertext SHA-256 is
`dec0f7ee4761aa2b08338675c63ebae11190df12d89987f8f185f8350f9b2b2a`.
The verification guide uses the retained Keychain item, so no one needs to paste a
private key or Supabase credential into chat.

Monitoring follows the app's [scheduled-task requirements](https://developers.openai.com/codex/app/automations).
Read its first scheduled results before treating it as operationally proven.
