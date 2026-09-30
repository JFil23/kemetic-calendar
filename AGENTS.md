# RC persistence and warm-state contract

These requirements supplement the Hꜣw authority card and four global coding laws.
This checkout remains the sole RC authority; this file grants no production or
backend deployment authority and does not authorize new worktrees or branches.

For every change to a route, repository read, account write, or persisted model:

- Read `docs/warm_state/change_contract.md` and review the affected entry in
  `config/warm_state_release_contract.v1.json`.
- Keep account-owned content in its account repository. The warm cache is
  disposable read acceleration. Never put pending writes in its eviction or
  logout cleanup paths.
- Preserve deployed cache keys across ordinary releases. Evolve payloads with
  resource-specific schema migrations and immutable old-release fixtures.
  Never add a build number, commit, or app version to the cache namespace.
- A new route or read boundary needs an explicit persistence owner and the
  appropriate cold/warm, background-refresh, account-change and write tests.
- Planner notes and nutrition mutations use `PlannerAccountStore` and the
  backend-owned mutation RPC. Do not restore a separate local-only fallback.
  Do not bypass acknowledgement, idempotency or revision conflict checks.
- Run `python3 scripts/warm_state_contract_test.py` and the affected behavioral
  tests; the complete App gate remains required before deployment.
- Do not remove assertions, raise inventory thresholds downward, rewrite old
  fixtures, or regenerate approved visual references merely to get green.
  A legitimate refactor must retain equivalent behavioral evidence and explain
  the changed ownership contract.

Passing the inventory guard alone is not proof of visible readiness or durable
storage. Verify the requested behavior and existing visual reference too.
