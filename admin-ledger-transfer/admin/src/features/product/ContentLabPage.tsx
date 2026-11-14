import {
  AlertTriangle,
  ChevronRight,
  ClipboardCheck,
  FileText,
  RefreshCcw,
  Save,
  Search,
  Send,
  Sparkles,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";

import {
  AdminApiError,
  deliverContentNudge,
  fetchContentContext,
  fetchContentEvaluations,
  fetchContentUsers,
  generateContentPreview,
  saveContentCritique,
  type ContentArtifact,
  type ContentContext,
  type ContentEvaluation,
  type ContentUserCard,
} from "../../lib/api";
import { formatDate } from "../../lib/format";
import { getAdminSession } from "../../lib/session";

const critiqueTagOptions = [
  "generic",
  "specific",
  "wrong_user",
  "good_evidence",
  "missing_nodes",
  "bad_tone",
  "ship_candidate",
  "needs_work",
];

const artifactLabels: Record<ContentArtifact, string> = {
  decan_reflection: "Reflection",
  decan_opening: "Decan opening",
  isfet_nudge: "Isfet nudge",
  maat_nudge: "Ma'at nudge",
  push_preview: "Push preview",
};

const maatFlowFixtureOptions = [
  { value: "", label: "Real evidence" },
  { value: "observed_only", label: "Weighing observed" },
  { value: "partial_only", label: "Weighing partial" },
  { value: "skipped_only", label: "Weighing skipped" },
  { value: "unobserved_only", label: "Weighing unobserved" },
  { value: "observed_plus_partial", label: "Weighing observed + partial" },
  { value: "partial_plus_skipped", label: "Weighing partial + skipped" },
];

function asString(value: unknown) {
  return typeof value === "string" ? value : "";
}

function asNumber(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === "object" && !Array.isArray(value);
}

function recordValue(value: unknown) {
  return isRecord(value) ? value : null;
}

function arrayOfRecords(value: unknown): Array<Record<string, unknown>> {
  return Array.isArray(value)
    ? value.filter((item): item is Record<string, unknown> =>
      !!item && typeof item === "object" && !Array.isArray(item)
    )
    : [];
}

function arrayOfStrings(value: unknown) {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === "string" && !!item.trim())
    : [];
}

function evidenceLines(context: ContentContext | null, preview: ContentEvaluation | null) {
  const contextLines = context?.evidence?.evidence_lines;
  const contextEvidence = arrayOfStrings(contextLines);
  if (contextEvidence.length) return contextEvidence;
  const previewLines = preview?.source_snapshot?.evidence_lines;
  return arrayOfStrings(previewLines);
}

function tagList(value: string) {
  return value.split(",").map((tag) => tag.trim()).filter(Boolean);
}

function nodeLabel(node: Record<string, unknown>) {
  return asString(node.title) || asString(node.slug) || "Node";
}

function scoreLabel(score: number | null | undefined) {
  if (typeof score !== "number" || !Number.isFinite(score)) return "unknown";
  return score > 0 ? `+${score.toFixed(1)}` : score.toFixed(1);
}

function formatDateOnly(value: string) {
  const match = value.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) return value;
  const [, year, month, day] = match;
  return new Intl.DateTimeFormat(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(new Date(Number(year), Number(month) - 1, Number(day)));
}

function humanizeToken(value: string) {
  const cleaned = value.replace(/[_-]/g, " ").trim();
  if (!cleaned) return "";
  return cleaned.charAt(0).toUpperCase() + cleaned.slice(1);
}

function tagLabel(tag: string) {
  const [rawKey, ...rawValue] = tag.split(":");
  const key = rawKey.trim().toLowerCase();
  const value = rawValue.join(":").trim();
  if (!value) return "";
  if (key === "kind") {
    if (value === "todo") return "To-do";
    if (value === "journal") return "Journal";
    if (value === "nutrition") return "Nutrition";
    return humanizeToken(value);
  }
  if (key === "state") {
    if (value === "done") return "Done";
    if (value === "partial") return "Partial";
    if (value === "skipped") return "Skipped";
    if (value === "pending") return "Pending";
    return humanizeToken(value);
  }
  return humanizeToken(value);
}

function parseEvidenceTags(value: string) {
  return value
    .split(",")
    .map((tag) => tag.trim())
    .filter((tag) => /^[a-z_]+:/i.test(tag))
    .map(tagLabel)
    .filter(Boolean);
}

