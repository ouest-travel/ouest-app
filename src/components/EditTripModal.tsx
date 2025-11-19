"use client";

import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "motion/react";
import { X, MapPin, DollarSign, Calendar as CalendarIcon, Dice6 } from "lucide-react";
import { Button } from "./ui/button";
import { Input } from "./ui/input";
import { Calendar } from "./ui/calendar";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "./ui/select";

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
  };
  onSave: (updatedTrip: any) => void;
}

const tripNameSuggestions = [
  "Girls Trip to Paradise",
  "Bros Weekend Escape",
  "Family Adventure 2025",
  "Squad Goals Vacation",
  "Wanderlust Chronicles",
  "The Great Escape",
];

const popularDestinations = [
  { city: "Paris", country: "France", flag: "🇫🇷" },
  { city: "Tokyo", country: "Japan", flag: "🇯🇵" },
  { city: "Lisbon", country: "Portugal", flag: "🇵🇹" },
  { city: "New York", country: "USA", flag: "🇺🇸" },
  { city: "Bali", country: "Indonesia", flag: "🇮🇩" },
  { city: "Barcelona", country: "Spain", flag: "🇪🇸" },
];

export function EditTripModal({ isOpen, onClose, tripData, onSave }: EditTripModalProps) {
  const [formData, setFormData] = useState({
    name: tripData.name,
    destination: tripData.destination,
    startDate: tripData.startDate,
    endDate: tripData.endDate,
    budget: tripData.budget || "",
    currency: tripData.currency || "CAD",
  });

  useEffect(() => {
    if (isOpen) {
      setFormData({
        name: tripData.name,
        destination: tripData.destination,
        startDate: tripData.startDate,
        endDate: tripData.endDate,
        budget: tripData.budget || "",
        currency: tripData.currency || "CAD",
      });
    }
  }, [isOpen, tripData]);

  const generateRandomName = () => {
    const randomName = tripNameSuggestions[Math.floor(Math.random() * tripNameSuggestions.length)];
    setFormData({ ...formData, name: randomName });
  };

  const selectDestination = (city: string) => {
    setFormData({ ...formData, destination: city });
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

  const handleSave = () => {
    onSave({
      ...tripData,
      ...formData,
    });
    onClose();
  };

  if (!isOpen) return null;

  return (
    <AnimatePresence>
      <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          exit={{ opacity: 0, scale: 0.95 }}
          transition={{ duration: 0.2 }}
          className="bg-background rounded-3xl max-w-2xl w-full max-h-[90vh] overflow-y-auto shadow-2xl"
        >
          {/* Header */}
          <div
            className="sticky top-0 px-6 py-4 border-b border-border z-10"
            style={{
              background: "var(--ouest-gradient-soft)",
            }}
          >
            <div className="flex items-center justify-between">
              <h2 className="text-foreground">Edit Trip</h2>
              <Button variant="ghost" size="sm" onClick={onClose}>
                <X className="w-5 h-5" />
              </Button>
            </div>
          </div>

          {/* Content */}
          <div className="px-6 py-6 space-y-6">
            {/* Trip Name */}
            <div className="space-y-3">
              <label className="text-sm text-muted-foreground">Trip Name</label>
              <div className="relative">
                <Input
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  placeholder="My Amazing Trip"
                  maxLength={40}
                  className="text-lg py-6 px-4 rounded-xl border-2 border-border focus:border-[var(--ouest-purple)] transition-all"
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
            <div className="space-y-3">
              <label className="text-sm text-muted-foreground">Destination</label>
              <div className="relative">
                <MapPin className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground z-10" />
                <Input
                  value={formData.destination}
                  onChange={(e) => setFormData({ ...formData, destination: e.target.value })}
                  placeholder="Search destination..."
                  className="text-lg py-6 pl-12 pr-4 rounded-xl border-2 border-border focus:border-[var(--ouest-purple)]"
                />
              </div>

              <div className="space-y-2">
                <p className="text-xs text-muted-foreground">Popular Destinations</p>
                <div className="grid grid-cols-3 gap-2">
                  {popularDestinations.map((dest) => (
                    <button
                      key={dest.city}
                      onClick={() => selectDestination(dest.city)}
                      className={`p-3 rounded-xl border-2 transition-all text-left ${
                        formData.destination === dest.city
                          ? "border-[var(--ouest-purple)] bg-muted"
                          : "border-border hover:border-muted-foreground"
                      }`}
                    >
                      <div className="text-xl mb-1">{dest.flag}</div>
                      <div className="text-sm text-foreground">{dest.city}</div>
                      <div className="text-xs text-muted-foreground">{dest.country}</div>
                    </button>
                  ))}
                </div>
              </div>
            </div>

            {/* Dates */}
            <div className="space-y-3">
              <label className="text-sm text-muted-foreground">Trip Dates</label>
              <div className="bg-muted rounded-xl border-2 border-border p-4">
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
            <div className="space-y-3">
              <label className="text-sm text-muted-foreground">Budget (optional)</label>
              <div className="grid grid-cols-3 gap-3">
                <div className="col-span-1">
                  <Select value={formData.currency} onValueChange={(val) => setFormData({ ...formData, currency: val })}>
                    <SelectTrigger className="rounded-xl py-6">
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
                      className="text-lg py-6 pl-12 pr-4 rounded-xl border-2 border-border focus:border-[var(--ouest-purple)]"
                    />
                  </div>
                </div>
              </div>
              <p className="text-xs text-muted-foreground">Total trip budget for all members.</p>
            </div>
          </div>

          {/* Footer */}
          <div className="sticky bottom-0 px-6 py-4 border-t border-border bg-background">
            <div className="flex gap-3">
              <Button
                variant="outline"
                onClick={onClose}
                className="flex-1 py-6 rounded-xl border-2"
              >
                Cancel
              </Button>
              <Button
                onClick={handleSave}
                disabled={!formData.name || !formData.destination}
                className="flex-1 py-6 rounded-xl text-white shadow-lg hover:shadow-xl transition-all disabled:opacity-50"
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

