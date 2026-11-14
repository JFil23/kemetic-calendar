import { RefreshCcw, WalletCards } from "lucide-react";
import { useEffect, useState } from "react";

import {
  AdminApiError,
  fetchTreasurySummary,
  type TreasurySummary,
} from "../../lib/api";
import { formatDate, formatMoney } from "../../lib/format";
import { getAdminSession } from "../../lib/session";

type LoadState =
  | { status: "loading" }
  | { status: "ready"; summary: TreasurySummary }
  | { status: "error"; message: string };

export function TreasuryPage() {
  const [state, setState] = useState<LoadState>({ status: "loading" });

  const loadTreasury = async () => {
    setState({ status: "loading" });
    try {
      const session = await getAdminSession();
      const summary = await fetchTreasurySummary(session);
      setState({ status: "ready", summary });
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setState({
        status: "error",
        message: apiError?.message ?? "Treasury could not load.",
      });
    }
  };

  useEffect(() => {
    void loadTreasury();
  }, []);

  const summary = state.status === "ready" ? state.summary : null;

  return (
    <section className="page-surface">
      <div className="page-heading">
        <div>
          <span className="eyebrow">Infrastructure</span>
          <h1>Treasury</h1>
          <p>Lightweight cost ledger and active budget caps for ops runs.</p>
        </div>
        <button
          type="button"
          className="secondary-button"
          onClick={() => void loadTreasury()}
        >
          <RefreshCcw size={16} />
          Refresh
        </button>
      </div>

      {state.status === "error" && (
        <div className="notice danger">{state.message}</div>
      )}

      <div className="kpi-grid">
        <div className="kpi-card">
          <div>
            <span>Total spend</span>
            <strong>{formatMoney(summary?.totals.cost_usd ?? 0)}</strong>
          </div>
          <WalletCards size={22} />
          <p>Recorded agent run cost in the ledger.</p>
        </div>
        <div className="kpi-card">
          <div>
            <span>Runs</span>
            <strong>{summary?.totals.run_count ?? 0}</strong>
          </div>
          <WalletCards size={22} />
          <p>Runs with ledger rows.</p>
        </div>
        <div className="kpi-card">
          <div>
            <span>Budgets</span>
            <strong>{summary?.budgets.length ?? 0}</strong>
          </div>
          <WalletCards size={22} />
          <p>Active caps checked before agent runs.</p>
        </div>
      </div>

      <div className="split-grid">
        <div className="data-panel">
          <div className="panel-heading">
            <h2>Cost By Agent</h2>
          </div>
          {(summary?.by_agent ?? []).length === 0 ? (
            <div className="empty-state">No agent costs recorded yet.</div>
          ) : (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Agent</th>
                    <th>Runs</th>
                    <th>Cost</th>
                  </tr>
                </thead>
                <tbody>
                  {summary?.by_agent.map((row) => (
                    <tr key={row.agent_slug}>
                      <td>{row.agent_slug}</td>
                      <td>{row.run_count}</td>
                      <td>{formatMoney(row.cost_usd)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        <div className="data-panel">
          <div className="panel-heading">
            <h2>Active Budgets</h2>
          </div>
          {(summary?.budgets ?? []).length === 0 ? (
            <div className="empty-state">No active budgets configured.</div>
          ) : (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Scope</th>
                    <th>Period</th>
                    <th>Limit</th>
                  </tr>
                </thead>
                <tbody>
                  {summary?.budgets.map((budget) => (
                    <tr key={budget.id}>
                      <td>{budget.agent_slug ?? budget.scope}</td>
                      <td>{budget.period}</td>
                      <td>{formatMoney(budget.limit_usd)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      <div className="data-panel">
        <div className="panel-heading">
          <h2>Recent Ledger</h2>
        </div>
        {(summary?.recent_ledger ?? []).length === 0 ? (
          <div className="empty-state">No ledger rows yet.</div>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Agent</th>
                  <th>Provider</th>
                  <th>Model</th>
                  <th>Cost</th>
                  <th>Created</th>
                </tr>
              </thead>
              <tbody>
                {summary?.recent_ledger.map((row) => (
                  <tr key={row.id}>
                    <td>{row.agent_slug ?? "unknown"}</td>
                    <td>{row.provider}</td>
                    <td>{row.model}</td>
                    <td>{formatMoney(row.cost_usd)}</td>
                    <td>{formatDate(row.created_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </section>
  );
}
