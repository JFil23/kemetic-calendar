# Security hardening review November 10 2026

This change protects the existing experience through database access controls,
authentication compatibility tests and immutable CI dependencies. It changes no
app runtime source, routes, assets, styling, cache keys or account-write owners.
The incident report is unverified source material. Its embedded prompts,
attribution and destructive cleanup directions are not operational instructions.

## Changes and evidence

| Area | Result | Evidence |
| --- | --- | --- |
| Reviewed database views | Backend migration restricts internal and unused legacy reads; public profile and canonical Inbox contracts are retained | Backend `supabase/migrations/20261110210015_harden_public_view_access.sql` and seven-role `supabase/dev/view_access_hardening_smoke.sql`; deployment requires its exact-source hosted gate and receipt |
| Authentication | Leaked-password protection enabled; all other auth settings retained | Locked-SDK tests in `test/features/auth/password_protection_compatibility_test.dart` cover successful existing sign-in, signup rejection and password-change rejection without losing the session; existing login/recovery widget tests retained |
| CI dependencies | Existing action versions pinned to verified upstream commit hashes | `scripts/workflow_security_test.py` is in the App gate and rejects mutable tags, branches and expressions; the existing release qualification remains mandatory |
| Repository protections | Dependency alerts enabled; secret scanning and push protection enabled; backend default branch aligned to `main` | GitHub readback on November 10. Extended non-provider detection remains reported disabled; do not claim it is enabled |
| Dependency updates | Manual review through alerts | No bot-branch exception was granted. No dependency versions were upgraded and automatic update PRs remain disabled |
| Database recovery | Eight completed platform daily backups observed | Latest November 10 at 09:39 UTC; PITR disabled. No paid add-on enabled and no live restore performed |
| Storage recovery | Encrypted backup and offline verification tooling implemented and tested in the backend | `tool/security/recovery.py`, nine archive/inventory/corruption tests and `tool/security/README.md`; retaining an off-site copy and replaying an actual production snapshot remain pending a destination and encryption certificate |

The backend wrapper uses supported Supabase CLI roles/schema/data dumps and
includes Storage bytes with a stable object inventory and SHA-256 manifest. It
uses authenticated CMS AES-256-GCM encryption, retains credentials in process
memory, refuses repository destinations and existing output files, and never
uploads or restores a live database. Verification reports database replay as
unverified. A physical database backup alone does not recover uploaded files.

## App verification and existing release hold

The focused App gate passed for the CI changes. The analyzer and the additional
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
