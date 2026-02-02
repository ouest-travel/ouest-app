"use client";

import {
  createContext,
  useContext,
  useState,
  useEffect,
  ReactNode,
} from "react";
import { User, Session, AuthError } from "@supabase/supabase-js";
import { supabase } from "../lib/supabase";
import { useDemoMode } from "./DemoModeContext";

const DEFAULT_EMAIL_REDIRECT_URL =
  process.env.NEXT_PUBLIC_SUPABASE_EMAIL_REDIRECT_URL ??
  (process.env.NODE_ENV === "production"
    ? "https://beta.ouest.app"
    : "http://localhost:3000");

interface AuthContextType {
  user: User | null;
  session: Session | null;
  loading: boolean;
  signUp: (
    email: string,
    password: string,
    displayName?: string
  ) => Promise<{ user: User | null; error: AuthError | null }>;
  signIn: (
    email: string,
    password: string
  ) => Promise<{ user: User | null; error: AuthError | null }>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  const { isDemoMode } = useDemoMode();

  useEffect(() => {
    // Skip auth in demo mode
    if (isDemoMode) {
      setUser(null);
      setSession(null);
      setLoading(false);
      return;
    }

    // Get initial session
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      setUser(session?.user ?? null);
      setLoading(false);
    });

    // Listen for auth changes
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session);
      setUser(session?.user ?? null);
      setLoading(false);
    });

    return () => subscription.unsubscribe();
  }, [isDemoMode]);

  const signUp = async (
    email: string,
    password: string,
    displayName?: string
  ) => {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: DEFAULT_EMAIL_REDIRECT_URL,
        data: {
          display_name: displayName,
        },
      },
    });

    if (data.user && !error) {
      // Generate a basic handle from display name or email
      const baseHandle = (displayName || email.split("@")[0])
        .toLowerCase()
        .replace(/[^a-z0-9]/g, "");

      // Create profile (handle will be made unique by database trigger if needed)
      await supabase.from("profiles").insert({
        id: data.user.id,
        email: data.user.email!,
        display_name: displayName || null,
        handle: baseHandle || "user",
      } as any);
    }

    return { user: data.user, error };
  };

  const signIn = async (email: string, password: string) => {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    return { user: data.user, error };
  };

  const signOut = async () => {
    await supabase.auth.signOut();
  };

  return (
    <AuthContext.Provider
      value={{ user, session, loading, signUp, signIn, signOut }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}
