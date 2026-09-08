# Ma'at flow visual acceptance authority

The tracked PNGs in `goldens/` are rendered from the real production widgets,
at the stated reference size, after direct comparison with the HTML authorities
listed below. They are normal test expectations: a visible drift fails
`flutter test` unless a reviewer deliberately regenerates and approves the
affected image.

The HTML files are design authorities, not implementation instructions. Their
CSS, embedded artwork, SVG geometry, typography, copy, and observable
interaction states govern the visual result. Their JavaScript is not copied
into the app.

This package contains **39** visual states, each with an exact macOS golden and
an exact Linux golden. **34** have an independent HTML-to-Flutter evidence set
in `evidence/`; the other **5** are explicitly supplemental product/safety
contracts for states the supplied HTML does not author. A prior report of 18
goldens was a stale partial count.

The macOS captures in `goldens/` remain the reviewed visual acceptance
authority. The captures in `goldens/linux/` are exact expectations for the
Linux renderer used by the release gate. They were generated with Flutter
3.35.3 (framework revision `a402d9a437`, engine revision `ddf47dd3ff`, engine
hash `672c59cfa87c8070c20ba2cd1a6c2a1baf5cf08b`) and Dart 3.9.2 from the
digest-pinned Linux image
`ghcr.io/cirruslabs/flutter@sha256:884b23ca58e874a704a5d9bfea6a3207e4061c9e9d45c6bed98fe76b6fd107c5`.
The two sets preserve the same geometry, layout, typography, artwork, color,
copy, and state. They differ only where the host renderer produces different
pixels. Tests select the matching platform directory and still compare with
zero tolerance; no normalization, fallback, or automatic baseline acceptance
is used.

| Surface | Locked source | SHA-256 |
| --- | --- | --- |
| Djed detail | `djed-detail-page-v12-ember-eventblocks.html` | `4c2d20bffbf6ce62341bde5feaa6c6edadfdeaf7c72bff89a5f369fdedc5316d` |
| Djed Day View | `djed-day-view-amber-v8-exact-eventblock.html` | `fa203d52bedadb5c261485df6e9a77ad8294fe7531781ac7473bfafbcb380308` |
| Reading House detail | `reading-house-detail-featured-scroll-icon.html` | `d279691c7443453fb1509562767d3c94337f02e6a431af3262f61de87d345cc3` |
| Reading House Inbox | `reading-house-inbox-invites-mockup-v4.html` | `be8bad3e14fb18e83bbc185619242867d2f835c719874d3bbdf1f1d3f69358aa` |
| Reading House Day View and House Chat | `reading-house-day-view-v16.html` | `ba77134ddcd137d9fd79d450dd04b2cef8650e579dabb8d1df9baad8e14cdb0c` |
| Offering Table Day View | `offering-table-day-view-bottom-detail-sheet-layered-v8.html` | `20e3619a6905c2e1d124da7a14def6f911107c79a89bf8da055ab361815a7bdb` |
| Offering Table detail and ritual | `offering-table-bottom-sheet-ritual-first-mockup (7).html` | `6dd08f89eee3128a37df26cf2ec76d3b2789a57e13f12e422556e0d8d42975af` |
| Flow discovery | `maat-flow-discovery-copy-v3.html` | `1d0559d15ff0d60b842739d22c125330590d19ce6aa09d253ba48f89f6e51ade` |

## State inventory

| Authority | Direct HTML pairs | Supplemental Flutter contracts |
| --- | --- | --- |
| Djed detail | hero; supports scroll; support 2 selected | none |
| Djed Day View | event block; initial sheet; docked practice; result; smaller retry; final raising | duplicate presentation-frame capture of the authored docked state |
| Reading House detail | hero; setup; calendar; sittings | none |
| Reading House Inbox | accepted House; pending invitation; House Chat | multiple-House isolation fixture |
| Reading House Day View | event block; initial sheet; docked House card; sheet bottom; incoming message; Observed completion | locked room; ended room |
| Offering Table Day View | event block; initial sheet; docked ritual; ritual bottom; context expanded | none |
| Offering Table detail | detail; ritual sheet; context expanded; completion | none |
| Flow discovery | initial Follow the Sky; Offering Table card; Reading House card | Djed card, because the approved product has four flows while the supplied HTML has only three |

Every direct pair preserves the full 390×844 reference and app capture, plus
normalized inputs, a 50/50 overlay, and a contrast-amplified absolute
difference. Read [the evidence index](evidence/README.md) for the individual
contact sheets. Phone status icons are treated as device chrome; no app
surface is hidden by normalization.

The three Day View captures use the real production `DayViewPage`, not an
isolated grid. The evidence index records the remaining visible context
differences explicitly: simplified mockup-only shared chrome, Djed's ordinary
calendar fixture cards, Offering Table's internally inconsistent 7:30/9:30 and
Kemetic/Gregorian placement, Reading House's late-day scroll clamp, and
cross-renderer anti-aliasing. None of those exceptions applies to authored
event-block or sheet geometry, artwork, palette, copy, or interaction state.

## Acceptance conditions

- Primary viewport: 390 x 844 logical pixels at device-pixel ratio 1.
- The Reading House presentation-only sheet uses its authored 390 x 720
  content frame inside the production shared sheet host.
- Production fonts are loaded explicitly before each golden comparison.
- Goldens exercise the widgets opened by the product; no parallel demo screen
  may satisfy the contract.
- Detail pages include top and scrolled checkpoints. Layered sheets include
  docked/initial, raised, and inner-content-scrolled checkpoints where the
  mockup defines those states.
- Djed's ember detail palette and amber Day View palette remain distinct.
- A golden update is acceptable only after overlaying the new app capture with
  the matching locked HTML state. Tolerance is zero in the automated test;
  platform anti-aliasing differences must be reviewed explicitly rather than
  used to excuse geometry, artwork, typography, color, or copy drift.
- The surrounding calendar is existing shared Day View chrome and is not
  redesigned by the Djed, Reading House, or Offering Table HTML. The full raw
  viewport is retained, while fidelity decisions for those references apply
  to the authored event block and the opened sheet.

Regenerate only after an approved visual change:

```sh
flutter test --update-goldens \
  test/features/calendar/authored_event_block_day_view_test.dart \
  test/features/calendar/djed_detail_page_visual_test.dart \
  test/features/calendar/djed_day_presentation_visual_test.dart \
  test/features/calendar/reading_house_detail_page_test.dart \
  test/features/calendar/reading_house_day_presentation_visual_test.dart \
  test/features/calendar/offering_table_detail_page_test.dart \
  test/features/calendar/maat_flow_discovery_view_test.dart \
  test/features/inbox/reading_house_inbox_section_visual_test.dart
```
