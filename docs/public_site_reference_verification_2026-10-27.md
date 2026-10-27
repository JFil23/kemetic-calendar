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
