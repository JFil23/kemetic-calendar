# Landscape visual references

The phone landscape fixture follows the approved `landscape-calendar-real-sheets-v5.html` layout and the supplied scroll recordings. Its 852 × 393 viewport includes phone safe-area insets. The subsequent user-approved refinement moves the divider 48 logical pixels left and replaces the two tiny header controls with one 48 × 48 quick-add target. The surface shows yesterday/today/tomorrow; the additional Djed and custom-flow captures verify native sheets confined to the calendar pane.

The root images are the reviewed macOS references. Linux x64 and ARM64 references were rendered with the pinned Flutter 3.35.3 toolchain in [App capture run 36491442901](https://github.com/JFil23/kemetic-calendar/actions/runs/36491442901), source commit `86079944786751000064ac789baccd1dadd34478`. All three images from each architecture were visually checked against the root references. Comparisons use exact pixels per renderer, with no tolerance or normalization.

All 52 existing native Ma'at portrait reference images in each capture are byte-identical to their checked-in references. Only landscape references were adopted from these captures.

The time-zoom extension adds `zoom-intermediate-852x393.png` and `zoom-full-day-852x393.png`. These are generated through real pinch gestures, with the full-day fixture including midnight and late-night notes. Native faces retain their proportions, the full day clears the Today control and safe area, and the original-scale references are unchanged.

The two zoom references for Linux x64 and ARM64 were reviewed from [App capture run 36522301728](https://github.com/JFil23/kemetic-calendar/actions/runs/36522301728), source commit `05e395d8b5ccb9b883a50cd984ba58a9a4441aef`, using the same pinned toolchain. All three original landscape references and all 52 native portrait references per architecture remained byte-identical. Only the four new zoom images were adopted.
