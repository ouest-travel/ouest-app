import { motion } from "motion/react";
import { 
  DollarSign, 
  TrendingUp, 
  Download, 
  Share2, 
  CreditCard,
  MessageCircle,
  CheckCircle2
} from "lucide-react";

export function BudgetFeatureShowcase() {
  const features = [
    {
      icon: DollarSign,
      title: "Currency Converter",
      description: "Convert between 10+ currencies with live rates",
      color: "var(--ouest-blue)",
      status: "✓ Working",
    },
    {
      icon: TrendingUp,
      title: "Smart Split Calculator",
      description: "Automatically calculates who owes who",
      color: "var(--ouest-pink)",
      status: "✓ Working",
    },
    {
      icon: CreditCard,
      title: "Settle Up",
      description: "PayPal, Apple Pay, Wise, Venmo, Cash",
      color: "var(--ouest-coral)",
      status: "✓ Working",
    },
    {
      icon: Download,
      title: "Export Summary",
      description: "Download expense summary as text file",
      color: "var(--ouest-indigo)",
      status: "✓ Working",
    },
    {
      icon: Share2,
      title: "Share in Chat",
      description: "Copy or share split summary to group",
      color: "var(--ouest-blue)",
      status: "✓ Working",
    },
    {
      icon: MessageCircle,
      title: "Chat Integration",
      description: "Expenses appear in group chat automatically",
      color: "var(--ouest-pink)",
      status: "✓ Working",
    },
  ];

  return (
    <div className="min-h-screen bg-background p-6">
      <div className="max-w-2xl mx-auto">
        <div className="text-center mb-8">
          <div
            className="inline-flex p-4 rounded-3xl mb-4"
            style={{
              background: "var(--ouest-gradient-main)",
            }}
          >
            <CheckCircle2 className="w-8 h-8 text-white" />
          </div>
          <h1 className="mb-2">Budget Tracker Features</h1>
          <p className="text-muted-foreground">
            All features are fully functional
          </p>
        </div>

        <div className="grid gap-4">
          {features.map((feature, index) => {
            const Icon = feature.icon;
            return (
              <motion.div
                key={feature.title}
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: index * 0.1 }}
                className="bg-card rounded-2xl p-5 border border-border shadow-md"
              >
                <div className="flex items-start gap-4">
                  <div
                    className="p-3 rounded-xl flex-shrink-0"
                    style={{
                      backgroundColor: `${feature.color}15`,
                    }}
                  >
                    <Icon
                      className="w-6 h-6"
                      style={{ color: feature.color }}
                    />
                  </div>
                  <div className="flex-1">
                    <div className="flex items-start justify-between gap-2 mb-1">
                      <h3 className="text-foreground">{feature.title}</h3>
                      <span
                        className="px-2 py-1 rounded-lg text-white whitespace-nowrap"
                        style={{
                          background: "var(--ouest-gradient-main)",
                          fontSize: "11px",
                        }}
                      >
                        {feature.status}
                      </span>
                    </div>
                    <p className="text-muted-foreground">
                      {feature.description}
                    </p>
                  </div>
                </div>
              </motion.div>
            );
          })}
        </div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.8 }}
          className="mt-8 p-6 rounded-2xl border border-border"
          style={{
            background: "var(--ouest-gradient-soft)",
          }}
        >
          <h3 className="text-foreground mb-3">How It Works</h3>
          <ol className="space-y-2 text-muted-foreground">
            <li className="flex gap-2">
              <span className="flex-shrink-0">1.</span>
              <span>Add expenses and split them among group members</span>
            </li>
            <li className="flex gap-2">
              <span className="flex-shrink-0">2.</span>
              <span>View split summary to see who owes who (auto-calculated)</span>
            </li>
            <li className="flex gap-2">
              <span className="flex-shrink-0">3.</span>
              <span>Settle up using PayPal, Apple Pay, Wise, Venmo, or Cash</span>
            </li>
            <li className="flex gap-2">
              <span className="flex-shrink-0">4.</span>
              <span>Export summary or share in group chat</span>
            </li>
            <li className="flex gap-2">
              <span className="flex-shrink-0">5.</span>
              <span>All expenses automatically appear in chat with links</span>
            </li>
          </ol>
        </motion.div>
      </div>
    </div>
  );
}
