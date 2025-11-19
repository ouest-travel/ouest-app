import { motion } from "motion/react";
import { ArrowLeft, Plus, MoreVertical, DollarSign, TrendingUp } from "lucide-react";
import { useState, useEffect } from "react";
import { ExpenseCard } from "./ExpenseCard";
import { AddExpenseModal } from "./AddExpenseModal";
import { SplitSummaryModal } from "./SplitSummaryModal";
import { CurrencyConverterModal } from "./CurrencyConverterModal";

interface BudgetOverviewScreenProps {
  onBack: () => void;
  onViewChat?: () => void;
  tripName?: string;
  tripId?: number | null;
}

const mockMembers = [
  { id: "1", name: "Trey", avatar: "👨🏻" },
  { id: "2", name: "Jason", avatar: "👨🏼" },
  { id: "3", name: "Sandra", avatar: "👩🏽" },
  { id: "4", name: "Timmy", avatar: "👨🏾" },
];

// Function to calculate who owes who based on expenses
function calculateDebts(expenses: any[], members: typeof mockMembers) {
  // Calculate balance for each member
  const balances: Record<string, number> = {};
  
  members.forEach(member => {
    balances[member.name] = 0;
  });

  expenses.forEach(expense => {
    const shareAmount = expense.amount / expense.splitAmong;
    
    // The payer gets credit
    balances[expense.paidBy] = (balances[expense.paidBy] || 0) + expense.amount;
    
    // Everyone who split it owes their share
    members.forEach(member => {
      if (expense.splitAmong === members.length || member.name === expense.paidBy) {
        balances[member.name] = (balances[member.name] || 0) - shareAmount;
      }
    });
  });

  // Simplify debts: match positive and negative balances
  const debts: any[] = [];
  const debtors = members.filter(m => balances[m.name] < -0.01).map(m => ({ ...m, amount: -balances[m.name] }));
  const creditors = members.filter(m => balances[m.name] > 0.01).map(m => ({ ...m, amount: balances[m.name] }));

  for (const debtor of debtors) {
    for (const creditor of creditors) {
      if (debtor.amount > 0.01 && creditor.amount > 0.01) {
        const amount = Math.min(debtor.amount, creditor.amount);
        debts.push({
          from: mockMembers.find(m => m.name === debtor.name)!,
          to: mockMembers.find(m => m.name === creditor.name)!,
          amount: Math.round(amount * 100) / 100,
          currency: "CAD",
        });
        debtor.amount -= amount;
        creditor.amount -= amount;
      }
    }
  }

  return debts;
}

