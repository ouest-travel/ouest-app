"use client";

import { useEffect, useState } from "react";
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
import { toast } from "sonner";
import { CountrySelector } from "./CountrySelector";
import { Country, countries } from "@/data/countries";

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
  const [selectedLocationCountry, setSelectedLocationCountry] = useState<Country | null>(null);

  const updateFormData = (updates: Partial<TripFormData>) => {
    setFormData((prev) => ({ ...prev, ...updates }));
  };

  useEffect(() => {
    if (!formData.location) {
      setSelectedLocationCountry(null);
      return;
    }

    const match = countries.find(
      (country) =>
        country.name.toLowerCase() === formData.location.toLowerCase() ||
        country.code.toLowerCase() === formData.location.toLowerCase(),
    );

    setSelectedLocationCountry(match ?? null);
  }, [formData.location]);

  const handleSave = () => {
    if (!formData.name || !formData.location) {
      toast.error("Please fill in trip name and location");
      return;
    }
    
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

  return (
    <div className="fixed inset-0 bg-background z-50 overflow-y-auto">
      {/* Header */}
      <div className="sticky top-0 bg-background/95 backdrop-blur-sm border-b border-border z-10">
        <div className="max-w-2xl mx-auto px-4 py-4 flex items-center justify-between">
          <Button variant="ghost" size="sm" onClick={onClose}>
            Cancel
          </Button>
          <h2 className="text-center">New Trip</h2>
          <Button 
            size="sm" 
            onClick={handleSave}
            className="bg-gradient-to-r from-blue-500 via-purple-500 to-pink-500 text-white hover:opacity-90"
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
          <div className="bg-muted/50 rounded-2xl p-4 border border-border">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                {formData.isPublic ? (
                  <Globe className="w-5 h-5" style={{ color: "var(--ouest-purple)" }} />
                ) : (
                  <Lock className="w-5 h-5 text-muted-foreground" />
                )}
                <div>
                  <p className="text-sm text-foreground">
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
              />
            </div>
          </div>

          {/* Trip Name */}
          <div className="bg-card rounded-2xl border-2 border-border overflow-hidden hover:border-primary/50 transition-colors">
            <div className="p-4">
              <Input
                value={formData.name}
                onChange={(e) => updateFormData({ name: e.target.value })}
                placeholder="Name your trip"
                className="border-0 px-0 text-lg focus-visible:ring-0 placeholder:text-muted-foreground"
              />
            </div>
          </div>

          {/* Cover Image */}
          <div className="bg-card rounded-2xl border-2 border-border overflow-hidden">
            {formData.coverImage ? (
              <div className="relative aspect-[16/9] w-full">
                <ImageWithFallback
                  src={formData.coverImage}
                  alt="Trip cover"
                  className="w-full h-full object-cover"
                />
                <button
                  onClick={() => updateFormData({ coverImage: null })}
                  className="absolute top-3 right-3 bg-background/90 rounded-full p-2 hover:bg-background transition-colors"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>
            ) : (
              <button
                onClick={() => setShowImageUpload(true)}
                className="w-full aspect-[16/9] flex flex-col items-center justify-center gap-3 hover:bg-muted transition-colors"
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
              <div className="flex items-center gap-3 mb-3">
                <MapPin className="w-5 h-5 text-muted-foreground flex-shrink-0" />
                <p className="text-foreground">Location</p>
              </div>
              <CountrySelector
                label="Choose a destination"
                value={selectedLocationCountry}
                onChange={(country) => {
                  setSelectedLocationCountry(country);
                  updateFormData({ location: country.name });
                }}
              />
            </div>

            {/* Date Range */}
            <Popover>
              <PopoverTrigger asChild>
                <button className="w-full p-4 flex items-center gap-4 hover:bg-muted transition-colors text-left">
                  <CalendarIcon className="w-5 h-5 text-muted-foreground flex-shrink-0" />
                  <span className={formData.startDate ? "text-foreground" : "text-muted-foreground"}>
                    {formatDateRange()}
                  </span>
                </button>
              </PopoverTrigger>
              <PopoverContent className="w-auto p-0" align="start">
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

            {/* Invite Members */}
            <button 
              onClick={handleShare}
              className="w-full p-4 flex items-center gap-4 hover:bg-muted transition-colors text-left"
            >
              <Share2 className="w-5 h-5 text-muted-foreground flex-shrink-0" />
              <div>
                <p className="text-foreground">Send invites</p>
                <p className="text-xs text-muted-foreground">Share trip with friends</p>
              </div>
            </button>

            {/* Budget */}
            <div className="p-4">
              <div className="flex items-center gap-4 mb-3">
                <DollarSign className="w-5 h-5 text-muted-foreground flex-shrink-0" />
                <p className="text-foreground">Budget</p>
              </div>
              <div className="flex gap-3 pl-9">
                <Select 
                  value={formData.currency} 
                  onValueChange={(val) => updateFormData({ currency: val })}
                >
                  <SelectTrigger className="w-28 rounded-xl">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="USD">🇺🇸 USD</SelectItem>
                    <SelectItem value="EUR">🇪🇺 EUR</SelectItem>
                    <SelectItem value="GBP">🇬🇧 GBP</SelectItem>
                    <SelectItem value="JPY">🇯🇵 JPY</SelectItem>
                    <SelectItem value="CAD">🇨🇦 CAD</SelectItem>
                  </SelectContent>
                </Select>
                <Input
                  type="number"
                  value={formData.budget}
                  onChange={(e) => updateFormData({ budget: e.target.value })}
                  placeholder="0.00"
                  className="flex-1 rounded-xl"
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
                <Vote className="w-5 h-5 text-muted-foreground flex-shrink-0" />
                <div>
                  <p className="text-foreground">Enable voting</p>
                  <p className="text-xs text-muted-foreground">Let members vote on activities</p>
                </div>
              </div>
              <Switch
                checked={formData.votingEnabled}
                onCheckedChange={(checked) => updateFormData({ votingEnabled: checked })}
              />
            </div>
          </div>

          {/* Description */}
          <div className="bg-card rounded-2xl border-2 border-border overflow-hidden p-4">
            <Textarea
              value={formData.description}
              onChange={(e) => updateFormData({ description: e.target.value })}
              placeholder="Add a description of your trip"
              className="border-0 px-0 min-h-32 resize-none focus-visible:ring-0 placeholder:text-muted-foreground"
            />
          </div>

          {/* Connected Features Info */}
          <div className="bg-muted/50 rounded-2xl p-4 border border-border">
            <p className="text-xs text-muted-foreground mb-2">✨ Features included:</p>
            <div className="grid grid-cols-2 gap-2 text-xs text-muted-foreground">
              <div>• Budget tracking</div>
              <div>• Entry requirements</div>
              <div>• Group chat</div>
              <div>• Expense splitting</div>
            </div>
          </div>
        </motion.div>
      </div>

      {/* Image Upload Modal */}
      {showImageUpload && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            className="bg-card rounded-3xl p-6 max-w-md w-full border border-border"
          >
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-foreground">Choose Cover Image</h3>
              <button onClick={() => setShowImageUpload(false)} className="text-muted-foreground hover:text-foreground">
                <X className="w-5 h-5" />
              </button>
            </div>
            <p className="text-sm text-muted-foreground mb-4">
              Select a stock image or upload your own
            </p>
            <div className="space-y-3">
              <Button
                className="w-full"
                onClick={() => {
                  // In a real app, this would open an image picker
                  updateFormData({ 
                    coverImage: "https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=800" 
                  });
                  setShowImageUpload(false);
                }}
              >
                Choose from Library
              </Button>
              <Button
                variant="outline"
                className="w-full"
                onClick={() => {
                  toast.info("Upload functionality would be here");
                  setShowImageUpload(false);
                }}
              >
                Upload Image
              </Button>
            </div>
          </motion.div>
        </div>
      )}
    </div>
  );
}