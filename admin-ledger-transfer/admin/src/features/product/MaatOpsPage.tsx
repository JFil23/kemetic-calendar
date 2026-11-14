import {
  HeartPulse,
  Play,
  RefreshCcw,
  Search,
  ShieldCheck,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";

import {
  AdminApiError,
  createMaatOverride,
  dryRunMaat,
  fetchMaatDeliveries,
  fetchMaatEvaluations,
  fetchMaatFixtures,
  fetchMaatOverrides,
  type MaatDelivery,
  type MaatDryRunResult,
  type MaatEvaluation,
  type MaatFixture,
  type MaatOverride,
} from "../../lib/api";
import { formatDate } from "../../lib/format";
import { getAdminSession } from "../../lib/session";

type LoadState =
  | { status: "loading" }
  | { status: "ready" }
  | { status: "error"; message: string };

export function MaatOpsPage() {
  const [state, setState] = useState<LoadState>({ status: "loading" });
  const [policyVersion, setPolicyVersion] = useState<string>("-");
  const [fixturePolicyVersion, setFixturePolicyVersion] = useState<
    string | null
  >(null);
  const [fixtures, setFixtures] = useState<MaatFixture[]>([]);
  const [selectedFixtureId, setSelectedFixtureId] = useState("");
  const [dryRunResult, setDryRunResult] = useState<MaatDryRunResult | null>(
    null,
  );
  const [deliveryUserId, setDeliveryUserId] = useState("");
  const [deliveries, setDeliveries] = useState<MaatDelivery[]>([]);
  const [evaluations, setEvaluations] = useState<MaatEvaluation[]>([]);
  const [overrides, setOverrides] = useState<MaatOverride[]>([]);
  const [notice, setNotice] = useState<string | null>(null);
  const [overrideScope, setOverrideScope] = useState<
    "global" | "cta" | "cohort" | "user" | "policy"
  >("cta");
  const [ctaType, setCtaType] = useState("flow_template");
  const [ctaRef, setCtaRef] = useState("");
  const [cohortType, setCohortType] = useState("");
  const [cohortKey, setCohortKey] = useState("");
  const [targetUserId, setTargetUserId] = useState("");
  const [overrideReason, setOverrideReason] = useState("");
  const [overrideJson, setOverrideJson] = useState('{\n  "weight": 1\n}');

  const selectedFixture = useMemo(
    () => fixtures.find((fixture) => fixture.id === selectedFixtureId) ?? null,
    [fixtures, selectedFixtureId],
  );

  const load = async () => {
    setState({ status: "loading" });
    try {
      const session = await getAdminSession();
      const [fixturePayload, overrideRows] = await Promise.all([
        fetchMaatFixtures(session),
        fetchMaatOverrides(session),
      ]);
      setPolicyVersion(fixturePayload.policy_version);
      setFixturePolicyVersion(fixturePayload.fixture_policy_version ?? null);
      setFixtures(fixturePayload.fixtures);
      setSelectedFixtureId(
        (current) => current || fixturePayload.fixtures[0]?.id || "",
      );
      setOverrides(overrideRows);
      setState({ status: "ready" });
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setState({
        status: "error",
        message: apiError?.message ?? "Ma'at operations could not load.",
      });
    }
  };

  useEffect(() => {
    void load();
  }, []);

  const runDryRun = async () => {
    setNotice(null);
    try {
      const session = await getAdminSession();
      const result = await dryRunMaat(session, {
        fixture_id: selectedFixtureId || undefined,
      });
      setDryRunResult(result);
      setNotice(
        "Dry-run completed with no delivery, snapshot, or routing writes.",
      );
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setNotice(apiError?.message ?? "Dry-run failed.");
    }
  };

  const lookupDeliveries = async () => {
    setNotice(null);
    try {
      const session = await getAdminSession();
      const userId = deliveryUserId.trim();
      const [deliveryRows, evaluationRows] = await Promise.all([
        fetchMaatDeliveries(session, userId),
        fetchMaatEvaluations(session, userId),
      ]);
      setDeliveries(deliveryRows);
      setEvaluations(evaluationRows);
      setNotice(
        `Lookup returned ${deliveryRows.length} delivery rows and ${evaluationRows.length} evaluations.`,
      );
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setNotice(apiError?.message ?? "Guidance lookup failed.");
    }
  };

  const createOverrideDraft = async () => {
    setNotice(null);
    let override: Record<string, unknown>;
    try {
      override = JSON.parse(overrideJson) as Record<string, unknown>;
    } catch (_error) {
      setNotice("Override JSON is invalid.");
      return;
    }

    try {
      const session = await getAdminSession();
      const result = await createMaatOverride(session, {
        scope: overrideScope,
        cta_type: ctaType,
        cta_ref: ctaRef,
        cohort_type: cohortType,
        cohort_key: cohortKey,
        target_user_id: targetUserId,
        override,
        reason: overrideReason,
      });
      setNotice(
        `Override draft created and sent to Approvals (${result.approval.id}).`,
      );
      setOverrideReason("");
      const rows = await fetchMaatOverrides(session);
      setOverrides(rows);
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setNotice(apiError?.message ?? "Override draft failed.");
    }
  };

  return (
    <section className="page-surface war-room-page">
      <div className="page-heading">
        <div>
          <span className="eyebrow">Product</span>
          <h1>Ma'at Ops</h1>
          <p>
            Inspect policy fixtures, user delivery status, and draft routing
            changes without changing production behavior.
          </p>
        </div>
        <span className="phase-pill ready">Phase 6</span>
      </div>

      <div className="status-row">
        <div className="icon-disc success">
          <ShieldCheck size={22} />
        </div>
        <div>
          <h2>Read and dry-run first</h2>
          <p>
            Dry-runs report the expected decision shape only. Routing overrides
            create approval requests and are not live policy changes.
          </p>
        </div>
      </div>

      {state.status === "error" && (
        <div className="notice danger">{state.message}</div>
      )}
      {notice && <div className="notice">{notice}</div>}

      <div className="kpi-grid">
        <div className="kpi-card">
          <div>
            <span>Policy version</span>
            <strong>{policyVersion}</strong>
          </div>
          <HeartPulse size={22} />
          <p>Runtime constant from the Ma'at guidance module.</p>
        </div>
        <div className="kpi-card">
          <div>
            <span>Fixtures</span>
            <strong>{fixtures.length}</strong>
          </div>
          <HeartPulse size={22} />
          <p>Fixture file version: {fixturePolicyVersion ?? "-"}</p>
        </div>
        <div className="kpi-card">
          <div>
            <span>War Room</span>
            <strong>Open</strong>
          </div>
          <HeartPulse size={22} />
          <p>
            <Link to="/war-room/dashboard">View aggregate Ma'at panels</Link>
          </p>
        </div>
      </div>

      <div className="split-grid">
        <div className="data-panel form-panel">
          <div className="panel-heading">
            <h2>Fixture Browser</h2>
            <span>product.maat.read</span>
          </div>
          <div className="form-grid">
            <label className="full-span">
              Fixture
              <select
                value={selectedFixtureId}
                onChange={(event) => setSelectedFixtureId(event.target.value)}
              >
                {fixtures.map((fixture) => (
                  <option key={fixture.id} value={fixture.id}>
                    {fixture.id} - {fixture.description}
                  </option>
                ))}
              </select>
            </label>
          </div>
          <article className="markdown-view">
            {selectedFixture ? (
              <>
                <h3>{selectedFixture.description}</h3>
                <pre>{JSON.stringify(selectedFixture.expect, null, 2)}</pre>
              </>
            ) : (
              <p>No fixtures loaded.</p>
            )}
          </article>
        </div>

        <div className="data-panel form-panel">
          <div className="panel-heading">
            <h2>Dry-run Evaluate</h2>
            <span>no writes</span>
          </div>
          <div className="form-actions padded-actions">
            <button type="button" onClick={() => void runDryRun()}>
              <Play size={16} />
              Run Dry-run
            </button>
            <button
              type="button"
              className="secondary-button"
              onClick={() => void load()}
            >
              <RefreshCcw size={16} />
              Refresh
            </button>
          </div>
          <article className="markdown-view">
            {dryRunResult ? (
              <pre>{JSON.stringify(dryRunResult, null, 2)}</pre>
            ) : (
              <p>Select a fixture and run a dry-run.</p>
            )}
          </article>
        </div>
      </div>

      <div className="data-panel form-panel">
        <div className="panel-heading">
          <h2>Delivery Inspector</h2>
          <span>product.users.support</span>
        </div>
        <div className="form-grid">
          <label className="full-span">
            User ID
            <input
              value={deliveryUserId}
              onChange={(event) => setDeliveryUserId(event.target.value)}
              placeholder="auth user id"
            />
          </label>
        </div>
        <div className="form-actions">
          <button type="button" onClick={() => void lookupDeliveries()}>
            <Search size={16} />
            Lookup Deliveries
          </button>
        </div>
        {deliveries.length === 0 ? (
          <div className="empty-state">No delivery rows loaded.</div>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Kind</th>
                  <th>Status</th>
                  <th>CTA</th>
                  <th>Preview</th>
                  <th>Created</th>
                </tr>
              </thead>
              <tbody>
                {deliveries.map((delivery) => (
                  <tr key={delivery.id}>
                    <td>
                      <strong>{delivery.kind}</strong>
                      <span>{delivery.decan_period_key}</span>
                    </td>
                    <td>{delivery.status}</td>
                    <td>
                      <strong>{delivery.cta_type ?? "-"}</strong>
                      <span>{delivery.cta_ref ?? "-"}</span>
                    </td>
                    <td>{delivery.teaser_preview ?? "-"}</td>
                    <td>{formatDate(delivery.created_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        {evaluations.length === 0 ? (
          <div className="empty-state">No evaluation rows loaded.</div>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Window</th>
                  <th>Suppressed</th>
                  <th>Drift</th>
                  <th>Strength</th>
                  <th>Memory</th>
                  <th>Created</th>
                </tr>
              </thead>
              <tbody>
                {evaluations.map((evaluation) => (
                  <tr key={evaluation.id}>
                    <td>
                      <strong>{evaluation.window_date}</strong>
                      <span>{evaluation.decan_period_key}</span>
                    </td>
                    <td>{evaluation.suppressed.join(", ") || "-"}</td>
                    <td>{String(evaluation.drift?.reason ?? "-")}</td>
                    <td>{String(evaluation.strength?.reason ?? "-")}</td>
                    <td>
                      {String(evaluation.memory_brief?.context_quality ?? "-")}
                    </td>
                    <td>{formatDate(evaluation.created_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <div className="split-grid">
        <div className="data-panel form-panel">
          <div className="panel-heading">
            <h2>Routing Override Draft</h2>
            <span>approval required</span>
          </div>
          <div className="form-grid">
            <label>
              Scope
              <select
                value={overrideScope}
                onChange={(event) =>
                  setOverrideScope(event.target.value as typeof overrideScope)
                }
              >
                <option value="global">global</option>
                <option value="cta">cta</option>
                <option value="cohort">cohort</option>
                <option value="user">user</option>
                <option value="policy">policy</option>
              </select>
            </label>
            <label>
              CTA type
              <input
                value={ctaType}
                onChange={(event) => setCtaType(event.target.value)}
              />
            </label>
            <label>
              CTA ref
              <input
                value={ctaRef}
                onChange={(event) => setCtaRef(event.target.value)}
              />
            </label>
            <label>
              Target user
              <input
                value={targetUserId}
                onChange={(event) => setTargetUserId(event.target.value)}
              />
            </label>
            <label>
              Cohort type
              <input
                value={cohortType}
                onChange={(event) => setCohortType(event.target.value)}
              />
            </label>
            <label>
              Cohort key
              <input
                value={cohortKey}
                onChange={(event) => setCohortKey(event.target.value)}
              />
            </label>
            <label className="full-span">
              Reason
              <textarea
                value={overrideReason}
                onChange={(event) => setOverrideReason(event.target.value)}
                rows={4}
              />
            </label>
            <label className="full-span">
              Override JSON
              <textarea
                value={overrideJson}
                onChange={(event) => setOverrideJson(event.target.value)}
                rows={6}
              />
            </label>
          </div>
          <div className="form-actions">
            <button type="button" onClick={() => void createOverrideDraft()}>
              Create Approval Draft
            </button>
          </div>
        </div>

        <div className="data-panel">
          <div className="panel-heading">
            <h2>Override Drafts</h2>
            <span>{overrides.length}</span>
          </div>
          {overrides.length === 0 ? (
            <div className="empty-state">No routing override drafts.</div>
          ) : (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Scope</th>
                    <th>Status</th>
                    <th>Reason</th>
                    <th>Approval</th>
                  </tr>
                </thead>
                <tbody>
                  {overrides.map((override) => (
                    <tr key={override.id}>
                      <td>
                        <strong>{override.scope}</strong>
                        <span>
                          {override.cta_ref ?? override.cohort_key ?? "-"}
                        </span>
                      </td>
                      <td>{override.status}</td>
                      <td>{override.reason}</td>
                      <td>{override.approval_request_id ?? "-"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </section>
  );
}
