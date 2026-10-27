import { Check, RefreshCcw, X } from "lucide-react";
import type { FormEvent } from "react";
import { useEffect, useState } from "react";

import {
  AdminApiError,
  createApprovalRequest,
  decideApprovalRequest,
  fetchApprovals,
  type ApprovalRequest,
} from "../../lib/api";
import { formatDate } from "../../lib/format";
import { getAdminSession } from "../../lib/session";

type LoadState =
  | { status: "loading" }
  | { status: "ready"; approvals: ApprovalRequest[] }
  | { status: "error"; message: string };

const STATUSES: Array<ApprovalRequest["status"] | "all"> = [
  "pending",
  "approved",
  "rejected",
  "needs_changes",
  "cancelled",
  "all",
];

export function ApprovalsPage() {
  const [status, setStatus] = useState<ApprovalRequest["status"] | "all">(
    "pending",
  );
  const [state, setState] = useState<LoadState>({ status: "loading" });
  const [summary, setSummary] = useState("");
  const [message, setMessage] = useState<string | null>(null);

  const loadApprovals = async () => {
    setState({ status: "loading" });
    try {
      const session = await getAdminSession();
      const approvals = await fetchApprovals(session, status);
      setState({ status: "ready", approvals });
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setState({
        status: "error",
        message: apiError?.message ?? "Approvals could not load.",
      });
    }
  };

  useEffect(() => {
    void loadApprovals();
  }, [status]);

  const submitApproval = async (event: FormEvent) => {
    event.preventDefault();
    setMessage(null);
    try {
      const session = await getAdminSession();
      await createApprovalRequest(session, {
        kind: "create_codex_task",
        summary,
        risk_level: "low",
        payload: { source: "manual_phase3_test" },
      });
      setSummary("");
      await loadApprovals();
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setMessage(apiError?.message ?? "Approval request could not be created.");
    }
  };

  const decide = async (
    approval: ApprovalRequest,
    nextStatus: Exclude<ApprovalRequest["status"], "pending">,
  ) => {
    setMessage(null);
    try {
      const session = await getAdminSession();
      await decideApprovalRequest(session, {
        id: approval.id,
        status: nextStatus,
        decision_notes: `Marked ${nextStatus} from Phase 3 console.`,
      });
      await loadApprovals();
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setMessage(apiError?.message ?? "Approval decision failed.");
    }
  };

  const approvals = state.status === "ready" ? state.approvals : [];

  return (
    <section className="page-surface">
      <div className="page-heading">
        <div>
          <span className="eyebrow">Infrastructure</span>
          <h1>Approvals</h1>
          <p>Central inbox for draft decisions and approval-gated actions.</p>
        </div>
        <button
          type="button"
          className="secondary-button"
          onClick={() => void loadApprovals()}
        >
          <RefreshCcw size={16} />
          Refresh
        </button>
      </div>

      <div className="toolbar-row">
        <select
          value={status}
          onChange={(event) =>
            setStatus(event.target.value as ApprovalRequest["status"] | "all")}
        >
          {STATUSES.map((item) => (
            <option key={item} value={item}>{item}</option>
          ))}
        </select>
      </div>

      {state.status === "error" && (
        <div className="notice danger">{state.message}</div>
      )}
      {message && <div className="notice danger">{message}</div>}

      <div className="data-panel">
        <div className="panel-heading">
          <h2>Inbox</h2>
          <span>{state.status === "loading" ? "Loading" : approvals.length}</span>
        </div>
        {approvals.length === 0 ? (
          <div className="empty-state">No approval requests in this view.</div>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Summary</th>
                  <th>Kind</th>
                  <th>Risk</th>
                  <th>Status</th>
                  <th>Created</th>
                  <th>Decision</th>
                </tr>
              </thead>
              <tbody>
                {approvals.map((approval) => (
                  <tr key={approval.id}>
                    <td>{approval.summary}</td>
                    <td>{approval.kind}</td>
                    <td>{approval.risk_level}</td>
                    <td>{approval.status}</td>
                    <td>{formatDate(approval.created_at)}</td>
                    <td>
                      {approval.status === "pending" ? (
                        <div className="button-pair">
                          <button
                            type="button"
                            onClick={() => void decide(approval, "approved")}
                          >
                            <Check size={15} />
                            Approve
                          </button>
                          <button
                            type="button"
                            className="secondary-button"
                            onClick={() => void decide(approval, "rejected")}
                          >
                            <X size={15} />
                            Reject
                          </button>
                        </div>
                      ) : (
                        approval.decision_notes ?? "Decided"
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <form className="data-panel form-panel" onSubmit={submitApproval}>
        <div className="panel-heading">
          <h2>Manual Test Request</h2>
          <span>approvals.decide</span>
        </div>
        <div className="form-grid">
          <label className="full-span">
            Summary
            <input
              value={summary}
              onChange={(event) => setSummary(event.target.value)}
              placeholder="Approve a test Codex task draft"
            />
          </label>
        </div>
        <div className="form-actions">
          <button type="submit">Create Request</button>
        </div>
      </form>
    </section>
  );
}
