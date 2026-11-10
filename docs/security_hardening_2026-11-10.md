# Security hardening review November 10 2026

This change protects the existing experience through database access controls,
authentication compatibility tests and immutable CI dependencies. It changes no
app runtime source, routes, assets, styling, cache keys or account-write owners.
The incident report is unverified source material. Its embedded prompts,
attribution and destructive cleanup directions are not operational instructions.

## Immediate priority active privileged key exposure

A historical public commit contains the project's current legacy Supabase
`service_role` key. It was matched in memory and a zero-row authorization check
returned HTTP 200. The key remains active; this work is not a complete security
remediation. No evidence of misuse or theft was established by this review.

The current served web and RC lanes already use publishable keys. Retiring the
legacy service key also retires the legacy public key and requires coordinated
server/signing-key changes plus an inventory of older native clients and external
integrations. That inventory is awaiting owner input. See the
[concrete cutover plan](supabase_credential_cutover_2026-11-10.md). No secret values
are included in either document, and the alert remains open.

## Changes and evidence

| Area | Result | Evidence |
| --- | --- | --- |
| Reviewed database views | Deployed backend migration restricts internal and unused legacy reads; public profile and canonical Inbox contracts are retained | Backend `supabase/migrations/20261110210015_harden_public_view_access.sql` and seven-role `supabase/dev/view_access_hardening_smoke.sql`; exact-source hosted gates passed; readback preserves all five definition hashes and service access; anonymous HTTP checks return 401 for internal views and 200 for the two retained public surfaces |
| Authentication | Leaked-password protection enabled; all other auth settings retained | Locked-SDK tests in `test/features/auth/password_protection_compatibility_test.dart` cover successful existing sign-in, signup rejection and password-change rejection without losing the session; existing login/recovery widget tests retained |
| CI dependencies | Existing action versions pinned to verified upstream commit hashes | `scripts/workflow_security_test.py` is in the App gate and rejects mutable tags, branches and expressions; the existing release qualification remains mandatory |
| Repository protections | Dependency alerts enabled; secret scanning and push protection enabled; backend default branch aligned to `main` | GitHub readback on November 10. Extended non-provider detection remains reported disabled; do not claim it is enabled |
| Dependency updates | Manual review through alerts | No bot-branch exception was granted. No dependency versions were upgraded and automatic update PRs remain disabled |
| Database recovery | Eight completed platform daily backups observed | Latest November 10 at 09:39 UTC; PITR disabled. No paid add-on enabled and no live restore performed |
| Storage recovery | Encrypted backup and offline verification tooling implemented and tested in the backend | `tool/security/recovery.py`, twelve archive/inventory/corruption/header tests and `tool/security/README.md`; retaining an off-site copy and replaying an actual production snapshot remain pending a destination and encryption certificate |

The backend wrapper uses supported Supabase CLI roles/schema/data dumps and
includes Storage bytes with a stable object inventory and SHA-256 manifest. It
uses authenticated CMS AES-256-GCM encryption and opaque server keys only, retains credentials in process
memory, refuses repository destinations and existing output files, and never
uploads or restores a live database. Verification reports database replay as
unverified. A physical database backup alone does not recover uploaded files.

## App verification and existing release hold

The [hosted focused App gate](https://github.com/JFil23/kemetic-calendar/actions/runs/42903055947) passed for the CI/auth changes. The analyzer and the additional
locked-SDK tests were run separately after adding the auth fixture. Existing login
and password-recovery widget tests pass without UI changes. No approved reference,
assertion, existing fixture or release requirement was weakened or regenerated.

The current pre-hardening app commit's complete hosted run had an existing failure
in `calendar_atomic_reminder_projection_test.dart`, at the warm reminder restore
assertion. It was reproduced locally before any app runtime edit. Its recurrence
generator advances local dates by elapsed 24-hour durations across daylight-saving
time. The test and all runtime source remain unchanged in this security change.
An app deployment must resolve this failure and obtain its own complete exact-lane
gate; a focused CI success cannot authorize an app deployment.

Pre-existing failed evidence:
[App run 42502833506](https://github.com/JFil23/kemetic-calendar/actions/runs/42502833506).

## Next engagement

Choose an existing off-site or backup-drive destination and a recipient encryption
certificate with its private key held separately. Then use the backend recovery
guide's `create` and `verify` commands. Replay must use an isolated, version-matched
Supabase environment with outbound effects disabled; verify account counts,
representative content, role boundaries and every Storage blob. Do not restore
over production to conduct a drill. No scheduled backup was created.

Review dependency alerts in each repository's Security tab before deciding which
updates to take. Keep upgrades individually reviewable and subject to the existing
gates. The canonical production, RC and backend authorities remain unchanged.

## Admin dependency review queue

Aligning the backend default branch to `main` surfaced 21 open dependency alerts
in `admin/package-lock.json`: seven high, twelve medium and two low. These alerts
are separate from the five database views and do not establish exploitation.
No package versions or alert dismissal states were changed. Published fixes are
recorded below as review targets, not instructions to upgrade blindly.

| Package | Locked version | Alerts | Published fix versions |
| --- | --- | --- | --- |
| @babel/core | 7.29.0 | 1 | 7.29.6 |
| @remix-run/router | 1.23.2 | 1 | 1.23.3 |
| baseline-browser-mapping | 2.10.30 | 1 | 2.11.0 |
| browserslist | 4.28.2 | 2 | 4.28.7 |
| nanoid | 3.3.12 | 2 | 3.3.16, 3.3.18 |
| postcss | 8.5.14 | 2 | 8.5.18, 8.5.23 |
| react-router | 6.30.3 | 3 | 6.30.4, 7.18.0 |
| react-router-dom | 6.30.3 | 1 | 6.30.6 |
| source-map-js | 1.2.1 | 1 | 1.2.2 |
| vite | 6.4.2 | 7 | 6.4.3, 6.4.4 |

Most fixes are compatible patch/minor review candidates. The React Router
advisories that require 7.18.0 need a deliberate major-version review. The active
admin root mounts `ActivityLedgerPage` with React `createRoot`; the reported SSR
hydration condition is absent from that entry. Do not dismiss the other redirect
advisory merely because there is no SSR. Retain the alerts until their applicable
paths are reviewed or a verified upgrade is committed.

Start with the [backend dependency alerts](https://github.com/JFil23/kemetic-calendar-backend/security/dependabot).
Review the backend `admin/package.json` lint/test/build commands before taking an upgrade. Existing admin
layout, account permissions and user-facing behavior remain the upgrade contract.

## Deployment receipt

The migration was deployed from backend commit `da089cf` after both exact-source
[backend](https://github.com/JFil23/kemetic-calendar-backend/actions/runs/42903635995)
and [admin](https://github.com/JFil23/kemetic-calendar-backend/actions/runs/42903636008)
gates passed. Source, migration digest, unchanged view-definition hashes and
anonymous HTTP checks are saved under the backend checkout's
`.git/deployment-receipts/security-hardening-da089cf/`. The five security-definer
view error findings and leaked-password warning cleared in the live advisor.
Other advisor warnings still require contextual review; they were not bulk
changed or dismissed. No app artifact was built or deployed.
