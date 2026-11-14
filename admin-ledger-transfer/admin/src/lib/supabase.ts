import { createClient } from "@supabase/supabase-js";

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL?.trim() ?? "";
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY?.trim() ?? "";
const defaultStaffEmail =
  import.meta.env.VITE_ADMIN_DEFAULT_EMAIL?.trim() ?? "";
const localDevPassword = import.meta.env.DEV
  ? import.meta.env.VITE_ADMIN_DEV_PASSWORD?.trim() ?? ""
  : "";
const localDevAuthKey = "haw_admin_local_dev_auth";

export const supabaseConfig = {
  url: supabaseUrl,
  anonKey: supabaseAnonKey,
  defaultStaffEmail,
  localDevAuthEnabled: import.meta.env.DEV && localDevPassword.length > 0,
  isConfigured: supabaseUrl.length > 0 && supabaseAnonKey.length > 20,
};

export const supabase = supabaseConfig.isConfigured
  ? createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUrl: true,
      },
    })
  : null;

export function matchesLocalDevPassword(password: string) {
  return supabaseConfig.localDevAuthEnabled && password === localDevPassword;
}

export function isLocalDevAuthenticated() {
  return import.meta.env.DEV &&
    window.localStorage.getItem(localDevAuthKey) === "1";
}

export function setLocalDevAuthenticated(value: boolean) {
  if (!import.meta.env.DEV) return;
  if (value) {
    window.localStorage.setItem(localDevAuthKey, "1");
  } else {
    window.localStorage.removeItem(localDevAuthKey);
  }
}
