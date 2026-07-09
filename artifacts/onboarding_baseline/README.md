# Onboarding Baseline

This artifact records the accepted first-run onboarding source of truth. Treat
this behavior as canonical until a new real user bug changes the baseline.

## Visual Oracle

Accepted slides 1-4 visual/runtime oracle:

```txt
/Users/jaralephillips/Desktop/Screen Recording 2026-07-03 at 3.18.26 PM.mov
```

Use that recording as the source of truth for the first four onboarding screens.
The captured first-frame thumbnail is stored at:

```txt
artifacts/onboarding_oracle/2026-07-09_recording/Screen Recording 2026-07-03 at 3.18.26 PM.mov.png
```

## Canonical First-Run Flow

```txt
Enter ḥꜣw -> understand today -> choose or skip first flow -> arrive at calendar -> receive Day's Rhythm -> after closing it, see only Tap to explore
```

The sequence must feel continuous. The user should not see a jump, a stale
prompt, or a helper from a later part of the app before the handoff is complete.

## Slides 1-4 Visual Parity Checklist

- Slide 1: `ḥꜣw` is visibly brighter than `this is`, using the hero gold
  emphasis from the recording.
- Slide 1: `skip` and `tap to begin` remain readable but quiet.
- Slides 1-3: the menu button is not visible.
- Slide 2: selecting the bottom option keeps its text, padding, border, glow,
  and rounded bottom corners fully visible.
- Slide 3: copy consistently says `Ka-her-Ka`; it must not say `Khoiak`.
- Slide 3: `next` is readable.
- Slide 4: Recommended First Flow uses the real Ma'at flow detail structure.
- Slide 4: the three-decan arc stays horizontal across simulator, emulator,
  and PWA review widths.
- Slide 4: `Join Flow` is enabled while the carry field is empty.
- Slide 4: empty `Join Flow` tap shows the gold prompted field treatment, not a
  red, orange, pink, or error-looking treatment.
- Slide 4: after typing, the field remains in the gold system and clears the
  prompted state.

## Evening Threshold Empty-Carry Interaction

When the user taps `Join Flow` on the recommended Evening Threshold flow with an
empty carry field:

- `Join Flow` remains tappable while the field is empty.
- The flow does not join and does not create events.
- The carry field smooth-scrolls into a comfortable center-screen view.
- After the scroll settles, the carry field receives focus and the keyboard opens.
- The field is softly highlighted with the gold system.
- The normal border is muted gold.
- The prompted or focused border is soft gold.
- The prompted ring/glow is a subtle outer gold glow only.
- There is no red or pink validation styling.
- There is no yellow inner glow.
- There is no snackbar, toast, validator, `errorText`, `errorBorder`,
  `focusedErrorBorder`, or disabled-button dead end.
- The hint fades in with this exact copy:

```txt
Name what you carry today before this flow begins.
```

When the user enters non-empty text:

- The prompted state clears.
- The hint fades out.
- The user can tap `Join Flow` again to proceed.

## Accepted Onboarding Guards

- The three-decan arc must stay horizontal during onboarding, including narrow
  mobile and PWA widths.
- Opening or canceling the date picker must not reset onboarding state.
- First-time users must not receive a reflection/decan prompt during the
  onboarding handoff.
- After Day's Rhythm closes, the next visible guide is only `Tap to explore`.
- Planner has no first-run helper.
- Planner must not show a meaningless empty `0%`.
- Library, Inbox, Calendars, and Reflections stay quiet during first-run
  onboarding unless a new real user bug justifies changing this.

## Verification Order

Verify in this order before accepting or deploying a new onboarding baseline:

1. iOS simulator / Xcode simulator.
2. Android emulator.
3. PWA.
4. Clean deploy from the verified commit.
5. Confirm `/version.json` identifies the deployed commit.

Do not continue power-user exploration after onboarding changes until this
sequence passes again.

## Runtime Review Entry Point

Use the hidden review route for runtime parity checks:

```txt
/debug/onboarding-review
```

The route is available only when this runtime gate is enabled:

```txt
APP_ENV != prod
ENABLE_ONBOARDING_REVIEW=true
```

For local PWA review builds, `PWA_REVIEW_MODE=true` may also enable the same
route when `APP_ENV != prod`.

Simulator and emulator runs can boot directly to the route with:

```txt
--dart-define=ENABLE_ONBOARDING_REVIEW=true
--dart-define=H3W_DEBUG_ROUTE=/debug/onboarding-review
```

This route replays onboarding with in-memory onboarding progress. It does not
read remote onboarding completion, does not reset local onboarding progress,
and does not mark the signed-in user's onboarding complete.

During review-mode onboarding, Join Flow uses review-only in-memory data. It
must not create persisted flows, persisted events, notifications, analytics
events, onboarding progress, orientation rows, or completion rows. The review
branch creates one synthetic Evening Threshold flow and one synthetic target
event in the local runtime cache, then exercises the real onboarding transition
with that synthetic flow id.

Review-mode calendar state must also opt out of warm-start cache restore/save so
the synthetic review flow/event cannot be serialized into the signed-in user's
local calendar cache.

Completing the review onboarding must not navigate from `/debug/onboarding-review`
to the normal production calendar route. Review mode remains active after the
closing handoff, and calendar helper/decan reflection prompts stay suppressed in
that route.

The Day View handoff is also isolated from the signed-in user's existing
calendar events. The embedded onboarding Day View receives only the synthetic
target event. Event detail and completion controls may update in-memory sheet
state for review, but must not call the user event completion, daily
orientation, notification, or flow persistence paths. It does not delete, hide,
or mutate the user's persisted flow data. If the review target event cannot be
found, the review Day View should fail visibly rather than filling the screen
with unrelated existing events.
