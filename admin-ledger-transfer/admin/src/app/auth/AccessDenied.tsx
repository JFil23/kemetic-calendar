import { ShieldAlert } from "lucide-react";

import { supabase } from "../../lib/supabase";

type Props = {
  message: string;
  statusCode?: number;
  onSignOut?: () => void;
};

export function AccessDenied({ message, statusCode, onSignOut }: Props) {
  return (
    <main className="auth-screen">
      <section className="auth-panel">
        <div className="icon-disc danger">
          <ShieldAlert size={24} />
        </div>
        <h1>Access denied</h1>
        <p>
          {statusCode ? `${statusCode}: ` : ""}
          {message}
        </p>
        <button
          type="button"
          className="secondary-button full-width"
          onClick={() => {
            onSignOut?.();
            void supabase?.auth.signOut();
          }}
        >
          Sign out
        </button>
      </section>
    </main>
  );
}
