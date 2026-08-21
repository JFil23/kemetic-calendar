# Calendar extent contributor inventory

Status: closed source inventory for the Extent Model feasibility gate. This is
not renderer or production-consumer authority.

Audited implementation parent:
`948a291df5c4f3e5292a33ff6dbf87a7193607c4`.

## Scope and conclusion

The indexed domain is the portrait-style year sliver built by `_YearSection`.
It is also used on tablet/desktop landscape. Phone landscape uses
`LandscapeMonthView` and is a separate renderer; it does not consume these
section offsets.

The inventory is closed: every widget on the render path from
`CalendarGeometrySection` through an ordinary month or Heriu Renpet was traced
to the child that determines its vertical size. The marker render objects are
plain `RenderProxyBox` objects and add no extent. Decorations, opacity,
shader masks, repaint boundaries, hit targets, and horizontal gaps do not add
vertical extent.

All live cases can be represented by one immutable environment snapshot and
one immutable content-summary snapshot. No mount-time measurement exception is
currently required. Exact text and fitted-row sizes must be produced by the
same layout factory using Flutter text measurement; replacing them with guessed
constants would not satisfy parity.

## Complete section equation

For every month:

```text
section = gold divider + optional season header + month body
```

The gold divider is `12 + 0.65 + 12 = 24.65` logical pixels high. Its width is
responsive but cannot change its height.

The season header exists only for months 1, 5, and 9. Its extent is `16 +
measured text height + 8`. The text is not capped to one line, so viewport
width, resolved font metrics, and `TextScaler` are real inputs.

For ordinary months 1–12, the body is:

```text
22 outer vertical padding
+ 20 inner vertical padding
+ measured month-title/right-label row
+ 8 header gap
+ sum for decans 1..3:
     15.3 fixed decan-label row
   + (0 in details, otherwise 4) label-to-weekday gap
   + measured weekday-row height
   + 3 weekday-to-tile gap
   + decan chip height
+ 12 between-decan gaps
```

The 15.3 label row is fixed by a `SizedBox`; text overflow cannot change its
extent. The weekday row is intrinsic text layout and therefore must use the
shared text primitive.

For Heriu Renpet (month 13), the body is:

```text
(6 top + (6 details, otherwise 24) bottom) outer padding
+ 20 inner vertical padding
+ measured title/Gregorian row
+ (0 details, otherwise 10) header gap
+ measured weekday-row height
+ 3 weekday-to-tile gap
+ epagomenal chip height
```

Five versus six epagomenal days changes the content summary and horizontal
allocation, but the day count does not directly add a row.

## Chip-height projection

For compact, stacked, and labeled modes every day chip in a row has a fixed
height of 36, 62, and 98 respectively.

All four expansion modes share a fixed 28-pixel day-number header inside the
chip. The 23-pixel number opts out of ambient text scaling so the application's
1.5x tablet scaler cannot make that internal header overflow. This does not
remove `TextScaler` from the section environment: month, season, decan, and
weekday text remain scale-sensitive extent contributors.

The shared tile padding is 1 pixel vertically. After the header, stacked mode
has 32 pixels for its two 12-pixel pills and 3-pixel gap; labeled mode has 68
pixels for its two 30-pixel pills and 4-pixel gap. Their required content
heights are 27 and 64 pixels, respectively, so neither internal `ClipRect`
truncates a pill. These internal allocations do not alter the outer fixed chip
extent.

Details mode is content-derived. For each ordinary decan, summarize the maximum
visible event count on any of its ten days and whether any day exceeds the
visible cap. For Heriu Renpet, apply the same summary across its five or six
days. The current projection is:

```text
pills = 0                                      when visible count = 0
pills = 52 + 58 * (visible count - 1)          otherwise
pills += 19                                    when hidden events exist
chip = clamp(50 + pills, 80, 300)
```

