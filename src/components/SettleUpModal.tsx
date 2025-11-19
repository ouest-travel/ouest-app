import { X, CreditCard, Smartphone, Send, Check } from "lucide-react";
import { motion, AnimatePresence } from "motion/react";
import { useState } from "react";

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

interface SettleUpModalProps {
  isOpen: boolean;
  onClose: () => void;
  debt: Debt | null;
  onConfirmPayment: (method: string) => void;
}

const paymentMethods = [
  { id: "paypal", name: "PayPal", icon: "💳", description: "Send money instantly" },
  { id: "applepay", name: "Apple Pay", icon: "📱", description: "Quick & secure" },
  { id: "wise", name: "Wise", icon: "🌍", description: "International transfers" },
  { id: "venmo", name: "Venmo", icon: "💸", description: "Split with friends" },
  { id: "cash", name: "Cash", icon: "💵", description: "Pay in person" },
];

export function SettleUpModal({ isOpen, onClose, debt, onConfirmPayment }: SettleUpModalProps) {
  const [selectedMethod, setSelectedMethod] = useState<string | null>(null);
  const [showSuccess, setShowSuccess] = useState(false);

  const handleConfirm = () => {
    if (!selectedMethod) return;
    
    setShowSuccess(true);
    setTimeout(() => {
      onConfirmPayment(selectedMethod);
      setShowSuccess(false);
      setSelectedMethod(null);
      onClose();
    }, 2000);
  };

  if (!debt) return null;

  return (
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
            className="fixed inset-4 max-w-md mx-auto my-auto max-h-[85vh] bg-card rounded-3xl shadow-2xl z-50 overflow-hidden flex flex-col"
          >
            {/* Success Animation Overlay */}
            <AnimatePresence>
              {showSuccess && (
                <motion.div
                  initial={{ opacity: 0, scale: 0.8 }}
                  animate={{ opacity: 1, scale: 1 }}
                  exit={{ opacity: 0, scale: 0.8 }}
                  className="absolute inset-0 flex flex-col items-center justify-center z-10 bg-card/95 backdrop-blur-sm"
                >
                  <motion.div
                    initial={{ scale: 0 }}
                    animate={{ scale: [0, 1.2, 1] }}
                    transition={{ duration: 0.5 }}
                    className="mb-4"
                  >
                    <div
                      className="w-20 h-20 rounded-full flex items-center justify-center"
                      style={{
                        background: "var(--ouest-gradient-main)",
                      }}
                    >
                      <Check className="w-10 h-10 text-white" />
                    </div>
                  </motion.div>
                  
                  <h3 className="text-foreground">Payment Sent!</h3>
                  <p className="text-muted-foreground mt-2">
                    {debt.to.name} will be notified
                  </p>
                </motion.div>
              )}
            </AnimatePresence>

            {/* Header */}
            <div
              className="px-6 py-5 border-b border-border"
              style={{
                background: "var(--ouest-gradient-soft)",
              }}
            >
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="text-foreground">Settle Up</h2>
                  <p className="text-muted-foreground" style={{ fontSize: "14px" }}>
                    Choose payment method
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

            {/* Payment Summary */}
            <div className="px-6 py-5 border-b border-border">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-3">
                  <span className="text-3xl">{debt.from.avatar}</span>
                  <div>
                    <p className="text-foreground">{debt.from.name}</p>
                    <p className="text-muted-foreground" style={{ fontSize: "13px" }}>
                      You
                    </p>
                  </div>
                </div>
                
                <Send className="w-5 h-5 text-muted-foreground" />

                <div className="flex items-center gap-3">
                  <span className="text-3xl">{debt.to.avatar}</span>
                  <div>
                    <p className="text-foreground">{debt.to.name}</p>
                    <p className="text-muted-foreground" style={{ fontSize: "13px" }}>
                      Recipient
                    </p>
                  </div>
                </div>
              </div>

              <div
                className="text-center py-3 rounded-xl"
                style={{
                  background: "var(--ouest-gradient-soft)",
                }}
              >
                <p className="text-muted-foreground mb-1" style={{ fontSize: "13px" }}>
                  Amount to send
                </p>
                <div className="text-foreground">
                  {debt.currency} ${debt.amount.toFixed(2)}
                </div>
              </div>
            </div>

            {/* Payment Methods */}
            <div className="flex-1 overflow-y-auto px-6 py-5">
              <h4 className="text-foreground mb-3">Payment Methods</h4>
              <div className="space-y-3">
                {paymentMethods.map((method) => (
                  <button
                    key={method.id}
                    onClick={() => setSelectedMethod(method.id)}
                    className={`w-full flex items-center gap-4 p-4 rounded-2xl border-2 transition-all ${
                      selectedMethod === method.id
                        ? "border-ouest-blue bg-ouest-blue/10"
                        : "border-border bg-muted/50 hover:bg-muted"
                    }`}
                  >
                    <span className="text-3xl">{method.icon}</span>
                    <div className="flex-1 text-left">
                      <p className="text-foreground">{method.name}</p>
                      <p className="text-muted-foreground" style={{ fontSize: "13px" }}>
                        {method.description}
                      </p>
                    </div>
                    {selectedMethod === method.id && (
                      <Check className="w-5 h-5" style={{ color: "var(--ouest-blue)" }} />
                    )}
                  </button>
                ))}
              </div>
            </div>

            {/* Footer */}
            <div className="px-6 py-4 border-t border-border">
              <button
                onClick={handleConfirm}
                disabled={!selectedMethod}
                className="w-full py-4 rounded-2xl text-white shadow-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed hover:shadow-xl"
                style={{
                  background: selectedMethod
                    ? "var(--ouest-gradient-main)"
                    : "#e5e7eb",
                }}
              >
                Confirm Payment
              </button>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
