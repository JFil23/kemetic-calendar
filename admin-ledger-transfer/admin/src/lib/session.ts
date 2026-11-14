import type { Session } from "@supabase/supabase-js";

import { AdminApiError } from "./api";
import { isLocalDevAuthenticated, supabase } from "./supabase";

export async function getAdminSession(): Promise<Session> {
  if (isLocalDevAuthenticated()) {
    return {
      access_token: "local-dev-preview",
      token_type: "bearer",
      expires_in: 3600,
      expires_at: Math.floor(Date.now() / 1000) + 3600,
      refresh_token: "local-dev-preview",
      user: {
        id: "local-dev-admin",
        app_metadata: {},
        user_metadata: {},
        aud: "authenticated",
        created_at: new Date().toISOString(),
      },
    } as Session;
  }

  const result = await supabase?.auth.getSession();
  const session = result?.data.session;
  if (!session) {
    throw new AdminApiError("Admin session is missing.", 401);
  }
  return session;
}
