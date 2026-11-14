import type { Session } from "@supabase/supabase-js";
import { useEffect, useMemo, useState } from "react";

import { AdminApiError, fetchAdminMe, type AdminMe } from "../../lib/api";
import {
  isLocalDevAuthenticated,
  setLocalDevAuthenticated,
  supabase,
  supabaseConfig,
} from "../../lib/supabase";
import { AccessDenied } from "./AccessDenied";
import { LoginPage, PasswordRecoveryPage } from "./LoginPage";

type GateState =
  | { status: "loading" }
  | { status: "signed-out" }
  | { status: "checking"; session: Session }
  | { status: "allowed"; admin: AdminMe }
  | { status: "password-recovery" }
  | { status: "denied"; message: string; statusCode?: number };

type Props = {
  children: (admin: AdminMe) => React.ReactNode;
};

function localDevAdmin(): AdminMe {
  return {
    user: {
      id: "local-dev-admin",
      email: supabaseConfig.defaultStaffEmail || "local-dev-admin",
    },
    staff: {
      role: "owner",
      scopes: [],
    },
  };
}

export function AdminAuthGate({ children }: Props) {
  const [state, setState] = useState<GateState>({ status: "loading" });

  useEffect(() => {
    if (!supabaseConfig.isConfigured || !supabase) {
      setState({
        status: "denied",
        message: "Admin Supabase configuration is missing.",
        statusCode: 500,
      });
      return;
    }

    let alive = true;
    const urlParams = new URLSearchParams(
      window.location.hash.startsWith("#")
        ? window.location.hash.slice(1)
        : window.location.search,
    );
    const isPasswordRecovery = urlParams.get("type") === "recovery";

    const checkSession = async (session: Session | null) => {
      if (!alive) return;
      if (isPasswordRecovery) {
        setState({ status: "password-recovery" });
        return;
      }
      if (isLocalDevAuthenticated()) {
        setState({ status: "allowed", admin: localDevAdmin() });
        return;
      }
      if (!session) {
        setState({ status: "signed-out" });
        return;
      }

      setState({ status: "checking", session });
      try {
        const admin = await fetchAdminMe(session);
        if (alive) setState({ status: "allowed", admin });
      } catch (error) {
        const apiError = error instanceof AdminApiError ? error : null;
        if (alive) {
          setState({
            status: "denied",
            message: apiError?.message ?? "Admin access check failed.",
            statusCode: apiError?.status,
          });
        }
      }
    };

    supabase.auth.getSession().then(({ data }) => checkSession(data.session));
    const { data: subscription } = supabase.auth.onAuthStateChange(
      (event, session) => {
        if (event === "PASSWORD_RECOVERY") {
          setState({ status: "password-recovery" });
          return;
        }
        void checkSession(session);
      },
    );

    return () => {
      alive = false;
      subscription.subscription.unsubscribe();
    };
  }, []);

  const content = useMemo(() => {
    if (state.status === "loading" || state.status === "checking") {
      return <div className="center-panel">Checking staff access...</div>;
    }
    if (state.status === "signed-out") {
      return (
        <LoginPage
          onLocalDevAccess={() =>
            setState({ status: "allowed", admin: localDevAdmin() })}
        />
      );
    }
    if (state.status === "password-recovery") {
      return (
        <PasswordRecoveryPage
          onComplete={() => setState({ status: "signed-out" })}
        />
      );
    }
    if (state.status === "denied") {
      return (
        <AccessDenied
          message={state.message}
          statusCode={state.statusCode}
          onSignOut={() => setLocalDevAuthenticated(false)}
        />
      );
    }
    return children(state.admin);
  }, [children, state]);

  return <>{content}</>;
}
