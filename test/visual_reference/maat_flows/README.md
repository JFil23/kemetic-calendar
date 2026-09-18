# Ma'at flow visual acceptance authority

The tracked PNGs in `goldens/` are rendered from the real production widgets
at the stated reference size. Direct-pair states are compared with the HTML
authorities listed below; supplemental states are governed by their documented
product or explicit user instruction. They are normal test expectations: a
visible drift fails `flutter test` unless a reviewer deliberately regenerates
and approves the affected image.

The HTML files are design authorities, not implementation instructions. Their
CSS, embedded artwork, SVG geometry, typography, copy, and observable
interaction states govern the visual result. Their JavaScript is not copied
into the app.

This package contains **52** registered visual states. **34** have an
independent HTML-to-Flutter evidence set in `evidence/`; the other **18** are
explicitly supplemental product/safety contracts or user-authored overrides
that the supplied HTML does not govern. The contract is intentionally
bidirectional: no tracked golden may exist outside the manifest, and every
registered golden must exist for every required rendering platform.

The macOS captures in `goldens/` remain reviewed visual acceptance evidence.
The independent HTML files frozen in `authorities/`, together with later
explicit user overrides recorded here, are the visual authority. The captures
in `goldens/linux/` are exact ARM64 Linux
expectations; the captures in `goldens/linux-x64/` are exact x86_64 Linux
expectations for the release gate. Both were generated with Flutter 3.35.3
(framework revision `a402d9a437`, engine revision `ddf47dd3ff`, engine hash
`672c59cfa87c8070c20ba2cd1a6c2a1baf5cf08b`) and Dart 3.9.2 from the
same digest-pinned multi-architecture Linux image
`ghcr.io/cirruslabs/flutter@sha256:884b23ca58e874a704a5d9bfea6a3207e4061c9e9d45c6bed98fe76b6fd107c5`.
The three sets preserve the same geometry, layout, typography, artwork, color,
copy, and state. They differ only where the host platform and CPU architecture
produce different raster pixels. Tests select the exact platform/architecture
directory and still compare with zero tolerance; no normalization, fallback,
or automatic baseline acceptance is used. An unregistered Linux architecture
fails closed.

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
| Kꜣr Day View | `the-kar-day-view-behaviors-v10-lifecycle-clean.html` | `e694f1003b89f1a822454bb3d156e0f8a179ec6fab4fb02a16059015941c7604` |

The Day View HTML authorities for Djed, Offering Table, Reading House, and Kꜣr
are stored byte-for-byte in `authorities/`. Follow the Sky predates those HTML
references; its reviewed lowered and raised production captures are the
mechanical housing authority recorded in `day_view_contract.v1.json`.

## State inventory

| Authority | Direct HTML pairs | Supplemental Flutter contracts |
| --- | --- | --- |
| Follow the Sky Day View | none | approved lowered and raised mechanical housing reference |
| Djed detail | hero; supports scroll; support 2 selected; sitting 2 top; sitting 2 bottom | none |
| Djed Day View | event block; initial sheet; raised practice foreground; result; smaller retry; final raising | duplicate presentation-frame capture of the raised state; mixed support-condition palette; released-history state with four filled beams, one pillar, and no ghost |
| Reading House detail | hero; setup; calendar; sittings | none |
| Reading House Inbox | accepted House; pending invitation; House Chat | multiple-active-House isolation fixture; ended Houses absent |
| Reading House Day View | event block; initial sheet; docked House card; sheet bottom; incoming message; Observed completion | one-reader draft with inactive Send; transient ended room |
| Offering Table Day View | event block; initial sheet; docked ritual; ritual bottom; context expanded | none |
| Offering Table detail | detail; ritual sheet; context expanded; completion | none |
| Kꜣr Day View | none | approved lowered and raised five-flow housing states |
| Flow discovery | initial Follow the Sky; Offering Table card; Reading House card | Djed card, because the approved five-flow product extends the supplied three-card HTML |

Every direct pair preserves its independently rendered reference and app
capture, plus normalized inputs, a 50/50 overlay, and a contrast-amplified
absolute difference. Read [the evidence index](evidence/README.md) for the
individual contact sheets. Phone status icons are treated as device chrome;
no app surface is hidden by normalization.

