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

## October 1 landscape keyboard ownership

Reference: `ScreenRecording_10-01-2026 09-44-37_1.MP4`. The Reading House
composition remains visible at 37.532 seconds and disappears by 37.548 seconds
while the keyboard opens. Closing the keyboard restores the sheet and typed
draft. The existing approved landscape and five-flow portrait references remain
the visual contract; none are regenerated.

CalendarPage's landscape scaffold and DayViewPage's landscape mode now leave
keyboard occlusion to the pane-local modal's existing KeyboardInsetBoundary.
The scaffold previously shortened the nested navigator without recording that
consumption, so the modal consumed the inset again. DayViewPage retains its
portrait scaffold resizing. The pane continues publishing its actual constrained
height: this preserves browser visual-viewport sizing rather than substituting
physical-screen height. No sheet composition, opening extent, persistence owner,
cache key, model or backend contract changes.

`landscape_keyboard_ownership_test.dart` uses both actual page scaffolds and
their nested navigators with the existing populated Reading House presentation.
It covers native insets, web layout-sized viewports, and web visual-sized
viewports with stale raw insets, each at 100, 200 and 240 logical pixels. It
asserts pane and visible field bounds, hit testing, retained editable State and
focus, draft retention after keyboard dismissal, and return to portrait. The
pre-fix native calendar case fails because the 393px pane shrinks to 293px at
a 100px inset. Optional `CAPTURE_LANDSCAPE_KEYBOARD=true` writes review captures
under `/tmp/haw-video-review`, outside the approved references. Widget captures
simulate occlusion; they do not render an operating-system keyboard or replace
physical-device replay.


## October 1 compact landscape editing follow-up

References: `ScreenRecording_10-01-2026 10-32-41_1.MP4` shows the sheet
surviving but the composer clipped while the keyboard is open;
`ScreenRecording_10-01-2026 10-34-39_1.MP4` shows Apple Calendar prioritizing
the active field above the keyboard. The earlier ownership fix is necessary
but does not establish full composer visibility. Apple's field priority is
inspiration; existing Hꜣw content and approved portrait/non-editing references
remain authoritative.

The shared InstrumentEventSheetHost now uses compact geometry while a keyboard
is visible in landscape. It hides the 48px header, removes the header gap and
extra top clearance, gives the original body the available height, and reserves
the right edge for the existing keyboard switch. The body stays in the same
element slot, with the same field State, controller and scroll surface. Closing
the keyboard restores the normal header, footer and stored extent. Portrait,
keyboard ownership, five-flow opening extents, account writes and persistence
contracts are unchanged. No approved images were regenerated.

The strengthened regression checks both actual CalendarPage and DayViewPage
scaffolds, all three native/web viewport models, and 100/200/240/270/290px
occlusion on an 852×393 display. It intersects every ancestor paint clip,
checks the full field and Send bounds, checks Send against the keyboard switch,
retains field hit testing and State/focus assertions, types a draft before
resizing, closes and reopens the keyboard, and verifies the existing Send
callback receives the draft once. Caret-reveal scrolling must finish before
hit testing: Flutter temporarily ignores pointer events during that animation.
The unmodified portrait/landscape visual references and five-flow opening tests
remain required, alongside the full App release gate.

`tool/landscape_keyboard_probe.dart` reuses the real nested landscape navigator,
shared housing and populated Reading House presentation with a local no-op
send callback. It permits visual verification with iOS Safari's real software
keyboard without signing into an account. In iOS 26.2 Simulator, with Safari's
address/tab toolbar collapsed to match the recording, the complete field,
caret and enabled Send were visible above the native keyboard accessory bar.
Switching to the custom keyboard and back retained the draft and full composer.
The normal header/footer returned on keyboard dismissal. This is simulator
verification, not a claim of replay on the user's physical phone. With both
Safari address and tab bars fully expanded, the remaining landscape web area
was smaller than the field itself; that extreme browser-chrome state cannot
show a full-height composer within the available app viewport.
