"use client";

import { useState } from "react";
import { ArrowLeft, Info } from "lucide-react";
import { motion } from "motion/react";
import { CountrySelector } from "./CountrySelector";
import { ResultCard } from "./ResultCard";
import { LoadingState } from "./LoadingState";
import { InfoModal } from "./InfoModal";

interface Country {
  code: string;
  name: string;
  flag: string;
}

interface EntryRequirementsProps {
  onBack: () => void;
}

export function EntryRequirements({ onBack }: EntryRequirementsProps) {
  const [passportCountry, setPassportCountry] = useState<Country | null>(null);
  const [destinationCountry, setDestinationCountry] = useState<Country | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [showResult, setShowResult] = useState(false);
  const [showInfo, setShowInfo] = useState(false);

  const handleCheckRequirements = async () => {
    if (!passportCountry || !destinationCountry) return;

    setIsLoading(true);
    setShowResult(false);

    // Simulate API call
    await new Promise((resolve) => setTimeout(resolve, 1500));

    setIsLoading(false);
    setShowResult(true);
  };

  // Determine visa status based on countries (mock logic)
  const getVisaStatus = () => {
    if (!passportCountry || !destinationCountry) return "visa-required";
    
    // Mock logic for demonstration
    const powerfulPassports = ["US", "CA", "GB", "FR", "DE", "IT", "ES", "JP", "AU"];
    const easyDestinations = ["US", "CA", "GB", "FR", "DE", "IT", "ES", "JP", "AU", "SG", "TH"];
    
    if (powerfulPassports.includes(passportCountry.code) && easyDestinations.includes(destinationCountry.code)) {
      return "no-visa" as const;
    } else if (passportCountry.code === "US" || passportCountry.code === "CA") {
      return "visa-on-arrival" as const;
    }
    
    return "visa-required" as const;
  };

  return (
    <div className="min-h-screen bg-background pb-24">
      {/* Header with gradient shimmer */}
      <div
        className="relative px-6 pt-safe-top pb-8 overflow-hidden"
        style={{
          background: "var(--ouest-gradient-main)",
        }}
      >
        {/* Animated shimmer effect */}
        <div className="absolute inset-0 shimmer-animate opacity-30" />

        <div className="relative z-10">
          <div className="flex items-center justify-between mb-6">
            <button
              onClick={onBack}
              className="p-2 rounded-full bg-white/20 hover:bg-white/30 transition-colors"
            >
              <ArrowLeft className="w-5 h-5 text-white" />
            </button>

            <button
              onClick={() => setShowInfo(true)}
              className="p-2 rounded-full bg-white/20 hover:bg-white/30 transition-colors"
            >
              <Info className="w-5 h-5 text-white" />
            </button>
          </div>

          <h1 className="text-white mb-2">Entry Requirements</h1>
          <p className="text-white/90" style={{ fontSize: '15px' }}>
            Check visa and travel rules before you book.
          </p>
        </div>
      </div>

      {/* Content */}
      <div className="px-6 -mt-4">
        {/* Input Card - Apple Wallet style */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-card rounded-3xl p-6 shadow-xl border border-border mb-6"
        >
          <div className="space-y-5">
            <CountrySelector
              label="Your Passport"
              value={passportCountry}
              onChange={setPassportCountry}
            />

            <CountrySelector
              label="Destination"
              value={destinationCountry}
              onChange={setDestinationCountry}
            />

            <button
              onClick={handleCheckRequirements}
              disabled={!passportCountry || !destinationCountry || isLoading}
              className="w-full py-4 rounded-2xl text-white shadow-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed hover:shadow-xl active:scale-98"
              style={{
                background: passportCountry && destinationCountry
                  ? "var(--ouest-gradient-main)"
                  : "#e5e7eb",
              }}
            >
              Check Requirements
            </button>
          </div>
        </motion.div>

        {/* Loading State */}
        {isLoading && <LoadingState />}

        {/* Result Card */}
        {showResult && !isLoading && passportCountry && destinationCountry && (
          <ResultCard
            from={passportCountry}
            to={destinationCountry}
            status={getVisaStatus()}
          />
        )}

        {/* Empty State - commented out for now since we always show result
        {!showResult && !isLoading && (
          <EmptyState />
        )}
        */}

        {/* Navigation Hint */}
        {!showResult && !isLoading && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.5 }}
            className="mt-12 text-center"
          >
            <p className="text-muted-foreground" style={{ fontSize: '14px' }}>
              More travel tools in Guide →
            </p>
          </motion.div>
        )}
      </div>

      {/* Info Modal */}
      <InfoModal isOpen={showInfo} onClose={() => setShowInfo(false)} />
    </div>
  );
}
