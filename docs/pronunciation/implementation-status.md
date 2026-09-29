# Pronunciation cutover

Changes live only in `/Users/jaralephillips/dev/kemetic-calendar-rc`, branch `rc`.
The initial local/live identity receipt was `b07af9c3169bf9716a2ede32aacce85c14d468b3`.
It is a historical receipt, not durable RC authority. No production/backend or
protected historical checkout was changed. No branch or worktree was created.

## Runtime and content

- Exactly 54 structural identities: 13 month/Heriu Renpet entries, 36 decans,
  five birthdays. Leap day six deliberately has no invented birthday recording.
- Existing names, written transliterations, and decan glosses are frozen by tests.
  Source transliteration and pronunciation fields are separate from display text.
- Allen §2.6 and cited calendar sections supply the speaking convention;
  MEDU NETER/Faulkner supports components. Discrepancies stay in source notes.
- `PronunciationService` owns both engines, active identity, cancellation, route
  ownership, lifecycle stops, and Settings preview. Callers pass keys only.
- `just_audio` plays bundled MP3s first. Only missing/failed playback enters the
  device fallback, which reads catalog respelling then the existing gloss with
  the catalog pause. Settings previews explicitly use that same fallback path.
- The old resolver, overrides, service, speech-only month field, phonetic flag,
  and arbitrary surface speech construction are removed.

## Replaceable audio

All 54 assets were rendered offline by macOS `say`, Samantha en-US, 145 words/minute.
The installed English voices report compact quality; these files are authorized
first-pass assets, not a final neural/human recording or listening approval.
Each name/gloss segment is edge-trimmed; the segments are joined with exactly
300 ms silence and loudness-normalized to -18 LUFS / -2 dB true peak target.
Output is mono 44.1 kHz 128 kbps MP3. Name-only rows have no added gap or gloss.
FFmpeg decoded every output successfully during rendering.

`audio-manifest.json` and generated Dart receipts bind the catalog input,
render settings, and file SHA-256. The release test requires the exact 54-file
set and current hashes, including approved text fingerprints. Future text or
recipe changes invalidate the receipt. Listening approval is independently
tracked and is not fabricated for these first-pass recordings.

Rebuild on macOS: `FFMPEG=/path/to/ffmpeg python3 tool/render_pronunciation.py`.
Then format the generated Dart part and regenerate the catalog review sheet.
The renderer needs macOS Samantha and FFmpeg; it needs no cloud credentials.

## Surface coverage

Day card/dropdown; Month/Decan Info; Kemetic scrolling month header (Gregorian
month header stays silent); normal/focused decan headers; onboarding; Day's
Rhythm; reflection sheet and detail masthead; Decan Opening; Settings fallback.
Existing labels/navigation remain; the speaker is its own tap target. The shared
control has explicit idle/playing visuals and preserves expanded phone targets.
Unmounting or covering the owning route, changing the key, tapping stop, or
leaving the app cancels playback without triggering fallback.

## Validation receipt

- Catalog/assets/fallback/identity/header targeted suite: 33 passed. Final focused/landscape/visual suite: 35 passed. Day-card mapping, Decan Opening, navigation ownership, and onboarding suite: nine passed. All are included in the full regression run.
- Static narrow-screen and 1.5× text images reviewed before playback hookup.
- Final analyzer: no errors or warnings; six existing private-type informational findings in unchanged `calendar_active_maat_flows.dart` (`--no-fatal-infos`).
- Full RC app debug web build succeeded. Every one of its 54 packaged audio files matches the catalog SHA-256 receipt (2,190,732 bytes total).
- Browser smoke check: month.12 and decan.01.02 loaded their MP3s and completed. A forced HTTP 404 for month.01 completed through device TTS; the temporary test-build file was restored afterward.
- Full regression suite: **3,072 passed, one skipped, zero failures** in 7m48s (`flutter test --no-pub --reporter expanded`).
- iOS playback verification is **blocked**: the existing `speech_to_text` 6.6.2 dependency fails simulator compilation with `speech_to_text/speech_to_text-Swift.h file not found`. The integration test could not launch, so native playback, second-tap stop, route stop, and forced fallback are not claimed as verified on iOS. The corresponding injected-driver/widget checks pass, and the integration test is saved for retry after the native build issue is fixed.
- No deployment was requested or performed by this implementation step.
