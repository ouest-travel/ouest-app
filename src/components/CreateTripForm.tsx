"use client";

import { useState, useRef } from "react";
import { motion } from "motion/react";
import { 
  X, 
  MapPin, 
  Calendar as CalendarIcon, 
  DollarSign, 
  Share2, 
  Image as ImageIcon,
  Globe,
  Lock,
  Vote
} from "lucide-react";
import { Button } from "./ui/button";
import { Input } from "./ui/input";
import { Textarea } from "./ui/textarea";
import { Switch } from "./ui/switch";
import { Calendar } from "./ui/calendar";
import { Popover, PopoverContent, PopoverTrigger } from "./ui/popover";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "./ui/select";
import { ImageWithFallback } from "./figma/ImageWithFallback";
import { LocationAutocomplete } from "./LocationAutocomplete";
import { uploadImageToCloudinary } from "../lib/cloudinary/uploadImage";
import { toast } from "sonner";

interface CreateTripFormProps {
  onClose: () => void;
  onSave?: (tripData: TripFormData) => void;
  onCreateTrip?: (tripData: TripFormData) => void;
}

interface TripFormData {
  name: string;
  isPublic: boolean;
  coverImage: string | null;
  location: string;
  startDate: Date | undefined;
  endDate: Date | undefined;
  budget: string;
  currency: string;
  votingEnabled: boolean;
  description: string;
  invitedMembers: string[];
}

