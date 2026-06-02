# P0 Launch Verification Notes

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
