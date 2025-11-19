"use client";

import { motion } from "motion/react";
import { MessageCircle, MoreHorizontal } from "lucide-react";
import { useState } from "react";
import { Expense } from "../hooks/useExpenses";

interface ExpenseCardProps {
  expense: Expense;
  onViewChat?: () => void;
  onEdit?: () => void;
  onDelete?: () => void;
}

const categoryConfig = {
  food: { emoji: "🍽️", color: "#FF8B94", label: "Food" },
  transport: { emoji: "🚕", color: "#4F8FFF", label: "Transport" },
  stay: { emoji: "🏨", color: "#C77DFF", label: "Accommodation" },
  activities: { emoji: "🎟️", color: "#6366F1", label: "Activities" },
  other: { emoji: "📦", color: "#10b981", label: "Other" },
};

export function ExpenseCard({ expense, onViewChat, onEdit, onDelete }: ExpenseCardProps) {
  const [showOptions, setShowOptions] = useState(false);
  const config = categoryConfig[expense.category];
  
  // Get user display name and avatar
  const userName = expense.paidByProfile?.display_name || 'User';
  const userAvatar = expense.paidByProfile?.avatar_url;

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      whileTap={{ scale: 0.98 }}
      className="bg-card rounded-2xl p-4 border border-border shadow-md hover:shadow-lg transition-all"
    >
      <div className="flex items-start gap-3">
        {/* Category Icon */}
        <div
          className="p-3 rounded-xl flex-shrink-0"
          style={{
            backgroundColor: `${config.color}15`,
          }}
        >
          <span className="text-2xl leading-none">{config.emoji}</span>
        </div>

        {/* Expense Details */}
        <div className="flex-1 min-w-0">
          <div className="flex items-start justify-between gap-2 mb-1">
            <h4 className="text-foreground truncate">{expense.title}</h4>
            <div className="text-foreground whitespace-nowrap">
              {expense.currency} ${expense.amount.toFixed(2)}
            </div>
          </div>

          <div className="flex items-center gap-2 mb-2">
            {/* User Avatar or Profile Picture */}
            {userAvatar && userAvatar.startsWith('http') ? (
              <img 
                src={userAvatar} 
                alt={userName}
                className="w-5 h-5 rounded-full object-cover"
              />
            ) : (
              <span className="text-base leading-none">{userAvatar || '👤'}</span>
            )}
            <p className="text-muted-foreground" style={{ fontSize: "13px" }}>
              Paid by {userName}
            </p>
          </div>

          <div className="flex items-center justify-between">
            <span className="text-muted-foreground" style={{ fontSize: "12px" }}>
              Split among {expense.splitAmong || expense.split_among?.length || 1} {(expense.splitAmong || expense.split_among?.length || 1) === 1 ? "person" : "people"}
            </span>

            <div className="flex items-center gap-2">
              {expense.hasChat && (
                <button
                  onClick={onViewChat}
                  className="p-1.5 rounded-lg hover:bg-muted transition-colors"
                >
                  <MessageCircle className="w-4 h-4 text-muted-foreground" />
                </button>
              )}

              <button
                onClick={() => setShowOptions(!showOptions)}
                className="p-1.5 rounded-lg hover:bg-muted transition-colors"
              >
                <MoreHorizontal className="w-4 h-4 text-muted-foreground" />
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Options Menu */}
      {showOptions && (
        <motion.div
          initial={{ opacity: 0, height: 0 }}
          animate={{ opacity: 1, height: "auto" }}
          exit={{ opacity: 0, height: 0 }}
          className="mt-3 pt-3 border-t border-border flex gap-2"
        >
          <button
            onClick={onEdit}
            className="flex-1 py-2 px-3 rounded-lg bg-muted hover:bg-muted/70 transition-colors text-foreground"
            style={{ fontSize: "13px" }}
          >
            Edit
          </button>
          {onViewChat && (
            <button
              onClick={onViewChat}
              className="flex-1 py-2 px-3 rounded-lg bg-muted hover:bg-muted/70 transition-colors text-foreground"
              style={{ fontSize: "13px" }}
            >
              View Chat
            </button>
          )}
          <button
            onClick={onDelete}
            className="flex-1 py-2 px-3 rounded-lg bg-destructive/10 hover:bg-destructive/20 transition-colors text-destructive"
            style={{ fontSize: "13px" }}
          >
            Delete
          </button>
        </motion.div>
      )}
    </motion.div>
  );
}