function isTagSegment(value: string) {
  const tags = value.split(",").map((tag) => tag.trim()).filter(Boolean);
  return tags.length > 0 && tags.every((tag) => /^[a-z_]+:/i.test(tag));
}

function evidenceItemFromLine(line: string, index: number) {
  const parts = line.split(/\s+-\s+/).map((part) => part.trim()).filter(Boolean);
  const date = /^\d{4}-\d{2}-\d{2}$/.test(parts[0] ?? "") ? parts.shift() : "";
  const rawTitle = parts.shift() ?? line;
  const rawTags = parts.length && isTagSegment(parts[parts.length - 1])
    ? parts.pop() ?? ""
    : "";
  const detail = parts.join(" - ");
  const dateLabel = date ? formatDateOnly(date) : "";
  const tagMeta = parseEvidenceTags(rawTags);

  const todoMatch = rawTitle.match(/^(unchecked|done|partial|skipped|pending)\s+to-do:\s*(.+)$/i);
  if (todoMatch) {
    const [, state, title] = todoMatch;
    const stateLabel = humanizeToken(state === "unchecked" ? "pending" : state);
    return {
      id: `${line}-${index}`,
      title: `To-do: ${title}`,
      detail,
      meta: [dateLabel, "To-do", stateLabel, ...tagMeta]
        .filter((item, itemIndex, arr) => arr.indexOf(item) === itemIndex),
    };
  }

  const nutritionMatch = rawTitle.match(/^nutrition(?: plan)?:\s*(.+)$/i);
  if (nutritionMatch) {
    return {
      id: `${line}-${index}`,
      title: `Nutrition: ${nutritionMatch[1]}`,
      detail,
      meta: [dateLabel, "Nutrition", ...tagMeta]
        .filter((item, itemIndex, arr) => arr.indexOf(item) === itemIndex),
    };
  }

  return {
    id: `${line}-${index}`,
    title: rawTitle,
    detail,
    meta: [dateLabel, ...tagMeta]
      .filter((item, itemIndex, arr) => arr.indexOf(item) === itemIndex),
  };
}

function evidenceItemFromRecord(record: Record<string, unknown>, index: number) {
  const title = asString(record.title) || asString(record.name) || "User action";
  const date = asString(record.occurred_on) || asString(record.date);
  const tags = arrayOfStrings(record.tags).map(tagLabel).filter(Boolean);
  return {
    id: `${title}-${date}-${index}`,
    title,
    detail: asString(record.details) || asString(record.summary),
    meta: [
      date ? formatDateOnly(date) : "",
      ...tags,
    ].filter(Boolean),
  };
}

function evidenceItemsFromSnapshot(snapshot: Record<string, unknown>) {
  const lines = arrayOfStrings(snapshot.evidence_lines);
  if (lines.length) return lines.map(evidenceItemFromLine);
  return arrayOfRecords(snapshot.badges).map(evidenceItemFromRecord);
}

function evidenceCountLabel(snapshot: Record<string, unknown>, itemCount: number) {
  const count = asNumber(snapshot.evidence_count) || itemCount;
  const badgeCount = asNumber(snapshot.badge_count);
  if (!count && !badgeCount) return "0 evidence items";
  if (count === badgeCount || !badgeCount) {
    return `${count} evidence item${count === 1 ? "" : "s"}`;
  }
  return `${count} shown · ${badgeCount} total badge${badgeCount === 1 ? "" : "s"}`;
}

function EvidenceUsedList({ snapshot }: { snapshot: Record<string, unknown> }) {
  const items = evidenceItemsFromSnapshot(snapshot);
  const windowStart = asString(snapshot.window_start);
  const windowEnd = asString(snapshot.window_end);
  const windowText = windowStart && windowEnd
    ? `${formatDateOnly(windowStart)} -> ${formatDateOnly(windowEnd)}`
    : "";

  return (
    <div className="evidence-used-list">
      <div className="evidence-used-meta">
        <span>{evidenceCountLabel(snapshot, items.length)}</span>
        {windowText && <span>{windowText}</span>}
      </div>
      {items.length ? (
        <ul className="evidence-action-list">
          {items.map((item) => (
            <li key={item.id} className="evidence-action-item">
              <strong>{item.title}</strong>
              {item.meta.length > 0 && (
                <span className="evidence-action-meta">{item.meta.join(" · ")}</span>
              )}
              {item.detail && <p>{item.detail}</p>}
            </li>
          ))}
        </ul>
      ) : (
        <div className="evidence-empty-note">
          No user action names were used for this preview.
        </div>
      )}
    </div>
  );
}

