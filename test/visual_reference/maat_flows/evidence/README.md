# Ma'at mockup-to-app visual evidence

Each row pairs an independently rendered supplied HTML state with the actual Flutter widget. The Flutter golden is regression evidence only; it is never used as the visual authority.

Contact sheets are ordered **HTML reference | Flutter app | 50/50 overlay | amplified absolute difference**.

The raw captures remain in `reference/` and `app/`. In comparison inputs, only mock phone/status chrome is excluded: Discovery content is aligned below the app's real 32 px OS safe area, and the shared 47 px status-bar area is masked for Reading House and Offering Table Day View states. No authored app surface is resized, recolored, blurred, or masked.

## Explicitly reviewed context differences

- The Day View raw app captures now use the real production `DayViewPage`, including its shared header, mini-calendar behavior, and floating shortcuts. The HTML uses illustrative phone/status glyphs and simplified shared chrome. Per the user's frozen-Day-View instruction, direct fidelity authority applies to each authored event block and opened sheet; the full raw context remains visible.
- Djed's three surrounding ordinary events use production scheduled-event cards in Flutter and simplified unlabeled bars in the HTML. Their titles, times, and colors are retained; they are not Djed-authored surfaces.
- Offering Table's HTML labels the event `7:30 AM` but visually places it near the 9:30 row, and pairs `Rekh-Wer 13` with `FRI SEP 4`. Flutter correctly places it at 7:30 and maps that Kemetic date to `SAT AUG 29` through the canonical calendar. Event-block/sheet visuals follow the HTML; the functioning shared calendar math remains unchanged.
- The September 9 product instruction supersedes two older mockup details: Offering Table event blocks now share Djed's solid amber border rule, and Discovery cards are complete accessible tap targets with no separate `Open` button or reserved button row.
- Reading House's HTML clips the late-day grid after 9 PM. Production Day View keeps midnight reachable, so its clamped late-day viewport places the same 7 PM block about 24 px lower. The block itself retains matching geometry.
- Chromium CSS and Flutter/Skia produce minor anti-aliasing and platform-glyph differences. These do not excuse changed bounds, line breaks, artwork geometry, palette values, copy, or state.

| State | Authority | Scope | Contact |
| --- | --- | --- | --- |
| `djed-detail-hero` | `djed-detail-page-v12-ember-eventblocks.html` | full detail viewport | [inspect](contact/djed-detail-hero.png) |
| `djed-detail-supports` | `djed-detail-page-v12-ember-eventblocks.html` | support editor scroll checkpoint | [inspect](contact/djed-detail-supports.png) |
| `djed-detail-support-2-selected` | `djed-detail-page-v12-ember-eventblocks.html` | support 2 selected in row and spine | [inspect](contact/djed-detail-support-2-selected.png) |
| `djed-day-view` | `djed-day-view-amber-v8-exact-eventblock.html` | authored event block in Day View | [inspect](contact/djed-day-view.png) |
| `djed-day-sheet` | `djed-day-view-amber-v8-exact-eventblock.html` | initial layered detail sheet | [inspect](contact/djed-day-sheet.png) |
| `djed-day-sheet-docked` | `djed-day-view-amber-v8-exact-eventblock.html` | inner practice card docked | [inspect](contact/djed-day-sheet-docked.png) |
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
| `reading-house-day-sheet` | `reading-house-day-view-v16.html` | initial layered House sheet | [inspect](contact/reading-house-day-sheet.png) |
| `reading-house-day-sheet-docked` | `reading-house-day-view-v16.html` | inner House card docked | [inspect](contact/reading-house-day-sheet-docked.png) |
| `reading-house-day-sheet-bottom` | `reading-house-day-view-v16.html` | House practice scrolled to bottom | [inspect](contact/reading-house-day-sheet-bottom.png) |
| `reading-house-day-incoming` | `reading-house-day-view-v16.html` | incoming-message state | [inspect](contact/reading-house-day-incoming.png) |
| `reading-house-day-complete` | `reading-house-day-view-v16.html` | Observed completion selected | [inspect](contact/reading-house-day-complete.png) |
| `offering-day-view` | `offering-table-day-view-bottom-detail-sheet-layered-v8.html` | authored event block in Day View | [inspect](contact/offering-day-view.png) |
| `offering-day-sheet` | `offering-table-day-view-bottom-detail-sheet-layered-v8.html` | initial layered detail sheet | [inspect](contact/offering-day-sheet.png) |
| `offering-day-sheet-docked` | `offering-table-day-view-bottom-detail-sheet-layered-v8.html` | inner ritual card docked | [inspect](contact/offering-day-sheet-docked.png) |
| `offering-day-sheet-bottom` | `offering-table-day-view-bottom-detail-sheet-layered-v8.html` | ritual card scrolled to lower controls | [inspect](contact/offering-day-sheet-bottom.png) |
| `offering-day-sheet-context` | `offering-table-day-view-bottom-detail-sheet-layered-v8.html` | expanded context disclosure | [inspect](contact/offering-day-sheet-context.png) |
| `offering-detail` | `offering-table-bottom-sheet-ritual-first-mockup (7).html` | full detail viewport | [inspect](contact/offering-detail.png) |
| `offering-detail-sheet` | `offering-table-bottom-sheet-ritual-first-mockup (7).html` | preview ritual sheet | [inspect](contact/offering-detail-sheet.png) |
| `offering-detail-context` | `offering-table-bottom-sheet-ritual-first-mockup (7).html` | preview context disclosure | [inspect](contact/offering-detail-context.png) |
| `offering-detail-complete` | `offering-table-bottom-sheet-ritual-first-mockup (7).html` | preview completion state | [inspect](contact/offering-detail-complete.png) |
| `discovery` | `maat-flow-discovery-copy-v3.html` | Follow the Sky and list opening | [inspect](contact/discovery.png) |
| `discovery-offering` | `maat-flow-discovery-copy-v3.html` | Offering Table discovery card | [inspect](contact/discovery-offering.png) |
| `discovery-reading-house` | `maat-flow-discovery-copy-v3.html` | Reading House discovery card | [inspect](contact/discovery-reading-house.png) |

Five additional goldens cover product states the HTML does not author: Djed's approved fourth Discovery card, Reading House locked/ended rooms, Inbox room multiplicity, and a redundant component-frame capture of Djed's authored raised state. They are supplemental regression contracts, not mockup-fidelity evidence.
