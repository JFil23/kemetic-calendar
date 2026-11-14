import { Bot, Play, RefreshCcw } from "lucide-react";
import { useEffect, useState } from "react";
import { Link } from "react-router-dom";

import {
  AdminApiError,
  fetchAgentRunPayload,
  fetchApprovals,
  fetchWarRoomSummary,
  runCopyAgent,
  runChiefOperatorAgent,
  runEchoAgent,
  runProductQaAgent,
  runResearchAgent,
  runSocialAgent,
  runSuggestUpdatesAgent,
  type AgentRun,
  type AgentSlug,
  type ArchiveEntry,
  type CodexTask,
  type Suggestion,
} from "../../lib/api";
import { formatDate, formatMoney } from "../../lib/format";
import { getAdminSession } from "../../lib/session";

type AgentConfig = {
  slug: AgentSlug;
  title: string;
  purpose: string;
  phase: string;
};

const AGENTS: Record<AgentSlug, AgentConfig> = {
  research: {
    slug: "research",
    title: "Research",
    purpose: "Generate cited research briefs into Archive.",
    phase: "Phase 4",
  },
  social: {
    slug: "social",
    title: "Social",
    purpose: "Generate draft-only social content for manual posting.",
    phase: "Phase 5",
  },
  copy: {
    slug: "copy",
    title: "Copy",
    purpose: "Generate copy variants into Archive.",
    phase: "Phase 4",
  },
  suggest_updates: {
    slug: "suggest_updates",
    title: "Suggest Updates",
    purpose: "Generate War Room-backed suggestions.",
    phase: "Phase 5",
  },
  product_qa: {
    slug: "product_qa",
    title: "Product QA",
    purpose: "Generate Codex-ready task drafts.",
    phase: "Phase 5",
  },
  chief_operator: {
    slug: "chief_operator",
    title: "Chief Operator",
    purpose: "Generate weekly operating reports.",
    phase: "Phase 5",
  },
};

type LoadState =
  | { status: "loading" }
  | { status: "ready"; runs: AgentRun[] }
  | { status: "error"; message: string };

