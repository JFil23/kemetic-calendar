# P0 Launch Verification Notes

## PWA RC Readiness

- Smoke date: 2026-07-01 PDT / 2026-07-02 UTC
- Build path: `scripts/build_web_release.sh env/prod.json`
- Runtime config blocker fixed: `b8658b8` (`/env.json` is loaded from the site root)
- Direct-route blocker fixed: `02f2491` (authenticated PWA deep links win over passive restoration)
- Authenticated PWA smoke result: passed for login, auth restore after reload, auth restore after tab close/reopen, direct nested routes, Day View visible event-block continuity, Planner, Journal, Flows/My Flows, Profile, Inbox, Calendars, invalid shared-flow links, and invalid event-invite links.
- Browser log/privacy result: no warn/error logs after the fixed build and no observed email, UUID, JWT/bearer token, auth token, or journal text leaks in browser logs.

### PWA RC Risks To Watch

1. Real OS-level PWA install prompt and standalone app-switch resume were not fully testable in the in-app browser; watch closely during week one.
2. Browser Back from hash-normalized route-backed surfaces did not reliably return to Day View in the browser harness; app close/back affordances preserved visible calendar content.
3. Shared calendar selection UI was verified, but the smoke account's expanded member calendar had no upcoming events to display.
4. Push notification permission, subscription, and notification click-through were not fully exercised; manifest, messaging worker reference, and deep-link routes were checked.

## Calendar Import Privacy Boundary

- Calendar Import is one-way: external calendar -> HAw.
- HAw does not create, update, delete, or export events to outside calendars.
- Android requests `READ_CALENDAR` only.
- Destructive clear/disconnect was not manually smoked on the dev account.

## Account Deletion

- Repo verification date: 2026-06-01 PDT
- Environment checked locally: repository and linked Supabase project
- Local function present: yes, `supabase/functions/delete_account/index.ts`
- Mobile function name: `delete_account`
- Required function secrets in linked project: present by name (`SUPABASE_URL`, `PROJECT_URL`, `SERVICE_ROLE_KEY`, `SUPABASE_SERVICE_ROLE_KEY`)
- Function deployed to staging: not confirmed; `supabase functions list` for the linked project did not show `delete_account`
- Staging smoke result: pending
- Known limitation: this note does not confirm that the linked Supabase project is staging, nor does it confirm dashboard redirect allowlist or live account deletion behavior. Complete the staging smoke before public launch.

### Staging Smoke To Complete

1. Create a staging test account.
2. Add profile, journal, calendar/planner, flow, notification, and social data where available.
3. Trigger Delete account from Settings.
4. Confirm the app signs out and returns to the auth gate.
5. Confirm the account cannot access old data.
6. Confirm database rows are deleted or anonymized according to policy.
