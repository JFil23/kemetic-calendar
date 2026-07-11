# PWA Persisted Onboarding Rhythm Identity Smoke

Date: 2026-07-11

Build under test:

- Mobile base commit: `89aa851`
- Patch state: uncommitted onboarding rhythm identity fix
- Local URL: `http://127.0.0.1:54232/?persisted-local=mobile-89aa851-uncommitted-identity-fix`
- Environment: dev/staging Supabase public values, real persistence enabled
- Review mode: disabled

Method:

- Human-assisted persisted PWA smoke with a clean first-run state.
- The previous contaminated account was not reused.
- No production customer data was used.
- No auth bypass or email-confirmation bypass was used.

Smoke path:

Recommended First Flow -> Join Flow -> Day View -> Event Detail -> Day's Rhythm -> dismiss -> wait -> Tap to explore -> menu open/return -> selected-day change -> wait -> refresh.

Observed result:

- Exactly one Day's Rhythm presentation.
- No tomorrow-then-today Day's Rhythm sequence.
- No second today card.
- No adjacent-day replay.
- No replay after refresh.
- No duplicate reflection or Ma'at guidance presentation.
- No `You are in ...` / `Open guidance` lower-third.
- Onboarding otherwise completed normally.

Gate decision:

- Persisted PWA runtime gate: PASS.
- This smoke is accepted as the runtime proof for the local-day onboarding rhythm identity fix.
