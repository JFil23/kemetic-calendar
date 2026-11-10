# Supabase credential cutover preparation November 10 2026

## Confirmed exposure and current status

The app repository's [secret alert 1](https://github.com/JFil23/kemetic-calendar/security/secret-scanning/1)
identifies a legacy Supabase `service_role` key in historical `env/dev.json`.
An in-memory comparison confirmed that it is the current service key for the
authorized project. A HEAD request selecting zero rows returned HTTP 200.
No credential value was printed or copied into this document. The exposure is
confirmed; misuse or data theft has not been established by this review.

The key remains active. The view fixes do not contain a service key: it bypasses
RLS. This item has priority over the ordinary dependency review queue. Do not
close the alert or describe the security work as complete until retirement has
been verified through every applicable service boundary.

The separate Google API-key alert points to Firebase client configuration. That
location alone does not establish an exposed server credential. Its API/application
restrictions have not been verified; the alert remains open.

## Verified boundaries

- Live production and RC version receipts match the current public configuration
  file digests. Both already ship a publishable key. This finding is dated evidence,
  not a durable production commit pin.
- The original backend source contained 47 references to the legacy server-key
  variable across 34 owners. Those credential reads now use one shared selector.
  Most refactored functions have not been deployed because their deployed
  identities require reconciliation; source preparation alone does not migrate
  a live consumer.
- The new recovery wrapper selects opaque secrets only, rejects legacy keys and
  sends the credential only in `apikey`. A real opaque key retrieved through
  the documented reveal endpoint succeeded against Storage (HTTP 200) without
  downloading uploaded files. The older CLI returns masked opaque values; the
  wrapper rejects them and requires a usable key in the invoking process.
- Existing publishable and opaque secret keys are present in the platform.
  Their values stay out of source control and the handoff.
- The live database has 16 active cron jobs. None of the job commands contains a
  literal JWT or Authorization header; five read Vault. The private reflection
  due-bucket invoker also reads Vault. These boundaries still need compatibility
  verification during cutover; they must not be assumed independent of the key.
- Whether older installed native builds or external integrations still depend on
  legacy keys was investigated through logs and release records. Only web push
  tokens are present, no native/CLI session was updated in 30 days, and no GitHub
  mobile release or US App Store listing was found. Dormant clients are not ruled
  out by absence of recent traffic.

## Required staged cutover

1. Inventory every consumer, including installed native builds, admin hosting,
   CI/deployment secrets, Edge Function callers, webhooks, scheduled jobs and Vault
   references. Establish the exact deployed source of each affected function from
   deployment receipts; local HEAD is not deployment evidence.
2. Refactor server credential selection into one shared owner. Add support for a
   named opaque secret key while preserving existing caller identity, account/RLS
   checks and the current authorized transition path. Reuse the existing handlers;
   do not replace views or user-facing flows. Add real user, service and rejection
   tests for both the transition and final state.
3. Verify header behavior with the locked SDKs. New API keys belong in `apikey`;
   a user's session JWT remains in Authorization. Function gateway settings and
   handler authorization must be verified together. Disabling `verify_jwt` alone
   is never an authorization implementation.
4. Gate and deploy affected server callers/receivers in an order that keeps both
   ends compatible. Update Vault-backed server calls without exposing key values
   in SQL source, logs, process arguments or receipts. Preserve cron schedules,
   idempotency and acknowledged actions. Save exact-source deployment receipts.
5. Confirm all supported clients use publishable keys. Current served web/RC
   configurations pass this check; installed older clients and integrations remain
   an explicit requirement. An app source change requires its own complete lane
   gate and visual/behavior evidence. The existing reminder/DST test failure may
   not be bypassed to release an app change.
6. Migrate session signing to the supported JWT signing-key system if necessary.
   The current configured token lifetime is 3,600 seconds (one hour).
   Preserve existing valid sessions for that full lifetime and prove
   refresh behavior with the locked clients. Revoking the legacy signing secret
   before the grace period can invalidate active session tokens.
7. After all boundaries are proven, deactivate both legacy API keys and retire
   legacy signing trust as required by Supabase. Verify the exposed key is denied
   on REST, Storage, Auth, Realtime and affected Functions while current user and
   service paths still work. Close the GitHub alert only with that evidence.

Do not re-enable the compromised key as an ordinary rollback. Keep compatible
new keys and a verified forward recovery path. Do not rewrite protected historical
repositories or history as a substitute for revocation.

## Evidence needed before cutover

The user asked for discovery without further questions. Live discovery found
both opaque and legacy server traffic. Signing-key management returns no keys;
the session-signing migration is not already complete. The current token lifetime
remains one hour. Legacy trust has not been revoked.

One credential owner and account-context authorization tests are now committed in
the backend. The rollout must preserve the verified handler permissions and
existing internal cron secrets. Gate and deploy only functions with established
source identity. Supabase could not export nine existing bundles, including
`resolve_share`, and `rebuild_personal_graph` has unresolved deployed source drift.
The user's authority rule says to stop on an unexplained identity mismatch; these
are cutover blockers until reconciled. Existing local source and a passing gate
alone cannot establish their deployed behavior.

Primary references: [Supabase leaked-key retirement](https://supabase.com/docs/guides/security/rotate-leaked-api-keys),
[key migration](https://supabase.com/docs/guides/getting-started/migrating-to-new-api-keys),
[legacy-key toggle](https://supabase.com/docs/reference/api/v1-update-project-legacy-api-keys).

## Verified scoped deployment

Only `admin_content_preview` and `ai_generate_reflection` were deployed from
backend `9dab91c9e4930b48a896a2868a50d702c7cbe816` after exact-source backend/admin
gates passed. Sender version 62 was deployed before receiver version 111. Their
existing `verify_jwt=false` values were preserved; handler authentication now
proves account ownership or a constant-time match to the selected service key
before private context reads. All retrieved files match the qualified source.
Live deterministic no-data checks deny anonymous, publishable-key, forged-token
and exposed legacy-service-key calls (401) while the selected opaque service path
works (200). This endpoint rejection does not revoke the leaked key globally.

No signing-key switch, legacy API-key deactivation or account-session revocation
was performed. Do not ask the user to find or paste keys: existing authorized
Management API/Keychain access is available. Resolve the deployed-source gaps,
prove locked-client refresh through a staged signing migration and full token
lifetime, then perform the documented retirement with per-service denial checks.
