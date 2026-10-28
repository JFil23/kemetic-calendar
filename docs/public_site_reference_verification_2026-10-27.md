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
