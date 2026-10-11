import { LogOut } from "lucide-react";
import { useEffect, useRef } from "react";
import { NavLink, useLocation } from "react-router-dom";

import type { AdminMe } from "../../lib/api";
import { setLocalDevAuthenticated, supabase } from "../../lib/supabase";
import { adminRoutes, routeGroups } from "../routes";

type Props = {
  admin: AdminMe;
  children: React.ReactNode;
};

export function AdminLayout({ admin, children }: Props) {
  const location = useLocation();
  const contentRef = useRef<HTMLElement | null>(null);
  const mountedRef = useRef(false);

  useEffect(() => {
    if (!mountedRef.current) {
      mountedRef.current = true;
      return;
    }

    window.requestAnimationFrame(() => {
      if (window.matchMedia("(max-width: 860px)").matches) {
        contentRef.current?.scrollIntoView({ block: "start" });
        return;
      }
      window.scrollTo({ top: 0, left: 0 });
    });
  }, [location.pathname]);

  return (
    <div className="admin-shell">
      <aside className="sidebar">
        <div className="sidebar-brand">
          <span className="brand-mark compact">ḥꜣw</span>
          <span>Operator Console</span>
        </div>
        <nav className="sidebar-nav" aria-label="Admin navigation">
          {routeGroups.map((group) => (
            <section key={group} className="nav-group">
              <h2>{group}</h2>
              {adminRoutes
                .filter((route) => route.group === group)
                .map((route) => (
                  <NavLink
                    key={route.path}
                    to={route.path}
                    className={({ isActive }) =>
                      `nav-link${isActive ? " active" : ""}`
                    }
                  >
                    <route.Icon size={17} />
                    <span>{route.label}</span>
                  </NavLink>
                ))}
            </section>
          ))}
        </nav>
      </aside>
      <div className="workspace">
        <header className="topbar">
          <div>
            <span className="eyebrow">Private admin</span>
            <strong>{admin.staff.role}</strong>
            {admin.user.id === "local-dev-admin" ? (
              <span className="topbar-mode">Local preview</span>
            ) : null}
          </div>
          <div className="topbar-user">
            <span>{admin.user.email ?? admin.user.id}</span>
            <button
              type="button"
              onClick={() => {
                setLocalDevAuthenticated(false);
                void supabase?.auth.signOut();
                window.location.href = "/";
              }}
            >
              <LogOut size={16} />
              Sign out
            </button>
          </div>
        </header>
        <main className="content" ref={contentRef}>{children}</main>
      </div>
    </div>
  );
}
