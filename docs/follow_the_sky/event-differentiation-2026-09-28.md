# Follow the Sky graphic differentiation — September 28, 2026

Implemented in `/Users/jaralephillips/dev/kemetic-calendar-rc`, on the existing `rc` branch. This implementation review was captured before release. Subsequent deployment identity is recorded by the served `version.json` and sealed release receipts.

The existing seven Flutter instrument families remain the renderer and interaction authority. The supplied HTML and implementation report guide the degree and physical basis of differentiation. The HTML source was inspected directly; its demo times and simplified astronomy were not imported.

## Authority and scope

The checked baseline is `4f8888e963a6f8da0746961f5a28998a97434e31`, matching `origin/rc` and the served RC version receipt. The production checkout remains clean. Its current HEAD and served production receipt also identify that commit; its reflog records the earlier production fast-forward at 15:55 PDT on September 28. This explains why the September 18 authority card's production commit is now historical. This task did not change production, branches, worktrees, backend source, or release configuration.

References and SHA-256 hashes are recorded in [verification.json](event-differentiation-2026-09-28/verification.json):

- `follow_the_sky_current_behavior_mockups_v2.html`
- The attached implementation report, `Pasted text.txt`
- Actual Flutter source and baseline instrument/housing renders.

## Changed code and data

Paths below are relative to the RC checkout. The pre-edit file/field assessment was also reported in the chat before implementation.

| Boundary | Files | Change |
| --- | --- | --- |
| Existing detailed graphics | `lib/features/calendar/follow_the_sky/presentation/widgets/follow_sky_instrument_surface.dart` | Enrich the existing painters; retain their shared time controller. Keep the conjunction label clear of the larger disks while its peak anchor stays fixed. |
| Existing calendar graphics | `.../presentation/widgets/track_sky_event_block_visual.dart`, `.../presentation/widgets/follow_sky_preview_calendar.dart`, `lib/features/calendar/day_view.dart` | Use the same typed facts for compact accents. Day View adds only the existing ownership payload's event ID to the graphic widget. |
| Typed data | `.../domain/sky_event.dart`, `.../domain/sky_instrument_data.dart`, new `.../domain/sky_graphic_astronomy.dart` | Add optional graphic astronomy, preserving existing fields and consumers. |
| Provider boundary | `.../services/sky_instrument_data_provider.dart`, `.../presentation/follow_sky_observation_presentation_model.dart`, new `.../services/sky_graphic_geometry.dart` | Attach and normalize graphic samples to the existing wall-time timeline. Preserve timing, readout, copy and visibility authorities. |
| Sourced inputs | `assets/follow_the_sky/sky_catalog_v2.json`, new `.../services/sky_graphic_ephemeris.g.dart`, `tool/follow_sky/enrich_astronomy.cjs` | Add graphic metadata to 45 events and reproducible pinned ephemerides. Keep the discovery catalog small by storing bulk samples separately. |
| Verification | Two new Follow the Sky tests, independent engine fixture, three affected housing PNGs, their checksum and documentation | Verify typed geometry, visual states, regression behavior and graphic-only pixel changes. |

Already available typed data included observer coordinates/time zone/elevation, event kinds and source precision, peak/observation windows, provenance, Moon rise/transit/set and position samples, lunar contacts, planet identity strings, elongation direction/angle, conjunction separation samples, solar eclipse contacts, and the existing seasonal thresholds. Some catalog-provider values were placeholders or absent; their displayed values were deliberately not rewritten by this task.

The added fields are restricted to graphic facts: mean radiant coordinates and constellation, meteor speed/typical ZHR/profile width/shape/fireball and train character, observer horizon samples, Moon illumination and altitude, Sun altitude, typed planet identity/apparent diameter/magnitude, calculated separation samples, solar eclipse class and disk ratio, and lunar penumbral/umbral magnitudes. Source/version/calculation version and provisional status accompany these facts.

## Result

