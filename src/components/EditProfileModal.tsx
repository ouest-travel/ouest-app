import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "motion/react";
import { X, User, AtSign, Loader2 } from "lucide-react";
import { Button } from "./ui/button";
import { Input } from "./ui/input";
import { Label } from "./ui/label";
import { toast } from "sonner";

interface EditProfileModalProps {
  isOpen: boolean;
  onClose: () => void;
  currentName: string | null;
  currentHandle: string | null;
  onSave: (name: string, handle: string) => Promise<void>;
}

export function EditProfileModal({
  isOpen,
  onClose,
  currentName,
  currentHandle,
  onSave,
}: EditProfileModalProps) {
  const [displayName, setDisplayName] = useState(currentName || "");
  const [handle, setHandle] = useState(currentHandle || "");
  const [isSaving, setIsSaving] = useState(false);

  // Update form when props change
  useEffect(() => {
    setDisplayName(currentName || "");
    setHandle(currentHandle || "");
  }, [currentName, currentHandle]);

  const validateHandle = (value: string): boolean => {
    // Handle must be 3-30 characters, alphanumeric and underscores only
    const handleRegex = /^[a-zA-Z0-9_]{3,30}$/;
    return handleRegex.test(value);
  };

  const handleSave = async () => {
    // Validation
    if (!displayName.trim()) {
      toast.error("Please enter a display name");
      return;
    }

    if (!handle.trim()) {
      toast.error("Please enter a handle");
      return;
    }

    if (!validateHandle(handle)) {
      toast.error("Handle must be 3-30 characters and contain only letters, numbers, and underscores");
      return;
    }

    setIsSaving(true);
    try {
      await onSave(displayName.trim(), handle.trim().toLowerCase());
      toast.success("Profile updated successfully!");
      onClose();
    } catch (error: any) {
      console.error("Error saving profile:", error);
      
      // Check for unique constraint violation (handle already taken)
      if (error?.message?.includes('duplicate') || error?.code === '23505') {
        toast.error("This handle is already taken. Please choose another.");
      } else {
        toast.error("Failed to update profile. Please try again.");
      }
    } finally {
      setIsSaving(false);
    }
  };

  const handleHandleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    // Only allow alphanumeric and underscores
    const value = e.target.value.toLowerCase().replace(/[^a-z0-9_]/g, "");
    setHandle(value);
  };

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
            className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50"
          />

          {/* Modal */}
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
            <motion.div
              initial={{ opacity: 0, scale: 0.95, y: 20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95, y: 20 }}
              className="bg-card rounded-3xl shadow-2xl w-full max-w-md border border-border overflow-hidden"
            >
              {/* Header */}
              <div
                className="px-6 py-5 border-b border-border"
                style={{
                  background: "var(--ouest-gradient-soft)",
                }}
              >
                <div className="flex items-center justify-between">
                  <h2 className="text-xl font-semibold text-foreground">
                    Edit Profile
                  </h2>
                  <button
                    onClick={onClose}
                    className="p-2 hover:bg-background/50 rounded-full transition-colors"
                    disabled={isSaving}
                  >
                    <X className="w-5 h-5 text-muted-foreground" />
                  </button>
                </div>
              </div>

              {/* Content */}
              <div className="p-6 space-y-5">
                {/* Display Name Field */}
                <div className="space-y-2">
                  <Label htmlFor="displayName" className="text-sm font-medium">
                    Display Name
                  </Label>
                  <div className="relative">
                    <User className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                    <Input
                      id="displayName"
                      type="text"
                      value={displayName}
                      onChange={(e) => setDisplayName(e.target.value)}
                      placeholder="Enter your name"
                      className="pl-11 h-12 rounded-xl"
                      disabled={isSaving}
                      maxLength={50}
                    />
                  </div>
                  <p className="text-xs text-muted-foreground">
                    Your name as it appears to others
                  </p>
                </div>

                {/* Handle Field */}
                <div className="space-y-2">
                  <Label htmlFor="handle" className="text-sm font-medium">
                    Handle
                  </Label>
                  <div className="relative">
                    <AtSign className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                    <Input
                      id="handle"
                      type="text"
                      value={handle}
                      onChange={handleHandleChange}
                      placeholder="username"
                      className="pl-11 h-12 rounded-xl"
                      disabled={isSaving}
                      maxLength={30}
                    />
                  </div>
                  <p className="text-xs text-muted-foreground">
                    3-30 characters, letters, numbers, and underscores only
                  </p>
                </div>
              </div>

              {/* Footer */}
              <div className="px-6 py-4 bg-muted/30 border-t border-border flex gap-3">
                <Button
                  variant="outline"
                  onClick={onClose}
                  className="flex-1 h-11 rounded-xl"
                  disabled={isSaving}
                >
                  Cancel
                </Button>
                <Button
                  onClick={handleSave}
                  className="flex-1 h-11 rounded-xl"
                  style={{
                    background: "var(--ouest-gradient-main)",
                    color: "white",
                  }}
                  disabled={isSaving}
                >
                  {isSaving ? (
                    <>
                      <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                      Saving...
                    </>
                  ) : (
                    "Save Changes"
                  )}
                </Button>
              </div>
            </motion.div>
          </div>
        </>
      )}
    </AnimatePresence>
  );
}

