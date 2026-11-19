import { createClient } from "@supabase/supabase-js";

// Server-only Supabase client. Service-role key MUST stay on the server —
// never expose to the browser. Used by /api routes to fetch public preview
// fields (trip metadata, profile metadata) for OG tag rendering.
//
// Env vars required on Vercel:
//   SUPABASE_URL                — e.g. https://xyz.supabase.co
//   SUPABASE_SERVICE_ROLE_KEY   — service_role key from Supabase dashboard
//
// Convention: callers only ever SELECT. No INSERT/UPDATE/DELETE from web.
export function supabaseAdmin() {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) {
    throw new Error(
      "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY env var. " +
        "Set both in Vercel project settings."
    );
  }
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
