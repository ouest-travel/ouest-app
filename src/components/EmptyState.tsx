import { motion } from "motion/react";
import { PlaneTakeoff } from "lucide-react";

export function EmptyState() {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      className="flex flex-col items-center justify-center py-12 px-6 text-center"
    >
      <motion.div
        animate={{
          y: [0, -10, 0],
        }}
        transition={{
          duration: 3,
          repeat: Infinity,
          ease: "easeInOut",
        }}
        className="mb-6"
      >
        <div
          className="p-6 rounded-3xl"
          style={{
            background: "var(--ouest-gradient-soft)",
          }}
        >
          <PlaneTakeoff
            className="w-12 h-12"
            style={{ color: "var(--ouest-blue)" }}
          />
        </div>
      </motion.div>

      <h3 className="mb-2 text-foreground">Hmm... looks like this route isn't in our system yet.</h3>
      
      <p className="text-muted-foreground max-w-xs">
        Try another destination or check official travel.gov sites.
      </p>
    </motion.div>
  );
}
