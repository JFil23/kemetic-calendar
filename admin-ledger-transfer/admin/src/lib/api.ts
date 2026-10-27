import type { Session } from "@supabase/supabase-js";

import { supabaseConfig } from "./supabase";

export type AdminMe = {
  user: {
    id: string;
    email: string | null;
  };
  staff: {
    role: "owner" | "operator" | "support" | "readonly" | string;
    scopes: string[];
  };
};

export type WarRoomDays = 7 | 30 | 90;

export type WarRoomSummary = {
  period_days: number;
  generated_at: string;
  period_start: string;
  min_bucket_size: number;
  users?: {
    active_period?: number | null;
    active_7d?: number | null;
    active_30d?: number | null;
    new_period?: number | null;
    new_7d?: number | null;
    new_30d?: number | null;
    onboarding_completed_period?: number | null;
    onboarding_completed_total?: number | null;
    total_profiles?: number | null;
  };
  activation?: {
    first_node_opened_period?: number | null;
    first_flow_started_period?: number | null;
    first_journal_action_period?: number | null;
    first_reflection_action_period?: number | null;
  };
  maat?: {
    source?: string | null;
    outcomes?: Array<{
      cta_type?: string | null;
      cta_ref?: string | null;
      outcome_flag?: string | null;
      routing_effect?: string | null;
      measured_week_count?: number | null;
      completed_window_count?: number | null;
      positive_week_count?: number | null;
      negative_week_count?: number | null;
      weighted_delta_done_rate?: number | null;
      weighted_delta_skipped_rate?: number | null;
      latest_measured_week?: string | null;
      flag_rule?: string | null;
    }>;
    alerts?: Array<{
      alert_key?: string | null;
      severity?: string | null;
      cta_type?: string | null;
      cta_ref?: string | null;
      cohort_type?: string | null;
      cohort_key?: string | null;
      details?: Record<string, unknown> | null;
    }>;
  };
  nodes?: {
    top?: NodeMetric[];
    bottom?: NodeMetric[];
    min_bucket_size?: number | null;
  };
  flows?: {
    created_period?: number | null;
    created_users_period?: number | null;
    completed_events_period?: number | null;
    completed_users_period?: number | null;
    skipped_events_period?: number | null;
    skipped_users_period?: number | null;
    ai_generations_period?: number | null;
    ai_success_period?: number | null;
    ai_failure_period?: number | null;
  };
  errors?: {
    app_events?: Array<{
      event?: string | null;
      event_count?: number | null;
      distinct_users?: number | null;
      last_seen_at?: string | null;
    }>;
    flow_generation?: Array<{
      llm_status?: string | null;
      event_count?: number | null;
      distinct_users?: number | null;
      last_seen_at?: string | null;
    }>;
    min_bucket_size?: number | null;
  };
  empty_sections?: string[];
};

export type NodeMetric = {
  slug?: string | null;
  title?: string | null;
  glyph?: string | null;
  event_count?: number | null;
  distinct_users?: number | null;
  last_event_at?: string | null;
};

export type ArchiveEntry = {
  id: string;
  namespace: string;
  title: string;
  content_md: string;
  tags: string[];
  source_run_id?: string | null;
  source_type?: string | null;
  created_by?: string | null;
  created_at: string;
  updated_at: string;
};

export type ArmoryPlaybook = {
  id: string;
  slug: string;
  agent_slug?: string | null;
  version: number;
  name: string;
  system_prompt_md: string;
  tools_allowed: unknown;
  output_schema: unknown;
  requires_approval: boolean;
  is_active: boolean;
  created_at: string;
  updated_at: string;
};

export type ApprovalRequest = {
  id: string;
  kind: string;
  status: "pending" | "approved" | "rejected" | "needs_changes" | "cancelled";
  risk_level: "low" | "medium" | "high" | "restricted";
  payload: Record<string, unknown>;
  summary: string;
  requested_by?: string | null;
  requested_from_run_id?: string | null;
  decided_by?: string | null;
  decided_at?: string | null;
  decision_notes?: string | null;
  created_at: string;
  updated_at: string;
};

export type TreasurySummary = {
  totals: {
    cost_usd: number;
    run_count: number;
  };
  by_agent: Array<{
    agent_slug: string;
    cost_usd: number;
    run_count: number;
  }>;
  recent_ledger: Array<{
    id: string;
    run_id?: string | null;
    agent_slug?: string | null;
    provider: string;
    model: string;
    tokens_in: number;
    tokens_out: number;
    cost_usd: number | string;
    duration_ms?: number | null;
    budget_period: string;
    created_at: string;
  }>;
  budgets: Array<{
    id: string;
    scope: "global" | "agent_slug";
    agent_slug?: string | null;
    period: "daily" | "weekly" | "monthly";
    limit_usd: number | string;
    is_active: boolean;
    created_at: string;
    updated_at: string;
  }>;
};

