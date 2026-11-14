import { LockKeyhole, ShieldCheck } from "lucide-react";

import type { AdminRoute } from "../../app/routes";

type Props = {
  route: AdminRoute;
};

export function PlaceholderPage({ route }: Props) {
  const isReady = route.state === "phase1" || route.state === "active";
  const StatusIcon = isReady ? ShieldCheck : LockKeyhole;

  return (
    <section className="page-surface">
      <div className="page-heading">
        <div>
          <span className="eyebrow">{route.group}</span>
          <h1>{route.label}</h1>
          <p>{route.purpose}</p>
        </div>
        <span className={`phase-pill ${isReady ? "ready" : ""}`}>
          {route.phase}
        </span>
      </div>

      <div className="status-row">
        <div className={`icon-disc ${isReady ? "success" : ""}`}>
          <StatusIcon size={22} />
        </div>
        <div>
          <h2>{isReady ? "Available in Phase 1" : `Locked until ${route.phase}`}</h2>
          <p>
            {isReady
              ? "This page is available through the secure staff gate and scoped admin functions."
              : "This page will stay placeholder-only until its phase adds real data, tests, and approval rules."}
          </p>
        </div>
      </div>

      <div className="check-grid">
        <div>
          <strong>No broad data access</strong>
          <span>Admin data must flow through scoped admin functions.</span>
        </div>
        <div>
          <strong>Audit-first</strong>
          <span>Operator access and future decisions are logged server-side.</span>
        </div>
        <div>
          <strong>Draft before action</strong>
          <span>Future agent output remains approval-gated by default.</span>
        </div>
      </div>
    </section>
  );
}
