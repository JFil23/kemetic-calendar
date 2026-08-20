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
6. Use that newly served SHA as the base for Cut 1.
7. Repeat for every later cut.

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

candidate focused tests: PASS
existing calendar regression tests: PASS
full-suite new failures vs served prod: 0

physical iPhone smoke: PASS
physical Android smoke: PASS

candidate tree approved: YES/NO
```

Cut 0 has no runtime behavior, so physical product smoke may be explicitly
waived. The identity, diff, tests, canonical pairing, LOCK-GATE, deployment,
and served-SHA verification are not waived.

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

## Hostile physical smoke for Cuts 1–4

Use an account containing ordinary HAw notes, flows, reminders, and imported
native events. Snapshot visible state before beginning.

1. Enable sync.
2. Create, rename, move, resize, and delete native events; confirm HAw follows.
3. Create, edit, and delete ordinary HAw events; confirm Apple/Google does not
   change.
4. Turn sync OFF and modify the native calendar several times; confirm HAw is
   frozen and imported rows remain.
5. Turn sync ON; confirm one clean catch-up with no duplicates, disappearing
   events, or hydration cascade.
6. Kill HAw, modify the native calendar, reopen, and confirm catch-up.
7. Edit/delete one recurring occurrence and then the full series; confirm
   identity and deletion behavior are correct.
8. Use **Unlink and clear synced calendar data**; confirm only imported HAw
   rows disappear.
9. Restart HAw; confirm cleared imports do not return while sync stays OFF.

Also smoke Day View hydration, Planner, ordinary note add/edit/delete, Flow
add, reminders, restoration, and cold/warm reopen.

## Never

- Merge or deploy from the dirty development worktree.
- Call a prepared stacked branch a candidate.
- Deploy the tombstone migration with another production cut.
- Broaden a cut because its tests pass.
- Patch an accepted RC.
- Pair the parent/backend to a pre-merge mobile SHA.
- Claim physical-device PASS from a simulator, compiler check, or unit test.
