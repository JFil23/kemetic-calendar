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

## October 28 customer-facing copy and direct contact candidate

The user approved a customer-facing copy cleanup, direct Submit delivery to
`info@thisishaw.com`, and creating that email address. Social additions are
explicitly deferred. The four app CTAs remain at `https://kemet.pages.dev/`;
no app move, redirect, authentication, installation identity or app release is
included. Pronunciation remains deferred until the user's preference is known.

Removed the internal footer paragraph and its unused styling. Image descriptions
and accessible controls now describe the product without “actual,” “real,”
“original,” “fictional demo,” or film-tool terminology. The marketing experience
is called an interactive tour with sample activity. Existing post previews
retain their functional names. Explicit spaces separate the hero's underlying
sentences while its authored visual line breaks remain unchanged. Two FAQs
explain browser/home-screen use and guest versus account use, based on the
existing manifest and visitor/account owners. The nine previous FAQs and all
90 tour states, 69 sheets and 110 immutable assets are retained.

Contact retains the approved view, fields, typography and colors. Its single
Submit button replaces the email-app handoff and copying action. The browser
posts bounded form data to `/api/contact`, disables controls while awaiting a
receipt, and clears fields only after a successful server acknowledgement.
Failures, timeouts and rate limits preserve the draft; the browser does not
retry automatically. Editing a draft clears the previous confirmation.
Customer-facing contact addresses on the existing static documents also use
`info@thisishaw.com`.

The existing backend-only checkout owns the corresponding isolated Worker at
`cloudflare/contact/`. It accepts only the exact website contact route and
Origin, validates size, fields, topics and Reply-To, checks a honeypot and an
edge rate limit, and sends only to the fixed support recipient. It does not
proxy the website, touch the Flutter app, write account content, use the app's
warm cache, or deploy Supabase changes. Delivered support content belongs to
the receiving email provider. No affected app resource in
`config/warm_state_release_contract.v1.json` changes ownership. All existing
warm-state, route and source contracts remain in the focused/full App gates.

Static contact views at 390 and 1440 pixels were inspected before submission
behavior was connected. Sending, success and error presentations were inspected
on mobile. Settled before/after comparisons at 320, 390, 780, 1024 and 1440 pixels
show identical geometry and inspected styles for 228 elements across the hero,
flows, journey, rhythm and film sections, with no horizontal page overflow.
The comparison uses the browser's 1/64 CSS-pixel layout unit. Initial captures
with different tab viewport overrides and transient dot transitions were
identified as invalid comparisons; retained diagnostics document the cause.
Matching-viewport settled comparisons passed. The new FAQ and default contact
screenshots were inspected, and a tour entry and close action were replayed.

Browser submission checks use the real frontend and backend handler with an
explicitly simulated local email binding. They verify pending controls,
acknowledged success, failed delivery retaining the draft, rate limiting,
whitespace rejection and clearing a previous status when editing. Five automated
client tests cover receipt, concurrency, failure, timeout and validation behavior.
Nine backend tests cover delivery acknowledgement, failure, field/origin/size/
recipient boundaries, MIME/Unicode encoding, rate limits and deployment isolation.
The pinned Wrangler dry-run builds the isolated handler without uploading it.
The successful focused App gate retains every previous assertion, immutable
reference hash and asset restriction, including rejecting Functions and
`_worker.js` from the static website seal. The complete original supplied HTML
still reconstructs byte for byte by reversing only recorded approved revisions.

Evidence is in ignored `dist/public-site-customer-ready-20261028/`, including
`verification.json`, responsive comparisons, screenshots, simulated-delivery
results and `focused-gate/`. The backend's existing hosted gate now also requires
its contact unit tests and no-upload build, while retaining all Supabase checks.

Status: prepared, not published. The domain currently has no incoming email
service. Creating the selected inbox/forwarder, verifying the fixed recipient,
configuring the sender, qualifying both exact source commits, deploying the
isolated handler and observing a real inbox test are required before the custom
website domain can receive this candidate. No real email was sent, no paid plan
was purchased, and no production app or website cutover was performed locally.
## October 28 opening fade and interactive calendar explorer

The user requested exactly two additions: the app's opening text fade on the
existing hero, and a panel for browsing months and decans with their descriptions
and speech buttons. The canonical app source and actual introductory reference
were inspected before implementation. The live app's version receipt identified
`f75ea37205ca62e19fd5c31d99c2f463b62749f7` at inspection; the relevant source
owners in this checkout match that served baseline. This is an inspection receipt,
not a durable release pin. No Flutter, backend, account or app deployment changes
are part of this website revision.

