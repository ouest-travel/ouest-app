import { motion } from "motion/react";
import { ArrowLeft, MoreVertical, Send } from "lucide-react";
import { ChatExpenseMessage } from "./ChatExpenseMessage";
import { ChatSummaryMessage } from "./ChatSummaryMessage";
import { useState } from "react";
import { useChatMessages } from "../hooks/useChatMessages";

interface ChatDemoScreenProps {
  onBack?: () => void;
  onClose?: () => void;
  onNavigateToBudget?: () => void;
  tripName?: string;
  trip?: any;
  tripId?: string | number | null;
}

export function ChatDemoScreen({
  onBack,
  onClose,
  onNavigateToBudget,
  tripName,
  trip,
  tripId,
}: ChatDemoScreenProps) {
  const [message, setMessage] = useState("");

  // Get trip ID from props
  const currentTripId = tripId || trip?.id;
  const { messages, sendMessage } = useChatMessages(currentTripId);

  const displayName =
    trip?.name || trip?.destination || tripName || "Tokyo Adventure";

  const handleSendMessage = async () => {
    if (!message.trim()) return;

    await sendMessage(message, "text");
    setMessage("");
  };

  // Fallback demo messages for when there are no messages
  const demoMessages = [
    {
      type: "text",
      user: "Trey",
      avatar: "👨🏻",
      content: "Just booked our hotel in Shibuya! 🏨",
      timestamp: "2:34 PM",
    },
    {
      type: "text",
      user: "Sandra",
      avatar: "👩🏽",
      content: "Amazing! Can't wait 🎉",
      timestamp: "2:35 PM",
    },
    {
      type: "expense",
      user: "Timmy",
      avatar: "👨🏾",
      expenseTitle: "Sushi Zanmai Dinner",
      amount: 120,
      currency: "CAD",
      splitAmong: 4,
      timestamp: "3:12 PM",
    },
    {
      type: "text",
      user: "Jason",
      avatar: "👨🏼",
      content: "That sushi was incredible! 🍣",
      timestamp: "3:15 PM",
    },
    {
      type: "expense",
      user: "Jason",
      avatar: "👨🏼",
      expenseTitle: "Subway Tickets",
      amount: 45,
      currency: "CAD",
      splitAmong: 4,
      timestamp: "4:22 PM",
    },
    {
      type: "text",
      user: "Sandra",
      avatar: "👩🏽",
      content: "Let's settle up before we leave!",
      timestamp: "5:10 PM",
    },
    {
      type: "summary",
      user: "Jason",
      avatar: "👨🏼",
      timestamp: "5:12 PM",
      debts: [
        { from: "Trey", to: "Timmy", amount: 6.25, currency: "CAD" },
        { from: "Trey", to: "Sandra", amount: 18.75, currency: "CAD" },
        { from: "Jason", to: "Sandra", amount: 76.25, currency: "CAD" },
      ],
    },
  ];

  return (
    <div className="fixed inset-0 bg-background flex flex-col z-50">
      {/* Header */}
      <div
        className="px-6 py-4 border-b border-border"
        style={{
          background: "var(--ouest-gradient-soft)",
        }}
      >
        <div className="flex items-center justify-between max-w-md mx-auto">
          <div className="flex items-center gap-3">
            <button
              onClick={() => {
                onBack?.();
                onClose?.();
              }}
              className="p-2 rounded-full hover:bg-muted transition-colors"
            >
              <ArrowLeft className="w-5 h-5 text-foreground" />
            </button>

            <div>
              <h2 className="text-foreground">{displayName}</h2>
              <p className="text-muted-foreground" style={{ fontSize: "13px" }}>
                4 members
              </p>
            </div>
          </div>

          <button className="p-2 rounded-full hover:bg-muted transition-colors">
            <MoreVertical className="w-5 h-5 text-foreground" />
          </button>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto px-6 py-6 max-w-md mx-auto w-full">
        <div className="space-y-4">
          {(messages.length > 0 ? messages : demoMessages).map(
            (msg: any, index) => {
              const msgType = msg.type || msg.message_type;
              return (
                <div key={msg.id || index}>
                  {msgType === "text" ? (
                    <motion.div
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ delay: index * 0.05 }}
                      className="flex items-start gap-2"
                    >
                      <span className="text-xl mt-1">{msg.avatar}</span>
                      <div>
                        <div className="flex items-baseline gap-2 mb-1">
                          <span
                            className="text-foreground"
                            style={{ fontSize: "14px" }}
                          >
                            {msg.user}
                          </span>
                          <span
                            className="text-muted-foreground"
                            style={{ fontSize: "11px" }}
                          >
                            {msg.timestamp}
                          </span>
                        </div>
                        <div className="bg-card rounded-2xl rounded-tl-sm px-4 py-2.5 border border-border max-w-xs">
                          <p className="text-foreground">{msg.content}</p>
                        </div>
                      </div>
                    </motion.div>
                  ) : msgType === "expense" ? (
                    <motion.div
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ delay: index * 0.05 }}
                    >
                      <ChatExpenseMessage
                        userName={msg.user || "User"}
                        userAvatar={msg.avatar || "👤"}
                        expenseTitle={
                          msg.expenseTitle || msg.metadata?.title || "Expense"
                        }
                        amount={msg.amount || msg.metadata?.amount || 0}
                        currency={
                          msg.currency || msg.metadata?.currency || "CAD"
                        }
                        splitAmong={
                          msg.splitAmong || msg.metadata?.splitAmong || 1
                        }
                        timestamp={
                          msg.timestamp ||
                          new Date(
                            msg.created_at || Date.now()
                          ).toLocaleTimeString("en-US", {
                            hour: "numeric",
                            minute: "2-digit",
                          })
                        }
                        onViewInBudget={onNavigateToBudget}
                      />
                    </motion.div>
                  ) : (
                    <motion.div
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ delay: index * 0.05 }}
                    >
                      <ChatSummaryMessage
                        userName={msg.user || "User"}
                        userAvatar={msg.avatar || "👤"}
                        timestamp={
                          msg.timestamp ||
                          new Date(
                            msg.created_at || Date.now()
                          ).toLocaleTimeString("en-US", {
                            hour: "numeric",
                            minute: "2-digit",
                          })
                        }
                        debts={msg.debts || msg.metadata?.debts || []}
                        onViewInBudget={onNavigateToBudget}
                      />
                    </motion.div>
                  )}
                </div>
              );
            }
          )}
        </div>
      </div>

      {/* Message Input */}
      <div className="border-t border-border px-6 py-4 max-w-md mx-auto w-full">
        <div className="flex items-center gap-3">
          <input
            type="text"
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            onKeyPress={(e) => e.key === "Enter" && handleSendMessage()}
            placeholder="Type a message..."
            className="flex-1 px-4 py-3 bg-muted rounded-2xl border-0 focus:outline-none focus:ring-2 text-foreground focus:ring-blue-500"
          />
          <button
            onClick={handleSendMessage}
            className="p-3 rounded-2xl text-white"
            style={{
              background: message ? "var(--ouest-gradient-main)" : "#e5e7eb",
            }}
            disabled={!message}
          >
            <Send className="w-5 h-5" />
          </button>
        </div>
      </div>
    </div>
  );
}
