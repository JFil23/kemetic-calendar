# Calendar extent contributor inventory

Status: closed source inventory for the Extent Model feasibility gate. This is
not renderer or production-consumer authority.

Audited implementation parent:
`5ff66008f6bd083147637ed4962db91f6ecf3f66`.

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
height of 32, 62, and 98 respectively.

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
- expansion level
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

Pinch currently switches among discrete expansion levels, then finds month
geometry through keys and applies `jumpTo` to maintain the focal point. It does
not create an intermediate section-height formula. It remains a geometry
consumer that must move to semantic geometry before registry deletion and
program completion.

## Completeness proof and change control

Completeness was established by tracing these paths:

1. `_YearSection` enumerates exactly 13 `CalendarGeometrySection` children.
2. Each section contains one `_GoldDivider`, an optional `_SeasonHeader`, and
   exactly one `_MonthCard` or `_EpagomenalCard` inside
   `CalendarGeometryMonthBody`.
3. Every vertical padding, spacer, intrinsic row, and fixed-height child in
   both card columns is classified in the equations above.
4. `_DecanRow` and the Heriu row take their height from `_DayChip`, whose outer
   `SizedBox` uses only the projected chip height.
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
