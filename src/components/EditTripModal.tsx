"use client";

import { useState, useEffect, useRef } from "react";
import { motion, AnimatePresence } from "motion/react";
import { X, MapPin, DollarSign, Calendar as CalendarIcon, Dice6, Image as ImageIcon } from "lucide-react";
import { Button } from "./ui/button";
import { Input } from "./ui/input";
import { Calendar } from "./ui/calendar";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "./ui/select";
import { ImageWithFallback } from "./figma/ImageWithFallback";
import { uploadImageToCloudinary } from "../lib/cloudinary/uploadImage";
import { toast } from "sonner";

interface EditTripModalProps {
  isOpen: boolean;
  onClose: () => void;
  tripData: {
    id?: string | number | null;
    name: string;
    destination: string;
    startDate?: Date;
    endDate?: Date;
    budget?: string;
    currency?: string;
    coverImage?: string | null;
  };
  onSave: (updatedTrip: any) => Promise<void> | void;
}

const tripNameSuggestions = [
  "Girls Trip to Paradise",
  "Bros Weekend Escape",
  "Family Adventure 2025",
  "Squad Goals Vacation",
  "Wanderlust Chronicles",
  "The Great Escape",
];

export function EditTripModal({ isOpen, onClose, tripData, onSave }: EditTripModalProps) {
  const [formData, setFormData] = useState({
    name: tripData.name,
    destination: tripData.destination,
    startDate: tripData.startDate,
    endDate: tripData.endDate,
    budget: tripData.budget || "",
    currency: tripData.currency || "CAD",
    coverImage: tripData.coverImage || null,
  });
  const [uploading, setUploading] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (isOpen) {
      setFormData({
        name: tripData.name,
        destination: tripData.destination,
        startDate: tripData.startDate,
        endDate: tripData.endDate,
        budget: tripData.budget || "",
        currency: tripData.currency || "CAD",
        coverImage: tripData.coverImage || null,
      });
    }
  }, [isOpen, tripData]);

  const generateRandomName = () => {
    const randomName = tripNameSuggestions[Math.floor(Math.random() * tripNameSuggestions.length)];
    setFormData({ ...formData, name: randomName });
  };

  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (!file.type.startsWith("image/")) {
      toast.error("Please select an image file");
      return;
    }

    if (file.size > 5 * 1024 * 1024) {
      toast.error("Image must be less than 5MB");
      return;
    }

    setUploading(true);
    try {
      const imageUrl = await uploadImageToCloudinary(file);
      setFormData({ ...formData, coverImage: imageUrl });
      toast.success("Cover image updated!");
    } catch (error) {
      console.error("Upload error:", error);
      toast.error("Failed to upload image");
    } finally {
      setUploading(false);
      if (fileInputRef.current) {
        fileInputRef.current.value = "";
      }
    }
  };

  const getDayCount = () => {
    if (formData.startDate && formData.endDate) {
      const diff = Math.ceil((formData.endDate.getTime() - formData.startDate.getTime()) / (1000 * 60 * 60 * 24));
      return diff;
    }
    return 0;
  };

  const formatDate = (date: Date | undefined) => {
    if (!date) return "";
    return date.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
  };

  const handleSave = async () => {
    if (!formData.name || !formData.destination) {
      return;
    }
    
    try {
      const result = onSave({
        ...tripData,
        ...formData,
        coverImage: formData.coverImage,
      });
      
      // Handle both async and sync onSave functions
      if (result instanceof Promise) {
        await result;
      }
      
      // Close modal after successful save
      // Note: Parent component may also close it, but we ensure it closes here
      onClose();
    } catch (error) {
      // If save fails, don't close modal so user can retry
      console.error('Error saving trip:', error);
    }
  };

  if (!isOpen) return null;

  return (
    <AnimatePresence>
      <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-2 sm:p-4 lg:p-6">
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          exit={{ opacity: 0, scale: 0.95 }}
          transition={{ duration: 0.2 }}
          className="bg-background rounded-2xl sm:rounded-3xl max-w-2xl lg:max-w-4xl w-full max-h-[95vh] sm:max-h-[90vh] overflow-y-auto shadow-2xl"
        >
          {/* Header */}
          <div
            className="sticky top-0 px-4 sm:px-6 py-3 sm:py-4 border-b border-border z-10"
            style={{
              background: "var(--ouest-gradient-soft)",
            }}
          >
            <div className="flex items-center justify-between">
              <h2 className="text-foreground text-lg sm:text-xl">Edit Trip</h2>
              <Button variant="ghost" size="sm" onClick={onClose}>
                <X className="w-5 h-5" />
              </Button>
            </div>
          </div>

          {/* Content */}
          <div className="px-4 sm:px-6 lg:px-8 py-4 sm:py-6 lg:py-8 space-y-4 sm:space-y-6">
            {/* Cover Image */}
            <div className="space-y-2 sm:space-y-3">
              <label className="text-sm text-muted-foreground">Cover Image</label>
              <div className="bg-card rounded-2xl border-2 border-border overflow-hidden">
                {formData.coverImage ? (
                  <div className="relative aspect-[16/9] w-full">
                    <ImageWithFallback
                      src={formData.coverImage}
                      alt="Trip cover"
                      className="w-full h-full object-cover"
                    />
                    <button
                      onClick={() => setFormData({ ...formData, coverImage: null })}
                      className="absolute top-3 right-3 bg-background/90 rounded-full p-2 hover:bg-background transition-colors"
                    >
                      <X className="w-4 h-4" />
                    </button>
                  </div>
                ) : (
                  <button
                    onClick={() => fileInputRef.current?.click()}
                    disabled={uploading}
                    className="w-full aspect-[16/9] flex flex-col items-center justify-center gap-3 hover:bg-muted transition-colors disabled:opacity-50"
                  >
                    <div
                      className="w-14 h-14 rounded-full flex items-center justify-center"
                      style={{
                        background: "var(--ouest-gradient-soft)",
                      }}
                    >
                      <ImageIcon className="w-6 h-6" style={{ color: "var(--ouest-purple)" }} />
                    </div>
                    <div>
                      <p className="text-sm text-foreground">
                        {uploading ? "Uploading..." : "Add cover image"}
                      </p>
                      <p className="text-xs text-muted-foreground">Choose from library or upload</p>
                    </div>
                  </button>
                )}
              </div>
              <input
                ref={fileInputRef}
                type="file"
                accept="image/*"
                onChange={handleImageUpload}
                className="hidden"
              />
            </div>

            {/* Trip Name */}
            <div className="space-y-2 sm:space-y-3">
              <label className="text-sm text-muted-foreground">Trip Name</label>
              <div className="relative">
                <Input
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  placeholder="My Amazing Trip"
                  maxLength={40}
                  className="text-base sm:text-lg py-4 sm:py-6 px-4 rounded-xl border-2 border-border focus:border-[var(--ouest-purple)] transition-all"
                />
                <div className="flex items-center justify-between mt-2">
                  <span className="text-sm text-muted-foreground">{formData.name.length}/40</span>
                  <Button variant="ghost" size="sm" onClick={generateRandomName}>
                    <Dice6 className="w-4 h-4 mr-1" />
                    Surprise me
                  </Button>
                </div>
              </div>
            </div>

            {/* Destination */}
            <div className="space-y-2 sm:space-y-3">
              <label className="text-sm text-muted-foreground">Destination</label>
              <div className="relative">
                <MapPin className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground z-10" />
                <Input
                  value={formData.destination}
                  onChange={(e) => setFormData({ ...formData, destination: e.target.value })}
                  placeholder="Search destination..."
                  className="text-base sm:text-lg py-4 sm:py-6 pl-12 pr-4 rounded-xl border-2 border-border focus:border-[var(--ouest-purple)]"
                />
              </div>
            </div>

            {/* Dates */}
            <div className="space-y-2 sm:space-y-3">
              <label className="text-sm text-muted-foreground">Trip Dates</label>
              <div className="bg-muted rounded-xl border-2 border-border p-2 sm:p-4 lg:p-6">
                <div className="flex justify-center">
                  <Calendar
                    mode="range"
                    selected={{
                      from: formData.startDate,
                      to: formData.endDate,
                    }}
                    onSelect={(range) => {
                      setFormData({
                        ...formData,
                        startDate: range?.from,
                        endDate: range?.to,
                      });
                    }}
                    className="rounded-lg"
                  />
                </div>
              </div>

              {formData.startDate && formData.endDate && (
                <motion.div
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  className="rounded-xl p-4 text-center"
                  style={{
                    background: "var(--ouest-gradient-soft)",
                  }}
                >
                  <CalendarIcon className="w-5 h-5 mx-auto mb-2" style={{ color: "var(--ouest-purple)" }} />
                  <p className="text-foreground">
                    <span className="font-medium">{getDayCount()} days</span> in <span className="font-medium">{formData.destination}</span>
                  </p>
                  <p className="text-sm text-muted-foreground mt-1">
                    {formatDate(formData.startDate)} – {formatDate(formData.endDate)}
                  </p>
                </motion.div>
              )}
            </div>

            {/* Budget */}
            <div className="space-y-2 sm:space-y-3">
              <label className="text-sm text-muted-foreground">Budget (optional)</label>
              <div className="grid grid-cols-3 gap-2 sm:gap-3">
                <div className="col-span-1">
                  <Select value={formData.currency} onValueChange={(val) => setFormData({ ...formData, currency: val })}>
                    <SelectTrigger className="rounded-xl py-4 sm:py-6 text-sm sm:text-base">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="CAD">🇨🇦 CAD</SelectItem>
                      <SelectItem value="USD">🇺🇸 USD</SelectItem>
                      <SelectItem value="EUR">🇪🇺 EUR</SelectItem>
                      <SelectItem value="GBP">🇬🇧 GBP</SelectItem>
                      <SelectItem value="JPY">🇯🇵 JPY</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="col-span-2">
                  <div className="relative">
                    <DollarSign className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                    <Input
                      type="number"
                      value={formData.budget}
                      onChange={(e) => setFormData({ ...formData, budget: e.target.value })}
                      placeholder="3500"
                      className="text-base sm:text-lg py-4 sm:py-6 pl-12 pr-4 rounded-xl border-2 border-border focus:border-[var(--ouest-purple)]"
                    />
                  </div>
                </div>
              </div>
              <p className="text-xs text-muted-foreground">Total trip budget for all members.</p>
            </div>
          </div>

          {/* Footer */}
          <div className="sticky bottom-0 px-4 sm:px-6 lg:px-8 py-3 sm:py-4 border-t border-border bg-background">
            <div className="flex gap-2 sm:gap-3 lg:gap-4">
              <Button
                variant="outline"
                onClick={onClose}
                className="flex-1 py-4 sm:py-6 rounded-xl border-2 text-sm sm:text-base"
              >
                Cancel
              </Button>
              <Button
                onClick={handleSave}
                disabled={!formData.name || !formData.destination}
                className="flex-1 py-4 sm:py-6 rounded-xl text-white shadow-lg hover:shadow-xl transition-all disabled:opacity-50 text-sm sm:text-base"
                style={{
                  background: "var(--ouest-gradient-main)",
                }}
              >
                Save Changes
              </Button>
            </div>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  );
}