The hero retains its typography, layout, content and controls. Its three lines
use HawIntroSlide's existing 700/2200/4200 ms delays and 80/1100/1400 ms fades,
including the linear first fade and ease-out later fades. The effect is inline
and never blocks input. A website-only presentation marker suppresses replay on
return visits; deep links retain immediate content, and reduced-motion CSS and
the controller display all three lines immediately. The app's persisted state
and warm-cache keys are not read or changed.

The new section follows the ten-day explanation. A static spread was rendered
and inspected at desktop and phone widths before connecting navigation or audio.
Its exporter reuses all 13 canonical month records (12 counted months plus Heriu
Renpet), all 36 decans in their authored order, and every complete description
from calendar_period_descriptions.dart. Month navigation selects its first decan;
decan navigation updates the month at each boundary. Heriu Renpet is explicitly
outside the 36 decans, with an explicit Begin again action. Names are accompanied
by the same Material speaker/stop glyphs and exact default-G recordings used by
the app, including each decan's English cue and the catalog's shared Beautiful
Star alias. The original audio and icon-font bytes are retained without changes.
The existing elevenlabs.io attribution is carried into the panel.

The website adapter allows one recording at a time. Pressing the active control
stops it. Navigation, contact, a product tour, film playback, page hiding or
leaving the panel stop playback; stale completion cannot update a newer control.
Playback failures restore the play button and permit an explicit retry. No speech
API, provider credential, account state or audio autoplay is introduced.

Local evidence is retained in ignored `dist/public-site-rhythm-20261028/`:

- `visual-parity.json`: 392 existing elements compared at 320, 390, 780, 1024
  and 1440 pixels, with matching resting geometry and inspected typography/color
  properties and no horizontal overflow. Zero-area hidden nodes are normalized,
  resolved auto-margin shorthand is excluded in favor of actual geometry, and
  coordinates are compared to 0.1 CSS pixel to account for fractional SVG layout.
  Initial hover/resize-transition captures were investigated and replaced with
  resting-state evidence; no source change was made to hide those differences.
- `browser-behavior.json` and `month-sequence.json`: every decan and month is
  reached through the shipped buttons in a real browser, with the correct complete
  descriptions, month boundaries, season and threshold. Actual M4A playback reaches
  readyState 4 and the stop action removes playback.
- `opening-behavior.json`: actual first-visit fade timing/curves, intermediate
  wordmark opacity, full visibility on completion and immediate returning visits.
- `calendar-desktop.jpg`, `calendar-desktop-viewport.jpg` and the mobile captures:
  inspected responsive presentation. The existing browser's offscreen capture
  artifact affecting the fixed Skip link is not a source/layout modification.
- The calendar's six browser-controller tests cover full ordering, boundaries,
  exact descriptions, audio supersession/completion/error/retry and cleanup,
  first/return visits, reduced motion, deep links and refused browser storage.

The immutable original reference digest and original 109 assets remain intact.
The original film replacement remains unchanged. A separately reversible calendar
addition records the new content and 49 media assets (48 distinct app recordings
and the icon font), so the whole-document reconstruction assertion still checks
the exact supplied HTML. Existing assertions and approved references are preserved.
The exact hosted App qualification, sealed temporary publication and served
verification remain separate release evidence.

## October 29 Flow film panel

The supplied `Haw_Whats_a_Flow_Draft_09_Smooth_Flow_Transition.mp4` is added
between the flows panel and the original how-it-works panel. Its SHA-256 is
`a265762537ea0abb130f078c3c6e599c3752193dd0f76ca19232a104db2785a7`: 11,896,167
bytes, H.264/AAC, 1920×1080 at 60 fps, 38.383333 seconds. The video bytes are
unchanged. Its eight-second frame supplies the poster, and its nine authored
English subtitle cues are exposed through a native WebVTT caption track. No
draft/reviewer wording is displayed. The existing story film remains unchanged.

The existing film box, 16:9 stage, cover, play icon, overlay typography, responsive
spacing and native controls are reused. The static panel was inspected on phone
and desktop before playback was connected. One shared film controller now binds
both films, loads each only on request, restores its cover after completion or
failed playback, and coordinates playback with the other film and pronunciation
audio. Contact navigation, page departure and document hiding pause playback.
The media capture listener filters VIDEO events so pronunciation cannot stop
itself; this boundary has an additional behavioral regression test and actual
browser verification. Existing app/backend source and destinations are unchanged.