export type AgentSlug =
  | "research"
  | "social"
  | "copy"
  | "suggest_updates"
  | "product_qa"
  | "chief_operator";

export type AgentRun = {
  id: string;
  job_id: string;
  agent_slug: AgentSlug | string;
  status: string;
  model: string;
  input: Record<string, unknown>;
  output_summary?: string | null;
  archive_entry_id?: string | null;
  created_at: string;
  completed_at?: string | null;
  duration_ms?: number | null;
};

export type Suggestion = {
  id: string;
  title: string;
  category: string;
  priority: "low" | "medium" | "high" | "urgent" | string;
  status: "new" | "triaged" | "approved" | "done" | "wontfix" | string;
  created_at: string;
};

export type CodexTask = {
  id: string;
  title: string;
  status: string;
  spec_md: string;
  prompt_md?: string | null;
  created_at: string;
};

export type MaatFixture = {
  id: string;
  description: string;
  input: Record<string, unknown>;
  expect: Record<string, unknown>;
};

export type MaatDelivery = {
  id: string;
  user_id: string;
  kind: string;
  decan_period_key: string;
  status: string;
  priority?: number | null;
  teaser_preview?: string | null;
  cta_type?: string | null;
  cta_ref?: string | null;
  trigger_reason?: string | null;
  shown_at?: string | null;
  dismissed_at?: string | null;
  opened_at?: string | null;
  acted_at?: string | null;
  expired_at?: string | null;
  created_at: string;
  updated_at?: string | null;
};

export type MaatEvaluation = {
  id: string;
  user_id: string;
  snapshot_id?: string | null;
  decan_period_key: string;
  window_date: string;
  policy_version: string;
  maturity_level?: string | null;
  suppressed: string[];
  created_delivery_ids: string[];
  drift?: Record<string, unknown> | null;
  strength?: Record<string, unknown> | null;
  memory_brief?: Record<string, unknown> | null;
  created_at: string;
};

export type MaatOverride = {
  id: string;
  scope: string;
  status: string;
  cta_type?: string | null;
  cta_ref?: string | null;
  cohort_type?: string | null;
  cohort_key?: string | null;
  target_user_id?: string | null;
  override: Record<string, unknown>;
  reason: string;
  approval_request_id?: string | null;
  created_by?: string | null;
  created_at: string;
  updated_at: string;
};

export type MaatDryRunResult = {
  dry_run: boolean;
  policy_version: string;
  fixture_policy_version?: string | null;
  fixture?: { id: string; description: string } | null;
  input_preview: Record<string, unknown>;
  decision: Record<string, unknown>;
  side_effects: {
    deliveries_written: number;
    snapshots_written: number;
    evaluations_written: number;
    routing_changed: boolean;
  };
};

export type ContentArtifact =
  | "decan_reflection"
  | "decan_opening"
  | "maat_nudge"
  | "isfet_nudge"
  | "push_preview";

export type ContentEvaluation = {
  id: string;
  artifact: ContentArtifact;
  mode: string;
  status: string;
  target_user_id: string;
  window_start?: string | null;
  window_end?: string | null;
  decan_period_key?: string | null;
  generated_text: string;
  push_preview: Record<string, unknown>;
  source_snapshot: Record<string, unknown>;
  model_version?: string | null;
  rating?: number | null;
  feedback_tags: string[];
  critique_md?: string | null;
  created_at: string;
  updated_at: string;
};

export type ContentWindow = {
  start: string;
  end: string;
  decanName: string;
  decanTheme?: string | null;
  decanContextKey?: string | null;
};

export type ContentMaatSummary = {
  band: string;
  score?: number | null;
  reflection_move: string;
  lead_axis?: string | null;
  correction_axes?: string[];
  hard_gates?: string[];
  decan_period_key?: string | null;
  window_date?: string | null;
  updated_at?: string | null;
};

export type ContentContext = {
  profile: Record<string, unknown> | null;
  window: ContentWindow;
  decan_period_key: string;
  maat?: ContentMaatSummary;
  recommended_nudge?: ContentArtifact;
  top_nodes: Array<Record<string, unknown>>;
  node_activity: Array<Record<string, unknown>>;
  evidence: Record<string, unknown>;
  recent: {
    reflections: Array<Record<string, unknown>>;
    deliveries: Array<Record<string, unknown>>;
    evaluations: ContentEvaluation[];
  };
};

export type ContentUserCard = {
  id: string;
  display_name: string;
  handle?: string | null;
  timezone: string;
  created_at?: string | null;
  onboarding_completed?: boolean;
  decan_label: string;
  decan_period_key: string;
  window: ContentWindow;
  maat: ContentMaatSummary;
  recommended_nudge: ContentArtifact;
  top_nodes: Array<Record<string, unknown>>;
  badge_count_this_decan: number;
  has_pending_delivery: boolean;
  pending_delivery_count: number;
  needs_review: boolean;
  latest_evaluation?: ContentEvaluation | null;
  last_active_at?: string | null;
};

