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


## September 28 — close Planner and Feed edition gaps

Reference: the approved `haw-pages-editions.html` selection rules and the user's request to close the remaining code gaps. Existing pane geometry, labels, captions, routes, and backend contracts remain the reference. New display states were rendered with representative static data at 150, 186.5, and 205 logical pixel pane widths before connecting the selectors.

- Both panes use the existing visibility-gated one-shot edition timer: dawn 05:00, midday 11:30, dusk 17:30 (local time). Resume compares the edition's date as well as its name. There is no new polling, cron, persistence, or network call on edition change.
- Planner: dawn uses the existing active alignment note, then an unfinished due/undated to-do. Midday prioritizes today's enabled decan nutrition, including earlier times today; completed/skipped, weekday-only, previous-day and future-day nutrition cannot take that slot. Fallback is an unfinished due/undated to-do, then the note, then the scale. Dusk uses the canonical alignment scale. No synthetic content replaces missing records.
- Feed: dawn uses the unanswered daily question, then another viewer's public answer, then an eligible public practice, then public rhythm. Midday uses a joinable practice, then a public answer, then rhythm; it no longer repeats the unanswered morning question as its fallback. Dusk uses rhythm.
- Answer selection uses only the current question's existing server-visible answer collection. It excludes the viewer, requires 12 words, and picks deterministically by local day/edition. The length threshold is a simple content filter, not a claim of semantic quality or popularity. The preview reuses CommonsAnswerCard; the real Commons page owns all actions.
- A joinable public practice created within the current edition overrides the normal Feed slot. It remains selected while eligible until the next edition or opening Feed. The held ID and dismissal are transient controller state, not tracking rows. An app restart can show that same fresh practice again. Existing createdAt is the only freshness evidence: updatedAt does not prove that an older room just became public. Member-count minimum removed; all actual permission/lifecycle checks remain.
- Planner note lettering is extracted from the native Planner card without changing its original typography. Pane display data comes from PlannerOverview; all existing source read budgets remain unchanged.

Verification: `pages_planner_editions_test.dart`, `pages_feed_editions_test.dart`, `pages_resource_test.dart`, and `pages_edition_visual_test.dart` cover the new rules, actual controller transitions, cache updates, dismissal, same-edition next-day resume, zero requests/writes at boundaries, and pane fit. Existing Pages navigation, layout, data-budget, and persistence tests also apply. This entry describes source behavior; it is not a deployment receipt.