The visible cap is 5 normally and 4 for the portrait-style grid on a landscape
screen whose shortest side is at least 600. Note title, type, color, flow, and
ordering do not affect extent because pill and overflow-indicator space is
fixed and clipped inside the chip.

The ordinary-month and Heriu implementations currently duplicate this
projection. The future layout factory must own it once and supply both the
renderer and index; copying either implementation into the index would preserve
the drift risk.

## Immutable inputs

The environment snapshot must make these values stable for an epoch:

- logical viewport width and orientation
- shortest-side class used by the details visible cap
- resolved `TextScaler`
- locale, text direction, platform/font-resolution identity, and font readiness
- committed expansion level, plus transient `0.0..3.0` visual progress while
  a pinch is active or settling
- the fixed banner/viewport constraints used by semantic reveal calculations

The content snapshot must contain, per month:

- Kemetic year and month, including leap-year day count
- the three ordinary-decan summaries or one Heriu summary described above
- the static season and Gregorian labels derived for that section

`showGregorian`, today highlighting, temporal tone, flow colors, restoration
state, and hydration availability do not currently change section extent.
Heriu uses `Visibility.maintainSize` for its alternate header labels. The
hydration status banner is a `Positioned` overlay and adds no scroll extent.
The scrolling month banner has a fixed height of 58 and reduces the body
viewport; it is not part of any month section.

The application multiplies the incoming text scale by 1.5 on screens whose
shortest side is at least 600. `_SoftMonthNameTitle`, `_SeasonHeader`, weekday
labels, and the Heriu header make the old assumption that portrait section
extents ignore text scale unsafe. Phase 1 still decides, by measurement across
the supported scaler matrix, whether `TextScaler` changes a projected extent;
if it does, it is mandatory in the epoch environment key.

## Range and topology

Current source has 200 past years, the current year, and 200 future years:
`401 * 13 = 5,213` month sections. The index domain and sliver range must be
owned by one `CalendarRange` constant before flattening.

The approved flattened center is month 1 of today's Kemetic year. The negative
side begins with the previous year's Heriu Renpet and the positive side begins
with month 2. New Year changes this domain only through the controlled range
epoch.

Pinch keeps the four discrete expansion levels as persistence endpoints, but
renders a transient fractional progress value during the gesture and its
180-millisecond settle. Each fractional layout requests a same-layout semantic
day-anchor correction from `RenderCalendarEpochViewport`; the viewport applies
`ViewportOffset.correctBy` during layout. Pinch progression therefore emits no
`jumpTo`, `animateTo`, synthetic scroll lifecycle, or fractional restoration
state.

## Completeness proof and change control

Completeness was established by tracing these paths:

1. `_YearSection` enumerates exactly 13 `CalendarGeometrySection` children.
2. Each section contains one `_GoldDivider`, an optional `_SeasonHeader`, and
   exactly one `_MonthCard` or `_EpagomenalCard` inside
   `CalendarGeometryMonthBody`.
3. Every vertical padding, spacer, intrinsic row, and fixed-height child in
   both card columns is classified in the equations above.
4. `_DecanRow` and the Heriu row take their height from `_DayChip`, whose outer
   `SizedBox` uses only the projected endpoint or fractional chip height.
5. The geometry marker widgets were checked through their render objects and
   are layout-transparent proxies.
6. The responsive scaler, fixed banner, year-sliver topology, and pinch
   geometry consumer were traced outside the section subtree.

`docs/calendar_extent_inventory_manifest.json` hashes the exact audited source
fragments. Run:

```sh
python3 scripts/verify_calendar_extent_inventory.py
```

Any change to an extent owner, its environment, topology, marker layout, or
pinch consumer fails the check. Updating a hash is not a mechanical fix: the
closed contributor list and equations must be re-audited first.

The go/no-go result from source inventory is **go for inert model and shadow
work**. Production epoch work remains gated on numerical baselines, exact
spec-versus-render parity, and the layout-coupled correction feasibility proof.

