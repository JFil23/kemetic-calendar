# Pages menu validation

Implementation: app-only RC checkout, branch `rc`, based on `c28d4e8d5cc3ea7d33099daa983674b831fba969`. Both live identity receipts matched that commit on September 26, 2026. No backend source, schema, cron, production files, branches, or worktrees changed. These changes have not been deployed.

## Reference and visuals

Authority: `haw-pages-v5-arrangement.html` and the final approved Pages plan. The visual layout was built with representative data before the data connections. The Flutter render was inspected at 393 logical pixels wide. Tests also check 320, 430, and 844 widths for overflow.

Verified against the reference CSS: eight boards in the approved order, 6px grid sides, 8px column gap, 22px row gap, 1.49 board aspect ratio, 16px corners, shared 2:1 collage with 2px dividers, month plate, serif captions, search replacing the grid, and the loaded-data coverage notice. Commons and Library remain in place. Existing PostedFlowArtifact, MaatScale, UserFlowAppearanceHero, and ProfileAvatar provide real app visuals.

The source HTML was inspected directly; browser access to its local file was blocked. This is a CSS/specification comparison and an inspected Flutter render, not a pixel-diff golden against a browser render of the HTML. The preview uses representative records, not a live user's account.

## Behavior and arrangement

| Requirement | Evidence |
| --- | --- |
| Calendar launches normally; main calendar chevron opens Pages | Main app-bar and route changes inspected; existing app-bar architecture guards pass |
| Calendar returns; Feed opens revealed; Library opens nodes | `pages_navigation_test.dart`; actual Pages handlers with controlled route destinations |
| Planner, Journal, Inbox, Calendars open over Pages; Studio calls existing presenter | Navigation test checks existing utility scaffold, context, return and scroll retention; Studio presenter invocation is intercepted in the test |
| Fixed tile roles and priority across activity types | `pages_arrangement_test.dart`: newer join versus older like, actual join eligibility, Commons, planner next item, upcoming studio flow |
| Shared planner completion math | Planner header and Pages use `plannerCompletion`; unit coverage includes partial and fallback states |
| Journal privacy | Only badge title/color and written-day metadata retained in Pages snapshots; entry prose is not rendered or searched |
| Library preview cannot synchronize progress | Fake remote test fails on any remote access; Pages uses `readCachedSnapshotOnly`, never `readSnapshot` |
| Only affected tile updates | Journal notification test observes only its ValueNotifier changing, with no requests |
| Unknown/failed data differs from empty data | Explicit unavailable/loading states; cache retry and controller failure tests |
| Route navigation makes no telemetry writes | Open, revisit, pop and replacement test |

## Refresh and resource bounds

Account-scoped memory cache, shared repository snapshots, concurrent request deduplication, and at most two later-entry retries after an initial failure. Refresh work starts only while Pages is visible and foregrounded. Existing notifications replace/invalidate affected slices. A one-shot local boundary timer recalculates dates/events without network calls. No polling, recurring tasks, persistence table, hidden feature mounting, or new realtime subscription.

Bounded reads include 20 recent own posts, 20 rows per activity type, 20 inbox/together records, six Commons candidates, up to 100 flow/calendar summaries, and at most 201 upcoming event rows within 31 days. Planner reads include today/future-dated items and open or undated to-dos, excluding old completed history; disabled nutrition is excluded. Reads remain bounded and reject incomplete coverage at their caps. Journal inspects at most 14 recent documents to extract badges, discarding prose. Only two displayed calendar subjects can fetch member previews, at most three members each, followed by at most three missing glyph profiles. Only selected Feed/Studio image assets are requested; image decode dimensions match the panes. Unknown library progress stays unavailable.

Recorded mock-HTTP fixture: cold entry 15 bounded requests; fresh revisit 0; typing 0; journal notification 0; fresh resume 0; actual background/expired social resume 6; leave 0; write requests 0. Fixture response bytes are recorded in the test output and are not a real-account payload estimate. Member preview has its own projection/cap test. Read RPC bodies and authorization checks were inspected in existing backend migrations; no backend code changed.

No authenticated live-account payload profile or before/after database-row audit was performed. Tests establish the app's requested methods, bounds, deduplication and lifecycle behavior; they do not claim production traffic measurements.

## Checks