export function BudgetOverviewScreen({ onBack, onViewChat, tripName = "Tokyo Adventure", tripId = null }: BudgetOverviewScreenProps) {
  const [activeTab, setActiveTab] = useState<"all" | "person" | "category">("all");
  const [showAddExpense, setShowAddExpense] = useState(false);
  const [showSplitSummary, setShowSplitSummary] = useState(false);
  const [showConverter, setShowConverter] = useState(false);
  const [editingExpense, setEditingExpense] = useState<any>(null);
  
  // Default expenses for demo purposes
  const getDefaultExpenses = (tripId: number | null) => {
    // Tokyo trip (id: 1)
    if (tripId === 1) {
      return [
        {
          id: "1",
          title: "Sushi Zanmai Dinner",
          amount: 120,
          currency: "CAD",
          category: "food" as const,
          paidBy: "Timmy",
          splitAmong: 4,
          date: "2025-10-13",
          hasChat: true,
        },
        {
          id: "2",
          title: "Subway Tickets",
          amount: 45,
          currency: "CAD",
          category: "transport" as const,
          paidBy: "Jason",
          splitAmong: 4,
          date: "2025-10-13",
          hasChat: true,
        },
        {
          id: "3",
          title: "Hotel Check-in",
          amount: 380,
          currency: "CAD",
          category: "stay" as const,
          paidBy: "Sandra",
          splitAmong: 4,
          date: "2025-10-12",
          hasChat: false,
        },
        {
          id: "4",
          title: "TeamLab Borderless Tickets",
          amount: 95,
          currency: "CAD",
          category: "activities" as const,
          paidBy: "Trey",
          splitAmong: 4,
          date: "2025-10-12",
          hasChat: true,
        },
      ];
    }
    // Paris trip (id: 2)
    else if (tripId === 2) {
      return [
        {
          id: "p1",
          title: "Eiffel Tower Tickets",
          amount: 85,
          currency: "EUR",
          category: "activities" as const,
          paidBy: "Trey",
          splitAmong: 3,
          date: "2026-01-11",
          hasChat: false,
        },
        {
          id: "p2",
          title: "Metro Pass",
          amount: 32,
          currency: "EUR",
          category: "transport" as const,
          paidBy: "Sandra",
          splitAmong: 3,
          date: "2026-01-10",
          hasChat: false,
        },
      ];
    }
    // Barcelona trip (id: 3)
    else if (tripId === 3) {
      return [
        {
          id: "b1",
          title: "Sagrada Familia Tour",
          amount: 140,
          currency: "EUR",
          category: "activities" as const,
          paidBy: "Jason",
          splitAmong: 4,
          date: "2024-09-02",
          hasChat: false,
        },
        {
          id: "b2",
          title: "Beachfront Dinner",
          amount: 180,
          currency: "EUR",
          category: "food" as const,
          paidBy: "Timmy",
          splitAmong: 4,
          date: "2024-09-03",
          hasChat: false,
        },
        {
          id: "b3",
          title: "Airbnb Payment",
          amount: 560,
          currency: "EUR",
          category: "stay" as const,
          paidBy: "Sandra",
          splitAmong: 4,
          date: "2024-09-01",
          hasChat: false,
        },
      ];
    }
    // Default for new trips
    return [];
  };
  
  // Load expenses from localStorage or use defaults
  const loadExpenses = () => {
    if (tripId === null) return getDefaultExpenses(null);
    
    try {
      const stored = localStorage.getItem(`ouest-trip-${tripId}-expenses`);
      if (stored) {
        return JSON.parse(stored);
      }
      // First time loading this trip, set defaults
      const defaults = getDefaultExpenses(tripId);
      localStorage.setItem(`ouest-trip-${tripId}-expenses`, JSON.stringify(defaults));
      return defaults;
    } catch (error) {
      return getDefaultExpenses(tripId);
    }
  };
  
  const [expenses, setExpenses] = useState(loadExpenses);
  
  // Save expenses to localStorage whenever they change
  useEffect(() => {
    if (tripId !== null) {
      localStorage.setItem(`ouest-trip-${tripId}-expenses`, JSON.stringify(expenses));
    }
  }, [expenses, tripId]);
  
  // Reload expenses when tripId changes
  useEffect(() => {
    setExpenses(loadExpenses());
  }, [tripId]);

  const totalSpent = expenses.reduce((sum, exp) => sum + exp.amount, 0);
  const totalBudget = 3500;
  const remaining = totalBudget - totalSpent;
  const progressPercent = (totalSpent / totalBudget) * 100;

  const handleAddExpense = (expense: any) => {
    if (editingExpense) {
      // Update existing expense
      setExpenses(expenses.map(e => e.id === expense.id ? expense : e));
      setEditingExpense(null);
    } else {
      // Add new expense
      setExpenses([expense, ...expenses]);
    }
  };

  const handleEditExpense = (expense: any) => {
    setEditingExpense(expense);
    setShowAddExpense(true);
  };

  const handleCloseAddExpense = () => {
    setShowAddExpense(false);
    setEditingExpense(null);
  };

  const handleApplyConverterAmount = (amount: number, currency: string) => {
    // Open add expense modal with pre-filled amount
    setShowConverter(false);
    setShowAddExpense(true);
  };

  // Calculate current debts based on expenses
  const currentDebts = calculateDebts(expenses, mockMembers);

  // Filter expenses based on active tab
  const getFilteredExpenses = () => {
    switch (activeTab) {
      case "person":
        // Group by person who paid
        const byPerson: Record<string, any[]> = {};
        expenses.forEach(expense => {
          if (!byPerson[expense.paidBy]) {
            byPerson[expense.paidBy] = [];
          }
          byPerson[expense.paidBy].push(expense);
        });
        return byPerson;
      
      case "category":
        // Group by category
        const byCategory: Record<string, any[]> = {};
        expenses.forEach(expense => {
          if (!byCategory[expense.category]) {
            byCategory[expense.category] = [];
          }
          byCategory[expense.category].push(expense);
        });
        return byCategory;
      
      default:
        return expenses;
    }
  };

  const filteredData = getFilteredExpenses();

  return (
    <div className="min-h-screen bg-background pb-24">
      {/* Header */}
      <div
        className="relative px-6 pt-12 pb-8 overflow-hidden"
        style={{
          background: "var(--ouest-gradient-main)",
        }}
      >
        <div className="absolute inset-0 shimmer-animate opacity-20" />

        <div className="relative z-10">
          <div className="flex items-center justify-between mb-6">
            <button
              onClick={onBack}
              className="p-2 rounded-full bg-white/20 hover:bg-white/30 transition-colors"
            >
              <ArrowLeft className="w-5 h-5 text-white" />
            </button>

            <button className="p-2 rounded-full bg-white/20 hover:bg-white/30 transition-colors">
              <MoreVertical className="w-5 h-5 text-white" />
            </button>
          </div>

          <h1 className="text-white mb-1">{tripName} Budget</h1>
          <p className="text-white/90" style={{ fontSize: "15px" }}>
            Track shared expenses and balances
          </p>
        </div>
      </div>

      <div className="px-6 -mt-4 max-w-md mx-auto">
        {/* Summary Card */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-card rounded-3xl p-6 shadow-xl border border-border mb-6"
        >
          {/* Circular Progress */}
          <div className="flex items-center gap-6 mb-6">
            <div className="relative w-28 h-28">
              <svg className="w-full h-full transform -rotate-90">
                {/* Background circle */}
                <circle
                  cx="56"
                  cy="56"
                  r="48"
                  fill="none"
                  stroke="var(--muted)"
                  strokeWidth="8"
                />
                {/* Progress circle */}
                <motion.circle
                  cx="56"
                  cy="56"
                  r="48"
                  fill="none"
                  stroke="url(#gradient)"
                  strokeWidth="8"
                  strokeLinecap="round"
                  strokeDasharray={`${2 * Math.PI * 48}`}
                  initial={{ strokeDashoffset: 2 * Math.PI * 48 }}
                  animate={{ strokeDashoffset: 2 * Math.PI * 48 * (1 - progressPercent / 100) }}
                  transition={{ duration: 1, ease: "easeOut" }}
                />
                <defs>
                  <linearGradient id="gradient" x1="0%" y1="0%" x2="100%" y2="100%">
                    <stop offset="0%" stopColor="#4F8FFF" />
                    <stop offset="50%" stopColor="#C77DFF" />
                    <stop offset="100%" stopColor="#FF8B94" />
                  </linearGradient>
                </defs>
              </svg>
              <div className="absolute inset-0 flex items-center justify-center">
                <div className="text-center">
                  <div className="text-foreground" style={{ fontSize: "18px" }}>
                    {progressPercent.toFixed(0)}%
                  </div>
                  <div className="text-muted-foreground" style={{ fontSize: "10px" }}>
                    spent
                  </div>
                </div>
              </div>
            </div>

            <div className="flex-1 space-y-3">
              <div>
                <p className="text-muted-foreground mb-1" style={{ fontSize: "13px" }}>
                  Total Spent
                </p>
                <p className="text-foreground">CAD ${totalSpent.toFixed(2)}</p>
              </div>
              <div>
                <p className="text-muted-foreground mb-1" style={{ fontSize: "13px" }}>
                  Remaining Budget
                </p>
                <p className="text-foreground">CAD ${remaining.toFixed(2)}</p>
              </div>
            </div>
          </div>

          {/* Add Expense Button */}
          <button
            onClick={() => setShowAddExpense(true)}
            className="w-full py-4 rounded-2xl text-white shadow-lg hover:shadow-xl transition-all"
            style={{
              background: "var(--ouest-gradient-main)",
            }}
          >
            <span className="flex items-center justify-center gap-2">
              <Plus className="w-5 h-5" />
              Add Expense
            </span>
          </button>
        </motion.div>

        {/* Tabs */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="flex gap-2 mb-6"
        >
          {[
            { id: "all" as const, label: "💳 All Expenses" },
            { id: "person" as const, label: "👥 By Person" },
            { id: "category" as const, label: "🗂 By Category" },
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`flex-1 py-3 px-4 rounded-xl transition-all ${
                activeTab === tab.id
                  ? "bg-card border-2 shadow-md"
                  : "bg-muted"
              }`}
              style={{
                borderColor: activeTab === tab.id ? "var(--ouest-blue)" : "transparent",
              }}
            >
              <span
                className={activeTab === tab.id ? "text-foreground" : "text-muted-foreground"}
                style={{ fontSize: "13px" }}
              >
                {tab.label}
              </span>
            </button>
          ))}
        </motion.div>

        {/* Expense List */}
        <div className="space-y-4 mb-6">
          {activeTab === "all" ? (
            // Show flat list for "all" tab
            Array.isArray(filteredData) && filteredData.map((expense, index) => (
              <motion.div
                key={expense.id}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.2 + index * 0.05 }}
              >
                <ExpenseCard
                  expense={expense}
                  onViewChat={onViewChat}
                  onEdit={() => handleEditExpense(expense)}
                  onDelete={() => setExpenses(expenses.filter(e => e.id !== expense.id))}
                />
              </motion.div>
            ))
          ) : (
            // Show grouped lists for "person" and "category" tabs
            Object.entries(filteredData as Record<string, any[]>).map(([group, groupExpenses], groupIndex) => {
              const groupTotal = groupExpenses.reduce((sum, exp) => sum + exp.amount, 0);
              
              // Get display info based on tab type
              const getGroupDisplay = () => {
                if (activeTab === "person") {
                  const member = mockMembers.find(m => m.name === group);
                  return {
                    icon: member?.avatar || "👤",
                    name: group,
                  };
                } else {
                  const categoryConfig = {
                    food: { emoji: "🍽️", label: "Food & Drinks" },
                    transport: { emoji: "🚕", label: "Transport" },
                    stay: { emoji: "🏨", label: "Accommodation" },
                    activities: { emoji: "🎟️", label: "Activities" },
                    other: { emoji: "📦", label: "Other" },
                  };
                  const config = categoryConfig[group as keyof typeof categoryConfig] || { emoji: "📦", label: group };
                  return {
                    icon: config.emoji,
                    name: config.label,
                  };
                }
              };

              const display = getGroupDisplay();

              return (
                <motion.div
                  key={group}
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: groupIndex * 0.1 }}
                  className="space-y-3"
                >
                  {/* Group Header */}
                  <div
                    className="flex items-center justify-between p-4 rounded-2xl"
                    style={{
                      background: "var(--ouest-gradient-soft)",
                    }}
                  >
                    <div className="flex items-center gap-3">
                      <span className="text-2xl">{display.icon}</span>
                      <div>
                        <h4 className="text-foreground">{display.name}</h4>
                        <span className="text-muted-foreground" style={{ fontSize: "13px" }}>
                          {groupExpenses.length} {groupExpenses.length === 1 ? "expense" : "expenses"}
                        </span>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="text-foreground">CAD ${groupTotal.toFixed(2)}</p>
                      <span className="text-muted-foreground" style={{ fontSize: "12px" }}>
                        total
                      </span>
                    </div>
                  </div>

                  {/* Expenses in this group */}
                  {groupExpenses.map((expense) => (
                    <ExpenseCard
                      key={expense.id}
                      expense={expense}
                      onViewChat={onViewChat}
                      onEdit={() => handleEditExpense(expense)}
                      onDelete={() => setExpenses(expenses.filter(e => e.id !== expense.id))}
                    />
                  ))}
                </motion.div>
              );
            })
          )}
          
          {((Array.isArray(filteredData) && filteredData.length === 0) || 
            (!Array.isArray(filteredData) && Object.keys(filteredData).length === 0)) && (
            <div className="text-center py-12">
              <p className="text-muted-foreground">No expenses yet</p>
            </div>
          )}
        </div>

        {/* View Split Summary Button */}
        <motion.button
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.5 }}
          onClick={() => setShowSplitSummary(true)}
          className="w-full py-4 px-6 rounded-2xl border-2 hover:bg-muted transition-all mb-6 relative"
          style={{
            borderColor: "var(--ouest-blue)",
          }}
        >
          <span className="flex items-center justify-center gap-2 text-foreground">
            <TrendingUp className="w-5 h-5" />
            View Split Summary
          </span>
          {currentDebts.length > 0 && (
            <motion.span
              initial={{ scale: 0 }}
              animate={{ scale: 1 }}
              className="absolute -top-2 -right-2 w-6 h-6 rounded-full flex items-center justify-center text-white"
              style={{
                background: "var(--ouest-gradient-main)",
                fontSize: "12px",
              }}
            >
              {currentDebts.length}
            </motion.span>
          )}
        </motion.button>
      </div>

      {/* Floating Currency Converter Button */}
      <motion.button
        initial={{ scale: 0 }}
        animate={{ scale: 1 }}
        transition={{ delay: 0.6, type: "spring" }}
        onClick={() => setShowConverter(true)}
        className="fixed bottom-24 right-6 w-14 h-14 rounded-full shadow-2xl flex items-center justify-center"
        style={{
          background: "var(--ouest-gradient-main)",
        }}
      >
        <DollarSign className="w-6 h-6 text-white" />
      </motion.button>

      {/* Modals */}
      <AddExpenseModal
        isOpen={showAddExpense}
        onClose={handleCloseAddExpense}
        members={mockMembers}
        onAddExpense={handleAddExpense}
        existingExpense={editingExpense}
      />

      <SplitSummaryModal
        isOpen={showSplitSummary}
        onClose={() => setShowSplitSummary(false)}
        debts={currentDebts}
        onSettleUp={(debt) => console.log("Settled:", debt)}
        onExport={() => console.log("Exported summary")}
        onShare={() => console.log("Shared in chat")}
      />

      <CurrencyConverterModal
        isOpen={showConverter}
        onClose={() => setShowConverter(false)}
        onApplyToExpense={handleApplyConverterAmount}
      />
    </div>
  );
}