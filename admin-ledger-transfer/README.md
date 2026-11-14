# Admin activity ledger (backend transfer package)

Canonical target: `JFil23/kemetic-calendar-backend`.

This package is published from the Cloud Agent environment that only has write
access to `kemetic-calendar`. Apply it into the backend repo, then open the PR
there against `production`.

## Apply

```bash
# from kemetic-calendar-backend on production
git checkout -b cursor/admin-activity-ledger-c86f
bash /path/to/admin-ledger-transfer/APPLY_TO_BACKEND.sh .
git add admin supabase/migrations
git status
git commit -m "Replace admin console with owner activity ledger"
git push -u origin cursor/admin-activity-ledger-c86f
```

Or:

```bash
git checkout -b cursor/admin-activity-ledger-c86f production
git am /path/to/admin-ledger-transfer/admin-activity-ledger.patch
# or: git fetch ../admin-activity-ledger.bundle && git cherry-pick ...
```

## Verification already done

- `npm run typecheck`, `npm test`, `npm run build` in `admin/`
- Mockup layouts verified at desktop / 920 / 390
- Search, filters, Expand All, earlier-days interactions verified