- **Meteors:** a time-varying, observer-based radiant; distributed streaks that trace back to it; speed-dependent lengths; bounded density; deterministic occasional fireballs; train glow; broad, narrow and plateau activity curves. Daylight, lunar interference and radiant altitude reduce visibility. Below-horizon radiants are not drawn as visible sky objects.
- **Solar eclipses:** totality covers the solar disk and reveals a pale corona with a darker field. Annular events retain the smaller lunar disk, warm solar rim and brighter field. Contact timing remains the existing authority.
- **Planets:** disks and glow use calculated apparent diameter and magnitude on bounded visual scales. Jupiter's larger banded disk, Mars, Mercury, Venus and Saturn's rings remain members of their existing families. Conjunction spacing uses actual sampled separation; the roughly 0.3° pair closes more tightly than the roughly 1.2° pair.
- **Lunar eclipses:** partial events receive a curved umbral bite scaled by magnitude. Penumbral events receive diffuse shading, including the almost imperceptible July 2027 event.
- **Calendar accents:** compact meteor density/speed, eclipse classes and planet identities use the same data. Existing card text and shell remain unchanged.

## Visual evidence

The reference is a coherent instrument system, with distinctions caused by astronomy rather than unrelated decorative styles. Controlled static states make intrinsic differences visible independently of local daylight. Actual catalog states can legitimately look quiet when observing conditions are poor.

- [Controlled instrument comparisons, without event titles](event-differentiation-2026-09-28/static-peak-review.png)
- [Actual catalog peak states](event-differentiation-2026-09-28/catalog-peak-review.png)
- [Narrow-screen start/peak/end states](event-differentiation-2026-09-28/selected-time-review.png)
- [Compact calendar graphics](event-differentiation-2026-09-28/calendar-graphics.png)
- [Housing before/after/difference crops on all three platforms](event-differentiation-2026-09-28/housing-lunar-diff.png)

The visual harness rendered **216 actual catalog frames**: 24 events, three widths (320/390/768), and start/peak/end. It also rendered ten controlled reference states and thirteen compact cards. Representative states were visually inspected, including narrow conjunction labels and actual low-visibility meteor states. These are real existing Flutter widgets, not a separate demo renderer.

## Acceptance accounting

| Requirement | Status and evidence |
| --- | --- |
| Existing Follow the Sky shell, header, copy and prompts | Verified. Source boundaries retain them; all-catalog comparison checks presentation text/readouts/semantics. Housing pixel audit shows no changes outside the lunar disk. |
| Hero-wide drag; no generic visible slider or second input surface | Verified by existing interaction/controller/sheet tests. No gesture/controller implementation changes. |
| Moon, Sun, planets and eclipse bodies move with selected time | Verified by existing renderer tests plus actual start/peak/end captures. |
| Meteor Window retains its internal activity track | Verified in static and actual catalog renders; it still uses the shared controller. |
| Orionids, Taurids, Geminids and Quadrantids differ | Verified in controlled title-free comparisons through radiant, rate, streak character and curve width. Actual local conditions additionally affect visibility. |
| Total versus annular solar physics | Verified by typed data tests and paired renders. |
| Partial versus penumbral lunar shadows | Verified by typed data tests, renders and independent platform housing captures. |
| Mars versus Jupiter apparent scale/brightness | Verified by calculated data tests and paired renders. |
| Tight versus wider conjunction | Verified by actual separation tests and time-series renders. |
| Summer versus winter solar arcs | Verified by existing family behavior and paired catalog renders; seasonal implementation unchanged. |
| No new event-title parsing for detailed physics | Verified by source review. Typed facts drive new detail physics. Stable IDs are only ingest/sample lookup keys. Existing legacy small-card fallback remains. |
| Live following and fixed peak-marker behavior | Verified by existing regression tests. Marker anchors, timing and labels retain their existing authority; conjunction label spacing is graphic-only. |
| Turning/reflection/completion | Verified by existing Follow the Sky tests; persistence/meaning/controller implementations untouched. |
| Calendar materialization | Verified by existing tests and JSON comparison: every original field in all 70 catalog events is identical to baseline after removing the added graphic metadata. |
| Smooth drag | Existing gesture tests pass. New drawing work is bounded to 30 streaks and 81 curve points; ephemerides are precomputed and no network/ephemeris generation runs during drag. Physical-device frame-time profiling was not performed, so a device-specific smoothness claim remains unverified. |

## Checks

