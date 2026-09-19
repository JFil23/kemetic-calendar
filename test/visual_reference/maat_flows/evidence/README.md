# Ma'at mockup-to-app visual evidence

Each row pairs an independently rendered supplied HTML state with the actual Flutter widget. The Flutter golden is regression evidence only; it is never used as the visual authority.

Contact sheets are ordered **HTML reference | Flutter app | 50/50 overlay | amplified absolute difference**.

The raw captures remain in `reference/` and `app/`. In comparison inputs, only mock phone/status chrome is excluded: Discovery content is aligned below the app's real 32 px OS safe area, and the shared 47 px status-bar area is masked for Reading House and Offering Table Day View states. No authored app surface is resized, recolored, blurred, or masked.

## Explicitly reviewed context differences

- The Day View raw app captures now use the real production `DayViewPage`, including its shared header, mini-calendar behavior, and floating shortcuts. The HTML uses illustrative phone/status glyphs and simplified shared chrome. Per the user's frozen-Day-View instruction, direct fidelity authority applies to each authored event block and opened sheet; the full raw context remains visible.
- Djed's three surrounding ordinary events use production scheduled-event cards in Flutter and simplified unlabeled bars in the HTML. Their titles, times, and colors are retained; they are not Djed-authored surfaces.
- The Djed corrections supersede the HTML's older `.71` layered host, forced 30 px practice peek, decorative inner handle, and three instrument-header sections. Production uses Follow the Sky's `.58` standard host, the shared frame's authored foreground stop, and one outer handle. The sitting/day/phase label, time/duration row, and TODAY/context block are absent with no reserved height; the sitting title is followed by a 12 px gap and the graphic. The stage remains 230 px (205 px only when the full viewport is at most 720 px) and never rescales to the remaining sheet height. The fully lowered stop includes the instrument's top padding, title line, gap, complete stage, and existing 24 px bottom padding, leaving the angle label 32 px clear of the foreground edge and its upward shadow. Unselected supports use the HTML's 34% opacity (78% during orientation); the selected support stays at full opacity with its outline/glow, and holding, under-pressure, wobbling, and unassessed supports use their authored gradients. The existing diagonal rise guides appear behind the pillar in sittings 3–8 with unchanged geometry, color, and dash spacing; they remain absent in sittings 1, 2, and 9 and are not beam outlines. Sitting 9 retains the authored radial raising glow. Raising may cover the stage, and lowering reveals it again. At the exact foreground dock the focus heading and primary controls clear the fixed footer; the same single scroll exposes each remaining control above it. Djed's actions, footer, and single shared scroll remain intact. The latest explicit instruction additionally supersedes the HTML's released/ghost state: release remains stored history, but it has no alternate beam treatment; all four beams remain filled and every sitting shows exactly one pillar. That state is a supplemental Flutter visual contract rather than a direct HTML comparison.
- The September 18 product instruction makes Follow the Sky the mechanical housing authority for all five canonical Ma'at Day View sheets: Follow the Sky, Offering Table, Reading House, Djed, and Kꜣr. Follow the Sky, Reading House, and Djed open at `.58`; Offering Table and Kꜣr open at `.71`. They share one outer handle, one foreground scroll owner, menu/completion/footer placement, and artwork that is revealed or covered rather than resized. Offering Table retains authored variable-height artwork across its thirty days. The per-flow HTML remains authoritative for each flow's artwork, copy, fields, and interactive states, while its older inner handles and nested-layer geometry are superseded. Separate Flow-tab detail sheets and user-created flows are outside this Day View housing contract.
- The September 17 product correction supersedes the Offering Table HTML's event-card teaser and embedded `7:30 AM` label. Every Offering Table event block now contains only its day identity, title, and artwork; the prompt remains available to the sheet, and calendar placement still comes from the canonical schedule. The HTML also pairs `Rekh-Wer 13` with `FRI SEP 4`; Flutter maps that Kemetic date to `SAT AUG 29` through the canonical calendar.
- The September 9 product instruction supersedes two older mockup details: Offering Table event blocks now share Djed's solid amber border rule, and Discovery cards are complete accessible tap targets with no separate `Open` button or reserved button row.
- Reading House's HTML clips the late-day grid after 9 PM. Production Day View keeps midnight reachable, so its clamped late-day viewport places the same 7 PM block about 24 px lower. The block itself retains matching geometry.
- Reading House uses one House Chat visual composition in Day View and the Inbox room route, while preserving the separate outer housings authored for those routes. The latest explicit product contract removes ended Houses from the owning account's Inbox while retaining backend records for administration, and keeps a one-reader message field draftable with Send inactive; the ended Day View golden is only a transient safety state for a sheet that was already open.
- Chromium CSS and Flutter/Skia produce minor anti-aliasing and platform-glyph differences. These do not excuse changed bounds, line breaks, artwork geometry, palette values, copy, or state.

