import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import type { AdminMe } from "../../lib/api";
import { setLocalDevAuthenticated, supabase } from "../../lib/supabase";
import {
  applyWindow,
  categoryLabel,
  dayGroups,
  dayHeading,
  DETAIL_CONCURRENCY,
  formatShortDate,
  formatTime,
  initials,
  ownerInitials,
  padCount,
  personSubtitle,
  relativeActivity,
  runWithConcurrency,
  timeZoneCaption,
  timeZoneOf,
  visiblePeople,
  type LedgerEvent,
  type LedgerFilter,
  type LedgerPerson,
  type LedgerSort,
} from "./ledger-model";
import { Icon, LedgerIconDefs } from "./LedgerIcons";
import {
  fetchActivityUserDetail,
  fetchActivityUsers,
  type ActivityUserSummary,
} from "./ledger-api";
import { SAMPLE_REFERENCE_DATE, samplePeople } from "./sample-people";

type Props = {
  admin: AdminMe;
  useSampleData?: boolean;
};

type DetailState = {
  events: LedgerEvent[] | null;
  loading: boolean;
  error: string | null;
};

function defaultOpenId(people: LedgerPerson[]): string | null {
  return people[0]?.id ?? null;
}

export function ActivityLedgerPage({
  admin,
  useSampleData = false,
}: Props) {
  const [query, setQuery] = useState("");
  const [days, setDays] = useState<7 | 30 | 90>(30);
  const [filter, setFilter] = useState<LedgerFilter>("all");
  const [sort, setSort] = useState<LedgerSort>("recent");
  const [open, setOpen] = useState<Set<string>>(() => new Set());
  const [olderOpen, setOlderOpen] = useState<Set<string>>(() => new Set());
  const [people, setPeople] = useState<LedgerPerson[]>([]);
  const [totalMatching, setTotalMatching] = useState(0);
  const [listLoading, setListLoading] = useState(true);
  const [listError, setListError] = useState<string | null>(null);
  const [details, setDetails] = useState<Record<string, DetailState>>({});
  const [now, setNow] = useState(() =>
    useSampleData ? SAMPLE_REFERENCE_DATE : new Date(),
  );
  const openRef = useRef(open);
  openRef.current = open;
  const seededOpen = useRef(false);
  const detailInFlight = useRef(new Set<string>());
  const detailCacheKey = useRef<number>(days);

  const loadSample = useCallback(() => {
    const reference = SAMPLE_REFERENCE_DATE;
    setNow(reference);
    const mapped = samplePeople().map((person) =>
      applyWindow(person, days, reference),
    );
    setPeople(mapped);
    setTotalMatching(mapped.length);
    setListLoading(false);
    setListError(null);
    if (!seededOpen.current) {
      const first = defaultOpenId(mapped);
      setOpen(first ? new Set([first]) : new Set());
      seededOpen.current = true;
    }
    const nextDetails: Record<string, DetailState> = {};
    for (const person of samplePeople()) {
      nextDetails[person.id] = {
        events: applyWindow(person, days, reference).events,
        loading: false,
        error: null,
      };
    }
    setDetails(nextDetails);
  }, [days]);

  const loadUsers = useCallback(async () => {
    if (useSampleData) {
      loadSample();
      return;
    }
    setListLoading(true);
    setListError(null);
    setNow(new Date());
    try {
      const payload = await fetchActivityUsers(days, 250);
      const mapped = payload.users.map(mapSummary);
      setPeople(mapped);
      setTotalMatching(payload.total_matching_users);
      if (!seededOpen.current) {
        const first = defaultOpenId(
          visiblePeople(mapped, { query: "", filter: "all", sort: "recent" }),
        );
        setOpen(first ? new Set([first]) : new Set());
        seededOpen.current = true;
      }
    } catch (error) {
      setListError(
        error instanceof Error ? error.message : "Failed to load users.",
      );
      setPeople([]);
      setTotalMatching(0);
    } finally {
      setListLoading(false);
    }
  }, [days, loadSample, useSampleData]);

  useEffect(() => {
    void loadUsers();
  }, [loadUsers]);

  const ensureDetail = useCallback(
    async (userId: string) => {
      if (useSampleData) return;
      if (detailCacheKey.current !== days) {
        detailCacheKey.current = days;
        detailInFlight.current.clear();
      }
      if (detailInFlight.current.has(userId)) return;
      detailInFlight.current.add(userId);
      setDetails((current) => ({
        ...current,
        [userId]: { events: null, loading: true, error: null },
      }));
      try {
        const payload = await fetchActivityUserDetail(userId, days);
        const events = (payload.timeline ?? []).map((row) => ({
          id: row.id,
          occurredAt: row.occurred_at,
          label: row.label,
          detail: detailFromFields(row.safe_fields),
          category: categoryLabel(row.category),
        }));
        setDetails((current) => ({
          ...current,
          [userId]: { events, loading: false, error: null },
        }));
      } catch (error) {
        setDetails((current) => ({
          ...current,
          [userId]: {
            events: null,
            loading: false,
            error:
              error instanceof Error
                ? error.message
                : "Failed to load activity.",
          },
        }));
      } finally {
        detailInFlight.current.delete(userId);
      }
    },
    [days, useSampleData],
  );

  useEffect(() => {
    if (useSampleData) return;
    for (const id of open) {
      void ensureDetail(id);
    }
  }, [ensureDetail, open, useSampleData]);

  useEffect(() => {
    if (useSampleData) return;
    detailInFlight.current.clear();
    detailCacheKey.current = days;
    setDetails({});
    setOlderOpen(new Set());
  }, [days, useSampleData]);

  const shown = useMemo(
    () => visiblePeople(people, { query, filter, sort }),
    [people, query, filter, sort],
  );
  const activeCount = people.filter((person) => person.eventCount > 0).length;
  const quietCount = people.length - activeCount;
  const allExpanded =
    shown.length > 0 && shown.every((person) => open.has(person.id));

  const toggleOpen = (id: string) => {
    setOpen((current) => {
      const next = new Set(current);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const toggleOlder = (id: string) => {
    setOlderOpen((current) => {
      const next = new Set(current);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const expandAll = async () => {
    if (allExpanded) {
      setOpen(new Set());
      return;
    }
    const ids = shown.map((person) => person.id);
    setOpen(new Set(ids));
    if (useSampleData) return;
    await runWithConcurrency(
      ids,
      DETAIL_CONCURRENCY,
      async (id) => {
        await ensureDetail(id);
      },
      (id) => openRef.current.has(id),
    );
  };

  const resetFilters = () => {
    setQuery("");
    setDays(30);
    setFilter("all");
    setSort("recent");
  };

  return (
    <>
      <LedgerIconDefs />
      <div className="topbar-wrap">
        <header className="topbar">
          <div className="brand" aria-label="ḥꜣw Admin">
            <span className="brand-word">ḥꜣw</span>
            <span className="brand-divider" />
            <div className="brand-context">
              <strong>Admin</strong>
              <span>A private view of your community</span>
            </div>
          </div>
          <div className="topbar-right">
            {useSampleData ? (
              <div className="preview-tag">Interactive prototype</div>
            ) : null}
            <div className="owner" title={admin.user.email ?? admin.user.id}>
              <div className="owner-copy">
                <strong>Founder view</strong>
                <span>{admin.user.email ?? admin.user.id}</span>
              </div>
              <button
                type="button"
                className="owner-avatar"
                aria-label="Sign out"
                title="Sign out"
                onClick={() => {
                  setLocalDevAuthenticated(false);
                  void supabase?.auth.signOut();
                  window.location.href = "/";
                }}
              >
                {ownerInitials(admin.user.email)}
              </button>
            </div>
          </div>
        </header>
      </div>

      <main className="page">
        <section className="intro">
          <div>
            <div className="eyebrow">The people inside ḥꜣw</div>
            <h1>
              Activity <em>ledger.</em>
            </h1>
            <p>
              One place for every person. Open a name to see what they've been
              doing, organized by day and time.
            </p>
          </div>
          <div className="intro-aside" aria-label="Account count">
            <span className="small-rule" />
            <span className="mini-metric">{padCount(totalMatching)}</span>
            <span className="mini-caption">
              {useSampleData ? "sample accounts" : "accounts"}
            </span>
          </div>
        </section>

        <section className="toolbar" aria-label="Activity controls">
          <label className="search" htmlFor="search-input">
            <Icon name="search-icon" className="ico ico-lg" />
            <input
              type="search"
              id="search-input"
              placeholder="Search people, emails or handles"
              autoComplete="off"
              value={query}
              onChange={(event) => setQuery(event.target.value.trimStart())}
            />
            <button
              type="button"
              id="clear-search"
              title="Clear search"
              aria-label="Clear search"
              className={query ? "is-visible" : undefined}
              onClick={() => setQuery("")}
            >
              <Icon name="close-icon" className="ico ico-sm" />
            </button>
          </label>
          <div
            className="select-shell"
            aria-hidden="true"
            title="This selector is available from the sort control below on smaller screens"
          >
            <select
              id="large-sort"
              aria-label="Sort accounts"
              value={sort}
              onChange={(event) => setSort(event.target.value as LedgerSort)}
            >
              <option value="recent">Most recent</option>
              <option value="name">Name A–Z</option>
              <option value="joined">Recently joined</option>
            </select>
            <Icon name="chevron-icon" className="ico ico-sm select-chevron" />
          </div>
          <div
            className="segmented"
            id="range-control"
            role="group"
            aria-label="Activity date range"
          >
            {[7, 30, 90].map((value) => (
              <button
                key={value}
                type="button"
                data-days={value}
                className={days === value ? "active" : undefined}
                aria-pressed={days === value}
                onClick={() => setDays(value as 7 | 30 | 90)}
              >
                {value} days
              </button>
            ))}
          </div>
        </section>

        <div className="subtoolbar">
          <div
            className="filter-list"
            role="group"
            aria-label="Filter account activity"
          >
            {(
              [
                ["all", "All people", people.length],
                ["active", "Active", activeCount],
                ["quiet", "No activity", quietCount],
              ] as const
            ).map(([key, label, count]) => (
              <button
                key={key}
                type="button"
                className={`filter-btn${filter === key ? " active" : ""}`}
                data-filter={key}
                aria-pressed={filter === key}
                onClick={() => setFilter(key)}
              >
                {label}{" "}
                <span className="filter-count">{padCount(count)}</span>
              </button>
            ))}
          </div>
          <div className="right-controls">
            <label className="sort-select" htmlFor="mobile-sort">
              Sort{" "}
              <select
                id="mobile-sort"
                aria-label="Sort users"
                value={sort}
                onChange={(event) => setSort(event.target.value as LedgerSort)}
              >
                <option value="recent">Last active</option>
                <option value="name">Name A–Z</option>
                <option value="joined">Recently joined</option>
              </select>
            </label>
            <button
              type="button"
              className="expand-all"
              id="expand-all"
              onClick={() => void expandAll()}
            >
              {allExpanded ? "Collapse all" : "Expand all"}
            </button>
          </div>
        </div>

        <div className="section-meta">
          <span id="showing-label" aria-live="polite">
            {padCount(shown.length)}{" "}
            {shown.length === 1 ? "person" : "people"} shown
          </span>
          <span>
            {useSampleData
              ? "Illustrative data · not live"
              : `${days}-day window`}
          </span>
        </div>

        {listLoading ? (
          <p className="ledger-status">Loading people…</p>
        ) : null}
        {listError ? (
          <p className="ledger-status error">{listError}</p>
        ) : null}

        <section id="nodes" className="nodes" aria-label="User activity nodes">
          {shown.length ? (
            shown.map((person) => (
              <PersonNode
                key={person.id}
                person={person}
                days={days}
                now={now}
                opened={open.has(person.id)}
                olderOpen={olderOpen.has(person.id)}
                detail={details[person.id]}
                onToggle={() => toggleOpen(person.id)}
                onToggleOlder={() => toggleOlder(person.id)}
              />
            ))
          ) : !listLoading ? (
            <div className="no-results">
              <Icon
                name="search-icon"
                className="ico ico-lg"
              />
              <h3>No people found.</h3>
              <p>
                Try a different search, activity filter, or date range.
              </p>
              <button type="button" id="reset-filters" onClick={resetFilters}>
                Reset filters
              </button>
            </div>
          ) : null}
        </section>

        <footer className="end-note">
          <div className="privacy">
            <Icon name="lock-icon" />
            <span>
              The live ledger is intended to show actions and times, not the
              contents of private journals, messages, or personal calendar
              entries.
              {useSampleData
                ? " This mockup uses fictitious people and sample events."
                : ""}
            </span>
          </div>
          <span className="copyright">ḥꜣw / Owner workspace</span>
        </footer>
      </main>
    </>
  );
}

function mapSummary(user: ActivityUserSummary): LedgerPerson {
  return {
    id: user.id,
    name: user.display_name,
    handle: user.handle ?? "",
    email: user.email ?? "",
    joined: user.created_at,
    timezone: user.timezone,
    lastEventAt: user.last_seen_at ?? user.last_event_at ?? null,
    lastEventLabel: user.last_event_label ?? null,
    eventCount: user.event_count,
    events: [],
  };
}

function detailFromFields(
  fields: Record<string, unknown> | null | undefined,
): string {
  if (!fields) return "";
  const parts: string[] = [];
  for (const key of [
    "node_title",
    "node_slug",
    "route",
    "surface",
    "source_surface",
    "entry_point",
    "presentation",
    "level",
    "orientation",
  ]) {
    const value = fields[key];
    if (typeof value === "string" && value.trim()) parts.push(value.trim());
  }
  return parts.join(" · ");
}

function PersonNode({
  person,
  days,
  now,
  opened,
  olderOpen,
  detail,
  onToggle,
  onToggleOlder,
}: {
  person: LedgerPerson;
  days: number;
  now: Date;
  opened: boolean;
  olderOpen: boolean;
  detail?: DetailState;
  onToggle: () => void;
  onToggleOlder: () => void;
}) {
  const zone = timeZoneOf(person.timezone);
  const events = detail?.events ?? person.events;
  const groups = dayGroups(events, zone);
  const visibleGroups = olderOpen ? groups : groups.slice(0, 2);
  const hasOlder = groups.length > 2;
  const subtitle = personSubtitle(person);

  return (
    <article className={`node${opened ? " open" : ""}`} data-user={person.id}>
      <button
        type="button"
        className="node-toggle"
        data-toggle={person.id}
        aria-expanded={opened}
        aria-controls={opened ? `node-body-${person.id}` : undefined}
        onClick={onToggle}
      >
        <span className="user-avatar" aria-hidden="true">
          {initials(person.name)}
        </span>
        <span className="identity">
          <span className="identity-title">{person.name}</span>
          <span className="identity-sub">{subtitle}</span>
        </span>
        <span className="last-activity">
          <span className="activity-time">
            {relativeActivity(person.lastEventAt, now, zone)}
          </span>
          <span className="activity-caption">Last recorded activity</span>
        </span>
        <span className="event-count">
          <strong>{padCount(person.eventCount)}</strong>
          <span>{person.eventCount === 1 ? "action" : "actions"}</span>
        </span>
        <span className="chevron" aria-hidden="true">
          <Icon name="chevron-icon" className="ico ico-lg" />
        </span>
      </button>
      {opened ? (
        <div className="node-body" id={`node-body-${person.id}`}>
          <div className="node-details">
            <span>
              <strong>Email</strong> {person.email || "—"}
            </span>
            <span className="dot-divider" aria-hidden="true" />
            <span>
              <strong>Joined</strong>{" "}
              {formatShortDate(new Date(person.joined), zone)}
            </span>
            <span className="dot-divider" aria-hidden="true" />
            <span>
              <strong>Timezone</strong> {timeZoneCaption(person.timezone)}
            </span>
          </div>
          <div className="timeline-heading">
            <h3>Daily activity</h3>
            <p>Newest first · Action metadata only</p>
          </div>
          {detail?.loading ? (
            <div className="empty-user">
              <Icon name="empty-icon" />
              <p>Loading activity…</p>
            </div>
          ) : null}
          {detail?.error ? (
            <div className="empty-user">
              <Icon name="empty-icon" />
              <p>{detail.error}</p>
            </div>
          ) : null}
          {!detail?.loading && !detail?.error ? (
            groups.length ? (
              <>
                {visibleGroups.map((group) => {
                  const sample = new Date(group.events[0].occurredAt);
                  const heading = dayHeading(group.key, sample, now, zone);
                  return (
                    <section
                      className="day"
                      aria-label={heading.secondary ?? heading.primary}
                      key={group.key}
                    >
                      <div className="day-head">
                        <div className="day-name">
                          <strong>{heading.primary}</strong>
                          {heading.secondary ? (
                            <span>{heading.secondary}</span>
                          ) : null}
                        </div>
                        <span className="day-count">
                          {group.events.length}{" "}
                          {group.events.length === 1 ? "action" : "actions"}
                        </span>
                      </div>
                      <div className="timeline">
                        {group.events.map((event) => (
                          <div
                            className="event"
                            key={event.id}
                            aria-label={`${event.label} at ${formatTime(new Date(event.occurredAt), zone)}`}
                          >
                            <div className="event-time">
                              {formatTime(new Date(event.occurredAt), zone)}
                            </div>
                            <span className="event-mark" aria-hidden="true" />
                            <div className="event-main">
                              <div className="event-title">{event.label}</div>
                              {event.detail ? (
                                <div className="event-sub">{event.detail}</div>
                              ) : null}
                            </div>
                            <span className="event-category">
                              {event.category}
                            </span>
                          </div>
                        ))}
                      </div>
                    </section>
                  );
                })}
                {hasOlder ? (
                  <button
                    className="older"
                    type="button"
                    data-older={person.id}
                    data-open={olderOpen}
                    aria-expanded={olderOpen}
                    onClick={onToggleOlder}
                  >
                    {olderOpen
                      ? "Hide earlier days"
                      : `Show ${groups.length - 2} earlier ${
                          groups.length - 2 === 1 ? "day" : "days"
                        }`}
                    <Icon name="chevron-icon" className="ico ico-sm" />
                  </button>
                ) : null}
              </>
            ) : (
              <div className="empty-user">
                <Icon name="empty-icon" />
                <p>
                  No recorded actions within the selected {days}-day window.
                  This doesn't necessarily mean the person hasn't used hꜣw.
                </p>
              </div>
            )
          ) : null}
        </div>
      ) : null}
    </article>
  );
}
