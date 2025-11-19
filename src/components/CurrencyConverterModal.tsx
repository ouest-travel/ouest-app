"use client";

import { X, RefreshCw, ExternalLink, ArrowRight } from "lucide-react";
import { motion, AnimatePresence } from "motion/react";
import { useState } from "react";

interface CurrencyConverterModalProps {
  isOpen: boolean;
  onClose: () => void;
  onApplyToExpense?: (amount: number, currency: string) => void;
}

const currencies = [
  { code: "USD", name: "US Dollar", symbol: "$", flag: "🇺🇸" },
  { code: "CAD", name: "Canadian Dollar", symbol: "$", flag: "🇨🇦" },
  { code: "EUR", name: "Euro", symbol: "€", flag: "🇪🇺" },
  { code: "GBP", name: "British Pound", symbol: "£", flag: "🇬🇧" },
  { code: "JPY", name: "Japanese Yen", symbol: "¥", flag: "🇯🇵" },
  { code: "AUD", name: "Australian Dollar", symbol: "$", flag: "🇦🇺" },
  { code: "CHF", name: "Swiss Franc", symbol: "Fr", flag: "🇨🇭" },
  { code: "CNY", name: "Chinese Yuan", symbol: "¥", flag: "🇨🇳" },
  { code: "INR", name: "Indian Rupee", symbol: "₹", flag: "🇮🇳" },
  { code: "MXN", name: "Mexican Peso", symbol: "$", flag: "🇲🇽" },
];

// Mock exchange rates (in real app, fetch from API)
const exchangeRates: Record<string, Record<string, number>> = {
  USD: { CAD: 1.35, EUR: 0.92, GBP: 0.79, JPY: 149.50, AUD: 1.52, CHF: 0.88, CNY: 7.24, INR: 83.12, MXN: 17.05 },
  CAD: { USD: 0.74, EUR: 0.68, GBP: 0.59, JPY: 110.80, AUD: 1.13, CHF: 0.65, CNY: 5.36, INR: 61.57, MXN: 12.63 },
  EUR: { USD: 1.09, CAD: 1.47, GBP: 0.86, JPY: 162.50, AUD: 1.65, CHF: 0.96, CNY: 7.88, INR: 90.45, MXN: 18.55 },
};

