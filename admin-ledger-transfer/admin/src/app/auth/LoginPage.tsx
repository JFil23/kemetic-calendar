import { FormEvent, useState } from "react";
import { LogIn } from "lucide-react";

import {
  setLocalDevAuthenticated,
  supabase,
  supabaseConfig,
} from "../../lib/supabase";

type LoginPageProps = {
  onLocalDevAccess?: () => void;
};

export function LoginPage({ onLocalDevAccess }: LoginPageProps) {
  const [email, setEmail] = useState(supabaseConfig.defaultStaffEmail);
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const signInWithPassword = async (event: FormEvent) => {
    event.preventDefault();
    if (!supabase || !email.trim() || !password) return;
    setBusy(true);
    setMessage(null);
    const { error } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password,
    });
    setBusy(false);
    setMessage(
      error
        ? error.message === "Invalid login credentials"
          ? "Invalid Supabase password for this staff account. This is not the local dev preview password."
          : error.message
        : null,
    );
  };

  const useLocalPreview = () => {
    setMessage(null);
    setLocalDevAuthenticated(true);
    onLocalDevAccess?.();
  };

  const signInWithGoogle = async () => {
    if (!supabase) return;
    setBusy(true);
    setMessage(null);
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: window.location.origin },
    });
    if (error) {
      setMessage(error.message);
      setBusy(false);
    }
  };

  return (
    <main className="auth-screen">
      <section className="auth-panel">
        <div className="brand-mark">ḥꜣw</div>
        <h1>Admin Console</h1>
        <p>Staff access is required before any operator tools are shown.</p>
        <p className="auth-hint">
          This is separate from the public Kemetic app. Use the Supabase staff
          password for this project; then admin access is checked against
          staff membership.
        </p>
        {supabaseConfig.localDevAuthEnabled ? (
          <div className="notice">
            Local dev access is enabled for UI QA. Backend panels use preview
            data until a real Supabase staff session is active.
          </div>
        ) : null}
        {!supabaseConfig.isConfigured ? (
          <div className="notice danger">Missing Supabase admin env values.</div>
        ) : (
          <>
            <form onSubmit={signInWithPassword} className="auth-form">
              <label htmlFor="email">Staff email</label>
              <input
                id="email"
                type="email"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                placeholder="jaralephillips@gmail.com"
                autoComplete="email"
              />
              <label htmlFor="password">Password</label>
              <input
                id="password"
                type="password"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                autoComplete="current-password"
              />
              <button
                type="submit"
                disabled={busy || !email.trim() || !password}
              >
                <LogIn size={16} />
                Sign in
              </button>
            </form>
            <button
              type="button"
              className="secondary-button full-width stacked-button"
              onClick={signInWithGoogle}
              disabled={busy}
            >
              Sign in with Google
            </button>
            {supabaseConfig.localDevAuthEnabled ? (
              <button
                type="button"
                className="secondary-button full-width stacked-button"
                onClick={useLocalPreview}
                disabled={busy}
              >
                Use local UI preview
              </button>
            ) : null}
          </>
        )}
        {message ? <div className="notice">{message}</div> : null}
      </section>
    </main>
  );
}

export function PasswordRecoveryPage({ onComplete }: { onComplete: () => void }) {
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const updatePassword = async (event: FormEvent) => {
    event.preventDefault();
    if (!supabase || !password || password !== confirmPassword) return;
    setBusy(true);
    setMessage(null);
    const { error } = await supabase.auth.updateUser({ password });
    if (error) {
      setMessage(error.message);
      setBusy(false);
      return;
    }

    await supabase.auth.signOut();
    setBusy(false);
    onComplete();
  };

  return (
    <main className="auth-screen">
      <section className="auth-panel">
        <div className="brand-mark">ḥꜣw</div>
        <h1>Set Password</h1>
        <p>Create the password you will use for normal admin sign-in.</p>
        <form onSubmit={updatePassword} className="auth-form">
          <label htmlFor="new-password">New password</label>
          <input
            id="new-password"
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            autoComplete="new-password"
          />
          <label htmlFor="confirm-password">Confirm password</label>
          <input
            id="confirm-password"
            type="password"
            value={confirmPassword}
            onChange={(event) => setConfirmPassword(event.target.value)}
            autoComplete="new-password"
          />
          <button
            type="submit"
            disabled={busy || !password || password !== confirmPassword}
          >
            Set password
          </button>
        </form>
        {password && confirmPassword && password !== confirmPassword ? (
          <div className="notice danger">Passwords do not match.</div>
        ) : null}
        {message ? <div className="notice danger">{message}</div> : null}
      </section>
    </main>
  );
}