- Full Flutter suite: **2,984 passed, one existing skip**.
- Pages plus interaction architecture guards: **46 passed**.
- After the final date-filter adjustment (keeping future completed to-dos for local midnight recalculation), all **18 Pages tests passed** again.
- `flutter analyze --no-pub --no-fatal-infos`: no errors or warnings; six pre-existing `library_private_types_in_public_api` informational notices in `calendar_active_maat_flows.dart`.
- Release pipeline tests: **48 passed**; Ma’at visual contract tests: **5 passed**; served-artifact verifier tests: **21 passed**. These exercise the existing release machinery; no new release artifact was built or deployed.
- `git diff --check`: clean. Production working directory remains clean; dependencies and lockfile unchanged.

Preview: [Flutter Pages render](/Users/jaralephillips/.codex/visualizations/2026/09/26/01a0dfd5-244c-7982-a089-d882fe315655/pages-preview.png).

Remaining release verification: authenticated live-account navigation/traffic and database audit, plus any release build/deployment gates when deployment is requested.


## September 26 visual correction against v8

Reference: `/Users/jaralephillips/Downloads/haw-pages-v8.html`, the accompanying fidelity spec, and the user's direct request to remove pane backlights. The direct request takes precedence over residual radial glow instructions in the attachment. Example users, statuses, and featured flows in the HTML are representative data, not selection overrides.

Verified changes:
- Centered handle and bare profile glyph phrase; removed Pages title and avatar ring. Existing profile and add-note actions remain. Search is 44px tall with 6px side margins, 12px above and 18px below.
- Kept board order, 2:1 pane division, 2px gutters, 1.49 aspect, 16px corners, 8px column gap and 22px row gap. Widget checks cover 320, 393, 430 and 844 widths.
- Explicit dark search fill and per-role pane colors; no generic pane glow, title color blending, app-bar elevation tint or Planner scale oval backlight. Existing flow artwork retains its authored effects. Planner's original scale elsewhere retains its default appearance.
- Inbox/Feed avatars use the same shaded coin treatment as calendar members. Missing selected actor glyph IDs are resolved from the existing profile cache, otherwise a deduplicated account-scoped GET of only avatar_glyphs, filtered to that person, limit 1. No profile bootstrap, polling, writes or new subscriptions. The test confirms a shared Inbox actor needs one read for both panes and none on revisit.
- Inbox Reading House glyph, Journal completion icon and saved check, actual badge time, brighter captions and full Gregorian year in the mini calendar are restored. Non-today calendar dots are muted; today's retain event colors.
- Built-in Flow Studio art comes from the existing five-flow discovery asset registry, resolved from the saved maat metadata through the existing notes decoder. Custom saved flow appearances remain authoritative. Unknown progress totals do not produce a fabricated count or an Unavailable steps label.
- Selection order, navigation and sheet return behavior are unchanged. No sample account state or progress numbers are hardcoded in production.

Evidence: 19 Pages tests pass, including navigation/sheet return and selected-person glyph enrichment. Resource fixture: 15 cold reads, zero writes, zero fresh-revisit/search/sheet-return reads, six existing reads on expired social resume. Analysis has only the six pre-existing private-type infos in calendar_active_maat_flows.dart. Final fixture screenshot was inspected after priming retained raster layers; an earlier single-pass capture omitted retained text and was discarded.

Preview: [v8 correction render](/Users/jaralephillips/.codex/visualizations/2026/09/26/01a0dfd5-244c-7982-a089-d882fe315655/pages-v8-preview.png).

Limits: this is a representative Flutter render, not an authenticated screenshot of the user's account or a pixel-equivalence claim against browser-rendered HTML. Live Inbox statuses and the selected flow can differ from the mockup's dated snapshot. No backend schema/job changes, release build or deployment in this correction. Served RC was verified as b1a272064a51ad681cdec4de64b821bc920b8017 before editing; production was untouched.

## September 26 data, navigation and restoration correction

Authority: the user's 6:28 PM screenshot and direct requested corrections, on top of RC `f4a21308`. This section supersedes the earlier Studio-presenter and custom mini-calendar descriptions above.

