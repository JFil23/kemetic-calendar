# End-of-decan review implementation — October 7, 2026

## Authority and reference

Implementation is in the sole app RC checkout, `/Users/jaralephillips/dev/kemetic-calendar-rc`, branch `rc`, based on `bc4ccb80c302a67496864136294b63467d931fd5`. This was checked against the served RC receipt before work. Backend source and migrations belong only to `/Users/jaralephillips/dev/kemetic-calendar-backend`, branch `main`, based on `d6be715287e4b78a12fabc7d1810a9fda4a0701b`. No repository, branch or worktree was created. Production and `haw-production` were not changed. Nothing has been deployed.

Visual authority is `/Users/jaralephillips/Downloads/mockup (1).html`, preserved in the approved `decan-reference/mockup.html` visualization. The rejected `code-alignment.html` is not an implementation reference. The implementation preserves the warm crown, bone/gold palette, actual bundled Cormorant/Inter faces, ten-day rule, selected moments, single question, plain Journal composition, and public card with the author inside it. It adds necessary activity/retry/recovery/continuation states through those same primitives. Static presentations were inspected before data integration; actual registered reflection, Journal and post routes were subsequently captured and checked. Existing visual goldens were not regenerated.

## What the user receives

1. The floating Calendar badge stays in its existing position and becomes available at 8 pm local time on the tenth day. Civil-date calculations handle daylight saving and supplementary days. The scheduler sends an invitation at the established time; it no longer manufactures an old-style interpretation or creates a reflection before the user opens it.
2. Opening the badge uses the existing reflection detail route. A new review contains zero to three factual moments and one question. The user can browse more recorded activity, open its original source, change the selection, add an outside-app moment, or leave the question open.
3. A response is kept in the Journal on the day it is written. Returning to the reflection offers the saved response. Its Journal contribution links back to the selected moments and can be edited or removed without replacing other writing, formatting, badges, drawings, charts, or document metadata.
4. Posting is an explicit second action. The user reviews the exact words, chooses whether to include the question or a reading link, and publishes an independent snapshot to the existing profile/feed family. Journal edits never silently update the public post. Owner edit/removal and visitor report/block use existing action boundaries. Removed posts remain removed. Journal removal explicitly explains that an existing public post stays separate and points to the reflection to manage it.
5. Optional continuations suggest at most one flow and one Library reading. UI says “A flow to explore”, “From the Library” and reading titles; it does not call Library items nodes. Suggestions come from authored catalog relationships and selected activity, with a concrete reason. There is no character score, inferred virtue, or automatic enrollment.

## Inputs, question catalog and cost

New reviews stop calling the compositional phrase matrix. A versioned catalog of eight neutral, authored questions rotates against recent reflection history. The selected question and version are stored, so an old reflection does not change when wording changes. Earlier generated reflections and their provenance remain readable through the legacy reader and retained legacy tests.

The initial activity read has four bounded sources: flow completion records, Library activity, authored flow responses already carried into Journal, and recent reflection context. Each provider returns at most twelve records and a next cursor. The chooser loads further pages on demand. Custom flows use their recorded titles and actions; they do not need a profile definition or phrase-matrix expansion. All five current Ma’at identities are supported. A failed provider produces an explicit retry notice rather than pretending there was no activity.

Journal excerpts are requested deliberately. Reading House private margins are read only after a separate chooser action, through exact keys derived from verified owned flow/event identities; preference storage is never scanned. Up to twelve previously unchecked sittings are examined per request. Private margins remain unselected until the user chooses one, and the UI explains when keeping a selection creates a private account copy. Neither excerpts nor source moments are automatically placed in a public post.

Library inputs reflect the existing last-open/read and bookmark records; they are not a fabricated history of every revisit. Flow completions and responses retain the evidence actually stored by their owners. Deleted or unavailable sources produce an opening notice while the user's selected snapshot stays readable.

Suggestions use a local catalog join, a bounded active-flow membership read, the existing held Reading House membership RPC, and progress for only the candidate readings. Retired/unavailable flows, current flow memberships, selected or completed readings, and dismissed/recent suggestions are excluded. A saturated membership read conservatively omits flow suggestions. No eligible match is a valid quiet ending. No new AI service, embedding index, full-history scan or recurring recommendation job was added.

