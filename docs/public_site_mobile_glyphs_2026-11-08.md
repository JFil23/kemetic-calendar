# Public website mobile transliteration repair

The user's three iPhone screenshots identify missing Egyptological alef/ain in
the philosophy kicker and paragraph, decan 24, and footer navigation. The served
landing page was byte-identical to the canonical production source before this
change; its baseline receipt is retained in
`dist/public-site-glyph-audit-20261108/baseline.json`.

Cormorant Garamond does not contain U+A722–A725 or U+1E96. Mobile device fonts
cannot be relied on to supply these letters. Reuse the existing digest-verified
Gentium Plus font (`HawText`) as a fallback before generic fonts in the shared
serif/sans stacks and the picker's explicit stacks. The five linked static
documents declare that same existing face and fallback. Their validator allows
only that exact bundled font declaration; arbitrary font/resource loads and
executable content remain rejected.

No text is transliterated, replaced with Latin approximations, or rasterized.
All original font/media bytes, calendar data, pronunciation recordings,
interactions, layout declarations, reference assertions and preserved A/B mockups
remain intact. The new narrow, reversible typography revision restores the
preceding approved document exactly before either historical reconstruction.

Verification:

- The new dependency-free cmap regression inventories every non-ASCII letter or
  mark in all six documents (including dynamic JSON and expanded descriptions),
  plus uppercase/lowercase and NFD forms. All 29 required characters are present
  in the existing app-identical Gentium font. A separate fontTools audit confirms
  named, nonempty outlines for every character; no runtime dependency was added.
- Clicked through all 36 decans and all 13 month/threshold entries in a 390 px
  browser viewport, including expanded stories. Render records, screenshots and
  heading contact sheets are saved in the audit directory. Also inspected the
  mobile menu, contact view, footer and every linked document.
- iPhone 14 simulator, iOS 26.2 Safari: visually verified the reported uppercase
  kicker, philosophy paragraph, `sbꜣ ꜥpdw` heading and footer `Why ḥꜣw`. Saved
  `iphone-safari-story.jpg`, `iphone-safari-decan-24.jpg` and
  `iphone-safari-footer.jpg`. These are simulator checks, not a physical-device
  claim. An existing iPad simulator also rendered the corrected story text.
- Responsive checks at 320, 390, 430 and 1440 px retain the approved arrangement;
  there is no horizontal document overflow at the checked sizes.
- `python3 scripts/app_gate.py changed --base HEAD` passed, including all 27
  public-site tests, calendar/date/speech/film/contact regressions, original and
  B byte-for-byte reconstruction, release contracts and the selected Dart guard.
  Evidence: `dist/public-site-glyph-audit-20261108/focused-gate/`.

Publication requires the candidate's full hosted App gate, the existing
background website-only coordinator, qualified-preview verification and the
existing root CNAME cutover procedure. The final live-domain checks remain a
separate completion requirement. No app or backend release is included.
