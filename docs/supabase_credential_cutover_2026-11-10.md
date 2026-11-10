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
- The backend source contains 47 references to `SUPABASE_SERVICE_ROLE_KEY` across
  34 source owners, including shared helpers and one test reference. Reading that
  legacy variable does not migrate a function to a new secret key.
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
  legacy keys is awaiting owner input. No native-build retirement was inferred
  from web receipts.

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

## Owner input needed before cutover

Identify any installed iOS/Android builds or external integrations that must remain
supported. If the inventory is uncertain, keep this as a staged migration with an
explicit final cutover decision; silently disabling existing clients conflicts
with the requirement to preserve the user-facing experience. This does not make
the exposed key safe while it remains enabled.

Primary references: [Supabase leaked-key retirement](https://supabase.com/docs/guides/security/rotate-leaked-api-keys),
[key migration](https://supabase.com/docs/guides/getting-started/migrating-to-new-api-keys),
[legacy-key toggle](https://supabase.com/docs/reference/api/v1-update-project-legacy-api-keys).
