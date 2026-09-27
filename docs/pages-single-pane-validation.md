# Pages single-pane implementation — September 27, 2026

## Visual authority

User-approved `haw-current-pages.html`, SHA-256
`f9181ad72df9ea2714f47e48159e7df954e3842982c1cafb2740610262642c13`.
The HTML supplies the layout and visual reference, not production data or screenshot assets.

At 393 logical pixels: 6-pixel side insets, 8-pixel column gap, 1.49 board
aspect ratio, 43-pixel caption region, and 22-pixel row gap. Search occupies
82–126 vertically (excluding system safe area); the pane viewport starts at
126 and the first board at 144. Only the pane viewport scrolls. Titles use
Inter 400, uppercase, 7.7 pixels and 2.8 tracking. Calendar descriptions use
Cormorant Garamond 400 italic at 11.2 pixels. Existing caption colors remain.
Internal accent tint, saturated graphics and restrained colored borders carry
the neon treatment; no external pane backlights.

## Shared authorities and selection

- Calendar retains the main calendar's existing compact month renderer.
- Feed uses today's canonical reflection question and the shared Commons
  question/composer/answer widgets. Its destination explicitly selects Commons.
- Planner uses the existing alignment calculation and MaatScale.
- Journal uses today's actual document badge tokens and the same badge area as
  Journal, including its empty state. It does not label an older badge as today.
- Flow Studio selects the next future occurrence, then uses its actual Day View
  graphic: Follow the Sky observation instrument, Offering Table instrument,
  Djed instrument, Kꜣr hero layer, Reading House room graphic, or the existing
  user-flow day-sheet graphic/photo/colored void. The compact completion picker
  reflects the occurrence's stored completion. Missing instrument data shows the
  existing loading/unavailable state rather than invented artwork.
- Inbox retains the latest actual update; Calendars retains its existing collage.
- Library retains its read-only current-book selection with centered glyph.
- Pane previews open the existing destination or sheet. Embedded thumbnail
  controls do not write; editing happens in the canonical destination.
- Existing `/pages` restoration, sheet return and scroll preservation remain.

## Read budget

No cron, polling, background subscriptions, schema changes or write-on-read
repositories were added. The next-event instrument has one account-scoped cache
slot, replaces its snapshot when the selected occurrence changes, and loads
only while Pages is visible. Existing notifications invalidate affected slices.
Question/date and event boundaries use local scheduling, not backend jobs.

User flow/Djed instrument snapshots need only local completion state. Offering
Table uses local saved day state. Kꜣr uses one RLS-constrained SELECT rather than
load-or-create. Shared Reading House uses one summary SELECT and at most 50
messages, without joining, watching or marking read. Follow the Sky uses the
existing pure-compute resolver with persistence disabled and the canonical
catalog fallback. Library preview still never calls readSnapshot.

Resource fixture: cold entry 15 requests; fresh revisit, search, Journal
notification, fresh resume and leave add zero requests; stale social resume
adds six. All recorded HTTP requests are read operations. The pure-compute
resolver uses its existing HTTP invocation but performs no database writes.

## Verification

- Native rendered comparison against the approved HTML at 393 pixels; exact
  board/scroll geometry assertions and no-overflow checks at 320, 430 and 844.
- Five genuine flow graphic types, today question selection, real badges,
  canonical navigation, restored Pages route and fixed-header scrolling tested.
- Read-only instrument transport tests verify bounded SELECTs, no hidden reads
  and unchanged local preference keys.
- Full local app suite: 2,993 passed, one existing skip.
- Final focused Pages and Commons suite: 35 passed.
- Release pipeline contracts: 48 passed; Ma'at contracts: five passed;
  served-artifact contracts: 21 passed.
- Analyzer: no errors or warnings; six existing private-type API infos in the
  unchanged calendar_active_maat_flows.dart.

Static fixtures establish visual geometry and shared renderer fidelity. Live
content naturally differs with the account, date and next scheduled event.
Exact-commit CI and sealed artifact receipts are the release authority.

## Native pane refinement

The subsequent user review supersedes the scaled full-section presentation:
Calendar, Planner and Inbox are retained; remaining feature UI is composed for
its actual pane bounds. The board geometry, outside captions, fixed header,
selection rules, read budget, and destinations remain unchanged.

Commons now presents its actual question with readable typography and a single
Commons entry point instead of a miniature disabled answer form. Journal uses
its actual first visible badge and total count, or the existing empty glyph,
without a nested badge-area frame. Library separates the centered glyph from
the title/progress row. Calendars uses native text sizing in the same collage.

Flow previews give their existing instruments the pane bounds. Sheet headings
and forms are omitted, while the original drawing, state and identity remain.
Kꜣr fits only its authored vector art uniformly; it does not shrink a sheet.
The shared completion control uses compact native typography and padding.
All default feature-screen presentation modes remain unchanged.

Verification includes native captures of empty/populated Journal and all five
built-in instruments, explicit nonzero Djed drawing bounds, responsive page
layout, and canonical navigation. The pane widgets introduce no repositories,
network calls, timers or persistence.

The final refinement check passes 48 Pages/Djed tests; the other 144 shared
feature checks in the broader run passed. Calendar, Planner and Inbox board
crops are pixel-identical to the prior native reference. Analyzer has no new
errors or warnings. Final exact-commit CI is required before RC upload.
