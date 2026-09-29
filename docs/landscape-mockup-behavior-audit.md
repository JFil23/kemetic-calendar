# Landscape behavior acceptance

Reference: approved `landscape-calendar-real-sheets-v5.html`, the supplied `mockup correct scroll.mov`, `rc doesnt match.MP4`, and the conversation's Day View reuse requirements. Starting served RC: `c09d960e9605bbee0ebf70064d77083368eadc5b`.

Required behavior:

- The continuous, independently scrollable chronological event list ends 48 logical pixels left of the original one-third split (with a 144px minimum list width). The expanded calendar pane contains three continuous calendar days, a pinned month/day/all-day header and hour gutter.
- Pinching inside the calendar pane continuously changes the time scale from the original 58px/hour maximum to a full 24-hour day. The minimum uses the real viewport and clears both the phone safe area and the floating Today button. Day widths, the ledger, pinned headers, controls, and native sheets retain their dimensions.
- Zoom anchors the time under the fingers, preserves date position and the ledger's position, and reuses native event faces with proportional scaling. Both touch and browser/trackpad pinch are supported. Single-finger scrolling, wheel motion, taps, 15-minute note dragging, Today, and sheet behavior continue to use the current scale. Today retains the selected zoom; returning to landscape starts at the original scale.
- Calendar gestures move both axes with momentum. Headers and events move together. Crossing dates must not rebuild every event or interrupt motion.
- While linked, horizontal **and vertical** calendar movement smoothly brings the corresponding event into the list. Touching, scrolling, or using the keyboard on the list releases the link immediately. Today restores it.
- Tapping an offscreen list event selects it and smoothly locates its calendar block; tapping the now-visible event opens its native detail sheet. An already visible event opens immediately. Tapping a calendar block opens it without repositioning the calendar.
- Selection is shared by the list and block, with a brief locate pulse. Dismissing a sheet preserves selection and both scroll positions.
- Today centers today between yesterday and tomorrow, positions the current time about 81 minutes below the top of the timed area, and places the upcoming list event 18 pixels below the top. The floating native Today button stays at the calendar pane's lower left.
- The **sheet and scrim are confined to the calendar pane**. The list remains visible and usable. Shared native Day View sheet contents, image headers, colors, completion, actions, keyboard ownership, and restoration remain authoritative.
- Five Ma’at housing extents remain .71 for Offering Table/Kꜣr and .58 for Sky/Reading House/Djed. Custom flows retain separate native housing (.68 in landscape). Resizing and body scrolling must expose the entire native composition without covering the list.
- Past items retain full color. Native event artwork has reserved space; visual block heights participate in overlap placement. Canonical Kemetic metadata/date math owns month names and year boundaries.
- The landscape header has one 48 × 48 quick-add button for the existing note/reminder/flow sheet, with its entire hit target above the pinned day-header layer. The secondary three-dot menu is removed.
- Main Calendar and Day View both use this surface; rotating and returning from another route preserve their date context and sheet target.

The audit identified missing vertical list linkage, abrupt programmatic scrolling, competing one-axis gestures, unconditional list-tap sheet opening, missing block selection feedback, non-centered Today, repeated ledger text measurement, parent rebuilds during horizontal movement, and a full-screen sheet navigator. Verification must exercise these behaviors against the reference, including pointer drags and pane bounds; an initial static golden alone is insufficient.

## Verification evidence

- `landscape_pinch_zoom_test.dart` exercises real touch pinches, maximum/minimum bounds, focal anchoring, pane isolation, scrolling after zoom, pointer cancellation and stationary-finger release, native sheets, Today, viewport changes, note dragging, and browser/trackpad scale input. The zoom visual captures include midnight and late-night events and verify that the full day clears Today. The original three landscape references remain unchanged.

- `landscape_scroll_contract_test.dart` exercises physical diagonal drags and momentum, pinned headers, no parent date report while a finger is held, cached note projections, diagonal trackpad wheel input, smooth vertical list linkage, immediate list disengagement, Today relinking/centering, locate-before-open, unchanged scroll positions on block opening/dismissal, a usable list behind an open sheet, system Back, and proximity-only snapping.
- `landscape_split_behavior_test.dart` covers epagomenal/year boundaries, native Today placement, live-data refresh, full-color past events, painted-height overlap lanes, pinned all-day events, narrow native faces, and natural instrument height through resize/scroll.
- `landscape_split_view_test.dart` renders the real native sheet for all five Ma'at flows plus a custom flow. It checks sheet/scrim bounds and the `.71`/`.58` opening contract. The reviewed phone captures include the full surface, Djed, and custom-flow sheets. Fixtures use the same authored payloads as Day View rather than routing by display title alone.
- `landscape_user_sheet_test.dart` checks the native image provider, 190px hero, `.24` image treatment, pane boundaries, resizing, and scrolling through completion controls. `landscape_month_view_test.dart` exercises completion persistence, clearing, haptics and pulse feedback after native expansion.
- Existing navigation/rotation, restoration, keyboard and native portrait references remain part of the complete app gate. No native Day View sheet or backend implementation was changed in this pass.

The viewport refactor also fixes a pinned-Flutter behavior discovered by testing: a diagonal wheel event was delivered to only the inner axis. The calendar now resolves that signal once and applies both deltas through the existing `ScrollPosition.pointerScroll` behavior. Touch drags/momentum remain owned by Flutter's two-dimensional scrollable.
