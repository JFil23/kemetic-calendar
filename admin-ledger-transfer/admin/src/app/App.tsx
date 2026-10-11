import { AdminAuthGate } from "./auth/AdminAuthGate";
import { ActivityLedgerPage } from "../features/ledger/ActivityLedgerPage";
import { isLocalDevAuthenticated } from "../lib/supabase";

export function App() {
  return (
    <AdminAuthGate>
      {(admin) => (
        <ActivityLedgerPage
          admin={admin}
          useSampleData={
            isLocalDevAuthenticated() || admin.user.id === "local-dev-admin"
          }
        />
      )}
    </AdminAuthGate>
  );
}
