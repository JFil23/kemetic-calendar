# Event Workspace release cutover

Served production identity is a first-class authority, equal to event identity and time.

```text
SERVED_PRODUCTION_MOBILE_SHA → RELEASE_CANDIDATE_SHA
```

A feature PR and a production cut are different authorities. A PR being narrow is not enough. The production cut itself must be narrow.

Compare against the **mobile SHA currently served by production**, never remembered `origin/main`, a previous PR base, “the commit we think production came from,” or local parent.

```text
latest working served production
        +
small reviewed Event Workspace delta
        =
new candidate
```

Never replace working Hꜣw with a feature worktree.

## Production pair

```text
parent HEAD        == parent origin/main
mobile HEAD        == parent HEAD:mobile
mobile HEAD        == mobile origin/main
```

A clean pair behind main is not authorized. Worktree names prove nothing. Only SHAs prove identity.

## Worktree roles

**Development** (Cursor/Codex edit session): edit, test, commit, rebase. Must **never** deploy production.

**Candidate/release:** fetch, verify SHAs, LOCK-GATE, build immutable artifacts, deploy RC, after exact source promotion deploy production. No coding, cherry-picks, quick fixes, or file copies. Patching an accepted RC voids it.

## One cut per independently testable change

```text
PR 0 → production identity cut (no runtime RC)
PR 1 → RC → production
PR 2 → RC → production
...
PR 7 → production identity cut if tests-only; else RC → production
PR 5-prep (if needed) → RC → production before PR 5
Activation → RC → production
```

Do not accumulate PRs 1–7 as a development train. Flag-off (`enableEventWorkspace` remains false until Activation) makes serial machinery cuts user-invisible. That does not waive identity cuts.

## Served-production baseline

Before a candidate, record:

```text
served production build id
served production mobile SHA (PROD_BASE)
candidate SHA
expected changed files
expected runtime files
expected tests/docs
```

Require:

```bash
git diff SERVED_PRODUCTION_SHA...CANDIDATE_SHA --name-only
```

One unexplained file is a stop. Allowed files are the named PR envelope in `authority_map.md`.

## RC approval (product cuts)

```text
RC approval = approval of SHA X against production SHA Y.
```

Revoked by: rebase, merge from main, cherry-pick, amend, dependency resolution, generated-file change, test-only commit, conflict resolution, new parent SHA. Even when “no meaningful code changed.”

## After merge

```text
candidate head = proof tree (RC_SHA for product cuts; CANDIDATE_SHA when runtime RC is waived)
actual merge SHA = production source authority
```

```bash
git diff SERVED_PRODUCTION_SHA...ACTUAL_MERGE_SHA --name-only
git diff CANDIDATE_SHA...ACTUAL_MERGE_SHA --name-only
```

Required:

- production baseline → merge SHA: exactly the approved delta
- candidate SHA → merge SHA: **zero tree differences**

If the second comparison is non-empty, do not deploy.

## Backend pairing

```text
merge mobile
↓
read actual mobile main SHA
↓
verify diffs above
↓
create backend gitlink-only PR
↓
backend mobile gitlink = actual merge SHA
↓
merge backend pair
↓
LOCK-GATE / release contracts on that pair
↓
production deploy
↓
verify production serves that mobile SHA
```

Never pair backend to a pre-merge PR head.

## Docs/tests-only identity cut

Any merged mobile commit that becomes the base of a subsequent product candidate **must first become the served production mobile identity**.

```text
no runtime RC  ≠  no production identity cut
```

A docs/tests-only cut may waive manual runtime RC. It may **not** waive canonical pairing, release contracts, production deployment, or served-SHA verification.

### PR 0 (this cut)

No product behavior. No manual runtime RC.

```text
local → tests/CI
→ merge mobile
→ read actual mobile merge SHA
→ CANDIDATE_SHA → MERGE_SHA must be empty
→ backend gitlink-only pair to that SHA
→ LOCK-GATE / release contracts
→ production deploy
→ verify production serves that mobile SHA
```

That served PR 0 merge SHA is `PROD_BASE` for PR 1. Starting PR 1 from merged-but-unserved PR 0 would make `OLD_PROD → PR1` contain PR 0 docs/guards plus PR 1 runtime.

## Product-code cut (PR 1+)

1. Read the mobile SHA currently served by production (`PROD_BASE`).
2. Build one candidate from `PROD_BASE`.
3. `PROD_BASE → RC_SHA` contains only the named PR delta.
4. RC approval binds to exactly `PROD_BASE` + `RC_SHA`.
5. Any SHA/tree change invalidates approval.
6. Merge only after approval.
7. Read actual mobile merge SHA.
8. `PROD_BASE → MERGE_SHA` is the approved delta.
9. `RC_SHA → MERGE_SHA` has zero tree differences.
10. Pair backend only to `MERGE_SHA`, gitlink-only.
11. LOCK-GATE on those exact canonical main SHAs.
12. Production deploys only that pair.
13. The new served production mobile SHA is `PROD_BASE` for the next cut.

Use existing tooling from a paired release worktree: `scripts/build_web_release.sh`, `scripts/deploy_cloudflare_pages.sh` of an already-built archive, `python3 scripts/web_release_pipeline.py compare-environments` with `unexplained_differences = []`, parent `LOCK-GATE`. Staging and production are two sealed payloads from the **same** parent/mobile source plus the closed environment delta. Do not rebuild in deploy.

Event Workspace is stricter than “staging may be a descendant of main”: the accepted RC source must be capable of becoming the exact production main identity.

## PR 5-prep

If `requestEndChange` still does not exist: own production cut of calendar mutation machinery. RC through existing calendar UI, not Workspace. New served `PROD_BASE` before PR 5. Do not merge 5-prep with PR 5.

## PR 7

Tests first. Product defects become 7a / 7b: one defect, one RC, one production cut. If PR 7 is truly tests-only, it still needs a production identity cut before the next product candidate.

## Activation

Allowed runtime delta: `lib/core/feature_flags.dart` only. RC-test the compiled artifact (`static const` changes compiled behavior). Do not hide inside PR 6 or PR 7.

## Report identity at every stage

```text
parent HEAD / parent origin/main / parent mobile gitlink
mobile HEAD / mobile origin/main
dirty parent paths / dirty mobile paths
served production SHA
candidate SHA
identity contract: pass | fail
```

If it fails, stop. Do not repair a release worktree opportunistically.

## Never

- Deploy production from a development worktree
- Compare a release against anything other than the SHA actually served by production
- Bundle two independently testable runtime changes into one production cut
- Pair backend to a pre-merge mobile SHA
- Deploy a merge whose tree is not proven identical to the candidate tree
- Treat a rebase as preserving RC approval
- Start a product candidate from a merged SHA that is not yet served by production
- Treat waived runtime RC as waived production identity cut
