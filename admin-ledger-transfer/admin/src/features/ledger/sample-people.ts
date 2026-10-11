import type { LedgerEvent, LedgerHistory } from "./ledger-model";

function history(
  id: string,
  rows: Array<[string, string, string, string]>,
): LedgerEvent[] {
  return rows.map((row, index) => ({
    id: `${id}-${index}`,
    occurredAt: row[0],
    label: row[1],
    detail: row[2],
    category: row[3],
  }));
}

const zone = "America/Los_Angeles";

export const SAMPLE_REFERENCE_DATE = new Date("2026-10-10T18:00:00-07:00");

export function samplePeople(): LedgerHistory[] {
  return [
    {
      id: "e1",
      name: "Amara Ellis",
      handle: "amara.ellis",
      email: "amara@example.com",
      joined: "2026-09-14T12:00:00-07:00",
      timezone: zone,
      history: history("e1", [
        ["2026-10-10T17:31:00-07:00", "Completed a flow event", "The Reading House · Day 4", "Flows"],
        ["2026-10-10T17:22:00-07:00", "Saved a journal entry", "Entry saved · private text hidden", "Journal"],
        ["2026-10-10T17:18:00-07:00", "Joined a group flow", "The Reading House", "Together"],
        ["2026-10-10T17:15:00-07:00", "Opened a flow", "The Reading House", "Flows"],
        ["2026-10-10T17:12:00-07:00", "Opened ḥꜣw", "App resumed", "App"],
        ["2026-10-09T19:06:00-07:00", "Liked a flow post", "Feed · public post", "Community"],
        ["2026-10-09T18:44:00-07:00", "Opened the Calendar", "Month view", "Calendar"],
        ["2026-10-09T18:40:00-07:00", "Opened ḥꜣw", "App launched", "App"],
        ["2026-10-07T08:35:00-07:00", "Saved a flow", "Follow the Sky", "Flows"],
        ["2026-10-07T08:21:00-07:00", "Visited the Library", "Learning nodes", "Library"],
        ["2026-10-07T08:14:00-07:00", "Opened ḥꜣw", "App launched", "App"],
        ["2026-09-28T21:23:00-07:00", "Completed a flow event", "The Offering Table", "Flows"],
      ]),
    },
    {
      id: "e2",
      name: "Malik Jordan",
      handle: "malik.j",
      email: "malik@example.com",
      joined: "2026-09-28T12:00:00-07:00",
      timezone: zone,
      history: history("e2", [
        ["2026-10-10T14:42:00-07:00", "Created a flow", "Morning Groundwork", "Flows"],
        ["2026-10-10T14:28:00-07:00", "Opened Flow Studio", "Started creating a flow", "Flows"],
        ["2026-10-10T14:26:00-07:00", "Opened ḥꜣw", "App launched", "App"],
        ["2026-10-08T10:38:00-07:00", "Followed another user", "New mutual connection", "Community"],
        ["2026-10-08T10:34:00-07:00", "Visited the Feed", "Discovery surface", "Community"],
        ["2026-10-08T10:31:00-07:00", "Opened ḥꜣw", "App launched", "App"],
        ["2026-10-03T13:24:00-07:00", "Completed onboarding", "Account setup", "Onboarding"],
      ]),
    },
    {
      id: "e3",
      name: "Nia Robinson",
      handle: "nia.reads",
      email: "nia@example.com",
      joined: "2026-09-01T12:00:00-07:00",
      timezone: zone,
      history: history("e3", [
        ["2026-10-09T21:16:00-07:00", "Commented on a flow post", "The Reading House · post comment", "Community"],
        ["2026-10-09T21:10:00-07:00", "Viewed a group flow", "The Reading House", "Together"],
        ["2026-10-09T21:07:00-07:00", "Opened ḥꜣw", "App launched", "App"],
        ["2026-10-05T12:29:00-07:00", "Saved a journal entry", "Entry saved · private text hidden", "Journal"],
        ["2026-10-05T12:21:00-07:00", "Visited the Library", "The Djed", "Library"],
        ["2026-09-25T18:56:00-07:00", "Joined a group flow", "The Reading House", "Together"],
      ]),
    },
    {
      id: "e4",
      name: "Leila Hassan",
      handle: "leila.h",
      email: "leila@example.com",
      joined: "2026-10-01T12:00:00-07:00",
      timezone: zone,
      history: history("e4", [
        ["2026-10-08T07:56:00-07:00", "Added a calendar event", "Event details hidden", "Calendar"],
        ["2026-10-08T07:51:00-07:00", "Opened the Planner", "Today view", "Planner"],
        ["2026-10-08T07:47:00-07:00", "Opened ḥꜣw", "App launched", "App"],
        ["2026-10-04T20:37:00-07:00", "Started a flow", "Follow the Sky", "Flows"],
        ["2026-10-04T20:31:00-07:00", "Opened ḥꜣw", "App launched", "App"],
        ["2026-10-01T11:33:00-07:00", "Created account", "Joined ḥꜣw", "Onboarding"],
      ]),
    },
    {
      id: "e5",
      name: "David Okoye",
      handle: "david.o",
      email: "david@example.com",
      joined: "2026-08-19T12:00:00-07:00",
      timezone: zone,
      history: history("e5", [
        ["2026-10-06T18:22:00-07:00", "Marked a planner task complete", "One task completed", "Planner"],
        ["2026-10-06T18:14:00-07:00", "Opened ḥꜣw", "App launched", "App"],
        ["2026-09-27T16:52:00-07:00", "Saved a flow", "The Offering Table", "Flows"],
        ["2026-09-17T09:11:00-07:00", "Viewed a Library node", "Ma’at", "Library"],
      ]),
    },
    {
      id: "e6",
      name: "Jaden Torres",
      handle: "jaden.torres",
      email: "jaden@example.com",
      joined: "2026-09-20T12:00:00-07:00",
      timezone: zone,
      history: history("e6", [
        ["2026-10-04T16:09:00-07:00", "Opened the Feed", "Community feed", "Community"],
        ["2026-10-04T16:02:00-07:00", "Opened ḥꜣw", "App launched", "App"],
        ["2026-09-25T08:12:00-07:00", "Completed onboarding", "Account setup", "Onboarding"],
      ]),
    },
    {
      id: "e7",
      name: "Kayla Brooks",
      handle: "kayla.b",
      email: "kayla@example.com",
      joined: "2026-09-24T12:00:00-07:00",
      timezone: zone,
      history: history("e7", [
        ["2026-09-30T09:14:00-07:00", "Completed onboarding", "Account setup", "Onboarding"],
        ["2026-09-30T09:10:00-07:00", "Opened ḥꜣw", "App launched", "App"],
      ]),
    },
    {
      id: "e8",
      name: "Ayo Bennett",
      handle: "ayo.b",
      email: "ayo@example.com",
      joined: "2026-10-07T12:00:00-07:00",
      timezone: zone,
      history: history("e8", []),
    },
  ];
}