## 2026-08-14 ownership and paint re-audit

The production repair changed four audited fragments without changing any
extent equation:

- `_YearSection` now localizes temporal-tone publication to the current month
  and owns one repaint boundary around each complete month body.
- `_GoldDivider` paints the same fixed `0.65`-pixel gradient directly; the
  removed opacity/shader/repaint wrappers never contributed layout extent.
- the scroll notification path no longer performs restoration or hydration
  work before settle; its sliver topology and `401 * 13` domain are unchanged.
- geometry marker proxies publish when their laid-out size, identity, mount, or
  presentation epoch changes. Remembering the prior size adds no layout.

The original completeness trace and equations therefore remain exhaustive.

## 2026-08-21 day-number header and compact-height re-audit

The day-number hierarchy change modifies one extent term: compact day chips
are now 36 rather than 32 logical pixels. Each ordinary month contains three
decan rows, so its compact extent increases by 12 pixels. Heriu Renpet contains
one day row and increases by 4 pixels. A complete 12-month-plus-Heriu year is
therefore 148 pixels taller in compact mode. Stacked, labeled, and details
outer extents are unchanged; the details content-derived projection and caps
remain unchanged.

The render-path trace was repeated from `_MonthCard` and `_EpagomenalCard`
through `_DecanRow` and `_DayChip`. The day number, Track the Sky motif, compact
markers, event pills, and overflow count all remain children of the fixed
outer `_DayChip` `SizedBox`; none can add section extent. The day number uses a
fixed 28-pixel internal header and `TextScaler.noScaling`, while all
scale-sensitive headings already identified in the environment inventory
continue to inherit the responsive application scaler.

The measured-geometry path requires no formula update. Section, month-body,
weekday-row, and final-day marker proxies publish their laid-out boundaries,
so the extra compact height is included in snapshots and semantic scroll
ownership. Restoration, Today navigation, past/center/future normalization,
and the Heriu-to-new-year handoff consume those measured boundaries rather
than assuming the previous 32-pixel compact height. The closed contributor
list remains complete with the revised compact-height term above.

Calendar restoration layout revision 2 records the new geometry. Revision-1
states remain compatible because their raw compact offset is used only as a
provisional hint to mount an off-screen saved date; the persisted semantic
anchor then establishes the final viewport alignment under revision-2
geometry. The cross-version widget regression covers a next-year day target,
including the 148-pixel full-year delta and the target row's center shift.

## 2026-08-21 compact marker clearance re-audit

The compact event-marker row now uses `Alignment.center` instead of
`Alignment.bottomCenter` inside its existing `Expanded` marker region. This
moves the 2.35-pixel marker content away from the selected-day bottom border
without changing the 36-pixel compact chip, 28-pixel day-number header,
1-pixel header-to-marker gap, padding, border widths, row spacing, or any
expanded-state geometry.

The render-path trace was repeated from `_MonthCard` and `_EpagomenalCard`
through `_DecanRow` and `_DayChip`. The marker remains clipped inside the same
fixed outer `_DayChip` `SizedBox`; only its alignment within already allocated
space changed. Section boundaries, geometry marker publications, scroll
ownership, Today navigation, and semantic restoration therefore retain the
same extents and equations. Calendar restoration layout revision 2 remains
current because rendered outer geometry did not change.

## 2026-08-21 continuous pinch expansion re-audit

The four committed endpoint geometries remain unchanged: compact, stacked,
labeled, and details still resolve to progress `0`, `1`, `2`, and `3`, and only
those enum values are persisted. During an active pinch or its
180-millisecond ease-out settle, `CalendarExpansionGeometry` supplies a
transient progress value `p` in `0.0..3.0`.

For a details endpoint height `D` computed by the existing visible-event
summary, the transient day-row height is the piecewise-linear projection:

