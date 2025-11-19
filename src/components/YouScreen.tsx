import { motion } from "motion/react";
import { Settings, Bookmark, Heart, MapPin, Moon, Sun, Bell, CreditCard, HelpCircle } from "lucide-react";
import { useTheme } from "./ThemeProvider";

export function YouScreen() {
  const { theme, toggleTheme } = useTheme();

  const stats = [
    { label: "Countries Visited", value: "12", icon: MapPin },
    { label: "Trips Planned", value: "24", icon: Bookmark },
    { label: "Wishlist Items", value: "47", icon: Heart },
  ];

  const menuItems = [
    { icon: Bell, label: "Notifications", hasToggle: false },
    { icon: CreditCard, label: "Payment Methods", hasToggle: false },
    { icon: Bookmark, label: "Saved Trips", hasToggle: false },
    { icon: Settings, label: "Settings", hasToggle: false },
    { icon: HelpCircle, label: "Help & Support", hasToggle: false },
  ];

  return (
    <div className="min-h-screen bg-background pb-24">
      {/* Header with Profile */}
      <div
        className="px-6 pt-12 pb-12"
        style={{
          background: "var(--ouest-gradient-main)",
        }}
      >
        <div className="max-w-md mx-auto text-center">
          <motion.div
            initial={{ scale: 0 }}
            animate={{ scale: 1 }}
            transition={{ type: "spring", stiffness: 200 }}
            className="inline-flex items-center justify-center w-24 h-24 rounded-full bg-white/20 backdrop-blur-sm mb-4"
          >
            <span className="text-6xl">👤</span>
          </motion.div>

          <h2 className="text-white mb-1">Alex Taylor</h2>
          <p className="text-white/80" style={{ fontSize: '14px' }}>
            @alextravels
          </p>
        </div>
      </div>

      <div className="px-6 -mt-8 max-w-md mx-auto">
        {/* Stats Card */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-card rounded-3xl p-6 shadow-xl border border-border mb-6"
        >
          <div className="grid grid-cols-3 gap-4">
            {stats.map((stat) => {
              const Icon = stat.icon;
              return (
                <div key={stat.label} className="text-center">
                  <div
                    className="inline-flex p-3 rounded-2xl mb-2"
                    style={{
                      background: "var(--ouest-gradient-soft)",
                    }}
                  >
                    <Icon className="w-5 h-5" style={{ color: "var(--ouest-blue)" }} />
                  </div>
                  <div className="mb-1 text-foreground">{stat.value}</div>
                  <div className="text-muted-foreground" style={{ fontSize: '12px' }}>
                    {stat.label}
                  </div>
                </div>
              );
            })}
          </div>
        </motion.div>

        {/* Theme Toggle */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="bg-card rounded-3xl p-4 shadow-lg border border-border mb-4"
        >
          <button
            onClick={toggleTheme}
            className="w-full flex items-center justify-between"
          >
            <div className="flex items-center gap-3">
              <div
                className="p-3 rounded-xl"
                style={{
                  background: "var(--ouest-gradient-soft)",
                }}
              >
                {theme === "light" ? (
                  <Sun className="w-5 h-5" style={{ color: "var(--ouest-blue)" }} />
                ) : (
                  <Moon className="w-5 h-5" style={{ color: "var(--ouest-indigo)" }} />
                )}
              </div>
              <span className="text-foreground">
                {theme === "light" ? "Light Mode" : "Dark Mode"}
              </span>
            </div>
            <div className="text-muted-foreground">Toggle</div>
          </button>
        </motion.div>

        {/* Menu Items */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="bg-card rounded-3xl shadow-lg border border-border overflow-hidden"
        >
          {menuItems.map((item, index) => {
            const Icon = item.icon;
            return (
              <button
                key={item.label}
                className={`w-full flex items-center justify-between p-4 hover:bg-muted transition-colors ${
                  index !== menuItems.length - 1 ? "border-b border-border" : ""
                }`}
              >
                <div className="flex items-center gap-3">
                  <Icon className="w-5 h-5 text-muted-foreground" />
                  <span className="text-foreground">{item.label}</span>
                </div>
                {!item.hasToggle && (
                  <span className="text-muted-foreground">›</span>
                )}
              </button>
            );
          })}
        </motion.div>

        {/* App Version */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.4 }}
          className="mt-8 text-center text-muted-foreground"
          style={{ fontSize: '13px' }}
        >
          Ouest v1.0.0
        </motion.div>
      </div>
    </div>
  );
}
