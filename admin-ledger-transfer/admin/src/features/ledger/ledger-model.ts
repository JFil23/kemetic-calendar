export const DETAIL_CONCURRENCY = 4;

export type LedgerSort = "recent" | "name" | "joined";
export type LedgerFilter = "all" | "active" | "quiet";

export type LedgerEvent = {
  id: string;
  occurredAt: string;
  label: string;
  detail: string;
  category: string;
};

export type LedgerPerson = {
  id: string;
  name: string;
  handle: string;
  email: string;
  joined: string;
  timezone: string | null;
  lastEventAt: string | null;
  lastEventLabel: string | null;
  eventCount: number;
  events: LedgerEvent[];
};

export type LedgerHistory = Omit<
  LedgerPerson,
  "lastEventAt" | "lastEventLabel" | "eventCount" | "events"
> & {
  history: LedgerEvent[];
};

const DETAIL_KEYS = [
  "route",
  "surface",
  "source_surface",
  "entry_point",
  "presentation",
  "level",
  "orientation",
] as const;

export function padCount(value: number): string {
  return String(value).padStart(2, "0");
}

export function initials(name: string): string {
  return name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? "")
    .join("");
}

export function ownerInitials(email: string | null): string {
  if (!email) return "ḥ";
  const local = email.split("@")[0] ?? "";
  const parts = local.split(/[._-]+/).filter(Boolean);
  if (parts.length >= 2) {
    return `${parts[0][0] ?? ""}${parts[1][0] ?? ""}`.toUpperCase();
  }
  return (local.slice(0, 2) || "ḥ").toUpperCase();
}

export function timeZoneOf(value: string | null | undefined): string {
  if (!value) return "UTC";
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: value }).format(0);
    return value;
  } catch {
    return "UTC";
  }
}

export function timeZoneCaption(value: string | null | undefined): string {
  const zone = timeZoneOf(value);
  const segments = zone.split("/");
  const place = (segments[segments.length - 1] ?? zone).replace(/_/g, " ");
  try {
    const abbrev = new Intl.DateTimeFormat("en-US", {
      timeZone: zone,
      timeZoneName: "short",
    })
      .formatToParts(new Date())
      .find((part) => part.type === "timeZoneName")?.value;
    return abbrev && abbrev !== place ? `${place} (${abbrev})` : place;
  } catch {
    return place;
  }
}

export function categoryLabel(category: string): string {
  return category.replace(/_/g, " ");
}

export function eventDetail(
  fields: Record<string, unknown> | null | undefined,
): string {
  if (!fields) return "";
  const parts: string[] = [];
  const title = fields.node_title;
  const slug = fields.node_slug;
  if (typeof title === "string" && title.trim()) parts.push(title.trim());
  else if (typeof slug === "string" && slug.trim()) parts.push(slug.trim());
  for (const key of DETAIL_KEYS) {
    const value = fields[key];
    if (typeof value === "string" && value.trim()) parts.push(value.trim());
  }
  return parts.join(" · ");
}

export function dayKey(date: Date, timeZone: string): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    timeZone,
  }).formatToParts(date);
  const year = parts.find((part) => part.type === "year")?.value ?? "0000";
  const month = parts.find((part) => part.type === "month")?.value ?? "01";
  const day = parts.find((part) => part.type === "day")?.value ?? "01";
  return `${year}-${month}-${day}`;
}

export function formatTime(date: Date, timeZone: string): string {
  return new Intl.DateTimeFormat("en-US", {
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
    timeZone,
  }).format(date);
}

export function formatFullDate(date: Date, timeZone: string): string {
  return new Intl.DateTimeFormat("en-US", {
    weekday: "long",
    month: "long",
    day: "numeric",
    timeZone,
  }).format(date);
}

export function formatShortDate(date: Date, timeZone: string): string {
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    timeZone,
  }).format(date);
}

function daysAgo(date: Date, now: Date, timeZone: string): number {
  const asUtcDay = (key: string) => Date.parse(`${key}T00:00:00Z`);
  return Math.max(
    0,
    Math.round(
      (asUtcDay(dayKey(now, timeZone)) - asUtcDay(dayKey(date, timeZone))) /
        86400000,
    ),
  );
}

export function inWindow(occurredAt: string, days: number, now: Date): boolean {
  const elapsed = now.getTime() - new Date(occurredAt).getTime();
  return elapsed >= 0 && elapsed <= days * 86400000;
}

