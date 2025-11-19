import { motion } from "motion/react";
import { CheckCircle2, Filter, Edit3, Users, Tag } from "lucide-react";

export function FixedFeaturesSummary() {
  const fixes = [
    {
      icon: Filter,
      title: "Filter Tabs",
      before: "❌ Tabs didn't filter expenses",
      after: "✅ All three filter modes working",
      details: [
        "💳 All Expenses - Shows complete list",
        "👥 By Person - Groups by who paid",
        "🗂 By Category - Groups by expense type",
      ],
      color: "var(--ouest-blue)",
    },
    {
      icon: Users,
      title: "By Person View",
      before: "❌ Not implemented",
      after: "✅ Smart grouping with totals",
      details: [
        "Shows member avatar and name",
        "Displays expense count per person",
        "Calculates total paid by each member",
        "Animated gradient headers",
      ],
      color: "var(--ouest-pink)",
    },
    {
      icon: Tag,
      title: "By Category View",
      before: "❌ Not implemented",
      after: "✅ Visual category grouping",
      details: [
        "Groups: Food, Transport, Stay, Activities, Other",
        "Category icons and labels",
        "Total spending per category",
        "Easy to track spending patterns",
      ],
      color: "var(--ouest-coral)",
    },
    {
      icon: Edit3,
      title: "Edit Expense",
      before: "❌ Edit button did nothing",
      after: "✅ Full edit functionality",
      details: [
        "Pre-fills form with existing data",
        "Updates expense in place",
        "Preserves expense ID and metadata",
        "Success animation on update",
      ],
      color: "var(--ouest-indigo)",
    },
  ];

  return (
    <div className="min-h-screen bg-background p-6">
      <div className="max-w-3xl mx-auto">
        <div className="text-center mb-8">
          <div
            className="inline-flex p-4 rounded-3xl mb-4"
            style={{
              background: "var(--ouest-gradient-main)",
            }}
          >
            <CheckCircle2 className="w-8 h-8 text-white" />
          </div>
          <h1 className="mb-2">Fixed Features</h1>
          <p className="text-muted-foreground">
            All filter tabs and edit functionality now working
          </p>
        </div>

        <div className="grid gap-6">
          {fixes.map((fix, index) => {
            const Icon = fix.icon;
            return (
              <motion.div
                key={fix.title}
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: index * 0.1 }}
                className="bg-card rounded-2xl p-6 border border-border shadow-lg"
              >
                <div className="flex items-start gap-4 mb-4">
                  <div
                    className="p-3 rounded-xl flex-shrink-0"
                    style={{
                      backgroundColor: `${fix.color}15`,
                    }}
                  >
                    <Icon
                      className="w-6 h-6"
                      style={{ color: fix.color }}
                    />
                  </div>
                  <div className="flex-1">
                    <h3 className="text-foreground mb-3">{fix.title}</h3>
                    
                    <div className="space-y-2 mb-4">
                      <div className="flex items-start gap-2">
                        <span className="text-destructive mt-0.5">❌</span>
                        <span className="text-muted-foreground" style={{ fontSize: "14px" }}>
                          {fix.before}
                        </span>
                      </div>
                      <div className="flex items-start gap-2">
                        <span className="text-green-500 mt-0.5">✅</span>
                        <span className="text-foreground" style={{ fontSize: "14px" }}>
                          {fix.after}
                        </span>
                      </div>
                    </div>

                    <div
                      className="p-4 rounded-xl space-y-2"
                      style={{
                        background: "var(--ouest-gradient-soft)",
                      }}
                    >
                      {fix.details.map((detail, i) => (
                        <div key={i} className="flex items-start gap-2">
                          <span className="text-muted-foreground mt-0.5">•</span>
                          <span className="text-muted-foreground" style={{ fontSize: "13px" }}>
                            {detail}
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              </motion.div>
            );
          })}
        </div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.6 }}
          className="mt-8 p-6 rounded-2xl border border-border"
          style={{
            background: "var(--ouest-gradient-soft)",
          }}
        >
          <h3 className="text-foreground mb-3">How to Use</h3>
          <ol className="space-y-2 text-muted-foreground">
            <li className="flex gap-2">
              <span className="flex-shrink-0">1.</span>
              <span>Click the filter tabs to switch between different views</span>
            </li>
            <li className="flex gap-2">
              <span className="flex-shrink-0">2.</span>
              <span>In grouped views, see totals for each person or category</span>
            </li>
            <li className="flex gap-2">
              <span className="flex-shrink-0">3.</span>
              <span>Click the ⋮ menu on any expense card, then "Edit"</span>
            </li>
            <li className="flex gap-2">
              <span className="flex-shrink-0">4.</span>
              <span>Update any field and click "Update Expense"</span>
            </li>
          </ol>
        </motion.div>
      </div>
    </div>
  );
}
