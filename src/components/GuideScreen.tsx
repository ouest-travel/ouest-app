"use client";

import { motion } from "motion/react";
import { Shield, Wallet, Map, FileText, ChevronRight } from "lucide-react";

interface GuideScreenProps {
  onNavigateToEntryRequirements: () => void;
  onNavigateToBudget?: () => void;
}

export function GuideScreen({ onNavigateToEntryRequirements, onNavigateToBudget }: GuideScreenProps) {
  const tools = [
    {
      id: "entry-requirements",
      icon: Shield,
      title: "Entry Requirements",
      description: "Check visa and travel rules",
      color: "var(--ouest-blue)",
      onClick: onNavigateToEntryRequirements,
    },
    {
      id: "budget-tracker",
      icon: Wallet,
      title: "Budget Tracker",
      description: "Track expenses and split costs",
      color: "var(--ouest-pink)",
      onClick: onNavigateToBudget,
    },
    {
      id: "destination-guide",
      icon: Map,
      title: "Destination Guide",
      description: "Explore places and activities",
      color: "var(--ouest-coral)",
    },
    {
      id: "travel-checklist",
      icon: FileText,
      title: "Travel Checklist",
      description: "Never forget what to pack",
      color: "var(--ouest-indigo)",
    },
  ];

  return (
    <div className="min-h-screen bg-background pb-24">
      {/* Header */}
      <div
        className="px-6 pt-12 pb-8"
        style={{
          background: "var(--ouest-gradient-soft)",
        }}
      >
        <div className="max-w-md mx-auto">
          <h1 className="text-foreground mb-2">Travel Guide</h1>
          <p className="text-muted-foreground">
            Essential tools for every journey
          </p>
        </div>
      </div>

      <div className="px-6 -mt-4 max-w-md mx-auto">
        {/* Tools Grid */}
        <div className="space-y-4">
          {tools.map((tool, index) => {
            const Icon = tool.icon;
            return (
              <motion.button
                key={tool.id}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: index * 0.1 }}
                onClick={tool.onClick}
                whileTap={{ scale: 0.98 }}
                className="w-full bg-card rounded-3xl p-6 shadow-lg border border-border hover:shadow-xl transition-all text-left"
              >
                <div className="flex items-center gap-4">
                  <div
                    className="p-4 rounded-2xl"
                    style={{
                      backgroundColor: `${tool.color}15`,
                    }}
                  >
                    <Icon
                      className="w-6 h-6"
                      style={{ color: tool.color }}
                    />
                  </div>

                  <div className="flex-1">
                    <h3 className="text-foreground mb-1">{tool.title}</h3>
                    <p className="text-muted-foreground" style={{ fontSize: '14px' }}>
                      {tool.description}
                    </p>
                  </div>

                  <ChevronRight className="w-5 h-5 text-muted-foreground" />
                </div>
              </motion.button>
            );
          })}
        </div>

        {/* Featured Tip */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.5 }}
          className="mt-8 p-6 rounded-3xl border border-border"
          style={{
            background: "var(--ouest-gradient-soft)",
          }}
        >
          <div className="flex items-start gap-3">
            <span className="text-3xl">💡</span>
            <div>
              <h4 className="text-foreground mb-2">Travel Tip</h4>
              <p className="text-muted-foreground" style={{ fontSize: '14px' }}>
                Always check entry requirements at least 3 months before your trip. Some visas can take weeks to process.
              </p>
            </div>
          </div>
        </motion.div>
      </div>
    </div>
  );
}