export function relativeActivity(
  value: string | null,
  now: Date,
  timeZone: string,
): string {
  if (!value) return "Never";
  const date = new Date(value);
  const key = dayKey(date, timeZone);
  const today = dayKey(now, timeZone);
  const yesterday = dayKey(new Date(now.getTime() - 86400000), timeZone);
  if (key === today) return `Today, ${formatTime(date, timeZone)}`;
  if (key === yesterday) return "Yesterday";
  const ago = daysAgo(date, now, timeZone);
  return ago <= 7 ? `${ago} days ago` : formatShortDate(date, timeZone);
}

export function personSubtitle(person: LedgerPerson): string {
  const identity = person.handle || person.email || person.name;
  if (person.lastEventLabel) return `${identity} · ${person.lastEventLabel}`;
  const joined = formatShortDate(
    new Date(person.joined),
    timeZoneOf(person.timezone),
  );
  return `${identity} · Joined ${joined}`;
}

export function applyWindow(
  person: LedgerHistory,
  days: number,
  now: Date,
): LedgerPerson {
  const history = [...person.history].sort(
    (a, b) =>
      new Date(b.occurredAt).getTime() - new Date(a.occurredAt).getTime(),
  );
  const latest = history[0];
  return {
    id: person.id,
    name: person.name,
    handle: person.handle,
    email: person.email,
    joined: person.joined,
    timezone: person.timezone,
    lastEventAt: latest?.occurredAt ?? null,
    lastEventLabel: latest?.label ?? null,
    eventCount: history.filter((event) =>
      inWindow(event.occurredAt, days, now),
    ).length,
    events: history.filter((event) => inWindow(event.occurredAt, days, now)),
  };
}

export function visiblePeople(
  people: readonly LedgerPerson[],
  state: { query: string; filter: LedgerFilter; sort: LedgerSort },
): LedgerPerson[] {
  const query = state.query.trim().toLowerCase();
  const result = people.filter((person) => {
    if (state.filter === "active" && person.eventCount <= 0) return false;
    if (state.filter === "quiet" && person.eventCount > 0) return false;
    if (!query) return true;
    return [person.name, person.email, person.handle, person.id].some((value) =>
      value.toLowerCase().includes(query),
    );
  });
  result.sort((a, b) => {
    if (state.sort === "name") return a.name.localeCompare(b.name);
    if (state.sort === "joined") return b.joined.localeCompare(a.joined);
    const at = a.lastEventAt ? new Date(a.lastEventAt).getTime() : 0;
    const bt = b.lastEventAt ? new Date(b.lastEventAt).getTime() : 0;
    return bt - at;
  });
  return result;
}

export function dayGroups(
  events: readonly LedgerEvent[],
  timeZone: string,
): Array<{ key: string; events: LedgerEvent[] }> {
  const ordered = [...events].sort(
    (a, b) =>
      new Date(b.occurredAt).getTime() - new Date(a.occurredAt).getTime(),
  );
  const groups: Array<{ key: string; events: LedgerEvent[] }> = [];
  for (const event of ordered) {
    const key = dayKey(new Date(event.occurredAt), timeZone);
    const current = groups[groups.length - 1];
    if (!current || current.key !== key) groups.push({ key, events: [event] });
    else current.events.push(event);
  }
  return groups;
}

export function dayHeading(
  key: string,
  sample: Date,
  now: Date,
  timeZone: string,
): { primary: string; secondary: string | null } {
  const today = dayKey(now, timeZone);
  const yesterday = dayKey(new Date(now.getTime() - 86400000), timeZone);
  const full = formatFullDate(sample, timeZone);
  if (key === today || key === yesterday) {
    return { primary: key === today ? "Today" : "Yesterday", secondary: full };
  }
  return { primary: full, secondary: null };
}

export function createConcurrencyGate(limit: number) {
  let active = 0;
  const waiters: Array<() => void> = [];
  return {
    async acquire(stillWanted: () => boolean): Promise<boolean> {
      while (true) {
        if (!stillWanted()) {
          waiters.shift()?.();
          return false;
        }
        if (active < limit) {
          active += 1;
          return true;
        }
        await new Promise<void>((resolve) => {
          waiters.push(resolve);
        });
      }
    },
    release() {
      active = Math.max(0, active - 1);
      waiters.shift()?.();
    },
    active: () => active,
  };
}

export async function runWithConcurrency<T>(
  items: readonly T[],
  limit: number,
  worker: (item: T) => Promise<void>,
  stillWanted: (item: T) => boolean,
): Promise<void> {
  const gate = createConcurrencyGate(limit);
  await Promise.all(
    items.map(async (item) => {
      const allowed = await gate.acquire(() => stillWanted(item));
      if (!allowed) return;
      try {
        await worker(item);
      } finally {
        gate.release();
      }
    }),
  );
}
