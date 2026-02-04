"use client";

import { useState } from "react";
import { motion } from "motion/react";
import { 
  X, 
  MapPin, 
  Clock, 
  DollarSign, 
  Plus, 
  Calendar,
  CheckCircle2
} from "lucide-react";
import { Button } from "./ui/button";
import { ScrollArea } from "./ui/scroll-area";
import { toast } from "sonner";

interface Activity {
  id: number;
  name: string;
  time: string;
  location: string;
  cost: string;
  description: string;
  category: "food" | "activity" | "transport" | "accommodation";
  day: number;
}

interface ItineraryViewProps {
  tripName: string;
  tripLocation: string;
  tripDates: string;
  budget?: string;
  activities: Activity[];
  onClose: () => void;
  isOwnTrip?: boolean;
  onAddActivity?: (activity: Activity) => void;
  onRemoveActivity?: (activityId: number) => void;
  addedActivityIds?: number[];
}

const categoryIcons = {
  food: "🍴",
  activity: "🎯",
  transport: "🚗",
  accommodation: "🏨",
};

const categoryColors = {
  food: "from-orange-400 to-red-400",
  activity: "from-blue-400 to-purple-400",
  transport: "from-green-400 to-teal-400",
  accommodation: "from-pink-400 to-purple-400",
};

export function ItineraryView({
  tripName,
  tripLocation,
  tripDates,
  budget,
  activities,
  onClose,
  isOwnTrip = false,
  onAddActivity,
  onRemoveActivity,
  addedActivityIds = [],
}: ItineraryViewProps) {
  const [selectedDay, setSelectedDay] = useState(1);

  const totalDays = Math.max(...activities.map((a) => a.day), 1);
  const dayActivities = activities.filter((a) => a.day === selectedDay);

  const handleAddActivity = (activity: Activity) => {
    onAddActivity?.(activity);
    toast.success(`Added "${activity.name}" to your itinerary`);
  };

  const handleRemoveActivity = (activityId: number) => {
    onRemoveActivity?.(activityId);
    toast.success("Removed from your itinerary");
  };

  const isActivityAdded = (activityId: number) => addedActivityIds.includes(activityId);

  return (
    <div className="fixed inset-0 bg-white z-50 flex flex-col">
      {/* Header */}
      <div
        className="px-6 py-4 border-b border-border"
        style={{
          background: "var(--ouest-gradient-soft)",
        }}
      >
        <div className="max-w-2xl mx-auto">
          <div className="flex items-center justify-between mb-4">
            <Button variant="ghost" size="sm" onClick={onClose}>
              <X className="w-5 h-5" />
            </Button>
            <h2 className="text-foreground">Itinerary</h2>
            <div className="w-10" />
          </div>

          {/* Trip Info */}
          <div className="space-y-2">
            <h3 className="text-foreground">{tripName}</h3>
            <div className="flex items-center gap-4 text-muted-foreground">
              <div className="flex items-center gap-1">
                <MapPin className="w-4 h-4" />
                <span style={{ fontSize: "14px" }}>{tripLocation}</span>
              </div>
              <div className="flex items-center gap-1">
                <Calendar className="w-4 h-4" />
                <span style={{ fontSize: "14px" }}>{tripDates}</span>
              </div>
            </div>
            {budget && (
              <div className="flex items-center gap-1 text-muted-foreground">
                <DollarSign className="w-4 h-4" />
                <span style={{ fontSize: "14px" }}>{budget}</span>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Day Selector */}
      <div className="px-6 py-4 border-b border-border bg-white max-w-2xl mx-auto w-full">
        <ScrollArea className="w-full">
          <div className="flex gap-2">
            {Array.from({ length: totalDays }, (_, i) => i + 1).map((day) => (
              <button
                key={day}
                onClick={() => setSelectedDay(day)}
                className={`px-4 py-2 rounded-full transition-all whitespace-nowrap ${
                  selectedDay === day
                    ? "text-white shadow-lg"
                    : "bg-muted text-foreground hover:bg-muted/70"
                }`}
                style={
                  selectedDay === day
                    ? { background: "var(--ouest-gradient-main)" }
                    : {}
                }
              >
                Day {day}
              </button>
            ))}
          </div>
        </ScrollArea>
      </div>

      {/* Activities List */}
      <ScrollArea className="flex-1 px-6 py-6 max-w-2xl mx-auto w-full">
        <div className="space-y-4">
          {dayActivities.length === 0 ? (
            <div className="text-center py-12">
              <p className="text-muted-foreground">No activities for this day</p>
            </div>
          ) : (
            dayActivities.map((activity, index) => (
              <motion.div
                key={activity.id}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: index * 0.05 }}
                className="bg-card rounded-2xl border border-border overflow-hidden shadow-sm"
              >
                <div className="p-4">
                  <div className="flex items-start gap-3 mb-3">
                    <div
                      className={`w-12 h-12 rounded-xl flex items-center justify-center text-2xl bg-gradient-to-br ${
                        categoryColors[activity.category]
                      }`}
                    >
                      {categoryIcons[activity.category]}
                    </div>
                    <div className="flex-1 min-w-0">
                      <h4 className="text-foreground mb-1">{activity.name}</h4>
                      <div className="flex items-center gap-3 text-muted-foreground flex-wrap">
                        <div className="flex items-center gap-1">
                          <Clock className="w-3 h-3" />
                          <span style={{ fontSize: "13px" }}>{activity.time}</span>
                        </div>
                        <div className="flex items-center gap-1">
                          <MapPin className="w-3 h-3" />
                          <span style={{ fontSize: "13px" }}>{activity.location}</span>
                        </div>
                        <div className="flex items-center gap-1">
                          <DollarSign className="w-3 h-3" />
                          <span style={{ fontSize: "13px" }}>{activity.cost}</span>
                        </div>
                      </div>
                    </div>
                  </div>

                  {activity.description && (
                    <p className="text-muted-foreground mb-3" style={{ fontSize: "14px" }}>
                      {activity.description}
                    </p>
                  )}

                  {/* Add/Remove Button (only show for other people's trips) */}
                  {!isOwnTrip && (
                    <div className="pt-3 border-t border-border">
                      {isActivityAdded(activity.id) ? (
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => handleRemoveActivity(activity.id)}
                          className="w-full gap-2"
                        >
                          <CheckCircle2 className="w-4 h-4 text-green-500" />
                          Added to your itinerary
                        </Button>
                      ) : (
                        <Button
                          size="sm"
                          onClick={() => handleAddActivity(activity)}
                          className="w-full gap-2"
                          style={{
                            background: "var(--ouest-gradient-main)",
                          }}
                        >
                          <Plus className="w-4 h-4" />
                          Add to my itinerary
                        </Button>
                      )}
                    </div>
                  )}
                </div>
              </motion.div>
            ))
          )}
        </div>
      </ScrollArea>

      {/* Budget Summary at Bottom */}
      {budget && (
        <div className="px-6 py-4 border-t border-border bg-muted/30 max-w-2xl mx-auto w-full">
          <div className="flex items-center justify-between">
            <span className="text-muted-foreground">Total Trip Budget</span>
            <span className="text-foreground">{budget}</span>
          </div>
        </div>
      )}
    </div>
  );
}