The Day View captures use the real production `DayViewPage`, not an
isolated grid. The evidence index records the remaining visible context
differences explicitly: simplified mockup-only shared chrome, Djed's ordinary
calendar fixture cards, Offering Table's superseded embedded event-card copy
and internally inconsistent Kemetic/Gregorian placement, Reading House's late-day scroll clamp, and
cross-renderer anti-aliasing. The user's September 13 Djed correction
supersedes the older HTML sheet composition only: Djed Day View now uses Follow
the Sky's standard outer host and frame-controlled foreground while retaining
the authored Djed artwork, palette, title, actions, and footer. Its stage keeps
the HTML's 230 px height, uses 205 px only when the full viewport is at most
720 px, and is never resized by the shared foreground. The later
September 13 correction removes the instrument's sitting/day/phase label,
time/duration row, and TODAY/context block entirely; each sitting now presents
its title, a 12 px gap, and the fixed-size graphic. The lowered foreground stop
is the sum of the instrument's top padding, scaled title line, 12 px gap, and
stage height plus its existing 24 px bottom padding. That leaves 32 px from the
angle label's lower edge to the foreground and clears the upward shadow.
Unselected supports use the HTML's 34% opacity (78% during orientation); the
selected support stays at full opacity with its outline/glow, and each support
condition uses its authored gradient. The latest explicit user instruction
supersedes the older HTML released/ghost treatment: release remains stored
history but does not change beam painting, so all four beams stay filled and
every sitting renders exactly one pillar with no ghost. The existing diagonal
rise guides appear in sittings 3–8, using their authored coordinates, color,
dash spacing, and behind-pillar drawing order; they remain absent in sittings
1, 2, and 9 and are not beam outlines. Sitting 9 retains the radial raising
glow. Raising the foreground may cover
the stage; lowering it reveals the complete stage again. At the exact dock the
focus heading and primary controls clear the fixed footer; the same single
scroll exposes every remaining control above it.

Djed Flow detail and Djed Day View intentionally own different sitting-sheet
presentations. Flow detail uses the authored 86% conventional sheet with
24px top corners, one scrolling content column, close control, TODAY context,
214px stage, detail explanation, and “Back to the Djed.” It does not mount the
Day View layered foreground, completion picker, menu, or fixed footer. Both
presentations reuse the same sitting state/actions and the approved Djed stage
painter. The Flow detail calendar remains `MaatFlowThirtyDayCalendar`, matching
Follow the Sky’s shared calendar geometry while supplying Djed dates, accents,
and real event dots; the HTML calendar implementation is not copied.

All five built-in Ma’at flows use the universal Day View housing. Follow the
Sky, Reading House, and Djed open at `.58`; Offering Table and Kꜣr open at
`.71`. The shared host owns resizing, its single outer handle, the foreground
scroll, completion placement, menu placement, and keyboard/footer behavior.
Each flow continues to own its artwork, copy, fields, and state transitions.
Separate Flow-tab detail sheets and user-created flows are not part of this
housing contract.
The top and bottom sitting-sheet goldens exercise the owned/actionable path, so
both plan actions are visibly enabled. Catalog and invited previews retain the
same layout with mutations disabled; their disabled action labels use the
existing readable Djed muted text color instead of inheriting the near-black
Material default.

## Acceptance conditions

- Primary viewport: 390 x 844 logical pixels at device-pixel ratio 1.
- The Reading House presentation-only sheet uses its authored 390 x 720
  content frame inside the production shared sheet host.
- Reading House Day View and the Inbox room route share one House Chat visual
  composition while retaining their distinct outer housings. In a current
  one-reader House the message field accepts a draft and Send remains inactive;
  an ended House is absent from that account's Inbox while its backend records
  remain available for administration. The ended Day View golden covers only
  an already-open sheet reacting safely when its owning room disappears.
- Production fonts are loaded explicitly before each golden comparison.
- Goldens exercise the widgets opened by the product; no parallel demo screen
  may satisfy the contract.
- Detail pages include top and scrolled checkpoints. Instrument sheets include
  initial, raised, and inner-content-scrolled checkpoints where the interaction
  defines those states.
- Djed's ember detail palette and amber Day View palette remain distinct.
- A direct-pair golden update is acceptable only after overlaying the new app
  capture with the matching locked HTML state. A supplemental override must be
  rendered and reviewed against its explicit product/user contract instead;
  an older HTML state cannot override it. Tolerance is zero in the automated
  test, and platform anti-aliasing differences must be reviewed explicitly.
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