- `flutter test --no-pub test/features/calendar/follow_the_sky --reporter expanded`: **232 tests passed**.
- Targeted `flutter analyze --no-pub` across Follow the Sky, Day View and the new tests: **no issues**.
- `python3 scripts/maat_visual_contract_test.py`: **5 passed**.
- Pinned Flutter **3.35.3** Linux ARM64 and x64: affected housing golden independently regenerated, then compared again without update mode; **both passed**. Host macOS comparison passed in the suite.
- Each platform has exactly **1,857 changed pixels**, all within the lunar disk's bounding box `(171,539)–(219,588)` (exclusive upper bounds). The raised reference and every surrounding housing pixel are unchanged. The supplemental reference checksum was updated only after this review.
- Independent Astronomy Engine Horizon/Equator fixtures cover Los Angeles, Sydney and London at three instants, including interpolation between hourly samples.
- The pinned generator reproduces the catalog, generated ephemerides and engine fixtures **byte-for-byte**.
- `git diff --check`: clean. No lockfile/runtime dependency change.

Logs are retained beside this report. This is local implementation and verification, not a release build, deployment or full application release-gate receipt.

## Astronomy limits and catalog items for separate review

1. Meteor ZHR and profile widths are **typical shower character**, not precise year-specific local rate forecasts. The width parameters are documented qualitative envelopes; counts are illustrative and visibility-adjusted. The mean radiant is precessed to the catalog epoch, with actual observer rotation and geometric horizon projection. Atmospheric refraction, nightly radiant drift, extinction and full spherical sky-camera projection are outside this graphic enrichment.
2. **Quadrantids 2028 is already provisional** in the catalog. That flag and timing remain unchanged; generated geometry does not validate the annual peak prediction.
3. **Leonids 2027 enhanced windows** include four zero-duration entries and one seven-minute interval, while the note mentions modeled ZHR 40–50. Their intended duration/rate shape needs separate source review. This patch does not turn those entries into invented outbursts or silently change their schedule.
4. Day/range-precision meteor windows are not proof of a minute-accurate maximum. The graphic envelope preserves their uncertainty instead of replacing them with HTML demo times.
5. **July 18, 2027 penumbral eclipse:** NASA's penumbral magnitude is only **0.0014**. Its near-invisible graphic is intentional; making it as dark as a substantial eclipse would be misleading.
6. Planet samples are calculated around the existing catalog anchor. Displayed catalog peak times and any existing placeholder readouts are unchanged. Differences between a catalog closest-approach instant and a finer ephemeris minimum require a separate timing/readout review.
7. Solar eclipse classes and disk ratios describe the catalog event at central maximum. This patch does not create observer-specific eclipse visibility or local contacts, and it does not claim totality is visible from every selected observing place.
8. Existing seasonal path behavior is preserved as requested. A broader geographic/hemisphere ephemeris refactor would be separate work.

## Source provenance and regeneration

- [NASA GSFC solar eclipse catalog](https://eclipse.gsfc.nasa.gov/SEdecade/SEdecade2021.html): total/annular classes and central disk ratios.
- [NASA GSFC lunar eclipse catalog](https://eclipse.gsfc.nasa.gov/LEcat5/LE2001-2100.html): umbral and penumbral magnitudes.
- [NASA planetary fact sheets](https://nssdc.gsfc.nasa.gov/planetary/factsheet/): physical planetary radii.
- [IMO 2026 meteor calendar, table 5](https://www.imo.net/files/meteor-shower/cal2026.pdf) and [AMS calendar](https://www.amsmeteors.org/calendar/): working radiant/speed/rate and characteristic references. These support typical shower parameters, not new 2027/2028 annual forecasts.
- [NASA Quadrantids](https://science.nasa.gov/solar-system/meteors-meteorites/quadrantids/), [Orionids](https://science.nasa.gov/solar-system/meteors-meteorites/orionids/) and [Perseids](https://science.nasa.gov/solar-system/meteors-meteorites/perseids/): shower character.
- [Astronomy Engine JavaScript](https://github.com/cosinekitty/astronomy/tree/master/source/js), pinned **2.1.19**: EQD Moon/Sun vectors, illumination, planetary appearance and angular separation. It is a generation tool, not a new Flutter runtime dependency.

From the RC checkout, with `astronomy-engine@2.1.19` installed in a temporary dependency directory:

```sh
NODE_PATH=/path/to/temporary/node_modules node tool/follow_sky/enrich_astronomy.cjs
```

The script verifies the engine version and writes only graphic metadata, generated ephemerides and the independent test fixture. It does not rewrite scheduling fields.
