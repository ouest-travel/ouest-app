import { X, DollarSign } from "lucide-react";
import { motion, AnimatePresence } from "motion/react";
import { useState, useEffect } from "react";

interface Member {
  id: string;
  name: string;
  avatar: string;
}

interface AddExpenseModalProps {
  isOpen: boolean;
  onClose: () => void;
  members: Member[];
  onAddExpense: (expense: any) => void;
  defaultAmount?: number;
  defaultCurrency?: string;
  existingExpense?: any;
}

const categories = [
  { value: "food", label: "Food & Drinks", emoji: "🍽️" },
  { value: "transport", label: "Transport", emoji: "🚕" },
  { value: "stay", label: "Accommodation", emoji: "🏨" },
  { value: "activities", label: "Activities", emoji: "🎟️" },
  { value: "other", label: "Other", emoji: "📦" },
];

export function AddExpenseModal({
  isOpen,
  onClose,
  members,
  onAddExpense,
  defaultAmount,
  defaultCurrency = "CAD",
  existingExpense,
}: AddExpenseModalProps) {
  const [title, setTitle] = useState("");
  const [amount, setAmount] = useState(defaultAmount?.toString() || "");
  const [currency, setCurrency] = useState(defaultCurrency);
  const [category, setCategory] = useState("food");
  const [paidBy, setPaidBy] = useState(members[0]?.id || "");
  const [splitWith, setSplitWith] = useState<string[]>(
    members.map((m) => m.id)
  );
  const [splitEqually, setSplitEqually] = useState(true);
  const [notes, setNotes] = useState("");
  const [showSuccess, setShowSuccess] = useState(false);

  // Populate form when editing
  useEffect(() => {
    if (existingExpense && isOpen) {
      setTitle(existingExpense.title || "");
      setAmount(existingExpense.amount?.toString() || "");
      setCurrency(existingExpense.currency || "CAD");
      setCategory(existingExpense.category || "food");
      const paidByMember = members.find(
        (m) => m.name === existingExpense.paidBy
      );
      setPaidBy(paidByMember?.id || members[0]?.id || "");
      setSplitWith(members.map((m) => m.id));
      setNotes(existingExpense.notes || "");
    } else if (!existingExpense && isOpen) {
      // Reset form for new expense
      setTitle("");
      setAmount(defaultAmount?.toString() || "");
      setCurrency(defaultCurrency);
      setCategory("food");
      setPaidBy(members[0]?.id || "");
      setSplitWith(members.map((m) => m.id));
      setNotes("");
    }
  }, [existingExpense, isOpen, members, defaultAmount, defaultCurrency]);

  const handleSubmit = () => {
    if (!title || !amount || !paidBy) return;

    const expense = {
      id: existingExpense?.id || Date.now().toString(),
      title,
      amount: parseFloat(amount),
      currency,
      category,
      paidBy: members.find((m) => m.id === paidBy)?.name || "",
      paid_by: paidBy, // User ID for Supabase
      splitAmong: splitWith.length,
      split_among: splitWith, // Array of user IDs for Supabase
      date: existingExpense?.date || new Date().toISOString(),
      notes,
      hasChat: existingExpense?.hasChat ?? true,
      has_chat: existingExpense?.hasChat ?? true, // For Supabase
    };

    onAddExpense(expense);

    // Show success animation
    setShowSuccess(true);
    setTimeout(() => {
      setShowSuccess(false);
      onClose();
      // Reset form
      setTitle("");
      setAmount("");
      setCategory("food");
      setNotes("");
    }, 1500);
  };

  const toggleMember = (memberId: string) => {
    setSplitWith((prev) =>
      prev.includes(memberId)
        ? prev.filter((id) => id !== memberId)
        : [...prev, memberId]
    );
  };

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
            className="fixed inset-4 max-w-md mx-auto my-auto max-h-[90vh] bg-card rounded-3xl shadow-2xl z-50 overflow-hidden flex flex-col"
          >
            {/* Header */}
            <div
              className="px-6 py-5 border-b border-border flex items-center justify-between"
              style={{
                background: "var(--ouest-gradient-soft)",
              }}
            >
              <h2 className="text-foreground">
                {existingExpense ? "Edit Expense" : "Add Expense"}
              </h2>
              <button
                onClick={onClose}
                className="p-2 rounded-full hover:bg-muted transition-colors"
              >
                <X className="w-5 h-5 text-foreground" />
              </button>
            </div>

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
                      <span className="text-4xl">💸</span>
                    </div>
                  </motion.div>

                  {/* Confetti effect */}
                  {[...Array(12)].map((_, i) => (
                    <motion.div
                      key={i}
                      initial={{ scale: 0, x: 0, y: 0 }}
                      animate={{
                        scale: [0, 1, 0],
                        x: Math.cos((i * 30 * Math.PI) / 180) * 100,
                        y: Math.sin((i * 30 * Math.PI) / 180) * 100,
                      }}
                      transition={{ duration: 1, ease: "easeOut" }}
                      className="absolute w-2 h-2 rounded-full"
                      style={{
                        background: [
                          "var(--ouest-blue)",
                          "var(--ouest-pink)",
                          "var(--ouest-coral)",
                          "var(--ouest-indigo)",
                        ][i % 4],
                      }}
                    />
                  ))}

                  <h3 className="text-foreground">
                    {existingExpense
                      ? "Expense Updated Successfully!"
                      : "Expense Added Successfully!"}
                  </h3>
                </motion.div>
              )}
            </AnimatePresence>

            {/* Form Content */}
            <div className="flex-1 overflow-y-auto px-6 py-6 space-y-5">
              {/* Expense Name */}
              <div>
                <label className="block mb-2 text-foreground">
                  Expense Name
                </label>
                <input
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="e.g., Dinner at restaurant"
                  className="w-full px-4 py-3 bg-muted rounded-xl border-0 focus:outline-none focus:ring-2 focus:ring-blue-500 text-foreground"
                />
              </div>

              {/* Amount and Currency */}
              <div>
                <label className="block mb-2 text-foreground">Amount</label>
                <div className="flex gap-2">
                  <select
                    value={currency}
                    onChange={(e) => setCurrency(e.target.value)}
                    className="w-24 px-3 py-3 bg-muted rounded-xl border-0 focus:outline-none focus:ring-2 focus:ring-blue-500 text-foreground"
                  >
                    <option value="CAD">CAD</option>
                    <option value="USD">USD</option>
                    <option value="EUR">EUR</option>
                    <option value="GBP">GBP</option>
                    <option value="JPY">JPY</option>
                  </select>
                  <div className="relative flex-1">
                    <DollarSign className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                    <input
                      type="number"
                      value={amount}
                      onChange={(e) => setAmount(e.target.value)}
                      placeholder="0.00"
                      className="w-full pl-10 pr-4 py-3 bg-muted rounded-xl border-0 focus:outline-none focus:ring-2 focus:ring-blue-500 text-foreground"
                    />
                  </div>
                </div>
              </div>

              {/* Category */}
              <div>
                <label className="block mb-2 text-foreground">Category</label>
                <div className="grid grid-cols-3 gap-2">
                  {categories.map((cat) => (
                    <button
                      key={cat.value}
                      onClick={() => setCategory(cat.value)}
                      className={`p-3 rounded-xl border-2 transition-all ${
                        category === cat.value
                          ? "border-ouest-blue bg-ouest-blue/10"
                          : "border-border bg-muted"
                      }`}
                    >
                      <div className="text-2xl mb-1">{cat.emoji}</div>
                      <div
                        className="text-foreground"
                        style={{ fontSize: "11px" }}
                      >
                        {cat.label.split(" ")[0]}
                      </div>
                    </button>
                  ))}
                </div>
              </div>

              {/* Paid By */}
              <div>
                <label className="block mb-2 text-foreground">Paid By</label>
                <select
                  value={paidBy}
                  onChange={(e) => setPaidBy(e.target.value)}
                  className="w-full px-4 py-3 bg-muted rounded-xl border-0 focus:outline-none focus:ring-2 focus:ring-blue-500 text-foreground"
                >
                  {members.map((member) => (
                    <option key={member.id} value={member.id}>
                      {member.avatar} {member.name}
                    </option>
                  ))}
                </select>
              </div>

              {/* Split With */}
              <div>
                <div className="flex items-center justify-between mb-2">
                  <label className="text-foreground">Split With</label>
                  <label className="flex items-center gap-2">
                    <input
                      type="checkbox"
                      checked={splitEqually}
                      onChange={(e) => setSplitEqually(e.target.checked)}
                      className="rounded"
                    />
                    <span
                      className="text-muted-foreground"
                      style={{ fontSize: "13px" }}
                    >
                      Split equally
                    </span>
                  </label>
                </div>
                <div className="space-y-2">
                  {members.map((member) => (
                    <button
                      key={member.id}
                      onClick={() => toggleMember(member.id)}
                      className={`w-full flex items-center gap-3 p-3 rounded-xl border-2 transition-all ${
                        splitWith.includes(member.id)
                          ? "border-ouest-blue bg-ouest-blue/10"
                          : "border-border bg-muted"
                      }`}
                    >
                      <span className="text-2xl">{member.avatar}</span>
                      <span className="flex-1 text-left text-foreground">
                        {member.name}
                      </span>
                      {splitWith.includes(member.id) &&
                        splitEqually &&
                        amount && (
                          <span
                            className="text-muted-foreground"
                            style={{ fontSize: "13px" }}
                          >
                            {currency} $
                            {(parseFloat(amount) / splitWith.length).toFixed(2)}
                          </span>
                        )}
                    </button>
                  ))}
                </div>
              </div>

              {/* Notes */}
              <div>
                <label className="block mb-2 text-foreground">
                  Notes (optional)
                </label>
                <textarea
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="Add any additional details..."
                  rows={3}
                  className="w-full px-4 py-3 bg-muted rounded-xl border-0 focus:outline-none focus:ring-2 focus:ring-blue-500 text-foreground resize-none"
                />
              </div>
            </div>

            {/* Footer */}
            <div className="px-6 py-4 border-t border-border">
              <button
                onClick={handleSubmit}
                disabled={
                  !title || !amount || !paidBy || splitWith.length === 0
                }
                className="w-full py-4 rounded-2xl text-white shadow-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed hover:shadow-xl"
                style={{
                  background:
                    title && amount && paidBy && splitWith.length > 0
                      ? "var(--ouest-gradient-main)"
                      : "#e5e7eb",
                }}
              >
                {existingExpense ? "Update Expense" : "Save Expense"}
              </button>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
