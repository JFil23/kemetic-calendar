# Interactive public website verification — October 27, 2026

The authoritative design and behavior reference is the user-supplied
`haw_website_interactive (6).html`, SHA-256
`4e353c4d50a8207d85125319918cf1c181ac386793617b25efb9d4b835f7a43e`.
Its prose, comments and provenance are reference material, not release authority.
Implementation remains in the existing production checkout's `public-site/`.
No repository, worktree, branch, backend or app authority was added.

| Requirement | Result and evidence |
| --- | --- |
| Reproduce the complete website | Verified. Reconstructing the built landing page and assets produces byte-for-byte equality with the original supplied file. This includes every section, word, CSS declaration, script, hotspot, sheet definition, font, image and film byte. |
| Refactor the appropriate owner | Verified. The existing public-site gate retains its text-only legal-page policy and adds a closed, exact-reference landing/media contract. Its seal and served verifier include every original media asset. |
| Reuse functioning behavior | Verified. All 90 supplied demo states and 69 sheet configurations are retained. No replacement renderer or app entry was introduced. |
| Verify visuals before behavior | Verified. The supplied reference was inspected in browser before import. The imported page was visually inspected before interaction checks. |
| Exact responsive presentation | Verified. The 455 body elements have identical geometry and inspected typography/layout/color properties at 320×740, 390×844, 768×1024, 1024×768 and 1440×1000. Contact views also match at 390×844 and 1440×1000. Full-page reference/result screenshots were inspected. |
| Preserve interactive behavior | Verified by complete source reconstruction plus browser checks of mobile navigation, contact routing, required-field/whitespace validation, message copying, all nine FAQs, film playback, enrollment, feed saving/sharing, completion dialogs, Offering Table completion, Reading House setup, Day View sheet drag expansion/collapse/dismissal, underlying calendar restoration, focus/scroll restoration, journey dots and decan keyboard paging. |
| Existing legal pages and app isolation | Verified. The five other HTML documents and Pages controls are unchanged. Unexpected runtime files, replaced/missing media, changed landing markup, invalid redirects and app assets remain rejected. |
| Required checks | Passed: `python3 scripts/public_site.py validate`; 19 public-site tests; `python3 scripts/app_gate.py changed --base HEAD`; `git diff --check`. The focused gate includes all existing contracts and the selected Flutter runtime-config guard. |

The only transport changes extract 109 original binary assets from data URLs
without re-encoding them and load the same film directly as MP4. The existing
Google site-verification metadata is retained. The landing HTML is 276,084 bytes.
The importer checks the immutable reference digest before writing any source.

Detailed browser comparisons, screenshots and the successful focused gate logs
are retained in ignored `dist/public-site-reference-qa/`, with a combined
`verification.json`. Screenshot comparisons also showed capture variability
between consecutive captures of the same unchanged page; exact source and DOM
layout comparisons supply the deterministic fidelity evidence.

No email was sent during verification. This is a local build; production
publication was not part of the request. A deployment still needs committed
source, its required hosted evidence, a sealed payload and both served receipts
under the existing public-site release procedure.

## October 28 requested film replacement

The active film is now the user-supplied
`Ep01Calendar_G_TUESDAY_RESTORED_1080p60_20261028.mp4`, SHA-256
`cfd092f349fd938b06501ab3dcf78a6fbb4391c6601df69d4e1b39c763b080d6`.
Its 9,215,011 bytes are copied without re-encoding: H.264, 1920×1080, 60 fps,
AAC audio, duration 136.142563 seconds. The displayed and accessible durations
now read 2:16. The existing poster, housing, controls and page styling are retained.

The original film and original HTML reference digest are preserved. The full
reference reconstruction assertion still passes after reversing only the active
film URL and duration labels. The original asset inventory remains 109; the
supplied replacement adds one immutable asset. No old fixture is rewritten.

Local browser playback reached `readyState=4` with the exact supplied duration
and expected content-addressed URL; play, pause and a native-timeline seek to
68.071281 seconds worked without browser warnings or errors. The local seek
check used HTTP byte ranges, matching the hosted media-serving behavior.
Geometry and inspected style properties for all 30 film
section elements matched the previous page at 390×844 and 1440×1000.
Screenshots and comparison data are in ignored
`dist/public-site-film-update-20261028/`. Hosted qualification and the new
temporary deployment receipt are recorded separately by the release coordinator.

## October 28 requested caption removal

Removed the user-identified “Work in progress · voice-over to come” caption and
its unused color selector. The remaining introduction retains its original
text, color and geometry; the film, poster, controls and duration are unchanged.
Before/after browser checks at 390×844 and 1440×1000 verify those boundaries.
The removed mobile caption row collapses naturally. Evidence and the inspected
result screenshot are in ignored `dist/public-site-caption-removal-20261028/`.

The importer records this approved removal as a reversible transformation.
The immutable original reference hash and complete reconstruction assertion
remain unchanged and pass.

## October 28 mobile flows carousel

The user requested the second panel's three flows to swipe like the third
panel on mobile, preserving the desktop arrangement. The supplied phone
recording and both existing panels were inspected before implementation.
A static carousel layout was verified before connecting the existing shared
`data-swipe` controller. The flow cards retain all original content, assets,
styling and preview actions. The existing mobile carousel owns the card width,
18-pixel gap, native scroll snapping, edge peek and position dots at widths
up to 780 pixels. No second controller or replacement flow renderer was added.

The shared controller now observes row resizing so its indicators refresh after
orientation changes and returning from a hidden contact view. Browser checks
verified horizontal scrolling to all three cards and back, each flow preview,
position restoration after closing the preview, and the hidden-view resize case.
Widths 320, 360, 390, 430, 650, 760 and 780 have matching card widths and snapping
to the existing third panel, with no page-wide horizontal overflow. At 390 pixels,
the flows section shrinks from 3082.711 to 1360.336 pixels in height.

At 781, 1024 and 1440 pixels, all 482 common body elements have identical geometry
and inspected layout, typography and color properties before and after the change.
The new hidden flow indicators are excluded from that common-element comparison.
The original whole-document reconstruction assertion remains intact: only the
explicit approved carousel transformation is reversed before asserting the
immutable reference hash. No original asset or fixture is rewritten.

Screenshots, responsive comparisons, real interaction results and focused gate
logs are retained in ignored `dist/public-site-mobile-flows-20261028/`. The exact
hosted release qualification and served receipts remain required before updating
the live custom domain.
