import { X, ExternalLink, ShieldCheck } from "lucide-react";
import { motion, AnimatePresence } from "motion/react";

interface InfoModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export function InfoModal({ isOpen, onClose }: InfoModalProps) {
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
            initial={{ opacity: 0, scale: 0.95, y: 20 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, y: 20 }}
            transition={{ type: "spring", stiffness: 300, damping: 30 }}
            className="fixed inset-x-4 top-1/2 -translate-y-1/2 max-w-md mx-auto bg-card rounded-3xl shadow-2xl z-50 overflow-hidden"
          >
            {/* Header with gradient */}
            <div
              className="relative px-6 pt-6 pb-16"
              style={{
                background: "var(--ouest-gradient-main)",
              }}
            >
              <button
                onClick={onClose}
                className="absolute top-4 right-4 p-2 rounded-full bg-white/20 hover:bg-white/30 transition-colors"
              >
                <X className="w-5 h-5 text-white" />
              </button>

              <div className="flex items-center gap-3 text-white">
                <ShieldCheck className="w-8 h-8" />
                <h2>About Entry Requirements</h2>
              </div>
            </div>

            {/* Content */}
            <div className="px-6 py-6 space-y-4 -mt-10">
              <div className="bg-card rounded-2xl p-5 shadow-lg border border-border">
                <h3 className="mb-2 text-foreground">How it works</h3>
                <p className="text-muted-foreground">
                  We check visa requirements between your passport country and your destination.
                  Our data comes from official government sources and is updated regularly.
                </p>
              </div>

              <div className="bg-card rounded-2xl p-5 shadow-lg border border-border">
                <h4 className="mb-3 text-foreground">Official Sources</h4>
                <div className="space-y-2">
                  <a
                    href="https://www.henleyglobal.com/passport-index"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center justify-between p-3 rounded-xl bg-muted hover:bg-muted/70 transition-colors group"
                  >
                    <span className="text-foreground">Henley Passport Index</span>
                    <ExternalLink className="w-4 h-4 text-muted-foreground group-hover:text-foreground transition-colors" />
                  </a>
                  
                  <a
                    href="https://travel.state.gov"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center justify-between p-3 rounded-xl bg-muted hover:bg-muted/70 transition-colors group"
                  >
                    <span className="text-foreground">U.S. Travel.gov</span>
                    <ExternalLink className="w-4 h-4 text-muted-foreground group-hover:text-foreground transition-colors" />
                  </a>
                </div>
              </div>

              <p className="text-muted-foreground px-2" style={{ fontSize: '13px' }}>
                Always verify requirements with your destination's embassy before traveling.
              </p>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
