import { motion } from "motion/react";
import { TrendingUp, ChevronRight } from "lucide-react";

interface Debt {
  from: string;
  to: string;
  amount: number;
  currency: string;
}

interface ChatSummaryMessageProps {
  userName: string;
  userAvatar: string;
  timestamp: string;
  debts: Debt[];
  onViewInBudget?: () => void;
}

export function ChatSummaryMessage({
  userName,
  userAvatar,
  timestamp,
  debts,
  onViewInBudget,
}: ChatSummaryMessageProps) {
  const totalOwed = debts.reduce((sum, d) => sum + d.amount, 0);

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      className="max-w-sm"
    >
      {/* Regular chat message style */}
      <div className="flex items-start gap-2 mb-1">
        <span className="text-xl mt-1">{userAvatar}</span>
        <div className="flex-1">
          <div className="flex items-baseline gap-2 mb-1">
            <span className="text-foreground" style={{ fontSize: "14px" }}>
              {userName}
            </span>
            <span className="text-muted-foreground" style={{ fontSize: "11px" }}>
              {timestamp}
            </span>
          </div>

          {/* Summary Card Message */}
          <div
            className="rounded-2xl p-4 border border-border"
            style={{
              background: "var(--ouest-gradient-soft)",
            }}
          >
            <div className="flex items-start gap-3 mb-3">
              <div
                className="p-2 rounded-xl"
                style={{
                  background: "var(--ouest-gradient-main)",
                }}
              >
                <TrendingUp className="w-4 h-4 text-white" />
              </div>
              <div className="flex-1">
                <h4 className="text-foreground mb-1">💰 Split Summary</h4>
                <p className="text-muted-foreground" style={{ fontSize: "13px" }}>
                  {debts.length} {debts.length === 1 ? "balance" : "balances"} outstanding
                </p>
              </div>
            </div>

            {/* Debt List */}
            <div className="space-y-2 mb-3">
              {debts.map((debt, index) => (
                <div
                  key={index}
                  className="flex items-center justify-between py-2 px-3 rounded-lg bg-card/50"
                >
                  <span className="text-foreground" style={{ fontSize: "13px" }}>
                    {debt.from} → {debt.to}
                  </span>
                  <span className="text-foreground" style={{ fontSize: "13px" }}>
                    {debt.currency} ${debt.amount.toFixed(2)}
                  </span>
                </div>
              ))}
            </div>

            <div
              className="py-2 px-3 rounded-lg mb-3 text-center"
              style={{
                background: "var(--ouest-gradient-main)",
              }}
            >
              <p className="text-white/80 mb-0.5" style={{ fontSize: "12px" }}>
                Total Outstanding
              </p>
              <p className="text-white">
                CAD ${totalOwed.toFixed(2)}
              </p>
            </div>

            {/* View Button */}
            <button
              onClick={onViewInBudget}
              className="w-full flex items-center justify-center gap-2 py-2.5 px-4 rounded-xl bg-card hover:bg-card/80 transition-colors border border-border"
              style={{
                fontSize: "13px",
              }}
            >
              <span className="text-foreground">View in Budget Tracker</span>
              <ChevronRight className="w-4 h-4 text-muted-foreground" />
            </button>
          </div>
        </div>
      </div>
    </motion.div>
  );
}
