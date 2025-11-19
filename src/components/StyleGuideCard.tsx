import { motion } from "motion/react";

export function StyleGuideCard() {
  return (
    <div className="min-h-screen bg-background p-6">
      <div className="max-w-2xl mx-auto space-y-8">
        <div>
          <h1 className="mb-2">Ouest Style Guide</h1>
          <p className="text-muted-foreground">
            Design system for the travel budget tracker
          </p>
        </div>

        {/* Gradients */}
        <div>
          <h3 className="mb-4 text-foreground">Gradients</h3>
          <div className="space-y-3">
            <div>
              <p className="text-muted-foreground mb-2" style={{ fontSize: "13px" }}>
                Main Gradient (Blue → Pink → Coral → Indigo)
              </p>
              <div
                className="h-20 rounded-2xl"
                style={{
                  background: "var(--ouest-gradient-main)",
                }}
              />
            </div>
            <div>
              <p className="text-muted-foreground mb-2" style={{ fontSize: "13px" }}>
                Soft Gradient (10% opacity)
              </p>
              <div
                className="h-20 rounded-2xl border border-border"
                style={{
                  background: "var(--ouest-gradient-soft)",
                }}
              />
            </div>
          </div>
        </div>

        {/* Colors */}
        <div>
          <h3 className="mb-4 text-foreground">Brand Colors</h3>
          <div className="grid grid-cols-4 gap-3">
            <div>
              <div
                className="h-16 rounded-xl mb-2"
                style={{ backgroundColor: "var(--ouest-blue)" }}
              />
              <p style={{ fontSize: "12px" }} className="text-muted-foreground">
                Blue
              </p>
            </div>
            <div>
              <div
                className="h-16 rounded-xl mb-2"
                style={{ backgroundColor: "var(--ouest-pink)" }}
              />
              <p style={{ fontSize: "12px" }} className="text-muted-foreground">
                Pink
              </p>
            </div>
            <div>
              <div
                className="h-16 rounded-xl mb-2"
                style={{ backgroundColor: "var(--ouest-coral)" }}
              />
              <p style={{ fontSize: "12px" }} className="text-muted-foreground">
                Coral
              </p>
            </div>
            <div>
              <div
                className="h-16 rounded-xl mb-2"
                style={{ backgroundColor: "var(--ouest-indigo)" }}
              />
              <p style={{ fontSize: "12px" }} className="text-muted-foreground">
                Indigo
              </p>
            </div>
          </div>
        </div>

        {/* Typography */}
        <div>
          <h3 className="mb-4 text-foreground">Typography</h3>
          <div className="space-y-3">
            <div>
              <h1>Heading 1</h1>
            </div>
            <div>
              <h2>Heading 2</h2>
            </div>
            <div>
              <h3>Heading 3</h3>
            </div>
            <div>
              <h4>Heading 4</h4>
            </div>
            <div>
              <p>Body paragraph text</p>
            </div>
            <div>
              <p className="text-muted-foreground" style={{ fontSize: "13px" }}>
                Small text / captions
              </p>
            </div>
          </div>
        </div>

        {/* Cards */}
        <div>
          <h3 className="mb-4 text-foreground">Card Styles</h3>
          <div className="space-y-3">
            <div className="bg-card rounded-3xl p-6 border border-border shadow-lg">
              <p className="text-foreground">Large rounded card (radius: 24px)</p>
            </div>
            <div className="bg-card rounded-2xl p-4 border border-border shadow-md">
              <p className="text-foreground">Medium rounded card (radius: 16px)</p>
            </div>
            <div className="bg-card rounded-xl p-3 border border-border">
              <p className="text-foreground">Small rounded card (radius: 12px)</p>
            </div>
          </div>
        </div>

        {/* Buttons */}
        <div>
          <h3 className="mb-4 text-foreground">Buttons</h3>
          <div className="space-y-3">
            <button
              className="w-full py-4 rounded-2xl text-white shadow-lg"
              style={{
                background: "var(--ouest-gradient-main)",
              }}
            >
              Primary Gradient Button
            </button>
            <button className="w-full py-4 rounded-2xl border-2 text-foreground" style={{ borderColor: "var(--ouest-blue)" }}>
              Outlined Button
            </button>
            <button className="w-full py-3 rounded-xl bg-muted hover:bg-muted/70 text-foreground">
              Secondary Button
            </button>
          </div>
        </div>

        {/* Icons & Emojis */}
        <div>
          <h3 className="mb-4 text-foreground">Category Icons</h3>
          <div className="flex gap-4">
            <div className="text-center">
              <div className="text-4xl mb-2">🍽️</div>
              <p className="text-muted-foreground" style={{ fontSize: "12px" }}>
                Food
              </p>
            </div>
            <div className="text-center">
              <div className="text-4xl mb-2">🚕</div>
              <p className="text-muted-foreground" style={{ fontSize: "12px" }}>
                Transport
              </p>
            </div>
            <div className="text-center">
              <div className="text-4xl mb-2">🏨</div>
              <p className="text-muted-foreground" style={{ fontSize: "12px" }}>
                Stay
              </p>
            </div>
            <div className="text-center">
              <div className="text-4xl mb-2">🎟️</div>
              <p className="text-muted-foreground" style={{ fontSize: "12px" }}>
                Activities
              </p>
            </div>
          </div>
        </div>

        {/* Microinteractions */}
        <div>
          <h3 className="mb-4 text-foreground">Microinteractions</h3>
          <div className="space-y-3">
            <motion.div
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              className="bg-card rounded-2xl p-4 border border-border cursor-pointer"
            >
              <p className="text-foreground">Hover & Tap animation</p>
            </motion.div>
            <motion.div
              animate={{ opacity: [0.5, 1, 0.5] }}
              transition={{ duration: 2, repeat: Infinity }}
              className="bg-card rounded-2xl p-4 border border-border"
            >
              <p className="text-foreground">Pulse animation</p>
            </motion.div>
          </div>
        </div>
      </div>
    </div>
  );
}
