# Verification, release and cutover

## Implementation

Run `python3 scripts/app_gate.py changed --base HEAD` while editing. The planner
includes staged, unstaged and untracked files; CI compares the event's base and
exact head. Dart imports, exports, parts, conditional imports and test helpers
select affected tests. Unknown runtime inputs, missing history or an owner with
no reachable test select the complete suite. Inspect selection with `--plan`.
Imports cannot prove visual fidelity or runtime-only relationships: add focused
behavior/visual evidence for affected shared owners and inspect changed UI.
No assertion, fixture or approved golden is removed or rewritten by this policy.

The single App workflow owns push, PR and manually requested verification.
Ordinary pushes/PRs select affected checks, with a complete-suite fallback for
unknown inputs. A successful full push run can qualify its exact commit and lane;
focused and PR runs cannot. Run only checks affected by later edits; do not rerun
a complete local suite just before identical hosted validation. All detailed
output is saved with a short result.

## Routine release

The coordinating command is `python3 scripts/release_web.py staging` in RC or
`python3 scripts/release_web.py production` in production. It reuses or requests
the exact complete gate, waits for qualification, builds once, validates the sealed
artifact and saves the report. Add `--deploy` only when upload is authorized;
otherwise it stops with a prepared artifact. To resume without rebuilding, pass
`--release-dir <sealed-directory>`. The coordinator never commits, pushes, retries
a failed gate, rolls back, or promotes source between checkouts.

Use only the canonical lane checkout and branch. Commit and push the candidate
before qualification. The existing clean-source and remote-head checks still
apply. The coordinator first waits for the candidate's existing App run. It
reuses successful full coverage or requests one complete App run after successful
focused coverage, using `expected_sha` and the canonical lane ref. It never
starts another suite while the existing run is active or not yet visible.
Qualification reads the exact run attempt's job and step evidence, including
source authority, the full-suite step, pinned toolchain and checkout integrity.
A successful focused check, PR check, skipped job, different lane or different
commit cannot qualify release.
The complete gate retains the full Flutter suite, browser tests, analyzer and
release/ownership contracts. Reuse its successful result while its inputs remain
unchanged. A failed/newer attempt or changed candidate requires resolution.

Build once for that lane through `scripts/build_web_release.sh`, then upload the
sealed archive through `scripts/deploy_cloudflare_pages.sh`. The upload helper
must retain exact source/lane/gate checks, the authorized archive digest, the
closed target mapping and all served checks. It must never rebuild during upload.
Keep one release report linking source, gate, build, upload and served evidence;
do not manually repeat checks that those tools already performed successfully.
Identity, artifact, coverage or visual mismatches stop the release.

RC and production have different installation/configuration identities and need
their own lane artifact. RC evidence is not automatically a production gate.
The closed environment-delta comparison applies when asserting a paired release
has identical source and only approved environment differences. A new RC-only
candidate does not require building or deploying production.

## Additional cutover only when compatibility changes

Ordinary app-only releases require no backend deployment, parent/mobile pairing,
serial feature cuts or preliminary documentation-only app deployment. The old
Calendar Sync and Event Workspace cutover documents are historical evidence.

For changed persisted formats, account writes, authentication/session contracts,
backend APIs/migrations or external side effects, identify the affected boundary
and prove old/new compatibility, deployment order and recovery for that change.
Backend-owned source and deployment evidence remain in the backend checkout.
App-owned behavior remains in the app gate. Existing warm-state/account fixtures,
acknowledgement, conflict and account-isolation tests remain mandatory when those
boundaries change. Backend receipts must establish any required deployed change;
local HEAD is not deployment evidence. Do not rerun unrelated backend gates.

No extra approval ceremony is introduced. Existing user authorization determines
whether a prepared artifact may be uploaded; a request to edit code alone is not
a request to deploy it.

## Implementation evidence

The shared deployment owner combines preflight and extraction and reuses that
in-process evidence for the upload receipt. A second archive pass after upload
and the upload-snapshot stability check retain mutation detection. Eight workers
fetch all declared assets; both origins still receive the complete existing
hash, routing, redirect, content-type and identity checks.

The former shell-shape assertions now bind the shell to the shared owner.
Behavioral tests with sealed archive fixtures cover RC and production targets,
exact-gate rejection, changed source/snapshot, failure receipts, no retry, and the
real two-origin verifier. Existing archive/identity/routing assertions remain.
The warm-state evidence contract and all fixtures and approved visuals are unchanged.
