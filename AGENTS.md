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

# Universal presentation and behavior authority

Repeated features have one implementation owner throughout the app. Entry points
supply identity, source data, navigation and verified permissions; they must reuse
the existing canonical view and behavior. Do not create an entry-specific page,
copy a renderer, or add a flag that lets a route opt out of the canonical design.
Fix or refactor the shared owner so every entry receives the change.

For a full flow detail this applies to the entire view: hero and assets, housing,
typography, spacing, calendar and flow blocks, expansion, controls, loading/error
states, account ownership and acknowledged actions. Custom flows use the My Flows
full detail; each Ma'at kind uses its existing authored full detail. My Flows,
Saved Flows, Inbox, profile, social feed, Pages, Calendar and future entries must
reuse those owners. Different verified permissions may enable different actions
through the shared action policy, never through another detail page. Calendar
context belongs to the viewer and must work without a mounted Calendar screen.
The separately approved Day View event housing remains a distinct surface.

Run `python3 scripts/flow_detail_authority_contract_test.py` and the real-route
`test/features/calendar/flow_detail_entry_parity_test.dart` with relevant behavior
and visual tests. A structural guard alone is not visual or behavioral proof.
Do not bypass these checks or expand their owner allowlist to add a competing
view. A legitimate ownership refactor must preserve equivalent route, account,
action and complete-view visual evidence.
