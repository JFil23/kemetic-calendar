import { AdminApiError } from "../../lib/api";
import { supabase } from "../../lib/supabase";

export type ActivityUserSummary = {
  id: string;
  display_name: string;
  handle: string | null;
  email: string | null;
  timezone: string | null;
  created_at: string;
  telemetry_enabled?: boolean | null;
  first_seen_at?: string | null;
  last_seen_at?: string | null;
  last_event_at?: string | null;
  last_event_label?: string | null;
  event_count: number;
};

export type ActivityUsersPayload = {
  period_days: number;
  total_matching_users: number;
  users: ActivityUserSummary[];
};

export type ActivityTimelineRow = {
  id: string;
  occurred_at: string;
  source_table: string;
  event_name: string;
  canonical_event: string;
  category: string;
  label: string;
  basis: string;
  safe_fields?: Record<string, unknown> | null;
};

export type ActivityUserDetailPayload = {
  period_days: number;
  profile: {
    id: string;
    display_name: string;
    handle: string | null;
    email: string | null;
    timezone: string | null;
    created_at: string;
  };
  timeline: ActivityTimelineRow[];
};

async function callRpc<T>(
  name: string,
  args: Record<string, unknown>,
): Promise<T> {
  if (!supabase) {
    throw new AdminApiError("Supabase admin configuration is missing.", 500);
  }
  const { data, error } = await supabase.rpc(name, args);
  if (error) {
    const status =
      error.code === "42501"
        ? 403
        : error.message.toLowerCase().includes("jwt")
          ? 401
          : 400;
    throw new AdminApiError(error.message, status, error.code);
  }
  return data as T;
}

export async function fetchActivityUsers(
  days: number,
  limit = 250,
  query?: string | null,
): Promise<ActivityUsersPayload> {
  return callRpc<ActivityUsersPayload>("admin_activity_users", {
    p_days: days,
    p_limit: limit,
    p_query: query ?? null,
  });
}

export async function fetchActivityUserDetail(
  userId: string,
  days: number,
): Promise<ActivityUserDetailPayload> {
  return callRpc<ActivityUserDetailPayload>("admin_activity_user_detail", {
    p_target_user_id: userId,
    p_days: days,
  });
}
