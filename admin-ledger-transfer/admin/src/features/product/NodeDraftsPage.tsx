import { Eye, FileText, RefreshCcw, Save, ShieldCheck } from "lucide-react";
import { useEffect, useMemo, useState } from "react";

import {
  AdminApiError,
  approveNodeDraft,
  createNodeDraft,
  fetchNodeDrafts,
  requestNodeDraftApproval,
  saveNodeDraftVersion,
  type NodeDraft,
  type NodeDraftsPayload,
} from "../../lib/api";
import { formatDate } from "../../lib/format";
import { getAdminSession } from "../../lib/session";

type LoadState =
  | { status: "loading" }
  | { status: "ready"; payload: NodeDraftsPayload }
  | { status: "error"; message: string };

const EMPTY_PAYLOAD: NodeDraftsPayload = {
  drafts: [],
  published_nodes: [],
  source_of_truth:
    "ADR-002 Option C: Dart remains app-visible; admin drafts are not live content.",
};

function parseMetadata(value: string) {
  try {
    return JSON.parse(value) as Record<string, unknown>;
  } catch (_error) {
    return null;
  }
}

export function NodeDraftsPage() {
  const [state, setState] = useState<LoadState>({ status: "loading" });
  const [selectedDraftId, setSelectedDraftId] = useState("");
  const [slug, setSlug] = useState("");
  const [linkedNodeSlug, setLinkedNodeSlug] = useState("");
  const [title, setTitle] = useState("");
  const [bodyMd, setBodyMd] = useState("");
  const [metadataJson, setMetadataJson] = useState("{}");
  const [notice, setNotice] = useState<string | null>(null);

  const payload = state.status === "ready" ? state.payload : EMPTY_PAYLOAD;
  const selectedDraft = useMemo(
    () => payload.drafts.find((draft) => draft.id === selectedDraftId) ?? null,
    [payload.drafts, selectedDraftId],
  );

  const load = async () => {
    setState({ status: "loading" });
    try {
      const session = await getAdminSession();
      const nextPayload = await fetchNodeDrafts(session);
      setState({ status: "ready", payload: nextPayload });
      const nextSelected = selectedDraftId ||
        nextPayload.drafts[0]?.id ||
        "";
      setSelectedDraftId(nextSelected);
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setState({
        status: "error",
        message: apiError?.message ?? "Node drafts could not load.",
      });
    }
  };

  useEffect(() => {
    void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!selectedDraft) return;
    setSlug(selectedDraft.slug);
    setLinkedNodeSlug(selectedDraft.linked_node_slug ?? selectedDraft.slug);
    setTitle(selectedDraft.title);
    setBodyMd(selectedDraft.body_md);
    setMetadataJson(JSON.stringify(selectedDraft.metadata ?? {}, null, 2));
  }, [selectedDraft]);

  const createDraft = async () => {
    setNotice(null);
    const metadata = parseMetadata(metadataJson);
    if (!metadata) {
      setNotice("Metadata JSON is invalid.");
      return;
    }

    try {
      const session = await getAdminSession();
      const draft = await createNodeDraft(session, {
        slug,
        linked_node_slug: linkedNodeSlug,
        title,
        body_md: bodyMd,
        metadata,
      });
      setNotice(`Draft created: ${draft.title}`);
      setSelectedDraftId(draft.id);
      await load();
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setNotice(apiError?.message ?? "Node draft create failed.");
    }
  };

  const saveVersion = async () => {
    if (!selectedDraft) {
      setNotice("Select a draft first.");
      return;
    }
    setNotice(null);
    const metadata = parseMetadata(metadataJson);
    if (!metadata) {
      setNotice("Metadata JSON is invalid.");
      return;
    }

    try {
      const session = await getAdminSession();
      const result = await saveNodeDraftVersion(session, {
        id: selectedDraft.id,
        title,
        body_md: bodyMd,
        metadata,
        status: selectedDraft.status === "approved" ? "draft" : selectedDraft.status,
      });
      setNotice(`Version ${result.version.version_number} saved.`);
      await load();
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setNotice(apiError?.message ?? "Node draft save failed.");
    }
  };

  const requestApproval = async () => {
    if (!selectedDraft) {
      setNotice("Select a draft first.");
      return;
    }
    setNotice(null);
    try {
      const session = await getAdminSession();
      const result = await requestNodeDraftApproval(session, selectedDraft.id);
      setNotice(`Approval requested: ${result.approval.id}`);
      await load();
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setNotice(apiError?.message ?? "Approval request failed.");
    }
  };

  const markApproved = async () => {
    if (!selectedDraft) {
      setNotice("Select a draft first.");
      return;
    }
    setNotice(null);
    try {
      const session = await getAdminSession();
      await approveNodeDraft(session, selectedDraft.id);
      setNotice("Draft marked approved. It is still not app-visible.");
      await load();
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setNotice(apiError?.message ?? "Draft approval failed.");
    }
  };

  return (
    <section className="page-surface war-room-page">
      <div className="page-heading">
        <div>
          <span className="eyebrow">Product</span>
          <h1>Node Drafts</h1>
          <p>
            Create draft node content, version it, compare it to the current
            database stub, and gate any future publish step through approval.
          </p>
        </div>
        <span className="phase-pill ready">Phase 6</span>
      </div>

      <div className="status-row">
        <div className="icon-disc success">
          <ShieldCheck size={22} />
        </div>
        <div>
          <h2>Draft-only by ADR-002</h2>
          <p>{payload.source_of_truth}</p>
        </div>
      </div>

      {state.status === "error" && (
        <div className="notice danger">{state.message}</div>
      )}
      {notice && <div className="notice">{notice}</div>}

      <div className="split-grid">
        <div className="data-panel">
          <div className="panel-heading">
            <h2>Drafts</h2>
            <span>{payload.drafts.length}</span>
          </div>
          {payload.drafts.length === 0 ? (
            <div className="empty-state">No node drafts yet.</div>
          ) : (
            <div className="list-stack">
              {payload.drafts.map((draft) => (
                <button
                  key={draft.id}
                  type="button"
                  className={`list-row ${
                    selectedDraftId === draft.id ? "active" : ""
                  }`}
                  onClick={() => setSelectedDraftId(draft.id)}
                >
                  <strong>{draft.title}</strong>
                  <span>
                    {draft.slug} · {draft.status} · {draft.version_count ?? 0}
                    {" "}versions
                  </span>
                </button>
              ))}
            </div>
          )}
        </div>

        <div className="data-panel form-panel">
          <div className="panel-heading">
            <h2>{selectedDraft ? "Edit Draft" : "Create Draft"}</h2>
            <span>product.nodes.write</span>
          </div>
          <div className="form-grid">
            <label>
              Slug
              <input
                value={slug}
                onChange={(event) => setSlug(event.target.value)}
                placeholder="instruction-amenemope"
              />
            </label>
            <label>
              Linked published slug
              <input
                value={linkedNodeSlug}
                onChange={(event) => setLinkedNodeSlug(event.target.value)}
                placeholder="optional public.nodes slug"
              />
            </label>
            <label className="full-span">
              Title
              <input
                value={title}
                onChange={(event) => setTitle(event.target.value)}
              />
            </label>
            <label className="full-span">
              Body markdown
              <textarea
                value={bodyMd}
                onChange={(event) => setBodyMd(event.target.value)}
                rows={12}
              />
            </label>
            <label className="full-span">
              Metadata JSON
              <textarea
                value={metadataJson}
                onChange={(event) => setMetadataJson(event.target.value)}
                rows={5}
              />
            </label>
          </div>
          <div className="form-actions">
            <button type="button" onClick={() => void createDraft()}>
              <FileText size={16} />
              Create New Draft
            </button>
            <button
              type="button"
              className="secondary-button"
              onClick={() => void saveVersion()}
            >
              <Save size={16} />
              Save Version
            </button>
            <button
              type="button"
              className="secondary-button"
              onClick={() => void requestApproval()}
            >
              <Eye size={16} />
              Request Approval
            </button>
            <button
              type="button"
              className="secondary-button"
              onClick={() => void markApproved()}
            >
              Mark Approved
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
        </div>
      </div>

      {selectedDraft && (
        <div className="split-grid">
          <div className="data-panel">
            <div className="panel-heading">
              <h2>Draft Preview</h2>
              <span>{selectedDraft.status}</span>
            </div>
            <article className="markdown-view">
              <h3>{title}</h3>
              <pre>{bodyMd || "No draft body."}</pre>
            </article>
          </div>

          <div className="data-panel">
            <div className="panel-heading">
              <h2>Published Stub Diff</h2>
              <span>{selectedDraft.published_node?.slug ?? "none"}</span>
            </div>
            <article className="markdown-view">
              {selectedDraft.published_node ? (
                <>
                  <h3>{selectedDraft.published_node.title}</h3>
                  <pre>{selectedDraft.published_node.body_text}</pre>
                </>
              ) : (
                <p>No matching public.nodes row. This remains a standalone draft.</p>
              )}
            </article>
          </div>
        </div>
      )}

      {selectedDraft && (
        <div className="data-panel">
          <div className="panel-heading">
            <h2>Version History</h2>
            <span>{selectedDraft.versions?.length ?? 0}</span>
          </div>
          {selectedDraft.versions?.length ? (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Version</th>
                    <th>Title</th>
                    <th>Created</th>
                  </tr>
                </thead>
                <tbody>
                  {selectedDraft.versions.map((version) => (
                    <tr key={version.id}>
                      <td>{version.version_number}</td>
                      <td>{version.title}</td>
                      <td>{formatDate(version.created_at)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="empty-state">No versions yet.</div>
          )}
        </div>
      )}
    </section>
  );
}