Ignored `dist/public-site-flow-film-20261029/` retains the source overview, exact
poster/captions, static layout, responsive/browser evidence and final gate logs.
The local preview reuses the prior video preview server’s HTTP byte-range owner,
so timeline seeking is tested against the same transport behavior as hosted media.
The previous simple HTTP server could not expose a seekable range and was replaced
only for local preview. The video source was not changed to work around it.

The new panel and shared-controller refactor are separately reversible in the
reference manifest. All prior immutable assets and the complete original HTML
reconstruction assertion remain intact. New assertions bind the exact supplied
video, placement, poster, caption track and shared-controller behavior. The hosted
exact-commit gate and temporary publication receipts remain separate release
evidence; the custom domain is not changed by a preview upload.

Final local verification passed `scripts/app_gate.py changed --base HEAD`, with
24 website tests and the selected shared contracts/runtime guard. The browser
comparison found matching geometry and inspected presentation for all 461
existing elements at 390 and 1440 pixels, with no horizontal overflow. The new
16:9 stage also fits at 320 pixels. Actual desktop and phone playback reached
readyState 4 without errors; native captions, timeline seeking and natural
completion were verified. `playback.json`, `visual-parity.json`,
`panel-mobile.jpg`, `panel-desktop.jpg` and `app-gate-final/` retain that evidence.

## October 29 discovery and panel order

The requested sequence is now the ten-day rhythm panel, the complete story film,
then the calendar explorer. The calendar insertion/removal owner uses the FAQ
boundary, preserving exact reconstruction of the original supplied website.

The explorer now invites visitors to follow their curiosity through a seasonal
month wheel and three decan stars. Its visual layout was inspected with static
content on desktop and phone before new controls were connected. Full canonical
month/decan descriptions remain available in native expandable stories, and all
48 distinct recordings and the exact app pronunciation controls are retained.
Month stars, decan stars and the existing next/previous buttons use one position
and render owner. Heriu Renpet remains outside the 36 decans. Navigation stops
pronunciation through the existing cleanup owner.

Evidence in ignored `dist/public-site-discovery-20261029/` includes static and
finished screenshots, all 36 real-browser selections with exact complete stories,
actual pronunciation playback, the year threshold and five responsive widths
(320, 390, 780, 1024 and 1440). The 392 elements in the other panels retain their
inspected layout and presentation at 390 and 1440 pixels. An initial desktop
comparison used a different viewport height; matching the reference height
resolved its viewport-sized hero difference without modifying source or approved
references. The changed-source App gate passed, including 24 website tests and
the eight calendar/four film controller tests. Original assertions and assets
remain intact. Hosted qualification and temporary publication have separate
receipts; this change does not cut over the custom domain.

## October 29 aligned date wheels

A Gregorian month/day/year picker now precedes the explorer’s season strip and
existing month/decan cards. It uses the Stone Register picker’s five visible
48-pixel rows, Gregorian blue and Kemetic gold. The paired date, day stepping and
Back to today use one civil-date selection. Existing month/decan navigation
projects back into that selection, so the wheels and cards remain aligned.

Calendar’s `KemeticMath` and shared UTC epoch own conversion. The website’s direct
browser translation is bound to those source sections and verified against the
actual, unmodified Dart implementation for every day in the supported 401-year
range: 146,462 days in this run. The same complete parity and behavior checks run
in America/Los_Angeles and Pacific/Kiritimati. Gregorian month lengths, leap-day
clamping, the sixth day between years, New Year, pre-epoch dates, century dates,
range boundaries, wheel scrolling, keyboard input and date/card synchronization
are covered without changing the app’s source or existing assertions.

The static picker was inspected on desktop and phone before controls were
connected. A real phone-width hit check caught the rotated decorative bridge
overlapping the day wheel. Its bounds are now compact and it cannot receive
pointer events. The initial in-progress gate was superseded when that fix changed
the source; its exact-reference guard rejected the changing candidate. The final
changed-source App gate passed, including all 24 website tests and the twelve
calendar/four film controller tests. Only `app-gate-final/` is final local evidence.

Ignored `dist/public-site-date-picker-20261029/` retains static/final screenshots,
the independent Dart oracle, browser selections checked against it, keyboard and
native scroll evidence, audio cleanup, five responsive widths, and the hit check.
`card-parity.json` compares all 135 elements in the existing month/decan cards
using identical selected content at 390 and 1440 pixels; their geometry and
inspected presentation match exactly. Original assets and whole-document
reconstruction remain intact. Hosted qualification and temporary publication
remain separate receipts.
