"use client";

import { Navigation } from "@/components/Navigation";
import { usePathname, useRouter } from "next/navigation";
import { useAuth } from "@/contexts/AuthContext";
import { useDemoMode } from "@/contexts/DemoModeContext";
import { isSupabaseConfigured } from "@/lib/supabase";
import { useEffect, useRef } from "react";

export default function MainLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const router = useRouter();
  const { user, loading } = useAuth();
  const { isDemoMode } = useDemoMode();
  const hasCheckedAuth = useRef(false);

  // Only redirect to login on initial load, not when demo mode changes
  // Allow access if: demo mode is enabled, user is logged in, or Supabase isn't configured
  useEffect(() => {
    if (!loading && !hasCheckedAuth.current) {
      hasCheckedAuth.current = true;
      // Allow access if Supabase isn't configured (for development/demo)
      if (!isSupabaseConfigured) {
        return;
      }
      // Otherwise, require auth unless in demo mode
      if (!isDemoMode && !user) {
        router.push("/login");
      }
    }
  }, [user, loading, isDemoMode, router]);

  // Hide navigation on detail screens (trips and entry requirements)
  const hideNavigation =
    pathname.startsWith("/trips") || pathname.includes("/entry-requirements");

  // Show loading state while checking auth (only on initial load)
  if (loading && !hasCheckedAuth.current) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="max-w-md mx-auto relative min-h-screen bg-background shadow-2xl flex items-center justify-center">
          <div className="text-center">
            <img
              src="/ouest-transparent.png"
              alt="Ouest Logo"
              className="w-12 h-12 mx-auto mb-4 animate-pulse"
            />
            <p className="text-muted-foreground">Loading...</p>
          </div>
        </div>
      </div>
    );
  }

  // After initial check, always render the app
  // Users can toggle demo mode without being kicked out
  return (
    <div className="min-h-screen bg-background">
      {/* Mobile Container - constrained to max-width for mobile experience */}
      <div className="max-w-md mx-auto relative min-h-screen bg-background shadow-2xl">
        {children}

        {/* Bottom Navigation - hidden on detail screens */}
        {!hideNavigation && <Navigation />}
      </div>
    </div>
  );
}
