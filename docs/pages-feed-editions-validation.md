# Pages Feed editions

## Scope and visual authority

Implements the agreed Feed-first revision of `haw-pages-editions.html`.
The served starting authority was RC `73b24ffff544eaae4746131e3e454f1693064113`.
The existing Commons components supply the actual visuals; the HTML's synthetic
answers, milestone states, passages and practice artwork are not application data.
Calendar, Planner, Journal, Flow Studio, Inbox, Calendars and Library retain their
existing display selection and routes. The grid, captions, fixed header/search,
collection tabs and route restoration are retained.

## Local priorities

| Local time | Preferred content | Fallbacks |
| --- | --- | --- |
| 05:00–11:29 | Today's unanswered question | Eligible public practice, then public rhythm |
| 11:30–17:29 | Eligible public practice | Today's unanswered question, then public rhythm |
| 17:30–04:59 | Public rhythm | Existing loading/unavailable state when the Commons slice is unavailable |

These are fixed local-clock boundaries, not astronomical sunrise calculations.
A question already answered by the viewer is not promoted as unanswered. Its
identity still comes from `activeCommonsQuestion` and the canonical daily seed.
A room must be public, active, have at least two members, allow this viewer to
request joining, and not already be joined, managed, pending, blocked, approved
or closed to joining. The existing joinability helper remains the permission
basis. Viewer-specific room records take precedence when payload lists overlap.

Eligible rooms are sorted by canonical ID; a deterministic local date/edition
hash selects one. Repainting, reopening or reordering the same payload does not
reshuffle the selection. Eligibility changes can choose a new item. No history,
seen marker, engagement analytics or guarantee of artificial daily novelty is
introduced. A pane can remain unchanged when that is the useful fallback.

## Shared rendering and behavior

`CommonsPracticeCard` is extracted from the functioning Commons carousel card.
The full card retains its existing optimistic likes and capability-gated actions.
Its compact variant reuses the title, status pill and public member glyphs,
with a short Practice Together navigation affordance. At narrow widths the
headline uses a single ellipsized line rather than clipping vertically. Hidden
member identities stay private. Profile-image URLs are not fetched by the pane.
Question and rhythm continue using their existing shared pane variants.

Tapping any Feed mode opens the existing Commons destination. The passive pane
does not join, like, mark read or open a replacement sheet. A held pointer keeps
the displayed Feed card stable until release/cancel; this is transient widget
state, not event or read tracking.

## Resource contract

The existing hourly presentation timer is replaced, not supplemented, by one
one-shot timer aimed at the next edition boundary. It stops when Pages is
covered/backgrounded/disposed and recalculates on resume. Boundary handling only
selects from the existing `social.commons` account cache; it does not fetch,
invalidate, write, or run a backend job. Existing date and notification refresh
paths remain responsible for data freshness. No SQL, schema, RPC, cron, polling,
new subscriptions, library progress sync or read-state authority is added.
The obsolete social-event Feed selector has been removed.

## Verification

- Native practice visual checked before wiring selection at 150, 186.5 and 205
  logical-pixel pane widths, including no-public-member-name state.
- Shared full Commons card still invokes its actual like/join callback boundary.
- Pure selection tests cover exact boundaries, overnight behavior, answered
  questions, permission exclusions, duplicate identities, payload reordering,
  stable choice and eligibility loss.
- Lifecycle test verifies one timer, no hidden timer, resume and disposal.
- Resource regression verifies zero requests across edition changes/resume of
  the presentation timer and no changes to other pane notifiers. Existing
  cold-entry/revisit/search/sheet-return/leave read-budget checks remain.
- Touch regression verifies an update waits until release and taps still open
  the canonical Feed destination.
- Complete app suite: **3,009 passed, one skipped, zero failures**.
- `flutter analyze --no-pub --no-fatal-infos`: passed with no errors or warnings;
  six existing informational notices remain in unchanged Calendar code.
- Release contracts: **74 passed** (48 pipeline, five visual contracts,
  21 served-artifact verifier tests). `git diff --check` passed.
- Native side-by-side Question, Practice and Rhythm panes visually checked using
  representative static data; this is not a live account-data capture.

This source change alone is not a deployment receipt. RC publication requires
the normal exact-commit build, gate and served-artifact verification workflow.