```text
0 <= p <= 1: lerp(36, 62, p)
1 <= p <= 2: lerp(62, 98, p - 1)
2 <= p <= 3: lerp(98, D,  p - 2)
```

The event content stays inside that projected outer height. Compact markers
fade out while pills fade in; pill heights project from the compact marker
diameter through `12`, `30`, and `52`, and gaps project through `0`, `3`, `4`,
and `6`. Before details, the pill height is bounded by the available marker
region so two pills cannot overflow an early compact-to-stacked frame. Label
opacity projects from zero to one between stacked and labeled. Details event
capacity is still bounded from the currently available height and existing
device cap, so additional event pills reveal only when they fit.

The render subtree no longer changes at progress `1`, `2`, or `3`. Each
populated day owns one clipped `Stack` for the device's details-event cap at
every fractional sample. Its first two cards remain present for the stacked
and labeled endpoints; later cards stay mounted and reveal continuously as
details space becomes available. The overflow slot is also permanently
positioned inside that stack. Compact markers, the pill layer, and the Track
the Sky header motif stay mounted and cross-fade. Event labels stay mounted;
their one-line and multiline presentations overlap and cross-fade across the
labeled-to-details segment. The Track the Sky dense and labeled motifs use the
same overlap technique. These opacity and position changes are internal to the
projected `_DayChip` height and add no section extent.

This introduces bounded retained alpha layers during a fractional transition.
The repeated `_DayChip` path still contains no `ShaderMask`, explicit
`saveLayer`, or `RepaintBoundary`; the complete month body remains the sole
repeated repaint-boundary owner. At committed endpoints the major compact and
event layers resolve to opacity zero or one. The calendar paint ownership guard
permits the five intentional day-wrapper alpha nodes and continues to fail on
additional wrappers or manual save-layer constructs. Gesture frame behavior is
therefore a required simulator/profile verification, not inferred solely from
the source guard.

Other transient extent terms are also explicit. The ordinary-month
label-to-day-grid gap remains at its non-details endpoint through progress `2`
and then interpolates from `_kDecanLabelToDayGridGap` to `3`. Heriu bottom
padding interpolates from `24` to `6`, and its header gap from `10` to `0`, over
the same labeled-to-details segment. The fixed 23-pixel day number,
28-pixel number header, 1-pixel vertical tile padding, selected border, and all
committed endpoint values are unchanged. Calendar restoration layout revision
2 therefore remains current.

Each `_DayChip` now carries a layout-transparent
`RenderCalendarPinchDayAnchor`. At pinch start, hit testing selects the day
under the focal point. Before each coalesced fractional update, the
`CalendarLayoutCorrectionController` records that render anchor's viewport
coordinate; `RenderCalendarEpochViewport` applies `correctBy` inside the same
layout transaction after the new fractional extent is laid out. This changes
scroll pixels only as a layout correction, emits no scroll notification, and
keeps the semantic day visually fixed. The render marker is a `RenderProxyBox`
and contributes no extent of its own.

Each correction request closes over the exact render anchor resolved for its
"before" sample. It does not re-read the page's mutable pinch-anchor fields
after layout. This is required at settle completion: the endpoint commit may
clear those fields before the viewport consumes its pending request. Resolving
again at that point could compare a day before layout with a different month
fallback after layout and incorrectly correct by an entire month section.
Capturing one render object for both sides keeps the final fractional frame and
the committed enum frame geometrically identical.

The fractional value is owned by a local `ValueNotifier<double?>`, so pinch
frames rebuild the calendar viewport subtree without calling page-level
`setState`. Gesture updates are coalesced to the latest value once per frame.
On release, the progress animates to the nearest enum endpoint; only after that
settle does the page commit, persist, and emit analytics once. Interrupted
pinches continue to use the existing discrete restoration policy and settle
target. The closed contributor list remains complete with the fractional
projection, transient ordinary/Heriu spacing, and layout-transparent day
anchor now included in the audited fragments.