export type ContentUsersPayload = {
  users: ContentUserCard[];
  generated_at: string;
  filters: Record<string, unknown>;
};

export type ContentPreviewPayload = {
  preview: ContentEvaluation;
  context: {
    profile: Record<string, unknown> | null;
    window: ContentContext["window"];
    evidence: Record<string, unknown>;
    top_nodes: Array<Record<string, unknown>>;
  };
};

export type ContentDeliveryResult = {
  delivery: Record<string, unknown>;
  evaluation: ContentEvaluation;
};

export type NodeDraftVersion = {
  id: string;
  draft_id: string;
  version_number: number;
  title: string;
  body_md: string;
  metadata: Record<string, unknown>;
  created_by?: string | null;
  created_at: string;
};

export type PublishedNode = {
  id: string;
  slug: string;
  title: string;
  glyph?: string | null;
  body_text: string;
  is_active?: boolean | null;
  updated_at?: string | null;
};

export type NodeDraft = {
  id: string;
  slug: string;
  title: string;
  body_md: string;
  metadata: Record<string, unknown>;
  status: "draft" | "pending_approval" | "approved" | "rejected" | "cancelled";
  linked_node_slug?: string | null;
  approval_request_id?: string | null;
  created_by?: string | null;
  created_at: string;
  updated_at: string;
  latest_version?: NodeDraftVersion | null;
  version_count?: number;
  versions?: NodeDraftVersion[];
  published_node?: PublishedNode | null;
  app_visibility?: string;
};

export type NodeDraftsPayload = {
  drafts: NodeDraft[];
  published_nodes: PublishedNode[];
  source_of_truth: string;
};

export type AgentRunPayload = {
  runs: AgentRun[];
  suggestions?: Suggestion[];
  codex_tasks?: CodexTask[];
  latest_report?: ArchiveEntry | null;
};

export type EchoRunResult = {
  job: { id: string; agent_slug: string; status: string; created_at: string };
  run: AgentRun;
  output: { id: string; run_id: string; output_type: string };
  archive_entry: ArchiveEntry;
  treasury: {
    provider: string;
    model: string;
    cost_usd: number;
    tokens_in?: number;
    tokens_out?: number;
  };
};

export class AdminApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly code?: string,
    readonly detail?: unknown,
  ) {
    super(message);
  }
}

function previewId(prefix: string) {
  return `${prefix}-local-preview`;
}

function previewArchiveEntry(
  namespace = "ops",
  title = "Local preview entry",
): ArchiveEntry {
  const now = new Date().toISOString();
  return {
    id: previewId("archive"),
    namespace,
    title,
    content_md:
      "Local dev preview. Sign in with a real Supabase staff session to read or write production data.",
    tags: ["local-preview"],
    source_type: "local_dev",
    created_at: now,
    updated_at: now,
  };
}