- Header: added headroom equal to half the top safe-area inset (12–30 logical pixels), and enlarged the handle from 11 to 14. Board arrangement remains unchanged.
- Calendar: Pages renders the actual `_MonthCard` / `_EpagomenalCard` through `buildCalendarMonthCardPreview`, including real decan labels, Gregorian toggle, today's treatment, Sky signifiers and grouped calendar markers. The mounted Calendar publishes its visible, deduplicated notes and its own marker colors. Cold restoration reads a bounded current-month slice of the same filed-event view (501-row sentinel; incomplete coverage is rejected), respecting hidden calendars and stored calendar presentation. Calendar color decoding reuses existing stored override and Sky color logic. Date changes within the loaded month reuse the snapshot locally.
- Studio: removed Calendar's competing `pages.events` and `pages.flows` projections, which could overwrite the filed-flow lifecycle/count/appearance metadata. The event query now explicitly sorts ascending and requires `live_on_calendar`; hidden calendars are filtered. Selection retains the next event's owning flow and its saved appearance / built-in `maat` key. Read-only account inspection confirmed Full Moon (Follow the Sky) and Evening Reflection (Spanish) at 8 PM preceded the next morning's Offering Table event. A regression fixture verifies this ordering and the retained Sky artwork key.
- Inbox: pending outgoing shares no longer compete as incoming updates. Labels distinguish sharing a flow, inviting to an event/calendar, accepting and declining, with the correct actor direction. The inspected outgoing Math share was previously mislabeled as an invitation from its recipient.
- Journal: the inspected saved document really contained the Evening Reflection completion badge. Pages now reads the same account-scoped newer dirty draft when present, without initializing Journal or autosaving it. Existing Journal local saves notify the shared projection; unsaved drafts are labeled as such. Preview coverage remains the existing bounded recent-document window; sample mockup badges are not injected.
- Destinations: Calendar's Journal and Planner actions and the Pages actions use the same `/journal` and `/rhythm/today` routes. Studio now uses the canonical `/flows` utility route. Tests inspect the actual app route builders for Pages, Journal, Planner, Inbox, Studio and Calendars, in addition to testing push/pop and scroll retention. No substitute feature screen was added.
- Restoration: `/pages` is registered with the existing navigation persistence policy and wrapped in `SessionTrackedRoute`. Tests cover launch restoration, returning from Journal to Pages, and explicitly returning to Calendar. Persistence uses the existing app restoration system, not a new Pages table or job.

Resource fixture after the cold-calendar fix: 16 bounded requests on completely cold entry, zero data-write requests, zero additional reads on fresh revisit/search/sheet return/leave, and six existing social reads after a real expired social resume. Normal navigation from a fully hydrated Calendar reuses its month snapshot. No backend schema, cron, polling, progress-upsert or hidden feature mounting was added. Route continuity continues through the app's existing restoration persistence.

Verification: the final 82-test Pages/Journal/restoration/inventory run passes. The full app run recorded 2,989 passes and one existing skip; its single failure was the calendar inventory hash after extracting the preview factory. A byte comparison proved all grid source outside that factory span unchanged; the extent re-audit is documented, and the updated guard passes. The corrected resource/selection plus inventory run also passes all eight checks. Analysis of changed app/test files reports no issues, and `git diff --check` is clean.

The final 393-logical-pixel render uses a 3x phone device scale and was inspected with the decoded Sky asset, the longer Evening Reflection title and complete board roles. Tests also cover 320, 430 and 844 logical widths. Full PNG pixel checks confirm the unchanged header, Calendar/Feed, Planner, Inbox and lower boards match the inspected baseline; an incremental image-viewer presentation was not used as export evidence. These are app tests and representative renders, not a claim that this revision has been deployed or exercised in the authenticated browser session.

Preview: [Pages corrections, representative data](/Users/jaralephillips/.codex/visualizations/2026/09/26/01a0dfd5-244c-7982-a089-d882fe315655/pages-authority-preview.png).

## September 26 v9 presentation pass

Reference: `haw-pages-v9 (1).html`, interpreted under the user's instruction to reduce text without changing the accurate selection. The reference's alternative Feed/Studio pools, planner math and prototype interactions were not adopted.

- Board geometry, order, dark bases, header and the actual Calendar month preview remain unchanged. Labels now use uniform Inter type and one compact caption below each board.
- Feed renders the existing PostedFlowArtifact artwork with its same appearance/accent/date-progress calculation, without its title and duration overlays. The default artifact elsewhere remains unchanged. Commons stays in the bottom-right pane.
- Studio gives its selected upcoming flow's real artwork the whole large pane. The existing next-event title/time and actual remaining steps stay visible; repeated flow title/count copy inside the large pane is removed.
- Planner keeps its true scale and next item/time; alignment moves to the existing caption. Journal keeps the selected badge title/status, uses a compact truthful Saved/Draft/Open state and keeps actual weekly bars.
- Inbox uses selected actors' real glyph coins, with the selected update action/actor in its caption. Calendars keeps member coins and actual colored visibility indicators. Library keeps the selected chapter glyph and progress, with completion check and existing progress ring.
- Every tile retains its actual navigation action and full selected signal text in accessibility semantics. No controller, repository, selector, route, persistence, backend, scheduling or subscription change.

