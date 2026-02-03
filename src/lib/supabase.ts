import { createClient } from "@supabase/supabase-js";
import type { Database } from "../types/database";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || "";
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "";

export const isSupabaseConfigured = !!(
  supabaseUrl && 
  supabaseAnonKey && 
  supabaseUrl !== "" && 
  supabaseAnonKey !== ""
);

if (!isSupabaseConfigured) {
  if (process.env.NODE_ENV === "development") {
    console.warn(
      "Supabase credentials not found. App will run in limited mode. Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY to enable full functionality."
    );
  }
}

// Create client with fallback values to prevent initialization errors
// Actual Supabase operations will fail gracefully if credentials are missing
export const supabase = createClient<Database>(
  supabaseUrl || "https://placeholder.supabase.co",
  supabaseAnonKey || "placeholder-key",
  {
    auth: {
      persistSession: isSupabaseConfigured,
      autoRefreshToken: isSupabaseConfigured,
    },
    realtime: {
      params: {
        eventsPerSecond: 10,
      },
    },
  }
);
