# Flow Completion Identity Model

Date: 2026-07-11

## Scope

This note records the persistence identity contract for calendar flow
completion state. It is the forward-safe location for correcting engineering
language about this model; do not rewrite applied migration history or hand-edit
generated schema snapshots to correct explanatory text.

## Row Identity

`public.user_event_completions` stores one completion state per signed-in user
and scheduled event occurrence.

The row identity is:

```text
(user_id, client_event_id)
```

The database unique index is defined on `(user_id, client_event_id)`, and the
`record_event_completion` RPC uses `ON CONFLICT (user_id, client_event_id)` when
recording completion state.

`completed_on` is mutable completion data. It records the flow-window date used
for outcome coverage and may be updated by the RPC for the same
`(user_id, client_event_id)` row. It is not part of row identity.

## Occurrence Contract

Every independently completable scheduled occurrence must have its own stable
`client_event_id`. Reusing the same `client_event_id` for two independently
completable occurrences would collapse their completion state into one row.

The shared `EventCidUtil.buildClientEventId` helper builds IDs from Kemetic date,
start minute, title, and flow id, so generated IDs are occurrence-shaped when
those inputs differ. This note does not certify every event generator. New or
changed generators must preserve the invariant that each independently
completable occurrence has a distinct `client_event_id`.

## Process Rule

Do not edit already-applied migration files or generated schema snapshots to
correct historical wording. Use maintained engineering documentation like this
file, or add a new forward-only migration only when the live database metadata
itself must change.