function windowLabel(user: ContentUserCard | null, context: ContentContext | null) {
  const window = context?.window ?? user?.window;
  if (!window) return "Current decan";
  return `${window.start} -> ${window.end}`;
}

function previewIsNudge(preview: ContentEvaluation | null) {
  return preview?.artifact === "isfet_nudge" || preview?.artifact === "maat_nudge";
}

function previewRenderDiagnostics(preview: ContentEvaluation | null) {
  if (!preview) return null;
  const pushDiagnostics = recordValue(preview.push_preview?.render_diagnostics);
  if (pushDiagnostics) return pushDiagnostics;
  const guidance = recordValue(preview.source_snapshot?.guidance);
  return recordValue(guidance?.render_diagnostics);
}

function maatFlowDebugPayload(preview: ContentEvaluation | null) {
  if (!preview) return null;
  const guidance = recordValue(preview.source_snapshot?.guidance);
  const reflection = recordValue(guidance?.reflection);
  const outputControl = recordValue(reflection?.output_control);
  const pattern = recordValue(guidance?.maat_flow_decan_pattern) ??
    recordValue(reflection?.maat_flow_decan_pattern) ??
    recordValue(outputControl?.maatFlowDecanPattern) ??
    recordValue(outputControl?.maat_flow_decan_pattern);
  if (!pattern) return null;
  return {
    maat_flow_decan_pattern: pattern,
    maat_flow_do_not_say: guidance?.maat_flow_do_not_say ??
      reflection?.maat_flow_do_not_say ??
      outputControl?.maatFlowDoNotSay ??
      outputControl?.maat_flow_do_not_say ??
      [],
    maat_flow_evidence_metadata: guidance?.maat_flow_evidence_metadata ??
      reflection?.maat_flow_evidence_metadata ??
      outputControl?.maatFlowEvidenceMetadata ??
      outputControl?.maat_flow_evidence_metadata ??
      [],
    admin_preview_fixture: guidance?.admin_preview_fixture ??
      reflection?.admin_preview_fixture ??
      null,
  };
}

function diagnosticRow(label: string, value: unknown) {
  const text = asString(value);
  if (!text) return null;
  return (
    <span key={label}>
      <strong>{label}</strong>
      {text}
    </span>
  );
}

function RendererDiagnosticsPanel({
  diagnostics,
}: {
  diagnostics: Record<string, unknown> | null;
}) {
  if (!diagnostics) return null;
  const renderer = recordValue(diagnostics.renderer);
  const status = asString(diagnostics.status) || "unknown";
  const fallback = asString(renderer?.fallback_reason);
  const error = asString(renderer?.error);
  const engine = asString(renderer?.renderer);
  const model = asString(renderer?.model_version) || asString(renderer?.model_used);
  const rows = [
    diagnosticRow("surface", diagnostics.surface),
    diagnosticRow("engine", engine),
    diagnosticRow("model", model),
    diagnosticRow("case", diagnostics.case_key),
    diagnosticRow("offering", diagnostics.offering),
    diagnosticRow("example", diagnostics.example_id),
    diagnosticRow("fallback", fallback),
  ].filter(Boolean);

  return (
    <div className={`renderer-diagnostics renderer-diagnostics-${status}`}>
      <div className="renderer-diagnostics-heading">
        <strong>Renderer diagnostics</strong>
        <span>{status}</span>
      </div>
      <div className="renderer-diagnostics-grid">{rows}</div>
      {asString(diagnostics.diagnosis) && (
        <p>
          <strong>Diagnosis:</strong> {asString(diagnostics.diagnosis)}
        </p>
      )}
      {asString(diagnostics.concrete_action) && (
        <p>
          <strong>Action:</strong> {asString(diagnostics.concrete_action)}
        </p>
      )}
      {error && (
        <p className="renderer-error">
          <strong>Error:</strong> {error}
        </p>
      )}
      <details>
        <summary>Renderer payload</summary>
        <pre>{JSON.stringify(diagnostics, null, 2)}</pre>
      </details>
    </div>
  );
}

