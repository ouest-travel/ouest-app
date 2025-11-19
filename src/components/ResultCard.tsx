"use client";

import { motion } from "motion/react";
import { CheckCircle2, Clock, XCircle, ChevronDown, ExternalLink, Syringe, AlertTriangle } from "lucide-react";
import { useState } from "react";

interface Country {
  code: string;
  name: string;
  flag: string;
}

interface ResultCardProps {
  from: Country;
  to: Country;
  status: "no-visa" | "visa-on-arrival" | "visa-required";
}

const statusConfig = {
  "no-visa": {
    icon: CheckCircle2,
    color: "#10b981",
    title: "No Visa Required",
    description: "You can enter without a visa for tourism stays up to 90 days.",
  },
  "visa-on-arrival": {
    icon: Clock,
    color: "#f59e0b",
    title: "Visa on Arrival",
    description: "Visa available on arrival for tourism stays up to 90 days.",
  },
  "visa-required": {
    icon: XCircle,
    color: "#ef4444",
    title: "Visa Required",
    description: "You must obtain a visa before traveling for any length of stay.",
  },
};

export function ResultCard({ from, to, status }: ResultCardProps) {
  const [showDetails, setShowDetails] = useState(false);
  const config = statusConfig[status];
  const StatusIcon = config.icon;

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.1 }}
      className="bg-card rounded-3xl border border-border overflow-hidden shadow-lg"
    >
      {/* Header */}
      <div className="px-6 py-5 border-b border-border">
        <div className="flex items-center justify-center gap-3 mb-4">
          <span className="text-4xl">{from.flag}</span>
          <div
            className="px-4 py-1 rounded-full"
            style={{
              background: "var(--ouest-gradient-soft)",
            }}
          >
            <span className="text-muted-foreground">→</span>
          </div>
          <span className="text-4xl">{to.flag}</span>
        </div>

        <div className="text-center">
          <p className="text-muted-foreground mb-2" style={{ fontSize: '14px' }}>
            {from.name} → {to.name}
          </p>
        </div>
      </div>

      {/* Status */}
      <div className="px-6 py-6">
        <div className="flex items-start gap-4">
          <div
            className="p-3 rounded-2xl"
            style={{
              backgroundColor: `${config.color}15`,
            }}
          >
            <StatusIcon
              className="w-6 h-6"
              style={{ color: config.color }}
            />
          </div>

          <div className="flex-1">
            <h3 className="mb-1 text-foreground">{config.title}</h3>
            <p className="text-muted-foreground">{config.description}</p>
          </div>
        </div>

        {/* Expandable Details */}
        <button
          onClick={() => setShowDetails(!showDetails)}
          className="w-full mt-4 flex items-center justify-between px-4 py-3 rounded-xl bg-muted hover:bg-muted/70 transition-colors"
        >
          <span className="text-foreground">More Details</span>
          <ChevronDown
            className={`w-5 h-5 text-muted-foreground transition-transform ${
              showDetails ? "rotate-180" : ""
            }`}
          />
        </button>

        {/* Details Content */}
        <motion.div
          initial={false}
          animate={{
            height: showDetails ? "auto" : 0,
            opacity: showDetails ? 1 : 0,
          }}
          transition={{ duration: 0.3 }}
          className="overflow-hidden"
        >
          <div className="mt-4 space-y-3">
            {/* Vaccination Requirements */}
            <div className="flex items-start gap-3 p-4 rounded-xl bg-muted/50">
              <Syringe className="w-5 h-5 text-muted-foreground mt-0.5" />
              <div>
                <h4 className="text-foreground mb-1">Vaccinations</h4>
                <p className="text-muted-foreground" style={{ fontSize: '14px' }}>
                  Check with your healthcare provider for recommended vaccinations. Some countries may require proof of yellow fever vaccination.
                </p>
              </div>
            </div>

            {/* Travel Alerts */}
            <div className="flex items-start gap-3 p-4 rounded-xl bg-muted/50">
              <AlertTriangle className="w-5 h-5 text-muted-foreground mt-0.5" />
              <div>
                <h4 className="text-foreground mb-1">Travel Alerts</h4>
                <p className="text-muted-foreground" style={{ fontSize: '14px' }}>
                  Check your government's travel advisory website for current safety and security information.
                </p>
              </div>
            </div>
          </div>
        </motion.div>

        {/* Official Link */}
        <a
          href={`https://www.henleyglobal.com/passport-index`}
          target="_blank"
          rel="noopener noreferrer"
          className="mt-4 flex items-center justify-between px-4 py-3 rounded-xl border border-border hover:border-foreground/20 transition-colors group"
        >
          <span className="text-foreground">See official visa details</span>
          <ExternalLink className="w-4 h-4 text-muted-foreground group-hover:text-foreground transition-colors" />
        </a>
      </div>
    </motion.div>
  );
}
