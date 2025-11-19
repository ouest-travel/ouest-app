"use client";

import { useState } from "react";
import { motion } from "motion/react";
import { Mail, Lock, User, Eye, EyeOff } from "lucide-react";
import { Button } from "../ui/button";
import { Input } from "../ui/input";
import { useAuth } from "../../contexts/AuthContext";
import { toast } from "sonner";

interface SignUpScreenProps {
  onSwitchToLogin: () => void;
}

export function SignUpScreen({ onSwitchToLogin }: SignUpScreenProps) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const { signUp } = useAuth();

  const handleSignUp = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!email || !password || !displayName) {
      toast.error("Please fill in all fields");
      return;
    }

    if (password.length < 6) {
      toast.error("Password must be at least 6 characters");
      return;
    }

    setLoading(true);
    const { error } = await signUp(email, password, displayName);

    if (error) {
      toast.error(error.message);
      setLoading(false);
    } else {
      toast.success("Account created! Please check your email to verify.");
    }
  };

  return (
    <div className="min-h-screen bg-background flex items-center justify-center p-6">
      <div className="max-w-md w-full">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="text-center mb-8"
        >
          <img
            src="/ouest-transparent.png"
            alt="Ouest Logo"
            className="w-16 h-16 mx-auto mb-4"
          />
          <h1 className="text-foreground mb-2">Create Account</h1>
          <p className="text-muted-foreground">
            Start planning your adventures
          </p>
        </motion.div>

        <motion.form
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          onSubmit={handleSignUp}
          className="space-y-4"
        >
          <div className="bg-card rounded-2xl border border-border p-4">
            <div className="flex items-center gap-3 mb-4">
              <User className="w-5 h-5 text-muted-foreground" />
              <Input
                type="text"
                placeholder="Display name"
                value={displayName}
                onChange={(e) => setDisplayName(e.target.value)}
                className="border-0 px-0 focus-visible:ring-0"
                autoComplete="name"
              />
            </div>
            <div className="border-t border-border pt-4 mb-4">
              <div className="flex items-center gap-3">
                <Mail className="w-5 h-5 text-muted-foreground" />
                <Input
                  type="email"
                  placeholder="Email address"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="border-0 px-0 focus-visible:ring-0"
                  autoComplete="email"
                />
              </div>
            </div>
            <div className="border-t border-border pt-4">
              <div className="flex items-center gap-3">
                <Lock className="w-5 h-5 text-muted-foreground" />
                <Input
                  type={showPassword ? "text" : "password"}
                  placeholder="Password (min 6 characters)"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="border-0 px-0 focus-visible:ring-0"
                  autoComplete="new-password"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="text-muted-foreground hover:text-foreground transition-colors"
                >
                  {showPassword ? (
                    <EyeOff className="w-5 h-5" />
                  ) : (
                    <Eye className="w-5 h-5" />
                  )}
                </button>
              </div>
            </div>
          </div>

          <Button
            type="submit"
            className="w-full py-6 text-white shadow-lg hover:shadow-xl transition-all"
            style={{
              background: "var(--ouest-gradient-main)",
            }}
            disabled={loading}
          >
            {loading ? "Creating account..." : "Sign Up"}
          </Button>

          <div className="text-center">
            <button
              type="button"
              onClick={onSwitchToLogin}
              className="text-muted-foreground hover:text-foreground transition-colors text-sm"
            >
              Already have an account?{" "}
              <span className="underline">Sign in</span>
            </button>
          </div>
        </motion.form>
      </div>
    </div>
  );
}