function localPreviewResponse<T>(
  functionName: string,
  options: {
    method?: "GET" | "POST" | "PATCH";
    params?: Record<string, string | number | undefined>;
    body?: Record<string, unknown>;
  },
): T {
  const now = new Date().toISOString();

  if (functionName === "admin_auth/me") {
    return {
      user: { id: "local-dev-admin", email: supabaseConfig.defaultStaffEmail },
      staff: { role: "owner", scopes: [] },
    } as T;
  }

  if (functionName === "admin_war_room") {
    return {
      period_days: Number(options.params?.days ?? 7),
      generated_at: now,
      period_start: now,
      min_bucket_size: 5,
      users: {
        active_period: 0,
        active_7d: 0,
        active_30d: 0,
        new_period: 0,
        new_7d: 0,
        new_30d: 0,
      },
      activation: {},
      maat: { source: "local_preview", outcomes: [], alerts: [] },
      nodes: { top: [], bottom: [], min_bucket_size: 5 },
      flows: {},
      errors: { app_events: [], flow_generation: [], min_bucket_size: 5 },
      empty_sections: [
        "Local preview mode. Real War Room data requires Supabase staff auth.",
      ],
    } as T;
  }

  if (functionName === "admin_archive") {
    if (options.method === "POST") {
      return {
        entry: previewArchiveEntry(
          String(options.body?.namespace ?? "ops"),
          String(options.body?.title ?? "Local preview entry"),
        ),
      } as T;
    }
    return options.params?.id ? ({ entry: null } as T) : ({ entries: [] } as T);
  }

  if (functionName === "admin_armory") {
    return { playbooks: [] } as T;
  }

  if (functionName === "admin_approvals") {
    if (options.method === "POST" || options.method === "PATCH") {
      return {
        approval: {
          id: previewId("approval"),
          kind: String(options.body?.kind ?? "local_preview"),
          status: String(options.body?.status ?? "pending"),
          risk_level: String(options.body?.risk_level ?? "low"),
          payload: options.body?.payload ?? {},
          summary: String(options.body?.summary ?? "Local preview approval"),
          created_at: now,
          updated_at: now,
        },
      } as T;
    }
    return { approvals: [] } as T;
  }

  if (functionName === "admin_treasury") {
    return {
      totals: { cost_usd: 0, run_count: 0 },
      by_agent: [],
      recent_ledger: [],
      budgets: [],
    } as T;
  }

  if (functionName === "admin_agent_run") {
    if (options.method === "POST") {
      const agentSlug = String(options.body?.agent_slug ?? "research");
      const archiveEntry = previewArchiveEntry(
        agentSlug === "chief_operator" ? "chief_report" : agentSlug,
        `Local preview: ${agentSlug}`,
      );
      return {
        job: {
          id: previewId("job"),
          agent_slug: agentSlug,
          status: "completed",
          created_at: now,
        },
        run: {
          id: previewId("run"),
          job_id: previewId("job"),
          agent_slug: agentSlug,
          status: "completed",
          model: "local-preview",
          input: options.body?.input ?? {},
          output_summary: "Local preview run only.",
          archive_entry_id: archiveEntry.id,
          created_at: now,
          completed_at: now,
          duration_ms: 0,
        },
        output: {
          id: previewId("output"),
          run_id: previewId("run"),
          output_type: "archive_entry",
        },
        archive_entry: archiveEntry,
        treasury: {
          provider: "local",
          model: "local-preview",
          cost_usd: 0,
          tokens_in: 0,
          tokens_out: 0,
        },
      } as T;
    }
    return {
      runs: [],
      suggestions: [],
      codex_tasks: [],
      latest_report: null,
    } as T;
  }

  if (functionName === "admin_maat_ops") {
    if (options.method === "POST") {
      return {
        override: {
          id: previewId("maat-override"),
          scope: String(options.body?.scope ?? "global"),
          status: "pending_approval",
          override: options.body?.override ?? {},
          reason: String(options.body?.reason ?? "Local preview override"),
          approval_request_id: previewId("approval"),
          created_at: now,
          updated_at: now,
        },
        approval: {
          id: previewId("approval"),
          kind: "maat_policy_change",
          status: "pending",
          risk_level: "high",
          payload: {},
          summary: "Local preview Ma'at override",
          created_at: now,
          updated_at: now,
        },
      } as T;
    }
    const action = options.params?.action;
    if (action === "deliveries") return { deliveries: [] } as T;
    if (action === "evaluations") return { evaluations: [] } as T;
    if (action === "overrides") return { overrides: [] } as T;
    return {
      policy_version: "local-preview",
      fixture_policy_version: "local-preview",
      fixtures: [],
    } as T;
  }

  if (functionName === "admin_maat_dry_run") {
    return {
      dry_run: true,
      policy_version: "local-preview",
      fixture_policy_version: "local-preview",
      fixture: null,
      input_preview: {},
      decision: {
        source: "local_preview",
        note: "Real dry-run requires Supabase staff auth.",
      },
      side_effects: {
        deliveries_written: 0,
        snapshots_written: 0,
        evaluations_written: 0,
        routing_changed: false,
      },
    } as T;
  }

  if (functionName === "admin_content_preview") {
    if (options.params?.action === "list_users") {
      return {
        users: [
          {
            id: "local-user",
            display_name: "Local Preview User",
            handle: "preview",
            timezone: "America/Los_Angeles",
            decan_label: "Local Preview Decan",
            decan_period_key: "2026-05-19:2026-05-28:local-preview",
            window: {
              start: "2026-05-19",
              end: "2026-05-28",
              decanName: "Local Preview Decan",
              decanTheme: null,
              decanContextKey: "local-preview",
            },
            maat: {
              band: "mixed",
              score: 0,
              reflection_move: "inquire",
              lead_axis: "truth",
              correction_axes: [],
              hard_gates: [],
            },
            recommended_nudge: "maat_nudge",
            top_nodes: [{ slug: "maat", title: "Ma'at", score: 0.8 }],
            badge_count_this_decan: 0,
            has_pending_delivery: false,
            pending_delivery_count: 0,
            needs_review: false,
            latest_evaluation: null,
            last_active_at: now,
          },
        ],
        generated_at: now,
        filters: options.params ?? {},
      } as T;
    }
    const artifact = String(
      options.body?.artifact ?? options.params?.artifact ?? "decan_reflection",
    ) as ContentArtifact;
    const evaluation: ContentEvaluation = {
      id: previewId("content-evaluation"),
      artifact,
      mode: "preview",
      status: "draft",
      target_user_id: String(
        options.body?.target_user_id ??
          options.params?.target_user_id ??
          "local-user",
      ),
      window_start: String(
        options.body?.decan_start ??
          options.params?.decan_start ??
          "2026-05-19",
      ),
      window_end: String(
        options.body?.decan_end ?? options.params?.decan_end ?? "2026-05-28",
      ),
      decan_period_key: "2026-05-19:2026-05-28:local-preview",
      generated_text:
        "Local preview content. Sign in with a real staff session to generate from production evidence.",
      push_preview: {
        kind: artifact,
        title: "Local preview",
        body: "No push is sent from local preview mode.",
        deeplink: "/preview",
      },
      source_snapshot: {
        badge_count: 0,
        evidence_count: 0,
        evidence_lines: [],
        top_nodes: [],
      },
      model_version: "local-preview",
      rating: null,
      feedback_tags: [],
      critique_md: null,
      created_at: now,
      updated_at: now,
    };
    if (options.params?.action === "context") {
      return {
        profile: { id: evaluation.target_user_id, timezone: "local-preview" },
        window: {
          start: evaluation.window_start!,
          end: evaluation.window_end!,
          decanName: "Local Preview Decan",
          decanTheme: null,
          decanContextKey: "local-preview",
        },
        decan_period_key: evaluation.decan_period_key!,
        top_nodes: [],
        node_activity: [],
        evidence: evaluation.source_snapshot,
        recent: {
          reflections: [],
          deliveries: [],
          evaluations: [],
        },
      } as T;
    }
    if (options.params?.action === "evaluations") {
      return { evaluations: [] } as T;
    }
    if (options.params?.action === "save_critique") {
      return {
        evaluation: {
          ...evaluation,
          rating: Number(options.body?.rating ?? 3),
          feedback_tags: Array.isArray(options.body?.feedback_tags)
            ? (options.body.feedback_tags as string[])
            : [],
          critique_md: String(options.body?.critique_md ?? ""),
          status: String(options.body?.status ?? "reviewed"),
        },
      } as T;
    }
    if (options.params?.action === "deliver_nudge") {
      return {
        delivery: {
          id: previewId("maat-delivery"),
          user_id: evaluation.target_user_id,
          kind: artifact === "isfet_nudge" ? "drift_nudge" : "strength_nudge",
          status: "pending",
          decan_period_key: evaluation.decan_period_key,
          teaser_text: "Local preview delivery",
          body_text: "No production delivery is created in local preview mode.",
          cta_type: "none",
          cta_ref: null,
          created_at: now,
        },
        evaluation,
      } as T;
    }
    return {
      preview: evaluation,
      context: {
        profile: { id: evaluation.target_user_id, timezone: "local-preview" },
        window: {
          start: evaluation.window_start!,
          end: evaluation.window_end!,
          decanName: "Local Preview Decan",
          decanTheme: null,
          decanContextKey: "local-preview",
        },
        evidence: evaluation.source_snapshot,
        top_nodes: [],
      },
    } as T;
  }

  if (functionName === "admin_nodes") {
    if (options.method === "POST") {
      const draft = {
        id: previewId("node-draft"),
        slug: String(options.body?.slug ?? "local-preview"),
        title: String(options.body?.title ?? "Local preview draft"),
        body_md: String(options.body?.body_md ?? ""),
        metadata: {},
        status:
          options.body?.action === "request_approval"
            ? "pending_approval"
            : options.body?.action === "approve"
              ? "approved"
              : "draft",
        created_at: now,
        updated_at: now,
      };
      return {
        draft,
        approval: {
          id: previewId("approval"),
          kind: "node_draft_later",
          status: "pending",
          risk_level: "medium",
          payload: {},
          summary: "Local preview node approval",
          created_at: now,
          updated_at: now,
        },
        version: {
          id: previewId("node-version"),
          draft_id: draft.id,
          version_number: 1,
          title: draft.title,
          body_md: draft.body_md,
          metadata: {},
          created_at: now,
        },
      } as T;
    }
    return {
      drafts: [],
      published_nodes: [],
      source_of_truth:
        "Local preview. ADR-002 Option C remains draft-only until real Supabase staff auth is active.",
    } as T;
  }

  return {} as T;
}

