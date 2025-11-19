import { motion } from "motion/react";
import { Plane } from "lucide-react";

export function LoadingState() {
  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="flex flex-col items-center justify-center py-12 gap-4"
    >
      <motion.div
        animate={{
          rotate: [0, 360],
        }}
        transition={{
          duration: 2,
          repeat: Infinity,
          ease: "linear",
        }}
        className="relative w-16 h-16"
      >
        <div
          className="absolute inset-0 rounded-full opacity-20"
          style={{
            background: "var(--ouest-gradient-main)",
          }}
        />
        <Plane
          className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-8 h-8"
          style={{ color: "var(--ouest-blue)" }}
        />
      </motion.div>
      
      <motion.p
        animate={{ opacity: [0.5, 1, 0.5] }}
        transition={{
          duration: 2,
          repeat: Infinity,
          ease: "easeInOut",
        }}
        className="text-muted-foreground"
      >
        Checking requirements...
      </motion.p>
    </motion.div>
  );
}
