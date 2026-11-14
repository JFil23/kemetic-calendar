import { FilePlus2, RefreshCcw, Search } from "lucide-react";
import type { FormEvent } from "react";
import { useEffect, useMemo, useState } from "react";
import { useSearchParams } from "react-router-dom";

import {
  AdminApiError,
  createArchiveEntry,
  fetchArchiveEntries,
  type ArchiveEntry,
} from "../../lib/api";
import { formatDate } from "../../lib/format";
import { getAdminSession } from "../../lib/session";

const NAMESPACES = [
  "research",
  "copy",
  "social",
  "suggestions",
  "codex",
  "chief_report",
  "brand",
  "technical",
  "source_notes",
  "ops",
];

type LoadState =
  | { status: "loading" }
  | { status: "ready"; entries: ArchiveEntry[] }
  | { status: "error"; message: string };

export function ArchivePage() {
  const [searchParams] = useSearchParams();
  const [query, setQuery] = useState("");
  const [namespace, setNamespace] = useState("");
  const [state, setState] = useState<LoadState>({ status: "loading" });
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [title, setTitle] = useState("");
  const [contentMd, setContentMd] = useState("");
  const [tags, setTags] = useState("");
  const [createError, setCreateError] = useState<string | null>(null);

  const loadEntries = async () => {
    setState({ status: "loading" });
    try {
      const session = await getAdminSession();
      const entries = await fetchArchiveEntries(session, {
        q: query,
        namespace,
      });
      setState({ status: "ready", entries });
      setSelectedId((current) =>
        searchParams.get("entry") ?? current ?? entries[0]?.id ?? null
      );
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setState({
        status: "error",
        message: apiError?.message ?? "Archive could not load.",
      });
    }
  };

  useEffect(() => {
    void loadEntries();
    // Query reload is intentionally explicit through the refresh button.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [namespace]);

  const entries = state.status === "ready" ? state.entries : [];
  const selected = useMemo(
    () => entries.find((entry) => entry.id === selectedId) ?? entries[0] ?? null,
    [entries, selectedId],
  );

  const submitEntry = async (event: FormEvent) => {
    event.preventDefault();
    setCreateError(null);
    try {
      const session = await getAdminSession();
      const entry = await createArchiveEntry(session, {
        namespace: namespace || "technical",
        title,
        content_md: contentMd,
        tags: tags.split(",").map((tag) => tag.trim()).filter(Boolean),
      });
      setTitle("");
      setContentMd("");
      setTags("");
      setSelectedId(entry.id);
      await loadEntries();
    } catch (error) {
      const apiError = error instanceof AdminApiError ? error : null;
      setCreateError(apiError?.message ?? "Archive entry could not be created.");
    }
  };

  return (
    <section className="page-surface">
      <div className="page-heading">
        <div>
          <span className="eyebrow">Infrastructure</span>
          <h1>Archive</h1>
          <p>Search, inspect, and manually create markdown memory entries.</p>
        </div>
        <button
          type="button"
          className="secondary-button"
          onClick={() => void loadEntries()}
        >
          <RefreshCcw size={16} />
          Refresh
        </button>
      </div>

      <div className="toolbar-row">
        <label>
          <Search size={16} />
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            onKeyDown={(event) => {
              if (event.key === "Enter") void loadEntries();
            }}
            placeholder="Search title, content, or tags"
          />
        </label>
        <select
          value={namespace}
          onChange={(event) => setNamespace(event.target.value)}
        >
          <option value="">All namespaces</option>
          {NAMESPACES.map((item) => (
            <option key={item} value={item}>{item}</option>
          ))}
        </select>
      </div>

      {state.status === "error" && (
        <div className="notice danger">{state.message}</div>
      )}

      <div className="split-grid archive-layout">
        <div className="data-panel">
          <div className="panel-heading">
            <h2>Entries</h2>
            <span>{state.status === "loading" ? "Loading" : entries.length}</span>
          </div>
          {entries.length === 0 ? (
            <div className="empty-state">No Archive entries match this view.</div>
          ) : (
            <div className="list-stack">
              {entries.map((entry) => (
                <button
                  key={entry.id}
                  type="button"
                  className={`list-row${selected?.id === entry.id ? " active" : ""}`}
                  onClick={() => setSelectedId(entry.id)}
                >
                  <strong>{entry.title}</strong>
                  <span>{entry.namespace} · {formatDate(entry.created_at)}</span>
                </button>
              ))}
            </div>
          )}
        </div>

        <div className="data-panel">
          <div className="panel-heading">
            <h2>{selected ? "Entry" : "No Entry Selected"}</h2>
            {selected && <span>{selected.namespace}</span>}
          </div>
          {selected ? (
            <article className="markdown-view">
              <h3>{selected.title}</h3>
              <p>{selected.tags?.join(", ") || "No tags"}</p>
              <pre>{selected.content_md}</pre>
            </article>
          ) : (
            <div className="empty-state">Select an entry to inspect it.</div>
          )}
        </div>
      </div>

      <form className="data-panel form-panel" onSubmit={submitEntry}>
        <div className="panel-heading">
          <h2>Manual Entry</h2>
          <span>archive.write</span>
        </div>
        <div className="form-grid">
          <label>
            Title
            <input value={title} onChange={(event) => setTitle(event.target.value)} />
          </label>
          <label>
            Tags
            <input
              value={tags}
              onChange={(event) => setTags(event.target.value)}
              placeholder="phase3, note"
            />
          </label>
          <label className="full-span">
            Markdown
            <textarea
              value={contentMd}
              onChange={(event) => setContentMd(event.target.value)}
              rows={8}
            />
          </label>
        </div>
        {createError && <div className="notice danger">{createError}</div>}
        <div className="form-actions">
          <button type="submit">
            <FilePlus2 size={16} />
            Create Entry
          </button>
        </div>
      </form>
    </section>
  );
}
