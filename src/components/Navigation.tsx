"use client";

import { Home, Compass, MessageCircle, User } from "lucide-react";
import { motion } from "motion/react";
import Link from "next/link";
import { usePathname } from "next/navigation";

export function Navigation() {
  const pathname = usePathname();

  const tabs = [
    { id: "home", href: "/", icon: Home, label: "Home" },
    { id: "guide", href: "/guide", icon: Compass, label: "Guide" },
    { id: "community", href: "/community", icon: MessageCircle, label: "Community" },
    { id: "you", href: "/you", icon: User, label: "You" },
  ];

  return (
    <nav className="fixed bottom-0 left-0 right-0 bg-card border-t border-border safe-bottom z-50">
      <div className="max-w-md mx-auto px-4 pb-2 pt-3">
        <div className="flex items-center justify-around">
          {tabs.map((tab) => {
            const isActive = pathname === tab.href;
            const Icon = tab.icon;

            return (
              <Link
                key={tab.id}
                href={tab.href}
                className="relative flex flex-col items-center gap-1 py-2 px-4 transition-all duration-300 ease-out"
              >
                {/* Active gradient glow background */}
                {isActive && (
                  <motion.div
                    layoutId="activeTab"
                    className="absolute inset-0 rounded-2xl"
                    style={{
                      background: "var(--ouest-gradient-soft)",
                    }}
                    transition={{
                      type: "spring",
                      stiffness: 300,
                      damping: 30,
                    }}
                  />
                )}

                {/* Icon with gradient on active */}
                <div className="relative z-10">
                  {isActive ? (
                    <div
                      className="p-1.5 rounded-xl"
                      style={{
                        background: "var(--ouest-gradient-main)",
                      }}
                    >
                      <Icon className="w-5 h-5 text-white" strokeWidth={2.5} />
                    </div>
                  ) : (
                    <Icon
                      className="w-5 h-5 text-muted-foreground transition-colors"
                      strokeWidth={2}
                    />
                  )}
                </div>

                {/* Label */}
                <span
                  className={`relative z-10 transition-colors ${
                    isActive
                      ? "text-foreground"
                      : "text-muted-foreground"
                  }`}
                  style={{
                    fontSize: "11px",
                  }}
                >
                  {tab.label}
                </span>
              </Link>
            );
          })}
        </div>
      </div>
    </nav>
  );
}
