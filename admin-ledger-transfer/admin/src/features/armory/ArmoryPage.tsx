import { BookOpen, RefreshCcw } from "lucide-react";
import { useEffect, useMemo, useState } from "react";

import {
  AdminApiError,
  fetchArmoryPlaybooks,
  type ArmoryPlaybook,
} from "../../lib/api";
import { formatDate } from "../../lib/format";
import { getAdminSession } from "../../lib/session";

type LoadState =
  | { status: "loading" }
  | { status: "ready"; playbooks: ArmoryPlaybook[] }
  | { status: "error"; message: string };

export function ArmoryPage() {
  const [state, setState] = useState<LoadState>({ status: "loading" });
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const loadPlaybooks = async () => {
    setState({ status: "loading" });
    try {
      const session = await getAdminSession();
      const playbooks = await fetchArmoryPlaybooks(session);
      setState({ status: "ready", playbooks });
      setSelectedId((current) => current ?? playbooks[0]?.id ?? null);
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setState({
        status: "error",
        message: apiError?.message ?? "Armory could not load.",
      });
    }
  };

  useEffect(() => {
    void loadPlaybooks();
  }, []);

  const playbooks = state.status === "ready" ? state.playbooks : [];
  const selected = useMemo(
    () =>
      playbooks.find((playbook) => playbook.id === selectedId) ??
        playbooks[0] ??
        null,
    [playbooks, selectedId],
  );

  return (
    <section className="page-surface">
      <div className="page-heading">
        <div>
          <span className="eyebrow">Infrastructure</span>
          <h1>Armory</h1>
          <p>Read-only playbooks that future agents must follow.</p>
        </div>
        <button
          type="button"
          className="secondary-button"
          onClick={() => void loadPlaybooks()}
        >
          <RefreshCcw size={16} />
          Refresh
        </button>
      </div>

      {state.status === "error" && (
        <div className="notice danger">{state.message}</div>
      )}

      <div className="split-grid archive-layout">
        <div className="data-panel">
          <div className="panel-heading">
            <h2>Playbooks</h2>
            <span>{state.status === "loading" ? "Loading" : playbooks.length}</span>
          </div>
          {playbooks.length === 0 ? (
            <div className="empty-state">No playbooks are active.</div>
          ) : (
            <div className="list-stack">
              {playbooks.map((playbook) => (
                <button
                  key={playbook.id}
                  type="button"
                  className={`list-row${selected?.id === playbook.id ? " active" : ""}`}
                  onClick={() => setSelectedId(playbook.id)}
                >
                  <strong>{playbook.name}</strong>
                  <span>
                    {playbook.slug} · {playbook.agent_slug ?? "shared"}
                  </span>
                </button>
              ))}
            </div>
          )}
        </div>

        <div className="data-panel">
          <div className="panel-heading">
            <h2>{selected ? selected.name : "No Playbook Selected"}</h2>
            {selected && (
              <span>v{selected.version} · {formatDate(selected.updated_at)}</span>
            )}
          </div>
          {selected ? (
            <article className="markdown-view">
              <div className="inline-meta">
                <span>{selected.requires_approval ? "Approval gated" : "Draft output"}</span>
                <span>{selected.is_active ? "Active" : "Inactive"}</span>
              </div>
              <pre>{selected.system_prompt_md}</pre>
              <h3>Tools Allowed</h3>
              <pre>{JSON.stringify(selected.tools_allowed, null, 2)}</pre>
              <h3>Output Schema</h3>
              <pre>{JSON.stringify(selected.output_schema, null, 2)}</pre>
            </article>
          ) : (
            <div className="empty-state">Select a playbook to inspect it.</div>
          )}
        </div>
      </div>

      <div className="status-row">
        <div className="icon-disc success">
          <BookOpen size={22} />
        </div>
        <div>
          <h2>Draft rules only</h2>
          <p>
            Phase 3 exposes playbooks for inspection. Real Research, Copy, and
            other agent behavior waits for later phases.
          </p>
        </div>
      </div>
    </section>
  );
}