export function OpsAgentPage({ agentSlug }: { agentSlug: AgentSlug }) {
  const agent = AGENTS[agentSlug];
  const isResearch = agentSlug === "research";
  const isCopy = agentSlug === "copy";
  const isSocial = agentSlug === "social";
  const isSuggest = agentSlug === "suggest_updates";
  const isProductQa = agentSlug === "product_qa";
  const isChief = agentSlug === "chief_operator";
  const [state, setState] = useState<LoadState>({ status: "loading" });
  const [message, setMessage] = useState(`Phase 3 echo test for ${agent.title}.`);
  const [notice, setNotice] = useState<string | null>(null);
  const [lastArchiveEntryId, setLastArchiveEntryId] = useState<string | null>(
    null,
  );
  const [researchTopic, setResearchTopic] = useState("");
  const [researchScope, setResearchScope] = useState<
    "kemet_trends" | "competitor" | "app_research" | "business" | "technical"
  >("kemet_trends");
  const [researchDepth, setResearchDepth] = useState<
    "quick" | "standard" | "deep"
  >("quick");
  const [researchUrls, setResearchUrls] = useState("");
  const [useWarRoomContext, setUseWarRoomContext] = useState(false);
  const [copySurface, setCopySurface] = useState<
    | "app_ui"
    | "landing"
    | "email"
    | "app_store"
    | "onboarding"
    | "node_intro"
    | "flow_description"
    | "support"
  >("onboarding");
  const [copyBrief, setCopyBrief] = useState("");
  const [copyTone, setCopyTone] = useState("clear, calm, and practical");
  const [copyLengthLimit, setCopyLengthLimit] = useState(240);
  const [socialPlatform, setSocialPlatform] = useState<
    "tiktok" | "threads" | "instagram" | "carousel" | "youtube_short"
  >("tiktok");
  const [socialTopic, setSocialTopic] = useState("");
  const [socialHook, setSocialHook] = useState("");
  const [socialTone, setSocialTone] = useState("grounded and useful");
  const [socialBatchSize, setSocialBatchSize] = useState(1);
  const [suggestLookback, setSuggestLookback] = useState<7 | 30 | 90>(7);
  const [suggestFocus, setSuggestFocus] = useState<
    "product" | "content" | "maat" | "onboarding" | "retention" | "bugs"
  >("product");
  const [suggestions, setSuggestions] = useState<Suggestion[]>([]);
  const [qaReport, setQaReport] = useState("");
  const [qaLikelyArea, setQaLikelyArea] = useState("");
  const [qaLinks, setQaLinks] = useState("");
  const [codexTasks, setCodexTasks] = useState<CodexTask[]>([]);
  const [chiefLookback, setChiefLookback] = useState<7 | 30 | 90>(7);
  const [latestReport, setLatestReport] = useState<ArchiveEntry | null>(null);
  const [pendingApprovals, setPendingApprovals] = useState(0);
  const [activeUsers, setActiveUsers] = useState<number | null>(null);

  const loadRuns = async () => {
    setState({ status: "loading" });
    try {
      const session = await getAdminSession();
      const payload = await fetchAgentRunPayload(session, agentSlug);
      setSuggestions(payload.suggestions ?? []);
      setCodexTasks(payload.codex_tasks ?? []);
      setLatestReport(payload.latest_report ?? null);
      if (isChief) {
        const [approvals, warRoom] = await Promise.all([
          fetchApprovals(session, "pending"),
          fetchWarRoomSummary(session, 7),
        ]);
        setPendingApprovals(approvals.length);
        setActiveUsers(warRoom.users?.active_period ?? null);
      }
      setState({ status: "ready", runs: payload.runs });
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setState({
        status: "error",
        message: apiError?.message ?? "Agent runs could not load.",
      });
    }
  };

  useEffect(() => {
    void loadRuns();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [agentSlug]);

  const runEcho = async () => {
    setNotice(null);
    try {
      const session = await getAdminSession();
      const result = await runEchoAgent(session, {
        agent_slug: agentSlug,
        message,
      });
      setNotice(
        `Echo run created Archive entry "${result.archive_entry.title}" for ${formatMoney(result.treasury.cost_usd)}.`,
      );
      setLastArchiveEntryId(result.archive_entry.id);
      await loadRuns();
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setNotice(apiError?.message ?? "Echo run failed.");
    }
  };

  const runResearch = async () => {
    setNotice(null);
    try {
      const session = await getAdminSession();
      const result = await runResearchAgent(session, {
        topic: researchTopic,
        scope: researchScope,
        depth: researchDepth,
        urls: researchUrls
          .split(/\n|,/)
          .map((url) => url.trim())
          .filter(Boolean),
        use_war_room_context: useWarRoomContext,
      });
      setNotice(
        `Research brief "${result.archive_entry.title}" saved to Archive for ${formatMoney(result.treasury.cost_usd)}.`,
      );
      setLastArchiveEntryId(result.archive_entry.id);
      await loadRuns();
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setNotice(apiError?.message ?? "Research agent failed.");
    }
  };

  const runCopy = async () => {
    setNotice(null);
    try {
      const session = await getAdminSession();
      const result = await runCopyAgent(session, {
        surface: copySurface,
        brief: copyBrief,
        tone: copyTone,
        length_limit: copyLengthLimit,
      });
      setNotice(
        `Copy variants "${result.archive_entry.title}" saved to Archive for ${formatMoney(result.treasury.cost_usd)}.`,
      );
      setLastArchiveEntryId(result.archive_entry.id);
      await loadRuns();
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setNotice(apiError?.message ?? "Copy agent failed.");
    }
  };

  const runSocial = async () => {
    setNotice(null);
    try {
      const session = await getAdminSession();
      const result = await runSocialAgent(session, {
        platform: socialPlatform,
        topic: socialTopic,
        hook: socialHook,
        tone: socialTone,
        batch_size: socialBatchSize,
      });
      setNotice(
        `Social drafts "${result.archive_entry.title}" saved to Archive for ${formatMoney(result.treasury.cost_usd)}.`,
      );
      setLastArchiveEntryId(result.archive_entry.id);
      await loadRuns();
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setNotice(apiError?.message ?? "Social agent failed.");
    }
  };

  const runSuggest = async () => {
    setNotice(null);
    try {
      const session = await getAdminSession();
      const result = await runSuggestUpdatesAgent(session, {
        lookback_days: suggestLookback,
        focus: suggestFocus,
      });
      setNotice(
        `Suggestions "${result.archive_entry.title}" saved to Archive for ${formatMoney(result.treasury.cost_usd)}.`,
      );
      setLastArchiveEntryId(result.archive_entry.id);
      await loadRuns();
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setNotice(apiError?.message ?? "Suggest Updates agent failed.");
    }
  };

  const runProductQa = async () => {
    setNotice(null);
    try {
      const session = await getAdminSession();
      const result = await runProductQaAgent(session, {
        report: qaReport,
        likely_area: qaLikelyArea,
        links: qaLinks.split(/\n|,/).map((url) => url.trim()).filter(Boolean),
      });
      setNotice(
        `Codex task "${result.archive_entry.title}" saved to Archive for ${formatMoney(result.treasury.cost_usd)}.`,
      );
      setLastArchiveEntryId(result.archive_entry.id);
      await loadRuns();
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setNotice(apiError?.message ?? "Product QA agent failed.");
    }
  };

  const runChief = async () => {
    setNotice(null);
    try {
      const session = await getAdminSession();
      const result = await runChiefOperatorAgent(session, {
        lookback_days: chiefLookback,
      });
      setNotice(
        `Chief report "${result.archive_entry.title}" saved to Archive for ${formatMoney(result.treasury.cost_usd)}.`,
      );
      setLastArchiveEntryId(result.archive_entry.id);
      await loadRuns();
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setNotice(apiError?.message ?? "Chief Operator agent failed.");
    }
  };

  const runs = state.status === "ready" ? state.runs : [];

  return (
    <section className="page-surface">
      <div className="page-heading">
        <div>
          <span className="eyebrow">Ops</span>
          <h1>{agent.title}</h1>
          <p>{agent.purpose}</p>
        </div>
        <span className="phase-pill ready">
          {isResearch || isCopy ? "Phase 4" : "Phase 5"}
        </span>
      </div>

      <div className="status-row">
        <div className="icon-disc success">
          <Bot size={22} />
        </div>
        <div>
          <h2>
            Drafts only
          </h2>
          <p>
            This agent writes drafts, logs Treasury cost, and does not mutate
            production content or perform external actions.
          </p>
        </div>
      </div>

      {isChief && (
        <div className="kpi-grid">
          <div className="kpi-card">
            <div>
              <span>Active users</span>
              <strong>{activeUsers ?? "-"}</strong>
            </div>
            <Bot size={22} />
            <p>7 day War Room signal.</p>
          </div>
          <div className="kpi-card">
            <div>
              <span>Pending approvals</span>
              <strong>{pendingApprovals}</strong>
            </div>
            <Bot size={22} />
            <p>Approval inbox items waiting on a decision.</p>
          </div>
          <div className="kpi-card">
            <div>
              <span>Latest report</span>
              <strong>{latestReport ? "1" : "0"}</strong>
            </div>
            <Bot size={22} />
            <p>{latestReport?.title ?? "No report yet."}</p>
          </div>
        </div>
      )}

      <div className="data-panel form-panel">
        <div className="panel-heading">
          <h2>
            {isResearch
              ? "Run Research"
              : isCopy
                ? "Run Copy"
                : isSocial
                  ? "Run Social"
                  : isSuggest
                    ? "Run Suggest Updates"
                    : isProductQa
                      ? "Generate Codex Task"
                      : isChief
                        ? "Generate Weekly Report"
                        : "Run Echo Test"}
          </h2>
          <span>ops.run</span>
        </div>
        {isResearch ? (
          <div className="form-grid">
            <label>
              Topic
              <input
                value={researchTopic}
                onChange={(event) => setResearchTopic(event.target.value)}
                placeholder="Kemetic wellness trend scan"
              />
            </label>
            <label>
              Scope
              <select
                value={researchScope}
                onChange={(event) =>
                  setResearchScope(event.target.value as typeof researchScope)}
              >
                <option value="kemet_trends">kemet_trends</option>
                <option value="competitor">competitor</option>
                <option value="app_research">app_research</option>
                <option value="business">business</option>
                <option value="technical">technical</option>
              </select>
            </label>
            <label>
              Depth
              <select
                value={researchDepth}
                onChange={(event) =>
                  setResearchDepth(event.target.value as typeof researchDepth)}
              >
                <option value="quick">quick</option>
                <option value="standard">standard</option>
                <option value="deep">deep</option>
              </select>
            </label>
            <label className="check-label">
              <input
                type="checkbox"
                checked={useWarRoomContext}
                onChange={(event) => setUseWarRoomContext(event.target.checked)}
              />
              Use War Room context
            </label>
            <label className="full-span">
              Optional URLs
              <textarea
                value={researchUrls}
                onChange={(event) => setResearchUrls(event.target.value)}
                placeholder="https://example.com/source"
                rows={4}
              />
            </label>
          </div>
        ) : isCopy ? (
          <div className="form-grid">
            <label>
              Surface
              <select
                value={copySurface}
                onChange={(event) =>
                  setCopySurface(event.target.value as typeof copySurface)}
              >
                <option value="app_ui">app_ui</option>
                <option value="landing">landing</option>
                <option value="email">email</option>
                <option value="app_store">app_store</option>
                <option value="onboarding">onboarding</option>
                <option value="node_intro">node_intro</option>
                <option value="flow_description">flow_description</option>
                <option value="support">support</option>
              </select>
            </label>
            <label>
              Length limit
              <input
                type="number"
                min={0}
                value={copyLengthLimit}
                onChange={(event) =>
                  setCopyLengthLimit(Number(event.target.value))}
              />
            </label>
            <label className="full-span">
              Brief
              <textarea
                value={copyBrief}
                onChange={(event) => setCopyBrief(event.target.value)}
                rows={5}
              />
            </label>
            <label className="full-span">
              Tone
              <input
                value={copyTone}
                onChange={(event) => setCopyTone(event.target.value)}
              />
            </label>
          </div>
        ) : isSocial ? (
          <div className="form-grid">
            <label>
              Platform
              <select
                value={socialPlatform}
                onChange={(event) =>
                  setSocialPlatform(event.target.value as typeof socialPlatform)}
              >
                <option value="tiktok">TikTok</option>
                <option value="threads">Threads</option>
                <option value="instagram">Instagram</option>
                <option value="carousel">Carousel</option>
                <option value="youtube_short">YouTube Short</option>
              </select>
            </label>
            <label>
              Batch size
              <input
                type="number"
                min={1}
                max={5}
                value={socialBatchSize}
                onChange={(event) =>
                  setSocialBatchSize(Number(event.target.value))}
              />
            </label>
            <label className="full-span">
              Topic / campaign
              <input
                value={socialTopic}
                onChange={(event) => setSocialTopic(event.target.value)}
              />
            </label>
            <label className="full-span">
              Hook
              <input
                value={socialHook}
                onChange={(event) => setSocialHook(event.target.value)}
              />
            </label>
            <label className="full-span">
              Tone
              <input
                value={socialTone}
                onChange={(event) => setSocialTone(event.target.value)}
              />
            </label>
          </div>
        ) : isSuggest ? (
          <div className="form-grid">
            <label>
              Lookback
              <select
                value={suggestLookback}
                onChange={(event) =>
                  setSuggestLookback(Number(event.target.value) as 7 | 30 | 90)}
              >
                <option value={7}>7 days</option>
                <option value={30}>30 days</option>
                <option value={90}>90 days</option>
              </select>
            </label>
            <label>
              Focus
              <select
                value={suggestFocus}
                onChange={(event) =>
                  setSuggestFocus(event.target.value as typeof suggestFocus)}
              >
                <option value="product">product</option>
                <option value="content">content</option>
                <option value="maat">maat</option>
                <option value="onboarding">onboarding</option>
                <option value="retention">retention</option>
                <option value="bugs">bugs</option>
              </select>
            </label>
          </div>
        ) : isProductQa ? (
          <div className="form-grid">
            <label className="full-span">
              Bug / feature / observation
              <textarea
                value={qaReport}
                onChange={(event) => setQaReport(event.target.value)}
                rows={6}
              />
            </label>
            <label>
              Likely area
              <input
                value={qaLikelyArea}
                onChange={(event) => setQaLikelyArea(event.target.value)}
              />
            </label>
            <label>
              Links
              <input
                value={qaLinks}
                onChange={(event) => setQaLinks(event.target.value)}
                placeholder="Optional URLs"
              />
            </label>
          </div>
        ) : isChief ? (
          <div className="form-grid">
            <label>
              Lookback
              <select
                value={chiefLookback}
                onChange={(event) =>
                  setChiefLookback(Number(event.target.value) as 7 | 30 | 90)}
              >
                <option value={7}>7 days</option>
                <option value={30}>30 days</option>
                <option value={90}>90 days</option>
              </select>
            </label>
          </div>
        ) : (
          <div className="form-grid">
            <label className="full-span">
              Message
              <textarea
                value={message}
                onChange={(event) => setMessage(event.target.value)}
                rows={4}
              />
            </label>
          </div>
        )}
        {notice && <div className="notice">{notice}</div>}
        {lastArchiveEntryId && (
          <div className="notice">
            <Link to={`/infrastructure/archive?entry=${lastArchiveEntryId}`}>
              Open Archive entry
            </Link>
          </div>
        )}
        <div className="form-actions">
          <button
            type="button"
            onClick={() =>
              void (isResearch
                ? runResearch()
                : isCopy
                  ? runCopy()
                  : isSocial
                    ? runSocial()
                    : isSuggest
                      ? runSuggest()
                      : isProductQa
                        ? runProductQa()
                        : isChief
                          ? runChief()
                          : runEcho())}
          >
            <Play size={16} />
            {isResearch
              ? "Run Research"
              : isCopy
                ? "Run Copy"
                : isSocial
                  ? "Run Social"
                  : isSuggest
                    ? "Run Suggest Updates"
                    : isProductQa
                      ? "Generate Codex Task"
                      : isChief
                        ? "Generate Report"
                        : "Run Echo Test"}
          </button>
          <button
            type="button"
            className="secondary-button"
            onClick={() => void loadRuns()}
          >
            <RefreshCcw size={16} />
            Refresh Runs
          </button>
        </div>
      </div>

      {isSuggest && (
        <div className="data-panel">
          <div className="panel-heading">
            <h2>Suggestions Kanban</h2>
            <span>{suggestions.length}</span>
          </div>
          <div className="kanban-grid">
            {["new", "triaged", "approved", "done", "wontfix"].map((column) => (
              <div key={column} className="kanban-column">
                <h3>{column}</h3>
                {suggestions.filter((item) => item.status === column).length ===
                    0
                  ? <p>No items.</p>
                  : suggestions
                    .filter((item) => item.status === column)
                    .map((item) => (
                      <div key={item.id} className="kanban-card">
                        <strong>{item.title}</strong>
                        <span>{item.category} · {item.priority}</span>
                      </div>
                    ))}
              </div>
            ))}
          </div>
        </div>
      )}

      {isProductQa && codexTasks.length > 0 && (
        <div className="data-panel">
          <div className="panel-heading">
            <h2>Codex Tasks</h2>
            <span>{codexTasks.length}</span>
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Task</th>
                  <th>Status</th>
                  <th>Prompt</th>
                  <th>Created</th>
                </tr>
              </thead>
              <tbody>
                {codexTasks.map((task) => (
                  <tr key={task.id}>
                    <td>{task.title}</td>
                    <td>{task.status}</td>
                    <td>
                      <button
                        type="button"
                        className="secondary-button"
                        onClick={() =>
                          void navigator.clipboard?.writeText(
                            task.prompt_md ?? task.spec_md,
                          )}
                      >
                        Copy prompt
                      </button>
                    </td>
                    <td>{formatDate(task.created_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {isChief && latestReport && (
        <div className="data-panel">
          <div className="panel-heading">
            <h2>Latest Report</h2>
            <Link to={`/infrastructure/archive?entry=${latestReport.id}`}>
              Open in Archive
            </Link>
          </div>
          <article className="markdown-view">
            <h3>{latestReport.title}</h3>
            <pre>{latestReport.content_md}</pre>
          </article>
        </div>
      )}

      {state.status === "error" && (
        <div className="notice danger">{state.message}</div>
      )}

      <div className="data-panel">
        <div className="panel-heading">
          <h2>Run History</h2>
          <span>{state.status === "loading" ? "Loading" : runs.length}</span>
        </div>
        {runs.length === 0 ? (
          <div className="empty-state">No runs for this agent yet.</div>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Status</th>
                  <th>Model</th>
                  <th>Summary</th>
                  <th>Archive</th>
                  <th>Duration</th>
                  <th>Created</th>
                </tr>
              </thead>
              <tbody>
                {runs.map((run) => (
                  <tr key={run.id}>
                    <td>{run.status}</td>
                    <td>{run.model}</td>
                    <td>{run.output_summary ?? "No summary"}</td>
                    <td>
                      {run.archive_entry_id ? (
                        <Link to={`/infrastructure/archive?entry=${run.archive_entry_id}`}>
                          Open
                        </Link>
                      ) : (
                        "-"
                      )}
                    </td>
                    <td>{run.duration_ms ?? 0} ms</td>
                    <td>{formatDate(run.created_at)}</td>
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