## Persistence and shared owners

- `DecanReflectionDetailPage` owns every private review entry; `DecanReviewScreen` renders its new data kind. The existing Calendar badge and push/date routes supply identity and navigation. Existing reflection archive URLs remain valid.
- `DecanReflectionRepo` owns review context and bounded activity. Context uses revision checks and stable mutation receipts. `decan_review:user:<account>:<period-start>` retains pending requests and authored drafts independently of the warm cache.
- `JournalRepo` owns acknowledged Journal writes for every caller. Journal rows have monotonic revisions and a date-level tombstone ledger. The shared controller retains deployed document keys, adds a base-revision sidecar, serializes local writes and prevents an earlier acknowledgement from clearing later typing. Volatile autosave timestamps do not change a retry's mutation identity.
- One stable `decan_reflection:<reflection-id>` paragraph and `decan_journal_sources` link represent the contribution. The server merges that paragraph into the current document under a revision check. Source removal is tombstoned; adding the words back requires an explicit action. All entry points use `JournalDocumentView` for this document kind, with the existing rich text editor and toolbar for ordinary writing.
- Conflict receipts preserve attempted writing under owner RLS. Journal routine reads return only three recovery descriptors; full bodies load on a deliberate comparison. The shared recovery action shows the saved copy and the draft before a conditional choice. Reflection activity has a bounded “Find preserved drafts” action for interrupted context, Journal and post attempts. Recovery only stages content for review; it does not publish or overwrite automatically.
- `ProfileRepo` owns the additive `decan` insight-post kind. It has a real reflection identity, not a dummy Library identity. `DecanInsightPost` is reused by profile, feed, Commons and public detail. Posting and removal have revision/idempotency boundaries; post-detail removal also keeps its pending identity outside disposable cache. A replayed acknowledgement is checked against current server state before it can paint or clear a draft. An explicitly rejected removal leaves the post visible and ends that request; a later deliberate retry reads the current revision. An uncertain network result retains the exact request identity.
- Existing warm namespaces remain intact: `reflection.*`, `journal.*`, `social.*`, `flow.*`. Additive payload fields keep old rows readable. New activity/source keys are not mistaken for reflection IDs by passive recent-route warming. Profile insight snapshots retain their deployed keys with an optional viewer sidecar for member-only decan data. Cache invalidation does not erase pending writes.
- Account-operation fences reject late results, including A → B → A. Private views clear on account departure. Existing canonical My Flows/Ma’at/Library destinations handle source and suggestion navigation. The five-flow Day View housing is unchanged.

## Backend changes

The backend-only migrations are `20261007162827_decan_review_journal_and_public_snapshots.sql` and `20261007163441_bounded_decan_activity.sql`. They add owner-scoped review/Journal source records, mutation receipts, Journal revisions/tombstones/recovery, a typed independent public snapshot, bounded activity RPCs and indexed recovery reads. Public visibility respects signed-in membership and blocks in either direction. Anonymous callers cannot read private recovery or decan posts. Existing profile feed and Together owners expose the new kind.

The scheduled decan function now issues an authored invitation with date/period identity. Existing reflection IDs still route old notifications correctly. The generic push sender only gains the new date-route payload. Delivery leases, retries, token selection and schedule timing retain their existing contracts.

## Verification and release status

The focused repository/controller/route tests exercise bounded pagination, factual status labels, partial-source failure, actual first creation, local restart, lost acknowledgement, later typing, account isolation, current-state checks after deletion, recommendation filtering, real catalog IDs, Journal source preservation, private/public independence, and fresh-client conflict recovery. Static visual states cover 320/402/768 widths, enlarged text, keyboard occlusion and landscape; route captures cover the real review, saved response, Journal and public post. A browser visual harness uses the production review widgets and bundled assets. Actual browser rendering was compared with the approved HTML at phone and tablet sizes. The heavier Cormorant lettering in VM test captures was isolated to the test rasterizer: the browser uses the same verified font files and matches the reference. Temporary browser sizing and the preview server were cleaned up.