Verification: 31 Pages/shared-artifact tests pass, including content selection, resource requests, canonical navigation and artifact appearance/progress parity. Final visual test rerun passes after caption/accessibility polish, including 320/393/430/844 logical widths. Scoped analyzer reports no issues; diff whitespace check is clean. Final Sky and custom-flow fixture renders were inspected; the header, real Calendar and Sky pane are pixel-identical between the two polish captures outside intended changed regions. Representative data, not an authenticated account capture. This pass has not been deployed.

Preview: [v9 presentation, representative data](/Users/jaralephillips/.codex/visualizations/2026/09/26/01a0dfd5-244c-7982-a089-d882fe315655/pages-v9-preview.png).

### v9 follow-up: picture-only panes

The user's follow-up supersedes the compromise above that retained next-event, Planner and Library prose. Pane copy is now removed except the actual Calendar grid and selected Journal badge title (the same exceptions as the reference). Journal saved/open state is represented by seal intensity; weekly bars, real progress rings, member coins, visibility colors and the current decan's dots remain visual. Inbox caption is a short unread count; Flow Studio has no extra caption. Full selected records remain in accessibility semantics and existing destinations.

Studio retains the exact existing lead selector. Its two small panes now render other distinct visible, unfinished filed flows, applying that same next-event ordering to the already-loaded remainder. No fixture flows are injected. Missing companions leave a quiet pane. Companion artwork uses bundled real Ma'at assets, authored signs, or cached images only; it cannot initiate an image request. The card equality projection includes companions so existing notifications repaint changed artwork/progress. Feed Commons remains its existing role, now a group symbol.

Verification: all 31 Pages/shared-artifact tests pass, including resource and route checks. Analyzer reports no issues. The representative render was inspected with Sky as the lead and two real appearance fixtures as companions; the visual test explicitly excludes the previous note, event/time, Commons and chapter prose and verifies selected details remain accessible. This is an undeployed RC change.

### Flow Studio: bottom-sheet instruments

The user's next correction replaces detail-page hero photographs with the existing bottom-sheet graphics in all three Studio panes. PagesSheetGraphic reuses FollowSkyInstrumentSurface, OfferingTableDayInstrument, DjedSittingStage, KarDayShrineVisual and the Reading House sheet's extracted room emblem. Custom flows use UserFlowAppearanceHero with the same daySheet presentation surface. No discovery hero assets, sample chat messages or behavior sheets are mounted.

The existing lead/companion selection is unchanged. The existing bounded event query now includes behavior_payload (already used by the Calendar query), and carries the local flow ID. That exact occurrence travels with the selected flow: Sky resolves its real skyEventId; Offering Table resolves the selected day; Djed resolves the selected sitting and configured supports; Kꜣr resolves the selected stage. Missing occurrence metadata leaves a quiet instrument pane rather than inventing an event or falling back to a detail-page photograph.

Sky is a stationary preview at the selected event's peak, reusing the actual sheet renderer. A read-only option on the existing astronomy provider uses its valid saved calculation or the same catalog fallback used by the sheet; it never invokes the astronomy function, writes a result, or removes corrupt cache entries. This is a visual excerpt, not a live observing slider or a claim of fresh observer-specific ephemeris. Offering Table passively reads existing local day state; Djed uses configured support conditions, and Kꜣr shows the selected stage without claiming unsupplied shrine completion. Reading House uses its sheet emblem instead of fabricating a room transcript. No timers, polling, subscriptions or backend rows were added.

Verification: 51 Pages/artifact/Sky/inventory checks passed, followed by 18 final-render/all-flow/Reading House checks. The all-flow test verifies day 11, Djed sitting 4 without sample support text, Kꜣr stage 3, the real room emblem, custom daySheet styling and closed behavior when occurrence metadata is absent. Sky tests cover empty/valid/corrupt read-only cache and zero invocation/writes. The final phone render was inspected; responsive checks remain 320/393/430/844. Scoped analysis reports no issues. Resource checks retain 16 cold requests, zero writes, zero fresh revisit/search/return requests. This pass is not deployed.
