"use client";

import { useState, useRef } from "react";
import { motion } from "motion/react";
import {
  Settings,
  Bookmark,
  Heart,
  MapPin,
  Moon,
  Sun,
  Bell,
  CreditCard,
  HelpCircle,
  TestTube,
  LogOut,
  Camera,
  Edit2,
} from "lucide-react";
import { useTheme } from "./ThemeProvider";
import { useDemoMode } from "../contexts/DemoModeContext";
import { useAuth } from "../contexts/AuthContext";
import { useProfile } from "../hooks/useProfile";
import { useProfileStats } from "../hooks/useProfileStats";
import { Switch } from "./ui/switch";
import { toast } from "sonner";
import { uploadImageToCloudinary } from "../lib/cloudinary/uploadImage";
import { EditProfileModal } from "./EditProfileModal";
import { useRouter } from "next/navigation";

export function YouScreen() {
  const router = useRouter();
  const { theme, toggleTheme } = useTheme();
  const { isDemoMode, toggleDemoMode } = useDemoMode();
  const { user, signOut } = useAuth();
  const { profile, loading, updateProfile } = useProfile();
  const { stats, loading: statsLoading } = useProfileStats();
  const [uploading, setUploading] = useState(false);
  const [isEditModalOpen, setIsEditModalOpen] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleToggleDemoMode = () => {
    toggleDemoMode();
    toast.success(isDemoMode ? "Demo mode disabled" : "Demo mode enabled");
  };

  const handleSignOut = async () => {
    await signOut();
    toast.success("Signed out successfully");
    router.push("/login");
  };

  const handleSaveProfile = async (displayName: string, handle: string) => {
    const result = await updateProfile({
      display_name: displayName,
      handle: handle,
    });

    if (result.error) {
      throw result.error;
    }
  };

  const handleAvatarClick = () => {
    if (isDemoMode) {
      toast.info("Avatar upload disabled in demo mode");
      return;
    }
    fileInputRef.current?.click();
  };

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Validate file type
    if (!file.type.startsWith("image/")) {
      toast.error("Please select an image file");
      return;
    }

    // Validate file size (max 5MB)
    if (file.size > 5 * 1024 * 1024) {
      toast.error("Image must be less than 5MB");
      return;
    }

    setUploading(true);
    try {
      const avatarUrl = await uploadImageToCloudinary(file);
      await updateProfile({ avatar_url: avatarUrl });
      toast.success("Profile picture updated!");
    } catch (error) {
      console.error("Upload error:", error);
      toast.error("Failed to upload image");
    } finally {
      setUploading(false);
      // Reset file input
      if (fileInputRef.current) {
        fileInputRef.current.value = "";
      }
    }
  };

  const statsData = [
    {
      label: "Countries Visited",
      value: stats.countriesVisited.toString(),
      icon: MapPin,
    },
    {
      label: "Total Trips",
      value: stats.totalTrips.toString(),
      icon: Bookmark,
    },
    {
      label: "Wishlist Items",
      value: stats.wishlistItems.toString(),
      icon: Heart,
    },
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
            className="relative inline-block mb-4"
          >
            <div
              className="w-24 h-24 rounded-full bg-white/20 backdrop-blur-sm overflow-hidden flex items-center justify-center cursor-pointer hover:opacity-90 transition-opacity"
              onClick={handleAvatarClick}
            >
              {profile?.avatar_url ? (
                <img
                  src={profile.avatar_url}
                  alt="Profile"
                  className="w-full h-full object-cover"
                />
              ) : (
                <span className="text-6xl">👤</span>
              )}
              {uploading && (
                <div className="absolute inset-0 bg-black/50 flex items-center justify-center">
                  <div className="w-8 h-8 border-3 border-white border-t-transparent rounded-full animate-spin" />
                </div>
              )}
            </div>

            {/* Camera button overlay */}
            {!uploading && (
              <button
                onClick={handleAvatarClick}
                className="absolute bottom-0 right-0 p-2 rounded-full bg-white shadow-lg hover:scale-110 transition-transform"
                style={{ color: "var(--ouest-blue)" }}
              >
                <Camera className="w-4 h-4" />
              </button>
            )}
          </motion.div>

          {/* Hidden file input */}
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            onChange={handleFileChange}
            className="hidden"
          />

          {loading ? (
            <div className="text-white">Loading...</div>
          ) : (
            <>
              <h2 className="text-white mb-1">
                {profile?.display_name || "User"}
              </h2>
              <p className="text-white/80" style={{ fontSize: "14px" }}>
                @{profile?.handle || "user"}
              </p>

              {/* Edit Profile Button */}
              <button
                onClick={() => setIsEditModalOpen(true)}
                className="mt-3 inline-flex items-center gap-2 px-4 py-2 bg-white/20 hover:bg-white/30 backdrop-blur-sm rounded-full text-white text-sm transition-colors"
              >
                <Edit2 className="w-4 h-4" />
                Edit Profile
              </button>
            </>
          )}
        </div>
      </div>

      <div className="px-6 -mt-8 max-w-md mx-auto">
        {/* Stats Card */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-card rounded-3xl p-6 shadow-xl border border-border mb-6"
        >
          {statsLoading ? (
            <div className="text-center text-muted-foreground py-4">
              Loading stats...
            </div>
          ) : (
            <div className="grid grid-cols-3 gap-4">
              {statsData.map((stat) => {
                const Icon = stat.icon;
                return (
                  <div key={stat.label} className="text-center">
                    <div
                      className="inline-flex p-3 rounded-2xl mb-2"
                      style={{
                        background: "var(--ouest-gradient-soft)",
                      }}
                    >
                      <Icon
                        className="w-5 h-5"
                        style={{ color: "var(--ouest-blue)" }}
                      />
                    </div>
                    <div className="mb-1 text-foreground">{stat.value}</div>
                    <div
                      className="text-muted-foreground"
                      style={{ fontSize: "12px" }}
                    >
                      {stat.label}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </motion.div>

        {/* Theme Toggle */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="bg-card rounded-3xl shadow-lg border border-border mb-4 overflow-hidden"
        >
          <button
            onClick={toggleTheme}
            className="w-full flex items-center justify-between p-4 hover:bg-muted transition-colors"
          >
            <div className="flex items-center gap-3">
              <div
                className="p-3 rounded-xl"
                style={{
                  background: "var(--ouest-gradient-soft)",
                }}
              >
                {theme === "light" ? (
                  <Sun
                    className="w-5 h-5"
                    style={{ color: "var(--ouest-blue)" }}
                  />
                ) : (
                  <Moon
                    className="w-5 h-5"
                    style={{ color: "var(--ouest-indigo)" }}
                  />
                )}
              </div>
              <span className="text-foreground">
                {theme === "light" ? "Light Mode" : "Dark Mode"}
              </span>
            </div>
            <div className="text-muted-foreground">Toggle</div>
          </button>

          <div className="border-t border-border p-4 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div
                className="p-3 rounded-xl"
                style={{
                  background: "var(--ouest-gradient-soft)",
                }}
              >
                <TestTube
                  className="w-5 h-5"
                  style={{ color: "var(--ouest-purple)" }}
                />
              </div>
              <div>
                <span className="text-foreground">Demo Mode</span>
                <p className="text-xs text-muted-foreground">
                  Use mock data instead of backend
                </p>
              </div>
            </div>
            <Switch
              checked={isDemoMode}
              onCheckedChange={handleToggleDemoMode}
            />
          </div>
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

          {/* Sign Out Button (only show if not in demo mode and user is logged in) */}
          {!isDemoMode && user && (
            <button
              onClick={handleSignOut}
              className="w-full flex items-center justify-between p-4 hover:bg-muted transition-colors border-t border-border"
            >
              <div className="flex items-center gap-3">
                <LogOut className="w-5 h-5 text-muted-foreground" />
                <span className="text-foreground">Sign Out</span>
              </div>
              <span className="text-muted-foreground">›</span>
            </button>
          )}
        </motion.div>

        {/* App Version */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.4 }}
          className="mt-8 text-center text-muted-foreground"
          style={{ fontSize: "13px" }}
        >
          Ouest v1.0.0
        </motion.div>
      </div>

      {/* Edit Profile Modal */}
      <EditProfileModal
        isOpen={isEditModalOpen}
        onClose={() => setIsEditModalOpen(false)}
        currentName={profile?.display_name || null}
        currentHandle={profile?.handle || null}
        onSave={handleSaveProfile}
      />
    </div>
  );
}
