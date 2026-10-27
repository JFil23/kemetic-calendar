import {
  Activity,
  AlertTriangle,
  BarChart3,
  CalendarDays,
  Gauge,
  Network,
  RefreshCcw,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";

import {
  AdminApiError,
  fetchWarRoomSummary,
  type NodeMetric,
  type WarRoomDays,
  type WarRoomSummary,
} from "../../lib/api";
import { getAdminSession } from "../../lib/session";

const RANGE_OPTIONS: WarRoomDays[] = [7, 30, 90];

type LoadState =
  | { status: "loading" }
  | { status: "ready"; summary: WarRoomSummary }
  | { status: "error"; message: string; statusCode?: number };

function numberValue(value: number | null | undefined) {
  return typeof value === "number" && Number.isFinite(value)
    ? value.toLocaleString()
    : "—";
}

function percentDelta(value: number | null | undefined) {
  if (typeof value !== "number" || !Number.isFinite(value)) return "—";
  const sign = value > 0 ? "+" : "";
  return `${sign}${(value * 100).toFixed(1)}%`;
}

function dateValue(value: string | null | undefined) {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  return new Intl.DateTimeFormat(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(date);
}

function SectionEmpty({ message }: { message: string }) {
  return <div className="empty-state">{message}</div>;
}

function KpiCard({
  label,
  value,
  note,
  Icon,
}: {
  label: string;
  value: string;
  note: string;
  Icon: typeof Activity;
}) {
  return (
    <div className="kpi-card">
      <div>
        <span>{label}</span>
        <strong>{value}</strong>
      </div>
      <Icon size={22} />
      <p>{note}</p>
    </div>
  );
}

function NodeTable({
  title,
  rows,
  emptyMessage,
}: {
  title: string;
  rows: NodeMetric[];
  emptyMessage: string;
}) {
  return (
    <div className="data-panel">
      <div className="panel-heading">
        <h2>{title}</h2>
      </div>
      {rows.length === 0 ? (
        <SectionEmpty message={emptyMessage} />
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Node</th>
                <th>Events</th>
                <th>Users</th>
                <th>Last seen</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr key={`${row.slug ?? row.title}-${row.last_event_at}`}>
                  <td>
                    <strong>{row.title ?? row.slug ?? "Untitled node"}</strong>
                    <span>{row.slug ?? "No slug"}</span>
                  </td>
                  <td>{numberValue(row.event_count)}</td>
                  <td>{numberValue(row.distinct_users)}</td>
                  <td>{dateValue(row.last_event_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

export function WarRoomDashboardPage() {
  const [days, setDays] = useState<WarRoomDays>(7);
  const [state, setState] = useState<LoadState>({ status: "loading" });

  useEffect(() => {
    let alive = true;

    async function loadSummary() {
      setState({ status: "loading" });
      try {
        const session = await getAdminSession();
        const summary = await fetchWarRoomSummary(session, days);
        if (alive) setState({ status: "ready", summary });
      } catch (error) {
        const apiError = error instanceof AdminApiError ? error : null;
        if (alive) {
          setState({
            status: "error",
            message: apiError?.message ?? "War Room summary failed.",
            statusCode: apiError?.status,
          });
        }
      }
    }

    void loadSummary();

    return () => {
      alive = false;
    };
  }, [days]);

  const summary = state.status === "ready" ? state.summary : null;
  const kpis = useMemo(() => {
    if (!summary) return [];
    return [
      {
        label: "Active users",
        value: numberValue(summary.users?.active_period),
        note: `${summary.period_days} day telemetry-active users`,
        Icon: Activity,
      },
      {
        label: "New users",
        value: numberValue(summary.users?.new_period),
        note: "Profiles created in range",
        Icon: CalendarDays,
      },
      {
        label: "Onboarding",
        value: numberValue(summary.users?.onboarding_completed_period),
        note: "Completed onboarding in range",
        Icon: Gauge,
      },
      {
        label: "First node",
        value: numberValue(summary.activation?.first_node_opened_period),
        note: "First node opens in range",
        Icon: Network,
      },
      {
        label: "Flow starts",
        value: numberValue(summary.flows?.created_period),
        note: "Non-hidden flows created",
        Icon: BarChart3,
      },
      {
        label: "AI failures",
        value: numberValue(summary.flows?.ai_failure_period),
        note: "Flow generation failures",
        Icon: AlertTriangle,
      },
    ];
  }, [summary]);

  return (
    <section className="page-surface war-room-page">
      <div className="page-heading">
        <div>
          <span className="eyebrow">War Room</span>
          <h1>Dashboard</h1>
          <p>
            Read-only app health, Ma'at outcomes, node engagement, flow signals,
            and failures.
          </p>
        </div>
        <div className="range-control" aria-label="War Room date range">
          {RANGE_OPTIONS.map((option) => (
            <button
              key={option}
              type="button"
              className={days === option ? "active" : ""}
              onClick={() => setDays(option)}
            >
              {option}d
            </button>
          ))}
        </div>
      </div>

      {state.status === "loading" && (
        <div className="status-row">
          <div className="icon-disc">
            <RefreshCcw size={22} />
          </div>
          <div>
            <h2>Loading War Room</h2>
            <p>Fetching scoped aggregate metrics through admin_war_room.</p>
          </div>
        </div>
      )}

      {state.status === "error" && (
        <div className="status-row">
          <div className="icon-disc danger">
            <AlertTriangle size={22} />
          </div>
          <div>
            <h2>
              {state.statusCode === 401 || state.statusCode === 403
                ? "War Room access denied"
                : "War Room could not load"}
            </h2>
            <p>{state.message}</p>
          </div>
        </div>
      )}

      {summary && (
        <>
          <div className="summary-meta">
            <span>Generated {dateValue(summary.generated_at)}</span>
            <span>Period starts {dateValue(summary.period_start)}</span>
            <span>Minimum bucket {summary.min_bucket_size}</span>
          </div>

          <div className="kpi-grid">
            {kpis.map((kpi) => (
              <KpiCard key={kpi.label} {...kpi} />
            ))}
          </div>

          <div className="data-panel">
            <div className="panel-heading">
              <h2>Ma'at Outcomes</h2>
              <span>{summary.maat?.source ?? "No source"}</span>
            </div>
            {(summary.maat?.outcomes ?? []).length === 0 ? (
              <SectionEmpty message="No Ma'at outcome rows met the minimum bucket size for this period." />
            ) : (
              <div className="table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th>CTA</th>
                      <th>Outcome</th>
                      <th>Windows</th>
                      <th>Done delta</th>
                      <th>Skip delta</th>
                      <th>Latest week</th>
                    </tr>
                  </thead>
                  <tbody>
                    {(summary.maat?.outcomes ?? []).map((row) => (
                      <tr key={`${row.cta_type}-${row.cta_ref}-${row.outcome_flag}`}>
                        <td>
                          <strong>{row.cta_type ?? "Unknown"}</strong>
                          <span>{row.cta_ref ?? "No ref"}</span>
                        </td>
                        <td>
                          <strong>{row.outcome_flag ?? "Unflagged"}</strong>
                          <span>{row.routing_effect ?? "No routing effect"}</span>
                        </td>
                        <td>{numberValue(row.completed_window_count)}</td>
                        <td>{percentDelta(row.weighted_delta_done_rate)}</td>
                        <td>{percentDelta(row.weighted_delta_skipped_rate)}</td>
                        <td>{dateValue(row.latest_measured_week)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>

          {(summary.maat?.alerts ?? []).length > 0 && (
            <div className="data-panel">
              <div className="panel-heading">
                <h2>Ma'at Alerts</h2>
              </div>
              <div className="table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th>Alert</th>
                      <th>Severity</th>
                      <th>CTA</th>
                      <th>Cohort</th>
                    </tr>
                  </thead>
                  <tbody>
                    {(summary.maat?.alerts ?? []).map((row) => (
                      <tr key={`${row.alert_key}-${row.cta_ref}-${row.cohort_key}`}>
                        <td>{row.alert_key ?? "Unknown alert"}</td>
                        <td>{row.severity ?? "—"}</td>
                        <td>
                          <strong>{row.cta_type ?? "—"}</strong>
                          <span>{row.cta_ref ?? "No ref"}</span>
                        </td>
                        <td>
                          <strong>{row.cohort_type ?? "—"}</strong>
                          <span>{row.cohort_key ?? "No key"}</span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          <div className="split-grid">
            <NodeTable
              title="Top Nodes"
              rows={summary.nodes?.top ?? []}
              emptyMessage="No node rows met the minimum bucket size for this period."
            />
            <NodeTable
              title="Bottom Nodes"
              rows={summary.nodes?.bottom ?? []}
              emptyMessage="No lower-volume node rows met the minimum bucket size for this period."
            />
          </div>

          <div className="data-panel">
            <div className="panel-heading">
              <h2>Flow Signals</h2>
            </div>
            <div className="metric-strip">
              <div>
                <span>Created</span>
                <strong>{numberValue(summary.flows?.created_period)}</strong>
              </div>
              <div>
                <span>Completed</span>
                <strong>
                  {numberValue(summary.flows?.completed_events_period)}
                </strong>
              </div>
              <div>
                <span>Skipped</span>
                <strong>{numberValue(summary.flows?.skipped_events_period)}</strong>
              </div>
              <div>
                <span>AI success</span>
                <strong>{numberValue(summary.flows?.ai_success_period)}</strong>
              </div>
              <div>
                <span>AI failure</span>
                <strong>{numberValue(summary.flows?.ai_failure_period)}</strong>
              </div>
            </div>
          </div>

          <div className="split-grid">
            <div className="data-panel">
              <div className="panel-heading">
                <h2>App Failure Signals</h2>
              </div>
              {(summary.errors?.app_events ?? []).length === 0 ? (
                <SectionEmpty message="No app failure signals met the minimum bucket size for this period." />
              ) : (
                <div className="table-wrap">
                  <table>
                    <thead>
                      <tr>
                        <th>Event</th>
                        <th>Count</th>
                        <th>Users</th>
                        <th>Last seen</th>
                      </tr>
                    </thead>
                    <tbody>
                      {(summary.errors?.app_events ?? []).map((row) => (
                        <tr key={`${row.event}-${row.last_seen_at}`}>
                          <td>{row.event ?? "Unknown event"}</td>
                          <td>{numberValue(row.event_count)}</td>
                          <td>{numberValue(row.distinct_users)}</td>
                          <td>{dateValue(row.last_seen_at)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>

            <div className="data-panel">
              <div className="panel-heading">
                <h2>Flow Generation Failures</h2>
              </div>
              {(summary.errors?.flow_generation ?? []).length === 0 ? (
                <SectionEmpty message="No flow generation failure group met the minimum bucket size for this period." />
              ) : (
                <div className="table-wrap">
                  <table>
                    <thead>
                      <tr>
                        <th>Status</th>
                        <th>Count</th>
                        <th>Users</th>
                        <th>Last seen</th>
                      </tr>
                    </thead>
                    <tbody>
                      {(summary.errors?.flow_generation ?? []).map((row) => (
                        <tr key={`${row.llm_status}-${row.last_seen_at}`}>
                          <td>{row.llm_status ?? "Unknown status"}</td>
                          <td>{numberValue(row.event_count)}</td>
                          <td>{numberValue(row.distinct_users)}</td>
                          <td>{dateValue(row.last_seen_at)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          </div>
        </>
      )}
    </section>
  );
}