export function CurrencyConverterModal({ isOpen, onClose, onApplyToExpense }: CurrencyConverterModalProps) {
  const [fromCurrency, setFromCurrency] = useState(currencies[1]); // CAD
  const [toCurrency, setToCurrency] = useState(currencies[4]); // JPY
  const [amount, setAmount] = useState("");
  const [isConverting, setIsConverting] = useState(false);

  const calculateConversion = () => {
    if (!amount) return 0;
    const rate = exchangeRates[fromCurrency.code]?.[toCurrency.code] || 1;
    return (parseFloat(amount) * rate).toFixed(2);
  };

  const handleConvert = async () => {
    setIsConverting(true);
    await new Promise(resolve => setTimeout(resolve, 500));
    setIsConverting(false);
  };

  const handleApply = () => {
    if (onApplyToExpense && amount) {
      onApplyToExpense(parseFloat(amount), fromCurrency.code);
      onClose();
    }
  };

  const conversionResult = calculateConversion();
  const rate = exchangeRates[fromCurrency.code]?.[toCurrency.code] || 1;

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
            initial={{ opacity: 0, y: 50 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 50 }}
            transition={{ type: "spring", stiffness: 300, damping: 30 }}
            className="fixed inset-x-4 bottom-4 max-w-md mx-auto bg-card rounded-3xl shadow-2xl z-50 overflow-hidden"
          >
            {/* Gradient Header */}
            <div
              className="relative px-6 pt-6 pb-12 overflow-hidden"
              style={{
                background: "var(--ouest-gradient-main)",
              }}
            >
              {/* Floating currency symbols animation */}
              <div className="absolute inset-0 overflow-hidden opacity-20">
                <motion.div
                  animate={{ y: [0, -100], opacity: [0.5, 0] }}
                  transition={{ duration: 3, repeat: Infinity, ease: "easeOut" }}
                  className="absolute top-10 left-10 text-4xl text-white"
                >
                  $
                </motion.div>
                <motion.div
                  animate={{ y: [0, -100], opacity: [0.5, 0] }}
                  transition={{ duration: 3, repeat: Infinity, ease: "easeOut", delay: 0.5 }}
                  className="absolute top-20 right-20 text-4xl text-white"
                >
                  €
                </motion.div>
                <motion.div
                  animate={{ y: [0, -100], opacity: [0.5, 0] }}
                  transition={{ duration: 3, repeat: Infinity, ease: "easeOut", delay: 1 }}
                  className="absolute top-16 left-1/2 text-4xl text-white"
                >
                  ¥
                </motion.div>
              </div>

              <button
                onClick={onClose}
                className="absolute top-4 right-4 p-2 rounded-full bg-white/20 hover:bg-white/30 transition-colors"
              >
                <X className="w-5 h-5 text-white" />
              </button>

              <div className="relative z-10">
                <h2 className="text-white mb-1">Currency Converter</h2>
                <p className="text-white/80" style={{ fontSize: "14px" }}>
                  Convert between currencies easily
                </p>
              </div>
            </div>

            {/* Content */}
            <div className="px-6 py-6 -mt-6">
              <div className="bg-card rounded-2xl p-5 shadow-lg border border-border space-y-4">
                {/* From Currency */}
                <div>
                  <label className="block mb-2 text-muted-foreground" style={{ fontSize: "13px" }}>
                    From
                  </label>
                  <div className="flex gap-2">
                    <select
                      value={fromCurrency.code}
                      onChange={(e) => setFromCurrency(currencies.find(c => c.code === e.target.value)!)}
                      className="flex-1 px-4 py-3 bg-muted rounded-xl border-0 focus:outline-none focus:ring-2 text-foreground"
                    >
                      {currencies.map((currency) => (
                        <option key={currency.code} value={currency.code}>
                          {currency.flag} {currency.code}
                        </option>
                      ))}
                    </select>
                    <input
                      type="number"
                      value={amount}
                      onChange={(e) => setAmount(e.target.value)}
                      onFocus={handleConvert}
                      placeholder="0.00"
                      className="w-32 px-4 py-3 bg-muted rounded-xl border-0 focus:outline-none focus:ring-2 text-foreground"
                    />
                  </div>
                </div>

                {/* Swap Button */}
                <div className="flex justify-center">
                  <button
                    onClick={() => {
                      const temp = fromCurrency;
                      setFromCurrency(toCurrency);
                      setToCurrency(temp);
                    }}
                    className="p-2 rounded-full bg-muted hover:bg-muted/70 transition-colors"
                  >
                    <ArrowRight className="w-5 h-5 text-muted-foreground rotate-90" />
                  </button>
                </div>

                {/* To Currency */}
                <div>
                  <label className="block mb-2 text-muted-foreground" style={{ fontSize: "13px" }}>
                    To
                  </label>
                  <div className="flex gap-2">
                    <select
                      value={toCurrency.code}
                      onChange={(e) => setToCurrency(currencies.find(c => c.code === e.target.value)!)}
                      className="flex-1 px-4 py-3 bg-muted rounded-xl border-0 focus:outline-none focus:ring-2 text-foreground"
                    >
                      {currencies.map((currency) => (
                        <option key={currency.code} value={currency.code}>
                          {currency.flag} {currency.code}
                        </option>
                      ))}
                    </select>
                    <div className="w-32 px-4 py-3 bg-muted rounded-xl flex items-center justify-end">
                      {isConverting ? (
                        <RefreshCw className="w-4 h-4 animate-spin text-muted-foreground" />
                      ) : (
                        <span className="text-foreground">{conversionResult}</span>
                      )}
                    </div>
                  </div>
                </div>

                {/* Exchange Rate Info */}
                {amount && (
                  <motion.div
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    className="p-3 rounded-xl"
                    style={{
                      background: "var(--ouest-gradient-soft)",
                    }}
                  >
                    <p className="text-muted-foreground text-center" style={{ fontSize: "13px" }}>
                      Exchange rate: 1 {fromCurrency.code} = {rate.toFixed(4)} {toCurrency.code}
                    </p>
                    <p className="text-muted-foreground text-center mt-1" style={{ fontSize: "11px" }}>
                      Updated daily
                    </p>
                  </motion.div>
                )}
              </div>

              {/* External Source Link */}
              <a
                href="https://www.xe.com"
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center justify-center gap-2 mt-4 py-3 px-4 rounded-xl border border-border hover:border-foreground/20 transition-colors group"
              >
                <span className="text-muted-foreground group-hover:text-foreground transition-colors" style={{ fontSize: "13px" }}>
                  View source → xe.com
                </span>
                <ExternalLink className="w-3 h-3 text-muted-foreground group-hover:text-foreground transition-colors" />
              </a>

              {/* Action Buttons */}
              {onApplyToExpense && (
                <button
                  onClick={handleApply}
                  disabled={!amount}
                  className="w-full mt-4 py-4 rounded-2xl text-white shadow-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed hover:shadow-xl"
                  style={{
                    background: amount ? "var(--ouest-gradient-main)" : "#e5e7eb",
                  }}
                >
                  Apply to Expense
                </button>
              )}
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