The complete local Flutter suite passed: **4,071 tests, 1 existing skip, no failures**. The analyzer passed with no errors or warnings (110 informational lints). All deterministic App release/authority contracts passed, including the real-route flow parity test within the full suite. The two real-browser storage/quota tests passed. Backend function tests passed (613), backend source contracts passed (73), and the local SQL smoke passed, including privacy, cross-account recovery, exact retries, source preservation/deletion, post independence/removal, feed visibility and twelve-record pagination. Database lint reported no diagnostics in changed functions; five unchanged functions retain pre-existing diagnostics (including temporary-table references and an ambiguous `status` in Kꜣr pairing).

Legitimate test-boundary changes: the old prompt guard now requires an invitation and prohibits the retired compositor calls, retaining its no-LLM and interaction-order assertions. Existing Journal/flow tests now mock the shared mutation RPC and preserve their content, ownership, acknowledgement and invalidation assertions. The existing profile carousel fixture now authenticates each owner/visitor and asserts that removal changes its server fixture as well as the pager. No inventory threshold, old fixture, golden reference or visual-owner allowlist was relaxed.

At release preparation, no remote migration, Edge Function deployment or app deployment has been performed. The user has authorized review and deployment to RC; hosted gates and release receipts will record the subsequent release. Local SQL execution and function suites do not claim the backend's fresh-database CI migration gate or a served-RC replay. Those release checks and applying the backend contracts must precede making this app version available to users.


## Requirement ledger

“Verified locally” below means implementation and the named local evidence. It does not mean this version is deployed or has passed hosted CI.

| Requirement | Status | Evidence |
| --- | --- | --- |
| Preserve the uploaded design rather than replace it | Verified locally | Static production widgets were built before wiring; approved HTML compared with browser captures at 320/402/768 widths; actual registered route captures cover review, saved, Journal and public detail. |
| Keep the existing floating badge position and day-ten timing | Verified locally | Existing Calendar placement is retained; prompt guard requires an invitation; local 20:00 civil-date boundary and date-route validation are covered. Scheduler delivery tests retain timing, leasing and retries. |
| Few selected moments, one question, optional writing | Verified locally | Zero/one/three-moment states, chooser and writing visuals; versioned eight-question catalog; actual reflection route test. Leaving the question open persists context without requiring a response. |
| Include activity from current Ma’at and custom flows | Verified locally | Bounded repository tests and transactional SQL smoke cover recorded flow activity, current identity/status mapping, pagination and extant user-written responses. Custom flow titles need no authored phrase profile. |
| Let users browse and choose their own context | Verified locally | Per-source pagination, source navigation, outside-app moment and explicit Journal/private-margin selection; partial failures remain visible and retryable. |
| Keep writing in Journal alongside existing entries | Verified locally | Actual reflection → Journal edit → reflection reopening test; SQL verifies one stable source paragraph and preservation of earlier writing, drawing blocks and metadata. |
| Keep publication deliberate and independent | Verified locally | Exact composer preview, optional question/reading, separate public snapshot; route and SQL evidence prove private edits leave published wording unchanged and public removal leaves Journal intact. |
| Integrate with existing social surfaces and permissions | Verified locally | Shared typed post renderer, profile carousel regression, backend feed/Together and member/anonymous/bidirectional-block assertions. |
| Suggest flows and Library readings without a heavy service | Verified locally | Catalog-ID/filter tests; bounded membership/progress reads; at most one of each; canonical existing destinations; no AI or background recommender. UI uses “Library”/“reading,” never “nodes.” No eligible match is allowed. |
| Preserve drafts, handle retries and recover conflicts | Verified locally | Repository/controller/SQL tests cover restart, exact retry identity, lost acknowledgement, rejected-removal retry, later keystrokes, deleted sources/documents and fresh-device recovery. Recovery stages a draft for review and never publishes automatically. |
| Preserve account isolation and warm-state ownership | Verified locally | A → B → A tests, cleared private views, current-state checks after acknowledgements, unchanged warm namespaces, browser quota/IndexedDB checks and warm-state contract guard. |
| Retain existing flow details and older reflection history | Verified locally | Existing flow detail owners and separate Day View housing retained; structural authority guard plus full-suite real-route parity evidence. Legacy reflection readers and compositor fixtures remain in the suite. |
| Responsive, keyboard and accessibility behavior | Verified locally | Narrow/tablet/enlarged-text visual tests, save reachable above a simulated keyboard, landscape scrolling, and browser accessibility tree exposing question and controls. Physical handset and assistive-technology sessions remain release checks. |
| Complete local regression suite | Verified locally | 4,071 Flutter tests pass, 1 existing skip; analyzer has no errors/warnings; browser storage tests and deterministic release/authority contracts pass. Hosted exact-commit App CI remains a release prerequisite. |
| Backend release and served-RC replay | Incomplete — release work | Local SQL/function/source checks pass. Hosted fresh-database migration gate, applying backend migrations/functions, app deployment and served identity/behavior replay have not been performed. |
| Demonstrably inspire users | Unverified product outcome | Technical checks cannot establish this. A pilot must determine whether people recognize their moments, find the question useful and voluntarily return to their saved words. |

