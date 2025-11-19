"use client";

import { X, ArrowRight, DollarSign, Download, Share2 } from "lucide-react";
import { motion, AnimatePresence } from "motion/react";
import { useState } from "react";
import { SettleUpModal } from "./SettleUpModal";
import { toast } from "sonner";

interface Member {
  id: string;
  name: string;
  avatar: string;
}

interface Debt {
  from: Member;
  to: Member;
  amount: number;
  currency: string;
}

interface SplitSummaryModalProps {
  isOpen: boolean;
  onClose: () => void;
  debts: Debt[];
  onSettleUp?: (debt: Debt) => void;
  onExport?: () => void;
  onShare?: () => void;
}

export function SplitSummaryModal({ 
  isOpen, 
  onClose, 
  debts: initialDebts, 
  onSettleUp,
  onExport,
  onShare 
}: SplitSummaryModalProps) {
  const [debts, setDebts] = useState(initialDebts);
  const [showSettleUp, setShowSettleUp] = useState(false);
  const [selectedDebt, setSelectedDebt] = useState<Debt | null>(null);

  const handleSettleUpClick = (debt: Debt) => {
    setSelectedDebt(debt);
    setShowSettleUp(true);
  };

  const handleConfirmPayment = (method: string) => {
    if (selectedDebt) {
      // Remove the settled debt
      setDebts(debts.filter(d => d !== selectedDebt));
      onSettleUp?.(selectedDebt);
      toast.success(`Payment sent via ${method}!`, {
        description: `${selectedDebt.from.name} paid ${selectedDebt.to.name} ${selectedDebt.currency} $${selectedDebt.amount.toFixed(2)}`,
      });
    }
  };

  const handleExport = () => {
    // Create a summary text
    const summary = `
Split Summary - ${new Date().toLocaleDateString()}
${"=".repeat(40)}

Outstanding Balances:
${debts.map(d => `• ${d.from.name} owes ${d.to.name}: ${d.currency} $${d.amount.toFixed(2)}`).join('\n')}

Total Outstanding: ${debts.reduce((sum, d) => sum + d.amount, 0).toFixed(2)} CAD
    `.trim();

    // Create and download a text file
    const blob = new Blob([summary], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `split-summary-${Date.now()}.txt`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);

    toast.success("Summary exported!", {
      description: "File downloaded to your device",
    });
    onExport?.();
  };

  const handleShare = async () => {
    const summary = debts.length > 0
      ? `💰 Split Summary\n\n${debts.map(d => `${d.from.name} → ${d.to.name}: ${d.currency} ${d.amount.toFixed(2)}`).join('\n')}\n\nTotal Outstanding: CAD ${debts.reduce((sum, d) => sum + d.amount, 0).toFixed(2)}`
      : "✨ All settled up! No outstanding balances.";

    try {
      // Try to use Web Share API if available
      if (navigator.share) {
        await navigator.share({
          title: 'Trip Budget Split Summary',
          text: summary,
        });
        toast.success("Shared successfully!");
      } else {
        // Fallback to clipboard
        await navigator.clipboard.writeText(summary);
        toast.success("Copied to clipboard!", {
          description: "Paste in your group chat",
        });
      }
    } catch (error) {
      // If share is cancelled or fails, just copy to clipboard
      try {
        await navigator.clipboard.writeText(summary);
        toast.success("Copied to clipboard!", {
          description: "Paste in your group chat",
        });
      } catch (e) {
        toast.error("Failed to copy", {
          description: "Please try again",
        });
      }
    }
    
    onShare?.();
  };

  return (
    <>
      <AnimatePresence>
        {isOpen && (
          <>
            {/* Backdrop */}
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={onClose}
              className="fixed inset-0 bg-black/40 backdrop-blur-sm z-50"
            />

            {/* Modal */}
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.95 }}
              transition={{ type: "spring", stiffness: 300, damping: 30 }}
              className="fixed inset-4 max-w-md mx-auto my-auto max-h-[80vh] bg-card rounded-3xl shadow-2xl z-50 overflow-hidden flex flex-col"
            >
              {/* Header */}
              <div
                className="px-6 py-5 border-b border-border"
                style={{
                  background: "var(--ouest-gradient-soft)",
                }}
              >
                <div className="flex items-center justify-between">
                  <div>
                    <h2 className="text-foreground">Who Owes Who</h2>
                    <p className="text-muted-foreground" style={{ fontSize: "14px" }}>
                      {debts.length} {debts.length === 1 ? "balance" : "balances"} to settle
                    </p>
                  </div>
                  <button
                    onClick={onClose}
                    className="p-2 rounded-full hover:bg-muted transition-colors"
                  >
                    <X className="w-5 h-5 text-foreground" />
                  </button>
                </div>
              </div>

              {/* Content */}
              <div className="flex-1 overflow-y-auto px-6 py-6 space-y-4">
                {debts.length === 0 ? (
                  <motion.div
                    initial={{ opacity: 0, scale: 0.9 }}
                    animate={{ opacity: 1, scale: 1 }}
                    className="flex flex-col items-center justify-center py-12 text-center"
                  >
                    <div
                      className="w-20 h-20 rounded-full flex items-center justify-center mb-4"
                      style={{
                        background: "var(--ouest-gradient-soft)",
                      }}
                    >
                      <span className="text-4xl">✨</span>
                    </div>
                    <h3 className="text-foreground mb-2">All Settled Up!</h3>
                    <p className="text-muted-foreground max-w-xs">
                      No outstanding balances. Everyone's square!
                    </p>
                  </motion.div>
                ) : (
                  debts.map((debt, index) => (
                    <motion.div
                      key={`${debt.from.id}-${debt.to.id}-${index}`}
                      initial={{ opacity: 0, x: -20 }}
                      animate={{ opacity: 1, x: 0 }}
                      transition={{ delay: index * 0.1 }}
                      className="bg-card border border-border rounded-2xl p-5 shadow-md"
                    >
                      {/* Visual Connection */}
                      <div className="flex items-center justify-between mb-4">
                        <div className="flex flex-col items-center">
                          <span className="text-4xl mb-2">{debt.from.avatar}</span>
                          <span className="text-foreground" style={{ fontSize: "13px" }}>
                            {debt.from.name}
                          </span>
                        </div>

                        <div className="flex-1 mx-4 relative">
                          <div
                            className="h-1 rounded-full"
                            style={{
                              background: "var(--ouest-gradient-main)",
                            }}
                          />
                          <motion.div
                            animate={{ x: [0, 10, 0] }}
                            transition={{ duration: 2, repeat: Infinity }}
                            className="absolute right-0 top-1/2 -translate-y-1/2"
                          >
                            <ArrowRight className="w-5 h-5" style={{ color: "var(--ouest-pink)" }} />
                          </motion.div>
                        </div>

                        <div className="flex flex-col items-center">
                          <span className="text-4xl mb-2">{debt.to.avatar}</span>
                          <span className="text-foreground" style={{ fontSize: "13px" }}>
                            {debt.to.name}
                          </span>
                        </div>
                      </div>

                      {/* Amount */}
                      <div
                        className="text-center py-3 px-4 rounded-xl mb-3"
                        style={{
                          background: "var(--ouest-gradient-soft)",
                        }}
                      >
                        <p className="text-muted-foreground mb-1" style={{ fontSize: "12px" }}>
                          {debt.from.name} owes
                        </p>
                        <div className="text-foreground">
                          {debt.currency} ${debt.amount.toFixed(2)}
                        </div>
                      </div>

                      {/* Settle Up Button */}
                      <button
                        onClick={() => handleSettleUpClick(debt)}
                        className="w-full py-3 px-4 rounded-xl border-2 hover:bg-muted transition-all group"
                        style={{
                          borderColor: "var(--ouest-blue)",
                          color: "var(--ouest-blue)",
                        }}
                      >
                        <span className="flex items-center justify-center gap-2">
                          <DollarSign className="w-4 h-4" />
                          Settle Up
                        </span>
                      </button>
                    </motion.div>
                  ))
                )}
              </div>

              {/* Footer Actions */}
              <div className="px-6 py-4 border-t border-border space-y-3">
                <button
                  onClick={handleExport}
                  className="w-full py-3 px-4 rounded-xl bg-muted hover:bg-muted/70 transition-colors text-foreground"
                >
                  <span className="flex items-center justify-center gap-2">
                    <Download className="w-4 h-4" />
                    Export Summary
                  </span>
                </button>
                <button
                  onClick={handleShare}
                  className="w-full py-3 px-4 rounded-xl border border-border hover:border-foreground/20 transition-colors text-foreground"
                >
                  <span className="flex items-center justify-center gap-2">
                    <Share2 className="w-4 h-4" />
                    Share in Chat
                  </span>
                </button>
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>

      {/* Settle Up Modal */}
      <SettleUpModal
        isOpen={showSettleUp}
        onClose={() => setShowSettleUp(false)}
        debt={selectedDebt}
        onConfirmPayment={handleConfirmPayment}
      />
    </>
  );
}