type PreviewError = {
  message: string;
  status?: number | null;
  code?: string | null;
  detail?: unknown;
  artifact?: ContentArtifact;
  fixture?: string | null;
  requireLlm?: boolean;
};

function PreviewErrorPanel({ error }: { error: PreviewError }) {
  return (
    <div className="preview-error-panel">
      <div className="renderer-diagnostics-heading">
        <strong>Preview generation failed</strong>
        <span>{error.status ?? "error"}</span>
      </div>
      <p>{error.message}</p>
      <div className="renderer-diagnostics-grid">
        {diagnosticRow("artifact", error.artifact)}
        {diagnosticRow("fixture", error.fixture || "real evidence")}
        {diagnosticRow("require LLM", error.requireLlm ? "true" : "false")}
        {diagnosticRow("code", error.code)}
      </div>
      {error.detail !== undefined && (
        <details>
          <summary>Error payload</summary>
          <pre>{JSON.stringify(error.detail, null, 2)}</pre>
        </details>
      )}
    </div>
  );
}

export function ContentLabPage() {
  const [users, setUsers] = useState<ContentUserCard[]>([]);
  const [selectedUser, setSelectedUser] = useState<ContentUserCard | null>(null);
  const [context, setContext] = useState<ContentContext | null>(null);
  const [evaluations, setEvaluations] = useState<ContentEvaluation[]>([]);
  const [preview, setPreview] = useState<ContentEvaluation | null>(null);
  const [previewError, setPreviewError] = useState<PreviewError | null>(null);
  const [query, setQuery] = useState("");
  const [mode, setMode] = useState<"active" | "needs_review" | "">("active");
  const [band, setBand] = useState("");
  const [rating, setRating] = useState(3);
  const [critiqueTags, setCritiqueTags] = useState("generic");
  const [critique, setCritique] = useState("");
  const [critiqueStatus, setCritiqueStatus] = useState<
    "reviewed" | "golden" | "needs_work" | "discarded"
  >("reviewed");
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [loadingUsers, setLoadingUsers] = useState(false);
  const [requireLlmPreview, setRequireLlmPreview] = useState(false);
  const [maatFlowFixture, setMaatFlowFixture] = useState("");

  const lines = evidenceLines(context, preview);
  const renderDiagnostics = previewRenderDiagnostics(preview);
  const maatFlowDebug = maatFlowDebugPayload(preview);
  const topNodes = context?.top_nodes?.length
    ? context.top_nodes
    : selectedUser?.top_nodes ?? [];
  const nodeActivity = context?.node_activity ?? [];
  const recentReflections = context?.recent.reflections ?? [];
  const recentDeliveries = context?.recent.deliveries ?? [];
  const maat = context?.maat ?? selectedUser?.maat;
  const recommendedNudge = context?.recommended_nudge ??
    selectedUser?.recommended_nudge ?? "maat_nudge";

  const selectedHistory = useMemo(
    () => evaluations.filter((row) =>
      !selectedUser || row.target_user_id === selectedUser.id
    ),
    [evaluations, selectedUser],
  );

  const loadUserDetail = async (user: ContentUserCard) => {
    setNotice(null);
    setBusy(true);
    setSelectedUser(user);
    setPreview(null);
    setPreviewError(null);
    try {
      const session = await getAdminSession();
      const [nextContext, rows] = await Promise.all([
        fetchContentContext(session, { target_user_id: user.id }),
        fetchContentEvaluations(session, user.id),
      ]);
      setContext(nextContext);
      setEvaluations(rows);
      setRating(3);
      setCritiqueTags("generic");
      setCritique("");
      setCritiqueStatus("reviewed");
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setContext(null);
      setNotice(apiError?.message ?? "User context could not load.");
    } finally {
      setBusy(false);
    }
  };

  const loadUsers = async (autoSelect = false) => {
    setNotice(null);
    setLoadingUsers(true);
    try {
      const session = await getAdminSession();
      const payload = await fetchContentUsers(session, {
        q: query.trim() || undefined,
        mode,
        band: band.trim() || undefined,
        limit: 100,
      });
      setUsers(payload.users);
      const refreshedSelected = selectedUser
        ? payload.users.find((user) => user.id === selectedUser.id) ?? null
        : null;
      if (refreshedSelected) setSelectedUser(refreshedSelected);
      if (autoSelect && !selectedUser && payload.users[0]) {
        void loadUserDetail(payload.users[0]);
      }
      if (!payload.users.length) {
        setSelectedUser(null);
        setContext(null);
      }
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setNotice(apiError?.message ?? "User list could not load.");
    } finally {
      setLoadingUsers(false);
    }
  };

  useEffect(() => {
    void loadUsers(true);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const runPreview = async (artifact: ContentArtifact) => {
    if (!selectedUser) return;
    setNotice(null);
    setPreviewError(null);
    setBusy(true);
    try {
      const session = await getAdminSession();
      const payload = await generateContentPreview(session, {
        target_user_id: selectedUser.id,
        artifact,
        require_llm: requireLlmPreview,
        maat_flow_fixture: artifact === "decan_reflection" && maatFlowFixture
          ? maatFlowFixture
          : undefined,
      });
      setPreview(payload.preview);
      if (!context) {
        setContext({
          profile: payload.context.profile,
          window: payload.context.window,
          decan_period_key: payload.preview.decan_period_key ?? "",
          maat: selectedUser.maat,
          recommended_nudge: selectedUser.recommended_nudge,
          top_nodes: payload.context.top_nodes,
          node_activity: [],
          evidence: payload.context.evidence,
          recent: { reflections: [], deliveries: [], evaluations: [] },
        });
      }
      setRating(payload.preview.rating ?? 3);
      setCritiqueTags(payload.preview.feedback_tags.join(", ") || "generic");
      setCritique(payload.preview.critique_md ?? "");
      setCritiqueStatus("reviewed");
      const rows = await fetchContentEvaluations(session, selectedUser.id);
      setEvaluations(rows);
      setNotice(`${artifactLabels[artifact]} preview generated. Nothing was delivered.`);
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      const message = apiError?.message ?? "Preview generation failed.";
      setPreview(null);
      setPreviewError({
        message,
        status: apiError?.status ?? null,
        code: apiError?.code ?? null,
        detail: apiError?.detail,
        artifact,
        fixture: artifact === "decan_reflection" ? maatFlowFixture || null : null,
        requireLlm: requireLlmPreview,
      });
      setNotice(message);
    } finally {
      setBusy(false);
    }
  };

  const saveCritique = async () => {
    if (!preview) {
      setNotice("Generate or select an evaluation before saving critique.");
      return;
    }
    setNotice(null);
    setBusy(true);
    try {
      const session = await getAdminSession();
      const saved = await saveContentCritique(session, {
        evaluation_id: preview.id,
        rating,
        feedback_tags: tagList(critiqueTags),
        critique_md: critique,
        status: critiqueStatus,
      });
      if (saved) setPreview(saved);
      if (selectedUser) {
        const rows = await fetchContentEvaluations(session, selectedUser.id);
        setEvaluations(rows);
      }
      setNotice("Critique saved to Content Lab history.");
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setNotice(apiError?.message ?? "Critique save failed.");
    } finally {
      setBusy(false);
    }
  };

  const deliverNudge = async () => {
    if (!preview || !selectedUser || !previewIsNudge(preview)) return;
    const confirmed = window.confirm(
      `Deliver this ${artifactLabels[preview.artifact]} to ${selectedUser.display_name} as active in-app guidance?`,
    );
    if (!confirmed) return;
    setNotice(null);
    setBusy(true);
    try {
      const session = await getAdminSession();
      const result = await deliverContentNudge(session, {
        evaluation_id: preview.id,
        target_user_id: selectedUser.id,
      });
      const [nextContext, rows] = await Promise.all([
        fetchContentContext(session, { target_user_id: selectedUser.id }),
        fetchContentEvaluations(session, selectedUser.id),
      ]);
      setContext(nextContext);
      setEvaluations(rows);
      await loadUsers(false);
      const deliveryId = asString(result.delivery?.id);
      setNotice(
        deliveryId
          ? `Nudge delivered as active in-app Ma'at guidance (${deliveryId.slice(0, 8)}). Open or refresh the app to fetch it.`
          : "Nudge delivered as active in-app Ma'at guidance. Open or refresh the app to fetch it.",
      );
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setNotice(apiError?.message ?? "Nudge delivery failed.");
    } finally {
      setBusy(false);
    }
  };

  const selectEvaluation = (evaluation: ContentEvaluation) => {
    setPreview(evaluation);
    setRating(evaluation.rating ?? 3);
    setCritiqueTags(evaluation.feedback_tags.join(", ") || "generic");
    setCritique(evaluation.critique_md ?? "");
    setCritiqueStatus(
      evaluation.status === "golden" ||
        evaluation.status === "needs_work" ||
        evaluation.status === "discarded"
        ? evaluation.status
        : "reviewed",
    );
  };

  return (
    <section className="page-surface war-room-page content-lab-page">
      <div className="page-heading">
        <div>
          <span className="eyebrow">Product</span>
          <h1>Content Lab</h1>
          <p>
            Browse users through their knowledge graph, generate current decan
            surfaces, review the evidence, and deliver only Ma'at/Isfet nudges
            when you explicitly choose to.
          </p>
        </div>
        <span className="phase-pill ready">Operator console</span>
      </div>

      {notice && <div className="notice">{notice}</div>}

      <div className="content-lab-toolbar data-panel">
        <label>
          <Search size={16} />
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            onKeyDown={(event) => {
              if (event.key === "Enter") void loadUsers(false);
            }}
            placeholder="Search name, handle, node, or user id"
          />
        </label>
        <select value={mode} onChange={(event) => setMode(event.target.value as typeof mode)}>
          <option value="active">Active this decan</option>
          <option value="needs_review">Needs review</option>
          <option value="">All users</option>
        </select>
        <select value={band} onChange={(event) => setBand(event.target.value)}>
          <option value="">All Ma'at bands</option>
          <option value="leaning_maat">leaning_maat</option>
          <option value="mixed">mixed</option>
          <option value="leaning_isfet">leaning_isfet</option>
          <option value="isfet_patterned">isfet_patterned</option>
          <option value="unknown">unknown</option>
        </select>
        <button type="button" onClick={() => void loadUsers(false)} disabled={loadingUsers}>
          <RefreshCcw size={16} />
          Refresh
        </button>
      </div>

      <div className="content-lab-shell">
        <div className="data-panel">
          <div className="panel-heading">
            <h2>User Graphs</h2>
            <span>{loadingUsers ? "loading" : `${users.length} users`}</span>
          </div>
          {users.length ? (
            <div className="user-card-grid">
              {users.map((user) => (
                <button
                  key={user.id}
                  type="button"
                  className={`user-graph-card${
                    selectedUser?.id === user.id ? " active" : ""
                  }`}
                  onClick={() => void loadUserDetail(user)}
                >
                  <span className="user-graph-card-title">{user.display_name}</span>
                  <span className="user-graph-card-subtitle">
                    {user.decan_label} · {user.timezone}
                  </span>
                  <span className={`maat-band-pill ${user.maat.band}`}>
                    {user.maat.band}
                  </span>
                  <span className="user-card-stat-row">
                    <strong>{scoreLabel(user.maat.score)}</strong>
                    <span>{user.maat.reflection_move}</span>
                    <span>{user.badge_count_this_decan} evidence</span>
                  </span>
                  <span className="node-chip-row">
                    {user.top_nodes.slice(0, 3).map((node, index) => (
                      <span key={`${user.id}-${asString(node.slug)}-${index}`}>
                        {nodeLabel(node)}
                      </span>
                    ))}
                    {!user.top_nodes.length && <span>No nodes yet</span>}
                  </span>
                  <span className="user-card-footer">
                    {user.has_pending_delivery
                      ? `${user.pending_delivery_count} pending`
                      : user.needs_review
                      ? "needs review"
                      : "ready"}
                    <ChevronRight size={14} />
                  </span>
                </button>
              ))}
            </div>
          ) : (
            <div className="empty-state">
              No users match this filter. Switch to all users or clear search.
            </div>
          )}
        </div>

        <div className="content-lab-detail">
          <div className="data-panel">
            <div className="panel-heading">
              <h2>{selectedUser?.display_name ?? "Select a user"}</h2>
              <span>{selectedUser ? windowLabel(selectedUser, context) : "-"}</span>
            </div>
            {selectedUser ? (
              <>
                <div className="maat-readout">
                  <div>
                    <span>Ma'at / Isfet</span>
                    <strong>{maat?.band ?? "unknown"}</strong>
                    <small>
                      move: {maat?.reflection_move ?? "unknown"} · axis:{" "}
                      {maat?.lead_axis ?? "none"}
                    </small>
                  </div>
                  <div className="balance-meter">
                    <span
                      style={{
                        width: `${Math.max(
                          8,
                          Math.min(100, 50 + asNumber(maat?.score) * 10),
                        )}%`,
                      }}
                    />
                  </div>
                  <div className="maat-readout-tags">
                    {(maat?.hard_gates ?? []).map((gate) => (
                      <span key={gate}>
                        <AlertTriangle size={12} />
                        {gate}
                      </span>
                    ))}
                    {!(maat?.hard_gates ?? []).length && <span>No hard gates</span>}
                  </div>
                </div>

                <div className="operator-actions">
                  <button
                    type="button"
                    onClick={() => void runPreview("decan_reflection")}
                    disabled={busy}
                  >
                    <Sparkles size={16} />
                    Generate reflection
                  </button>
                  <button
                    type="button"
                    onClick={() => void runPreview("decan_opening")}
                    disabled={busy}
                  >
                    <FileText size={16} />
                    Generate decan open
                  </button>
                  <button
                    type="button"
                    onClick={() => void runPreview(recommendedNudge)}
                    disabled={busy}
                  >
                    <ClipboardCheck size={16} />
                    Generate nudge
                  </button>
                  <label className="operator-select">
                    Weighing fixture
                    <select
                      value={maatFlowFixture}
                      onChange={(event) => setMaatFlowFixture(event.target.value)}
                    >
                      {maatFlowFixtureOptions.map((option) => (
                        <option key={option.value || "real"} value={option.value}>
                          {option.label}
                        </option>
                      ))}
                    </select>
                  </label>
                  <label className="operator-toggle">
                    <input
                      type="checkbox"
                      checked={requireLlmPreview}
                      onChange={(event) => setRequireLlmPreview(event.target.checked)}
                    />
                    LLM polish / experimental (cost-bearing)
                  </label>
                </div>

                <div className="detail-grid">
                  <div>
                    <h3>Knowledge Graph</h3>
                    <div className="node-chip-row expanded">
                      {topNodes.slice(0, 8).map((node, index) => (
                        <span key={`${asString(node.slug)}-${index}`}>
                          {nodeLabel(node)}
                        </span>
                      ))}
                      {!topNodes.length && <span>No graph nodes loaded.</span>}
                    </div>
                  </div>
                  <div>
                    <h3>This Decan Evidence</h3>
                    <div className="compact-evidence">
                      {lines.slice(0, 8).map((line, index) => (
                        <span key={`${line}-${index}`}>{line}</span>
                      ))}
                      {!lines.length && <span>No evidence lines loaded.</span>}
                    </div>
                  </div>
                  <div>
                    <h3>Recent Surfaces</h3>
                    <div className="compact-evidence">
                      {recentDeliveries.slice(0, 4).map((row) => (
                        <span key={asString(row.id)}>
                          {asString(row.kind)} · {asString(row.status)} ·{" "}
                          {asString(row.teaser_text)}
                        </span>
                      ))}
                      {recentReflections.slice(0, 2).map((row) => (
                        <span key={asString(row.id)}>
                          reflection · {asString(row.decan_start)} ·{" "}
                          {asString(row.preview)}
                        </span>
                      ))}
                      {!recentDeliveries.length && !recentReflections.length && (
                        <span>No recent surfaces loaded.</span>
                      )}
                    </div>
                  </div>
                  <div>
                    <h3>Node Activity</h3>
                    <div className="compact-evidence">
                      {nodeActivity.slice(0, 5).map((row) => (
                        <span key={asString(row.id)}>
                          {asString(row.node_title)} · {asString(row.snippet)}
                        </span>
                      ))}
                      {!nodeActivity.length && <span>No node notes loaded.</span>}
                    </div>
                  </div>
                </div>
              </>
            ) : (
              <div className="empty-state">Choose a user card to inspect their graph.</div>
            )}
          </div>

          <div className="split-grid">
            <div className="data-panel">
              <div className="panel-heading">
                <h2>Generated Preview</h2>
                <span>{preview?.model_version ?? "safe preview"}</span>
              </div>
              <article className="markdown-view content-lab-output">
                {preview ? (
                  <>
                    <div className="inline-meta">
                      <span>{artifactLabels[preview.artifact]}</span>
                      <span>{preview.status}</span>
                      <span>{formatDate(preview.created_at)}</span>
                    </div>
                    <p>{preview.generated_text}</p>
                    <RendererDiagnosticsPanel diagnostics={renderDiagnostics} />
                    {maatFlowDebug && (
                      <details>
                        <summary>Ma'at flow semantics</summary>
                        <pre>{JSON.stringify(maatFlowDebug, null, 2)}</pre>
                      </details>
                    )}
                    {previewIsNudge(preview) && (
                      <div className="nudge-delivery-panel">
                        <strong>Delivery</strong>
                        <span>
                          Preview is safe. Send creates an active in-app guidance row
                          for the selected user; scheduled cadence jobs handle push timing.
                        </span>
                        <button type="button" onClick={() => void deliverNudge()} disabled={busy}>
                          <Send size={16} />
                          Create in-app nudge
                        </button>
                      </div>
                    )}
                    <details>
                      <summary>Evidence used</summary>
                      <EvidenceUsedList snapshot={preview.source_snapshot} />
                    </details>
                    <details>
                      <summary>Push / delivery package</summary>
                      <pre>{JSON.stringify(preview.push_preview, null, 2)}</pre>
                    </details>
                  </>
                ) : previewError ? (
                  <PreviewErrorPanel error={previewError} />
                ) : (
                  <p>
                    Select a user, then generate reflection, decan opening, or the
                    recommended Ma'at/Isfet nudge.
                  </p>
                )}
              </article>
            </div>

            <div className="data-panel form-panel">
              <div className="panel-heading">
                <h2>Critique</h2>
                <span>operator log</span>
              </div>
              <div className="form-grid">
                <label>
                  Rating
                  <select
                    value={rating}
                    onChange={(event) => setRating(Number(event.target.value))}
                  >
                    <option value={1}>1 - broken</option>
                    <option value={2}>2 - weak</option>
                    <option value={3}>3 - usable</option>
                    <option value={4}>4 - strong</option>
                    <option value={5}>5 - golden</option>
                  </select>
                </label>
                <label>
                  Status
                  <select
                    value={critiqueStatus}
                    onChange={(event) =>
                      setCritiqueStatus(event.target.value as typeof critiqueStatus)}
                  >
                    <option value="reviewed">reviewed</option>
                    <option value="needs_work">needs work</option>
                    <option value="golden">golden</option>
                    <option value="discarded">discarded</option>
                  </select>
                </label>
                <label className="full-span">
                  Tags
                  <input
                    value={critiqueTags}
                    onChange={(event) => setCritiqueTags(event.target.value)}
                    placeholder={critiqueTagOptions.join(", ")}
                  />
                </label>
                <label className="full-span">
                  Notes
                  <textarea
                    value={critique}
                    onChange={(event) => setCritique(event.target.value)}
                    placeholder="What is wrong, what is right, and what should change next?"
                    rows={7}
                  />
                </label>
              </div>
              <div className="form-actions">
                <button
                  type="button"
                  onClick={() => void saveCritique()}
                  disabled={busy || !preview}
                >
                  <Save size={16} />
                  Save critique
                </button>
              </div>
            </div>
          </div>

          <div className="data-panel">
            <div className="panel-heading">
              <h2>Evaluation History</h2>
              <span>{selectedHistory.length}</span>
            </div>
            {selectedHistory.length ? (
              <div className="list-stack">
                {selectedHistory.map((evaluation) => (
                  <button
                    key={evaluation.id}
                    type="button"
                    className={`list-row${
                      preview?.id === evaluation.id ? " active" : ""
                    }`}
                    onClick={() => selectEvaluation(evaluation)}
                  >
                    <strong>{artifactLabels[evaluation.artifact]}</strong>
                    <span>
                      {evaluation.status} · rating {evaluation.rating ?? "-"} ·{" "}
                      {formatDate(evaluation.created_at)}
                    </span>
                  </button>
                ))}
              </div>
            ) : (
              <div className="empty-state">
                Generate something for this user and critiques will accumulate here.
              </div>
            )}
          </div>
        </div>
      </div>
    </section>
  );
}
