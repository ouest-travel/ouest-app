import { motion } from "motion/react";
import { DollarSign } from "lucide-react";

interface ChatExpenseMessageProps {
  userName: string;
  userAvatar: string;
  expenseTitle: string;
  amount: number;
  currency: string;
  splitAmong: number;
  timestamp: string;
  onViewInBudget?: () => void;
}

export function ChatExpenseMessage({
  userName,
  userAvatar,
  expenseTitle,
  amount,
  currency,
  splitAmong,
  timestamp,
  onViewInBudget,
}: ChatExpenseMessageProps) {
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

          {/* Expense Card Message */}
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
                <DollarSign className="w-4 h-4 text-white" />
              </div>
              <div className="flex-1">
                <p className="text-muted-foreground mb-1" style={{ fontSize: "12px" }}>
                  added a new expense:
                </p>
                <h4 className="text-foreground mb-1">{expenseTitle}</h4>
                <p className="text-foreground">
                  {currency} ${amount.toFixed(2)}
                </p>
              </div>
            </div>

            <p className="text-muted-foreground mb-3" style={{ fontSize: "13px" }}>
              Split among {splitAmong} {splitAmong === 1 ? "person" : "people"}
            </p>

            {/* View in Budget Button */}
            <button
              onClick={onViewInBudget}
              className="w-full py-2.5 px-4 rounded-xl text-white hover:opacity-90 transition-opacity"
              style={{
                background: "var(--ouest-gradient-main)",
                fontSize: "13px",
              }}
            >
              💸 View in Budget Tracker
            </button>
          </div>
        </div>
      </div>
    </motion.div>
  );
}
