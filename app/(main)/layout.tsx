"use client";

import { Navigation } from "@/components/Navigation";
import { usePathname, useRouter } from "next/navigation";
import { useAuth } from "@/contexts/AuthContext";
import { useDemoMode } from "@/contexts/DemoModeContext";
import { useEffect } from "react";

export default function MainLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const router = useRouter();
  const { user, loading } = useAuth();
  const { isDemoMode } = useDemoMode();
  
  // Redirect to login if not authenticated and not in demo mode
  useEffect(() => {
    if (!loading && !isDemoMode && !user) {
      router.push("/login");
    }
  }, [user, loading, isDemoMode, router]);
  
  // Hide navigation on detail screens (trips and entry requirements)
  const hideNavigation = pathname.startsWith("/trips") || pathname.includes("/entry-requirements");

  // Show loading state while checking auth
  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="max-w-md mx-auto relative min-h-screen bg-background shadow-2xl flex items-center justify-center">
          <div className="text-center">
            <div className="w-12 h-12 mx-auto mb-4 rounded-xl animate-pulse" 
                 style={{ background: "var(--ouest-gradient-main)" }}>
            </div>
            <p className="text-muted-foreground">Loading...</p>
          </div>
        </div>
      </div>
    );
  }

  // Show nothing while redirecting to login
  if (!isDemoMode && !user) {
    return null;
  }

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

