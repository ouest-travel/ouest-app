import { useState } from "react";
import { ThemeProvider } from "./components/ThemeProvider";
import { DemoModeProvider } from "./contexts/DemoModeContext";
import { AuthProvider, useAuth } from "./contexts/AuthContext";
import { useDemoMode } from "./contexts/DemoModeContext";
import { Navigation } from "./components/Navigation";
import { HomeScreen } from "./components/HomeScreen";
import { GuideScreen } from "./components/GuideScreen";
import { CommunityScreen } from "./components/CommunityScreen";
import { YouScreen } from "./components/YouScreen";
import { EntryRequirements } from "./components/EntryRequirements";
import { BudgetOverviewScreen } from "./components/BudgetOverviewScreen";
import { ChatDemoScreen } from "./components/ChatDemoScreen";
import { LoginScreen } from "./components/auth/LoginScreen";
import { SignUpScreen } from "./components/auth/SignUpScreen";
import { Toaster } from "./components/ui/sonner";

type Tab = "home" | "guide" | "community" | "you";
type Screen = Tab | "entry-requirements" | "budget" | "chat";

function AppContent() {
  const { user, loading } = useAuth();
  const { isDemoMode } = useDemoMode();
  const [showSignUp, setShowSignUp] = useState(false);
  const [activeTab, setActiveTab] = useState<Tab>("home");
  const [currentScreen, setCurrentScreen] = useState<Screen>("home");
  const [currentTripName, setCurrentTripName] = useState<string>("Tokyo Adventure");
  const [currentTripId, setCurrentTripId] = useState<number | null>(null);

  const handleTabChange = (tab: Tab) => {
    setActiveTab(tab);
    setCurrentScreen(tab);
  };

  const handleNavigateToEntryRequirements = () => {
    setCurrentScreen("entry-requirements");
  };

  const handleNavigateToBudget = (tripName?: string, tripId?: number) => {
    if (tripName) setCurrentTripName(tripName);
    if (tripId !== undefined) setCurrentTripId(tripId);
    setCurrentScreen("budget");
  };

  const handleBackToGuide = () => {
    setCurrentScreen("guide");
    setActiveTab("guide");
  };

  const handleBackToHome = () => {
    setCurrentScreen("home");
    setActiveTab("home");
  };

  const handleNavigateToChat = () => {
    setCurrentScreen("chat");
  };

  const handleBackToBudget = () => {
    setCurrentScreen("budget");
  };

  // Show auth screens if not in demo mode and not authenticated
  if (!isDemoMode && !loading && !user) {
    return (
      <>
        <Toaster richColors position="top-center" />
        {showSignUp ? (
          <SignUpScreen onSwitchToLogin={() => setShowSignUp(false)} />
        ) : (
          <LoginScreen onSwitchToSignUp={() => setShowSignUp(true)} />
        )}
      </>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <Toaster richColors position="top-center" />
      {/* Mobile Container - constrained to max-width for mobile experience */}
      <div className="max-w-md mx-auto relative min-h-screen bg-background shadow-2xl">
        {/* Current Screen */}
        {currentScreen === "home" && (
          <HomeScreen onNavigateToBudget={handleNavigateToBudget} />
        )}
        {currentScreen === "guide" && (
          <GuideScreen 
            onNavigateToEntryRequirements={handleNavigateToEntryRequirements}
            onNavigateToBudget={() => handleNavigateToBudget()}
          />
        )}
        {currentScreen === "community" && <CommunityScreen />}
        {currentScreen === "you" && <YouScreen />}
        {currentScreen === "entry-requirements" && (
          <EntryRequirements onBack={handleBackToGuide} />
        )}
        {currentScreen === "budget" && (
          <BudgetOverviewScreen 
            onBack={handleBackToHome}
            onViewChat={handleNavigateToChat}
            tripName={currentTripName}
            tripId={currentTripId}
          />
        )}
        {currentScreen === "chat" && (
          <ChatDemoScreen 
            onBack={handleBackToBudget}
            onNavigateToBudget={handleBackToBudget}
            tripName={currentTripName}
            tripId={currentTripId}
          />
        )}

        {/* Bottom Navigation - hidden on detail screens */}
        {!["entry-requirements", "budget", "chat"].includes(currentScreen) && (
          <Navigation activeTab={activeTab} onTabChange={handleTabChange} />
        )}
      </div>
    </div>
  );
}

export default function App() {
  return (
    <ThemeProvider>
      <DemoModeProvider>
        <AuthProvider>
          <AppContent />
        </AuthProvider>
      </DemoModeProvider>
    </ThemeProvider>
  );
}