export function CreateTripForm({ onClose, onSave, onCreateTrip }: CreateTripFormProps) {
  const [formData, setFormData] = useState<TripFormData>({
    name: "",
    isPublic: false,
    coverImage: null,
    location: "",
    startDate: undefined,
    endDate: undefined,
    budget: "",
    currency: "USD",
    votingEnabled: false,
    description: "",
    invitedMembers: [],
  });

  const [showImageUpload, setShowImageUpload] = useState(false);
  const [errors, setErrors] = useState<{ name?: string; location?: string }>({});
  const [uploadingImage, setUploadingImage] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const updateFormData = (updates: Partial<TripFormData>) => {
    setFormData((prev) => ({ ...prev, ...updates }));
  };

  const handleSave = () => {
    const newErrors: { name?: string; location?: string } = {};
    
    if (!formData.name.trim()) {
      newErrors.name = "Trip name is required";
    }
    
    if (!formData.location.trim()) {
      newErrors.location = "Location is required";
    }
    
    if (Object.keys(newErrors).length > 0) {
      setErrors(newErrors);
      toast.error("Please fill in all required fields");
      return;
    }
    
    setErrors({});
    onCreateTrip?.(formData);
    onSave?.(formData);
    toast.success("Trip created successfully!");
    onClose();
  };

  const formatDateRange = () => {
    if (!formData.startDate) return "Select dates";
    if (!formData.endDate) return formData.startDate.toLocaleDateString("en-US", { month: "short", day: "numeric" });
    
    const start = formData.startDate.toLocaleDateString("en-US", { month: "short", day: "numeric" });
    const end = formData.endDate.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
    return `${start} - ${end}`;
  };

  const handleShare = () => {
    toast.success("Invite link copied to clipboard!");
  };

  const handleImageSelect = async (file: File) => {
    if (!file.type.startsWith("image/")) {
      toast.error("Please select an image file");
      return;
    }

    if (file.size > 10 * 1024 * 1024) {
      toast.error("Image size must be less than 10MB");
      return;
    }

    setUploadingImage(true);
    try {
      let imageUrl: string;

      // Try to upload to Cloudinary if configured, otherwise use data URL
      try {
        imageUrl = await uploadImageToCloudinary(file);
      } catch (error) {
        console.warn("Cloudinary upload failed, using local preview:", error);
        // Fallback to data URL for local storage
        imageUrl = await new Promise<string>((resolve, reject) => {
          const reader = new FileReader();
          reader.onload = (e) => resolve(e.target?.result as string);
          reader.onerror = reject;
          reader.readAsDataURL(file);
        });
      }

      updateFormData({ coverImage: imageUrl });
      setShowImageUpload(false);
      toast.success("Image added successfully");
    } catch (error) {
      console.error("Error processing image:", error);
      toast.error("Failed to process image");
    } finally {
      setUploadingImage(false);
    }
  };

  const handleFileInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      handleImageSelect(file);
    }
    // Reset input so same file can be selected again
    e.target.value = "";
  };

  return (
    <div 
      className="fixed inset-0 bg-background z-50 overflow-y-auto"
      role="dialog"
      aria-modal="true"
      aria-labelledby="trip-form-title"
    >
      {/* Header */}
      <div className="sticky top-0 bg-background/95 backdrop-blur-sm border-b border-border z-10">
        <div className="max-w-2xl mx-auto px-4 py-4 flex items-center justify-between">
          <Button 
            variant="ghost" 
            size="sm" 
            onClick={onClose}
            aria-label="Cancel and close trip form"
          >
            Cancel
          </Button>
          <h2 id="trip-form-title" className="text-center text-foreground font-semibold">
            New Trip
          </h2>
          <Button 
            size="sm" 
            onClick={handleSave}
            className="text-white hover:opacity-90 focus-visible:ring-2 focus-visible:ring-offset-2"
            style={{
              background: "var(--ouest-gradient-main)",
            }}
            aria-label="Save trip"
          >
            Save
          </Button>
        </div>
      </div>

      {/* Content */}
      <div className="max-w-2xl mx-auto px-4 py-6 pb-24">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4 }}
          className="space-y-4"
        >
          {/* Public/Private Toggle */}
          <div 
            className="rounded-2xl p-4 border border-border"
            style={{
              background: "var(--ouest-gradient-soft)",
            }}
          >
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                {formData.isPublic ? (
                  <Globe className="w-5 h-5 text-foreground" aria-hidden="true" />
                ) : (
                  <Lock className="w-5 h-5 text-muted-foreground" aria-hidden="true" />
                )}
                <div>
                  <p className="text-sm text-foreground font-medium">
                    {formData.isPublic ? "Public Trip" : "Private Trip"}
                  </p>
                  <p className="text-xs text-muted-foreground">
                    {formData.isPublic 
                      ? "Anyone can discover and join" 
                      : "Only invited members can see"}
                  </p>
                </div>
              </div>
              <Switch
                checked={formData.isPublic}
                onCheckedChange={(checked) => updateFormData({ isPublic: checked })}
                aria-label={formData.isPublic ? "Make trip private" : "Make trip public"}
                aria-describedby="trip-visibility-description"
              />
            </div>
            <span id="trip-visibility-description" className="sr-only">
              {formData.isPublic 
                ? "Public trips can be discovered and joined by anyone" 
                : "Private trips are only visible to invited members"}
            </span>
          </div>

          {/* Trip Name */}
          <div className="bg-card rounded-2xl border-2 border-border overflow-hidden hover:border-primary/50 transition-colors focus-within:border-primary">
            <div className="p-4">
              <label htmlFor="trip-name" className="sr-only">
                Trip Name
              </label>
              <Input
                id="trip-name"
                value={formData.name}
                onChange={(e) => {
                  updateFormData({ name: e.target.value });
                  if (errors.name) {
                    setErrors((prev) => ({ ...prev, name: undefined }));
                  }
                }}
                placeholder="Name your trip"
                className="border-0 px-0 text-lg bg-transparent text-foreground focus-visible:ring-2 focus-visible:ring-primary placeholder:text-muted-foreground"
                aria-required="true"
                aria-invalid={!!errors.name}
                aria-describedby={errors.name ? "trip-name-error" : undefined}
              />
              {errors.name && (
                <p id="trip-name-error" className="text-sm text-destructive mt-1" role="alert">
                  {errors.name}
                </p>
              )}
            </div>
          </div>

          {/* Cover Image */}
          <div className="bg-card rounded-2xl border-2 border-border overflow-hidden">
            {formData.coverImage ? (
              <div className="relative aspect-[16/9] w-full">
                <ImageWithFallback
                  src={formData.coverImage}
                  alt="Trip cover image"
                  className="w-full h-full object-cover"
                />
                <button
                  onClick={() => updateFormData({ coverImage: null })}
                  className="absolute top-3 right-3 bg-background/90 backdrop-blur-sm rounded-full p-2 hover:bg-background transition-colors focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2"
                  aria-label="Remove cover image"
                >
                  <X className="w-4 h-4 text-foreground" aria-hidden="true" />
                </button>
              </div>
            ) : (
              <button
                onClick={() => setShowImageUpload(true)}
                className="w-full aspect-[16/9] flex flex-col items-center justify-center gap-3 hover:bg-muted/50 transition-colors focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2 rounded-2xl"
                aria-label="Add cover image"
              >
                <div 
                  className="w-14 h-14 rounded-full flex items-center justify-center"
                  style={{
                    background: "var(--ouest-gradient-soft)",
                  }}
                >
                  <ImageIcon className="w-6 h-6 text-foreground" aria-hidden="true" />
                </div>
                <div>
                  <p className="text-sm text-foreground">Add cover image</p>
                  <p className="text-xs text-muted-foreground">Choose from library or upload</p>
                </div>
              </button>
            )}
          </div>

          {/* Sections Container */}
          <div className="bg-card rounded-2xl border-2 border-border overflow-hidden divide-y divide-border">
            {/* Location */}
            <div className="p-4">
              <div className="flex items-start gap-4">
                <MapPin className="w-5 h-5 text-muted-foreground flex-shrink-0 mt-1" aria-hidden="true" />
                <div className="flex-1">
                  <label htmlFor="trip-location" className="sr-only">
                    Trip Location
                  </label>
                  <LocationAutocomplete
                    id="trip-location"
                    value={formData.location}
                    onChange={(value) => {
                      updateFormData({ location: value });
                      if (errors.location) {
                        setErrors((prev) => ({ ...prev, location: undefined }));
                      }
                    }}
                    onSelect={(location) => {
                      updateFormData({ location: location.display_name });
                    }}
                    placeholder="Search for a location..."
                    className="border-0 px-0 bg-transparent text-foreground focus-visible:ring-2 focus-visible:ring-primary placeholder:text-muted-foreground"
                    ariaLabel="Trip Location"
                    ariaRequired={true}
                    ariaInvalid={!!errors.location}
                    ariaDescribedBy={errors.location ? "trip-location-error" : undefined}
                  />
                  {errors.location && (
                    <p id="trip-location-error" className="text-sm text-destructive mt-1" role="alert">
                      {errors.location}
                    </p>
                  )}
                </div>
              </div>
            </div>

            {/* Date Range */}
            <Popover>
              <PopoverTrigger asChild>
                <button 
                  className="w-full p-4 flex items-center gap-4 hover:bg-muted/50 transition-colors text-left focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2"
                  aria-label="Select trip dates"
                  aria-describedby="date-range-description"
                >
                  <CalendarIcon className="w-5 h-5 text-muted-foreground flex-shrink-0" aria-hidden="true" />
                  <span className={formData.startDate ? "text-foreground" : "text-muted-foreground"}>
                    {formatDateRange()}
                  </span>
                </button>
              </PopoverTrigger>
              <PopoverContent className="w-auto p-0 bg-card border-border" align="start">
                <Calendar
                  mode="range"
                  selected={{
                    from: formData.startDate,
                    to: formData.endDate,
                  }}
                  onSelect={(range) => {
                    updateFormData({
                      startDate: range?.from,
                      endDate: range?.to,
                    });
                  }}
                  initialFocus
                />
              </PopoverContent>
            </Popover>
            <span id="date-range-description" className="sr-only">
              Select the start and end dates for your trip
            </span>

            {/* Invite Members */}
            <button 
              onClick={handleShare}
              className="w-full p-4 flex items-center gap-4 hover:bg-muted/50 transition-colors text-left focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2"
              aria-label="Send invites to share trip with friends"
            >
              <Share2 className="w-5 h-5 text-muted-foreground flex-shrink-0" aria-hidden="true" />
              <div>
                <p className="text-foreground font-medium">Send invites</p>
                <p className="text-xs text-muted-foreground">Share trip with friends</p>
              </div>
            </button>

            {/* Budget */}
            <div className="p-4">
              <div className="flex items-center gap-4 mb-3">
                <DollarSign className="w-5 h-5 text-muted-foreground flex-shrink-0" aria-hidden="true" />
                <label htmlFor="trip-budget" className="text-foreground font-medium">
                  Budget
                </label>
              </div>
              <div className="flex gap-3 pl-9">
                <Select 
                  value={formData.currency} 
                  onValueChange={(val) => updateFormData({ currency: val })}
                >
                  <SelectTrigger className="w-28 rounded-xl bg-background border-border text-foreground">
                    <SelectValue aria-label="Currency" />
                  </SelectTrigger>
                  <SelectContent className="bg-card border-border">
                    <SelectItem value="USD">🇺🇸 USD</SelectItem>
                    <SelectItem value="EUR">🇪🇺 EUR</SelectItem>
                    <SelectItem value="GBP">🇬🇧 GBP</SelectItem>
                    <SelectItem value="JPY">🇯🇵 JPY</SelectItem>
                    <SelectItem value="CAD">🇨🇦 CAD</SelectItem>
                  </SelectContent>
                </Select>
                <label htmlFor="trip-budget" className="sr-only">
                  Budget Amount
                </label>
                <Input
                  id="trip-budget"
                  type="number"
                  value={formData.budget}
                  onChange={(e) => updateFormData({ budget: e.target.value })}
                  placeholder="0.00"
                  className="flex-1 rounded-xl bg-background border-border text-foreground placeholder:text-muted-foreground"
                  aria-label="Budget amount"
                />
              </div>
              {formData.budget && (
                <p className="text-xs text-muted-foreground mt-2 pl-9">
                  Connected to budget tracker • Split expenses with group
                </p>
              )}
            </div>

            {/* Voting Options */}
            <div className="p-4 flex items-center gap-4 justify-between">
              <div className="flex items-center gap-4">
                <Vote className="w-5 h-5 text-muted-foreground flex-shrink-0" aria-hidden="true" />
                <div>
                  <p className="text-foreground font-medium">Enable voting</p>
                  <p className="text-xs text-muted-foreground">Let members vote on activities</p>
                </div>
              </div>
              <Switch
                checked={formData.votingEnabled}
                onCheckedChange={(checked) => updateFormData({ votingEnabled: checked })}
                aria-label={formData.votingEnabled ? "Disable voting" : "Enable voting"}
                aria-describedby="voting-description"
              />
            </div>
            <span id="voting-description" className="sr-only">
              When enabled, trip members can vote on activities and destinations
            </span>
          </div>

          {/* Description */}
          <div className="bg-card rounded-2xl border-2 border-border overflow-hidden p-4 focus-within:border-primary">
            <label htmlFor="trip-description" className="sr-only">
              Trip Description
            </label>
            <Textarea
              id="trip-description"
              value={formData.description}
              onChange={(e) => updateFormData({ description: e.target.value })}
              placeholder="Add a description of your trip"
              className="border-0 px-0 min-h-32 resize-none bg-transparent text-foreground focus-visible:ring-2 focus-visible:ring-primary placeholder:text-muted-foreground"
              aria-label="Trip description"
            />
          </div>

          {/* Connected Features Info */}
          <div 
            className="rounded-2xl p-4 border border-border"
            style={{
              background: "var(--ouest-gradient-soft)",
            }}
          >
            <p className="text-xs text-foreground mb-2 font-medium">✨ Features included:</p>
            <ul className="grid grid-cols-2 gap-2 text-xs text-muted-foreground list-none">
              <li>• Budget tracking</li>
              <li>• Entry requirements</li>
              <li>• Group chat</li>
              <li>• Expense splitting</li>
            </ul>
          </div>
        </motion.div>
      </div>

      {/* Image Upload Modal */}
      {showImageUpload && (
        <div 
          className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4"
          role="dialog"
          aria-modal="true"
          aria-labelledby="image-upload-title"
          onClick={(e) => {
            if (e.target === e.currentTarget) {
              setShowImageUpload(false);
            }
          }}
        >
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            className="bg-card rounded-3xl p-6 max-w-md w-full border border-border"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between mb-4">
              <h3 id="image-upload-title" className="text-foreground font-semibold">
                Choose Cover Image
              </h3>
              <button 
                onClick={() => setShowImageUpload(false)}
                className="rounded-full p-1 hover:bg-muted transition-colors focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2"
                aria-label="Close image upload dialog"
              >
                <X className="w-5 h-5 text-foreground" aria-hidden="true" />
              </button>
            </div>
            <p className="text-sm text-muted-foreground mb-4">
              Select a stock image or upload your own
            </p>
            <div className="space-y-3">
              <input
                type="file"
                ref={fileInputRef}
                accept="image/*"
                onChange={handleFileInputChange}
                className="hidden"
                aria-label="Upload image file"
              />
              <Button
                className="w-full text-white focus-visible:ring-2 focus-visible:ring-offset-2"
                style={{
                  background: "var(--ouest-gradient-main)",
                }}
                onClick={() => {
                  updateFormData({ 
                    coverImage: "https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=800" 
                  });
                  setShowImageUpload(false);
                }}
                aria-label="Choose image from library"
              >
                Choose from Library
              </Button>
              <Button
                variant="outline"
                className="w-full border-border text-foreground hover:bg-muted focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2"
                onClick={() => {
                  fileInputRef.current?.click();
                }}
                disabled={uploadingImage}
                aria-label="Upload custom image"
              >
                {uploadingImage ? "Uploading..." : "Upload Image"}
              </Button>
            </div>
          </motion.div>
        </div>
      )}
    </div>
  );
}