| State | Authority | Scope | Contact |
| --- | --- | --- | --- |
| `djed-detail-hero` | `djed-detail-page-v12-ember-eventblocks.html` | full detail viewport | [inspect](contact/djed-detail-hero.png) |
| `djed-detail-supports` | `djed-detail-page-v12-ember-eventblocks.html` | support editor scroll checkpoint | [inspect](contact/djed-detail-supports.png) |
| `djed-detail-support-2-selected` | `djed-detail-page-v12-ember-eventblocks.html` | support 2 selected in row and spine | [inspect](contact/djed-detail-support-2-selected.png) |
| `djed-day-view` | `djed-day-view-amber-v8-exact-eventblock.html` | authored event block in Day View | [inspect](contact/djed-day-view.png) |
| `djed-day-sheet` | `djed-day-view-amber-v8-exact-eventblock.html` | initial shared instrument sheet | [inspect](contact/djed-day-sheet.png) |
| `djed-day-sheet-docked` | `djed-day-view-amber-v8-exact-eventblock.html` | foreground practice content raised | [inspect](contact/djed-day-sheet-docked.png) |
| `djed-day-result` | `djed-day-view-amber-v8-exact-eventblock.html` | result state | [inspect](contact/djed-day-result.png) |
| `djed-day-retry` | `djed-day-view-amber-v8-exact-eventblock.html` | smaller retry state | [inspect](contact/djed-day-retry.png) |
| `djed-day-raising` | `djed-day-view-amber-v8-exact-eventblock.html` | final raising state | [inspect](contact/djed-day-raising.png) |
| `reading-house-detail-hero` | `reading-house-detail-featured-scroll-icon.html` | full detail hero viewport | [inspect](contact/reading-house-detail-hero.png) |
| `reading-house-detail-setup` | `reading-house-detail-featured-scroll-icon.html` | setup scroll checkpoint | [inspect](contact/reading-house-detail-setup.png) |
| `reading-house-detail-calendar` | `reading-house-detail-featured-scroll-icon.html` | calendar scroll checkpoint | [inspect](contact/reading-house-detail-calendar.png) |
| `reading-house-detail-sittings` | `reading-house-detail-featured-scroll-icon.html` | sittings scroll checkpoint | [inspect](contact/reading-house-detail-sittings.png) |
| `reading-house-inbox` | `reading-house-inbox-invites-mockup-v4.html` | accepted House Inbox cell | [inspect](contact/reading-house-inbox.png) |
| `reading-house-inbox-pending` | `reading-house-inbox-invites-mockup-v4.html` | pending invitation sub-sheet | [inspect](contact/reading-house-inbox-pending.png) |
| `reading-house-inbox-chat` | `reading-house-inbox-invites-mockup-v4.html` | House Chat sub-sheet | [inspect](contact/reading-house-inbox-chat.png) |
| `reading-house-day-view` | `reading-house-day-view-v16.html` | authored event block in Day View | [inspect](contact/reading-house-day-view.png) |
| `reading-house-day-sheet` | `reading-house-day-view-v16.html` | initial shared Ma'at Day View housing | [inspect](contact/reading-house-day-sheet.png) |
| `reading-house-day-sheet-docked` | `reading-house-day-view-v16.html` | foreground House practice raised | [inspect](contact/reading-house-day-sheet-docked.png) |
| `reading-house-day-sheet-bottom` | `reading-house-day-view-v16.html` | House practice scrolled to bottom | [inspect](contact/reading-house-day-sheet-bottom.png) |
| `reading-house-day-incoming` | `reading-house-day-view-v16.html` | incoming-message state | [inspect](contact/reading-house-day-incoming.png) |
| `reading-house-day-complete` | `reading-house-day-view-v16.html` | Observed completion selected | [inspect](contact/reading-house-day-complete.png) |
| `offering-day-view` | `offering-table-day-view-bottom-detail-sheet-layered-v8.html` | authored event block in Day View | [inspect](contact/offering-day-view.png) |
| `offering-day-sheet` | `offering-table-day-view-bottom-detail-sheet-layered-v8.html` | initial shared Ma'at Day View housing | [inspect](contact/offering-day-sheet.png) |
| `offering-day-sheet-docked` | `offering-table-day-view-bottom-detail-sheet-layered-v8.html` | foreground ritual content raised | [inspect](contact/offering-day-sheet-docked.png) |
| `offering-day-sheet-bottom` | `offering-table-day-view-bottom-detail-sheet-layered-v8.html` | ritual card scrolled to lower controls | [inspect](contact/offering-day-sheet-bottom.png) |
| `offering-day-sheet-context` | `offering-table-day-view-bottom-detail-sheet-layered-v8.html` | expanded context disclosure | [inspect](contact/offering-day-sheet-context.png) |
| `offering-detail` | `offering-table-bottom-sheet-ritual-first-mockup (7).html` | full detail viewport | [inspect](contact/offering-detail.png) |
| `offering-detail-sheet` | `offering-table-bottom-sheet-ritual-first-mockup (7).html` | preview ritual sheet | [inspect](contact/offering-detail-sheet.png) |
| `offering-detail-context` | `offering-table-bottom-sheet-ritual-first-mockup (7).html` | preview context disclosure | [inspect](contact/offering-detail-context.png) |
| `offering-detail-complete` | `offering-table-bottom-sheet-ritual-first-mockup (7).html` | preview completion state | [inspect](contact/offering-detail-complete.png) |
| `discovery` | `maat-flow-discovery-copy-v3.html` | Follow the Sky and list opening | [inspect](contact/discovery.png) |
| `discovery-offering` | `maat-flow-discovery-copy-v3.html` | Offering Table discovery card | [inspect](contact/discovery-offering.png) |
| `discovery-reading-house` | `maat-flow-discovery-copy-v3.html` | Reading House discovery card | [inspect](contact/discovery-reading-house.png) |

Eighteen additional goldens cover product states the HTML does not author as one capture: approved Djed overrides and detail states, Reading House one-reader/ended and Inbox multiplicity states, the complete five-flow Discovery state, lowered/raised shared Day View housing states for Follow the Sky, Kꜣr, and Reading House, and Offering Table's complete 30-day instrument matrices. They are supplemental regression contracts, not mockup-fidelity evidence.
