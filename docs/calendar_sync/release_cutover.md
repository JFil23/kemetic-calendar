# Calendar sync release cutover

Calendar sync ships as serial production cuts, never as the bundled
development implementation.

```text
latest served production mobile SHA
        +
one closed calendar-sync delta
        =
candidate
```

The production `version.json` receipt read on 2026-08-20 reports:

```text
served production build id: 8dd4f90446550ec549d177cefa72511e00475b6a7188ef800f8a43733e068477
served production build version: production-b898be0-8dd4f9044655
served production parent SHA: 1a189d543a9f07a693ef5f586dcc2ec8c965b26e
served production mobile SHA: b898be0ec89a974776861908170a20d2e31974e5
served production mobile tree: ca917ac6d51252ee0cdcfa78199554997a39dfa7
```

Re-read the live receipt before every cut. This snapshot is evidence for Cut 0,
not permanent authority for later cuts.

## Serial gate

1. Build Cut 0 from the SHA actually served now.
2. Merge only the approved Cut 0 tree.
3. Pair the parent/backend to the actual mobile merge SHA.
4. Pass LOCK-GATE and promote that exact identity.
5. Verify production serves that merge SHA.
6. Build and serve mandatory Cut 0A from that newly served Cut 0 SHA.
7. Verify Cut 0A leaves a clean canonical calendar test baseline.
8. Use the newly served Cut 0A SHA as the base for Cut 1.
9. Repeat the merge, pairing, LOCK-GATE, promotion, and live-receipt proof for
   every later cut.

Prepared later-cut patches are source material only. They are not candidates,
and their test evidence does not transfer across a rebase, cherry-pick, merge,
dependency resolution, or generated-file change.

## Candidate identity report

Every cut must report:

```text
SERVED_PROD_MOBILE_SHA
CANDIDATE_SHA

expected changed runtime files
actual changed runtime files

unexpected files: 0

cut-specific tests: PASS

canonical calendar lane:
served failures: N
candidate failures: M
expected identity changes owned by this cut: documented
unexpected new failure identities: 0
unexpected removed/reclassified identities: 0
cut gate: PASS

full suite:
new failures vs served production: 0

physical iPhone smoke: PASS/WAIVED
physical Android smoke: PASS/WAIVED

candidate tree approved: YES/NO
production promotion authorized: YES/NO
```

Cut 0 has no runtime behavior, so physical product smoke may be explicitly
waived. Its exact served base, closed envelope, cut-specific guards, baseline
parity, merge identity, canonical pairing, LOCK-GATE, deployment, and
served-SHA verification are not waived.

## Approval decisions

`candidate tree approved` is YES only when all of these are true:

- the candidate starts from the correct served-production SHA;
- its diff is the exact closed cut envelope;
- unexpected files are zero;
- cut-specific tests pass; and
- it introduces no unexpected failure-identity change against served
  production.

`production promotion authorized` is YES only when all of these are true:

- candidate tree approved is YES;
- the actual merge tree equals the candidate tree;
- the previous served-production SHA to actual merge diff is the exact cut
  envelope;
- the parent gitlink points to the actual merge SHA; and
- LOCK-GATE is green for that paired identity.

A tree-approved candidate is not yet promotion-authorized.

After merge:

```text
git diff CANDIDATE_SHA...ACTUAL_MERGE_SHA --name-only
```

must return no files. Then verify:

```text
git diff PREVIOUS_SERVED_PROD_SHA...ACTUAL_MERGE_SHA --name-only
```

contains exactly the approved cut envelope. Pair the parent repository only to
the actual merge SHA, never to the pre-merge candidate.

## Cut 0 baseline-parity gate

Cut 0 must not expand into stale-test repair. When served production already
has canonical calendar failures, Cut 0 passes the regression gate only when
the candidate has the exact same failure identities:

```text
cut-specific tests: PASS

canonical calendar lane:
served failures: N
candidate failures: N
new failure identities: 0
removed/reclassified identities: 0
baseline parity: PASS

full suite:
new failures vs served production: 0
```

`N` is measured by running the canonical lane against served production and
the candidate under the same conditions; it is not a hard-coded expected
count. Inherited failures remain visible evidence, do not make a docs/test-only
candidate impossible to approve, and are not silently reclassified.

## Cut 0A — calendar test-authority cleanup

Cut 0A is mandatory after Cut 0 is served and before Cut 1 begins.

```text
runtime delta: none

purpose:
- repair stale hydration baseline
- repair obsolete quick-add source guard
- repair the time-dependent Day View Today-scroll source guard

allowed delta:
- only the affected calendar tests / test manifests
- supporting docs if needed

calendar regression lane after cut: PASS
full-suite new failures vs prior served prod: 0
```

The other inherited full-suite failures remain baseline-known when unrelated.
Cut 0A is not general test cleanup and may not borrow runtime work from Cut 1.

## Database expand/cut/contract gate

The native-import tombstone migration belongs to Cut 2 conceptually but is its
own production cut:

```text
additive compatibility migration
-> prove the currently served mobile app against the new database
-> ship the exact Cut 2 mobile candidate
-> observe
-> remove obsolete compatibility behavior only in a later contract cut
```

The migration may add an authenticated, user-scoped operation that clears only
an exact `native:` suppression record. It may not reinterpret ordinary HAw
deletions, broaden grants, delete native data, or require the old client to
call the new operation.

## Physical acceptance by owning cut

Use physical iPhone and Android devices with an account containing ordinary
HAw notes, flows, reminders, and imported native events. Snapshot visible state
before beginning. No cut is rejected for intentionally absent behavior owned
by a later cut.

### Cut 1 — read-only boundary and controls

- Prove native write capability is gone.
- Create, edit, move, resize, and delete ordinary HAw events; confirm native
  Apple/Google calendars do not change.
- Confirm basic existing native-to-HAw import still functions.
- Turn sync OFF; modify native events and confirm HAw stays frozen while
  imported rows remain.
- Use **Unlink and clear synced calendar data**; confirm only imported HAw rows
  disappear and native events remain untouched.
- Confirm neighboring HAw behavior does not regress.

### Cut 2 — reconciliation and occurrence identity

- Prove native rename, move, resize, and delete follow into HAw.
- Prove recurring occurrence identity for one occurrence and the full series.
- Prove external-source-wins reconciliation even when a HAw projection has a
  newer timestamp.
- Prove suppression removal lets an existing native occurrence return instead
  of remaining hidden by a HAw-side deletion.

### Cut 3 — automatic freshness and publication

- Prove native observer updates and debounce while sync is ON.
- Prove foreground catch-up after native changes made while HAw is backgrounded.
- Prove killed-app/reopen catch-up after native changes.
- Prove OFF performs no reconciliation and OFF to ON performs one clean
  catch-up.
- Prove one publication per changed reconciliation with no hydration cascade.

### Cut 4 — range and coverage

- Navigate beyond the old 30-day-past/180-day-future window and prove the
  rendered viewport reconciles.
- Prove startup, navigation, and viewport loading have no load or performance
  regression.

For every cut, also smoke Day View hydration, Planner, ordinary note
add/edit/delete, Flow add, reminders, restoration, and cold/warm reopen as
regression checks.

## Never

- Merge or deploy from the dirty development worktree.
- Call a prepared stacked branch a candidate.
- Deploy the tombstone migration with another production cut.
- Broaden a cut because its tests pass.
- Make an earlier cut satisfy a feature acceptance gate owned by a later cut.
- Patch an accepted RC.
- Pair the parent/backend to a pre-merge mobile SHA.
- Claim physical-device PASS from a simulator, compiler check, or unit test.