## Release sequence

1. Pass the backend's fresh-database CI migration and function gate, then apply the additive backend contracts and scheduler/push changes through the backend authority.
2. Pass the complete App gate on the exact RC commit and build/deploy only through the RC release pipeline. Preserve the new readers if new-format creation is rolled back.
3. Verify the served RC receipt and a disposable-account end-to-end review → Journal → optional post/recovery sequence, including phone keyboard, account change and removal. Production remains a separate release decision.

The production checkout is unchanged. Its current `bc4ccb80` identity is explained by the October 6 fast-forward in its reflog and the matching live production receipt; this is later history than the September authority card, not a change made by this task. The live RC receipt was rechecked and still matches the implementation baseline.


## Final local evidence

- Full Flutter suite: `4,071 passed; 1 existing skip; 0 failed`.
- Analyzer: exit 0, no errors or warnings; 110 informational style/API lints.
- Browser storage: 2 passed. Deterministic App guards and release-script/configuration checks passed.
- Backend: 613 function tests, 73 source-contract tests, transactional decan storage/activity smoke passed. Existing unrelated DB lint diagnostics are listed above.
- Exact changed-file hashes and copied test receipts are in [the evidence manifest](/Users/jaralephillips/.codex/visualizations/2026/10/07/01a11487-1619-7b61-a46f-08e7f865c646/decan-reference/implementation-evidence/source-manifest.json).
- [Actual browser phone capture](/Users/jaralephillips/.codex/visualizations/2026/10/07/01a11487-1619-7b61-a46f-08e7f865c646/decan-reference/implemented-browser.jpg) and [tablet capture](/Users/jaralephillips/.codex/visualizations/2026/10/07/01a11487-1619-7b61-a46f-08e7f865c646/decan-reference/implemented-tablet.jpg) use production widgets with static reference data. The browser capture tool records the visible 989-pixel height; complete route compositions are preserved in the route captures under the evidence directory.
- Code and migrations have completed local verification and are prepared for the authorized RC release. No production or historical checkout was modified. Subsequent hosted gates and deployment receipts identify the released commits.

## Shared-backend release compatibility review

RC and production use the same Supabase project. The migrations preserve legacy reflection text as the authored question and preserve V2 Journal paragraph and metadata formats. Date-only push invitations use a root-query URL: older apps safely return to Calendar while new apps open the review. Older social readers retain the words through their existing Insight fallback; managing a new reflection post requires the new app's acknowledged actions.

The final review narrowed the legacy Journal guard: older clients may edit ordinary writing when each active reflection paragraph and its source metadata remains unchanged. They cannot overwrite, duplicate, remove or resurrect the protected contribution, including after the entire day is deleted. Regression SQL proves allowed ordinary writes advance the same revision ledger, stale body/metadata edits are rejected, and tombstoned sources cannot return through a legacy insert. This protects new contributions without freezing the entire Journal day in the older production app. The compatibility smoke and 73 source contracts passed after this change.