async function adminFunctionFetch<T>(
  session: Session,
  functionName: string,
  options: {
    method?: "GET" | "POST" | "PATCH";
    params?: Record<string, string | number | undefined>;
    body?: Record<string, unknown>;
  } = {},
): Promise<T> {
  if (session.access_token === "local-dev-preview") {
    return localPreviewResponse<T>(functionName, options);
  }

  if (!supabaseConfig.isConfigured) {
    throw new AdminApiError("Supabase admin configuration is missing.", 500);
  }

  const url = new URL(`${supabaseConfig.url}/functions/v1/${functionName}`);
  for (const [key, value] of Object.entries(options.params ?? {})) {
    if (value !== undefined && value !== "") {
      url.searchParams.set(key, String(value));
    }
  }

  const response = await fetch(url.toString(), {
    method: options.method ?? "GET",
    headers: {
      authorization: `Bearer ${session.access_token}`,
      "content-type": "application/json",
      "x-request-id": crypto.randomUUID(),
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const detail = typeof payload.detail === "string" && payload.detail.trim()
      ? payload.detail
      : undefined;
    throw new AdminApiError(
      detail ?? payload.error ?? `${functionName} request failed.`,
      response.status,
      payload.error,
      payload,
    );
  }

  return payload as T;
}

export async function fetchAdminMe(session: Session): Promise<AdminMe> {
  return adminFunctionFetch<AdminMe>(session, "admin_auth/me");
}

export async function fetchWarRoomSummary(
  session: Session,
  days: WarRoomDays,
): Promise<WarRoomSummary> {
  return adminFunctionFetch<WarRoomSummary>(session, "admin_war_room", {
    params: { days },
  });
}

export async function fetchArchiveEntries(
  session: Session,
  filters: { q?: string; namespace?: string } = {},
): Promise<ArchiveEntry[]> {
  const payload = await adminFunctionFetch<{ entries: ArchiveEntry[] }>(
    session,
    "admin_archive",
    { params: filters },
  );
  return payload.entries;
}

export async function createArchiveEntry(
  session: Session,
  input: {
    namespace: string;
    title: string;
    content_md: string;
    tags: string[];
  },
): Promise<ArchiveEntry> {
  const payload = await adminFunctionFetch<{ entry: ArchiveEntry }>(
    session,
    "admin_archive",
    { method: "POST", body: input },
  );
  return payload.entry;
}

export async function fetchArmoryPlaybooks(
  session: Session,
): Promise<ArmoryPlaybook[]> {
  const payload = await adminFunctionFetch<{ playbooks: ArmoryPlaybook[] }>(
    session,
    "admin_armory",
  );
  return payload.playbooks;
}

export async function fetchApprovals(
  session: Session,
  status?: ApprovalRequest["status"] | "all",
): Promise<ApprovalRequest[]> {
  const payload = await adminFunctionFetch<{ approvals: ApprovalRequest[] }>(
    session,
    "admin_approvals",
    { params: { status: status === "all" ? undefined : status } },
  );
  return payload.approvals;
}

export async function createApprovalRequest(
  session: Session,
  input: {
    kind: string;
    summary: string;
    risk_level: ApprovalRequest["risk_level"];
    payload?: Record<string, unknown>;
  },
): Promise<ApprovalRequest> {
  const payload = await adminFunctionFetch<{ approval: ApprovalRequest }>(
    session,
    "admin_approvals",
    { method: "POST", body: input },
  );
  return payload.approval;
}

export async function decideApprovalRequest(
  session: Session,
  input: {
    id: string;
    status: Exclude<ApprovalRequest["status"], "pending">;
    decision_notes?: string;
  },
): Promise<ApprovalRequest> {
  const payload = await adminFunctionFetch<{ approval: ApprovalRequest }>(
    session,
    "admin_approvals",
    { method: "PATCH", body: input },
  );
  return payload.approval;
}

export async function fetchTreasurySummary(
  session: Session,
): Promise<TreasurySummary> {
  return adminFunctionFetch<TreasurySummary>(session, "admin_treasury");
}

export async function fetchAgentRuns(
  session: Session,
  agentSlug?: AgentSlug,
): Promise<AgentRun[]> {
  const payload = await adminFunctionFetch<AgentRunPayload>(
    session,
    "admin_agent_run",
    { params: { agent_slug: agentSlug } },
  );
  return payload.runs;
}

export async function fetchAgentRunPayload(
  session: Session,
  agentSlug: AgentSlug,
): Promise<AgentRunPayload> {
  return adminFunctionFetch<AgentRunPayload>(session, "admin_agent_run", {
    params: { agent_slug: agentSlug },
  });
}

export async function runEchoAgent(
  session: Session,
  input: {
    agent_slug: AgentSlug;
    message: string;
    estimated_cost_usd?: number;
  },
): Promise<EchoRunResult> {
  return adminFunctionFetch<EchoRunResult>(session, "admin_agent_run", {
    method: "POST",
    body: {
      agent_slug: input.agent_slug,
      mode: "echo",
      input: { message: input.message },
      estimated_cost_usd: input.estimated_cost_usd ?? 0.0001,
    },
  });
}

export async function runResearchAgent(
  session: Session,
  input: {
    topic: string;
    scope:
      | "kemet_trends"
      | "competitor"
      | "app_research"
      | "business"
      | "technical";
    depth: "quick" | "standard" | "deep";
    urls: string[];
    use_war_room_context: boolean;
  },
): Promise<EchoRunResult> {
  return adminFunctionFetch<EchoRunResult>(session, "admin_agent_run", {
    method: "POST",
    body: {
      agent_slug: "research",
      input,
    },
  });
}

export async function runCopyAgent(
  session: Session,
  input: {
    surface:
      | "app_ui"
      | "landing"
      | "email"
      | "app_store"
      | "onboarding"
      | "node_intro"
      | "flow_description"
      | "support";
    brief: string;
    tone: string;
    length_limit: number;
  },
): Promise<EchoRunResult> {
  return adminFunctionFetch<EchoRunResult>(session, "admin_agent_run", {
    method: "POST",
    body: {
      agent_slug: "copy",
      input,
    },
  });
}

export async function runSocialAgent(
  session: Session,
  input: {
    platform: "tiktok" | "threads" | "instagram" | "carousel" | "youtube_short";
    topic: string;
    hook: string;
    tone: string;
    batch_size: number;
  },
): Promise<EchoRunResult> {
  return adminFunctionFetch<EchoRunResult>(session, "admin_agent_run", {
    method: "POST",
    body: {
      agent_slug: "social",
      input,
    },
  });
}

export async function runSuggestUpdatesAgent(
  session: Session,
  input: {
    lookback_days: 7 | 30 | 90;
    focus: "product" | "content" | "maat" | "onboarding" | "retention" | "bugs";
  },
): Promise<EchoRunResult> {
  return adminFunctionFetch<EchoRunResult>(session, "admin_agent_run", {
    method: "POST",
    body: {
      agent_slug: "suggest_updates",
      input,
    },
  });
}

export async function runProductQaAgent(
  session: Session,
  input: {
    report: string;
    likely_area: string;
    links: string[];
  },
): Promise<EchoRunResult> {
  return adminFunctionFetch<EchoRunResult>(session, "admin_agent_run", {
    method: "POST",
    body: {
      agent_slug: "product_qa",
      input,
    },
  });
}

export async function runChiefOperatorAgent(
  session: Session,
  input: { lookback_days: 7 | 30 | 90 },
): Promise<EchoRunResult> {
  return adminFunctionFetch<EchoRunResult>(session, "admin_agent_run", {
    method: "POST",
    body: {
      agent_slug: "chief_operator",
      input,
    },
  });
}

export async function fetchMaatFixtures(session: Session): Promise<{
  policy_version: string;
  fixture_policy_version?: string | null;
  fixtures: MaatFixture[];
}> {
  return adminFunctionFetch<{
    policy_version: string;
    fixture_policy_version?: string | null;
    fixtures: MaatFixture[];
  }>(session, "admin_maat_ops", { params: { action: "fixtures" } });
}

export async function fetchMaatDeliveries(
  session: Session,
  userId: string,
): Promise<MaatDelivery[]> {
  const payload = await adminFunctionFetch<{ deliveries: MaatDelivery[] }>(
    session,
    "admin_maat_ops",
    { params: { action: "deliveries", user_id: userId } },
  );
  return payload.deliveries;
}

export async function fetchMaatEvaluations(
  session: Session,
  userId: string,
): Promise<MaatEvaluation[]> {
  const payload = await adminFunctionFetch<{ evaluations: MaatEvaluation[] }>(
    session,
    "admin_maat_ops",
    { params: { action: "evaluations", user_id: userId } },
  );
  return payload.evaluations;
}

export async function fetchMaatOverrides(
  session: Session,
): Promise<MaatOverride[]> {
  const payload = await adminFunctionFetch<{ overrides: MaatOverride[] }>(
    session,
    "admin_maat_ops",
    { params: { action: "overrides" } },
  );
  return payload.overrides;
}

export async function createMaatOverride(
  session: Session,
  input: {
    scope: "global" | "cta" | "cohort" | "user" | "policy";
    cta_type?: string;
    cta_ref?: string;
    cohort_type?: string;
    cohort_key?: string;
    target_user_id?: string;
    override: Record<string, unknown>;
    reason: string;
  },
): Promise<{ override: MaatOverride; approval: ApprovalRequest }> {
  return adminFunctionFetch<{
    override: MaatOverride;
    approval: ApprovalRequest;
  }>(session, "admin_maat_ops", {
    method: "POST",
    body: input,
  });
}

export async function dryRunMaat(
  session: Session,
  input: { fixture_id?: string; input?: Record<string, unknown> },
): Promise<MaatDryRunResult> {
  return adminFunctionFetch<MaatDryRunResult>(session, "admin_maat_dry_run", {
    method: "POST",
    body: input,
  });
}

export async function fetchContentContext(
  session: Session,
  input: {
    target_user_id: string;
    decan_start?: string;
    decan_end?: string;
    decan_name?: string;
    decan_theme?: string;
    decan_context_key?: string;
  },
): Promise<ContentContext> {
  return adminFunctionFetch<ContentContext>(session, "admin_content_preview", {
    params: {
      action: "context",
      target_user_id: input.target_user_id,
      decan_start: input.decan_start,
      decan_end: input.decan_end,
      decan_name: input.decan_name,
      decan_theme: input.decan_theme,
      decan_context_key: input.decan_context_key,
    },
  });
}

export async function fetchContentUsers(
  session: Session,
  filters: {
    q?: string;
    mode?: "active" | "needs_review" | "";
    band?: string;
    limit?: number;
  } = {},
): Promise<ContentUsersPayload> {
  return adminFunctionFetch<ContentUsersPayload>(
    session,
    "admin_content_preview",
    {
      params: {
        action: "list_users",
        q: filters.q,
        mode: filters.mode,
        band: filters.band,
        limit: filters.limit,
      },
    },
  );
}

export async function fetchContentEvaluations(
  session: Session,
  targetUserId?: string,
): Promise<ContentEvaluation[]> {
  const payload = await adminFunctionFetch<{
    evaluations: ContentEvaluation[];
  }>(session, "admin_content_preview", {
    params: { action: "evaluations", target_user_id: targetUserId },
  });
  return payload.evaluations;
}

export async function generateContentPreview(
  session: Session,
  input: {
    target_user_id: string;
    artifact: ContentArtifact;
    decan_start?: string;
    decan_end?: string;
    decan_name?: string;
    decan_theme?: string;
    decan_context_key?: string;
    day_card?: Record<string, unknown>;
    require_llm?: boolean;
    maat_flow_fixture?: string;
  },
): Promise<ContentPreviewPayload> {
  return adminFunctionFetch<ContentPreviewPayload>(
    session,
    "admin_content_preview",
    {
      method: "POST",
      params: { action: "generate" },
      body: input,
    },
  );
}

export async function saveContentCritique(
  session: Session,
  input: {
    evaluation_id: string;
    rating: number;
    feedback_tags: string[];
    critique_md: string;
    status: "reviewed" | "golden" | "needs_work" | "discarded";
  },
): Promise<ContentEvaluation | null> {
  const payload = await adminFunctionFetch<{
    evaluation: ContentEvaluation | null;
  }>(session, "admin_content_preview", {
    method: "POST",
    params: { action: "save_critique" },
    body: input,
  });
  return payload.evaluation;
}

export async function deliverContentNudge(
  session: Session,
  input: {
    evaluation_id: string;
    target_user_id?: string;
  },
): Promise<ContentDeliveryResult> {
  return adminFunctionFetch<ContentDeliveryResult>(
    session,
    "admin_content_preview",
    {
      method: "POST",
      params: { action: "deliver_nudge" },
      body: input,
    },
  );
}

export async function fetchNodeDrafts(
  session: Session,
): Promise<NodeDraftsPayload> {
  return adminFunctionFetch<NodeDraftsPayload>(session, "admin_nodes");
}

export async function createNodeDraft(
  session: Session,
  input: {
    slug: string;
    title: string;
    body_md: string;
    metadata: Record<string, unknown>;
    linked_node_slug?: string;
  },
): Promise<NodeDraft> {
  const payload = await adminFunctionFetch<{ draft: NodeDraft }>(
    session,
    "admin_nodes",
    { method: "POST", body: { action: "create", ...input } },
  );
  return payload.draft;
}

export async function saveNodeDraftVersion(
  session: Session,
  input: {
    id: string;
    title: string;
    body_md: string;
    metadata: Record<string, unknown>;
    status: NodeDraft["status"];
  },
): Promise<{ draft: NodeDraft; version: NodeDraftVersion }> {
  return adminFunctionFetch<{ draft: NodeDraft; version: NodeDraftVersion }>(
    session,
    "admin_nodes",
    {
      method: "POST",
      body: { action: "version", ...input },
    },
  );
}

export async function requestNodeDraftApproval(
  session: Session,
  id: string,
): Promise<{ draft: NodeDraft; approval: ApprovalRequest }> {
  return adminFunctionFetch<{ draft: NodeDraft; approval: ApprovalRequest }>(
    session,
    "admin_nodes",
    {
      method: "POST",
      body: { action: "request_approval", id },
    },
  );
}

export async function approveNodeDraft(
  session: Session,
  id: string,
): Promise<NodeDraft> {
  const payload = await adminFunctionFetch<{ draft: NodeDraft }>(
    session,
    "admin_nodes",
    { method: "POST", body: { action: "approve", id } },
  );
  return payload.draft;
}
