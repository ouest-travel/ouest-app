"use client";

import { motion } from "motion/react";
import { MapPin, Clock, DollarSign, X, Calendar } from "lucide-react";
import { useSavedItineraryItems } from "../hooks/useSavedItineraryItems";
import { Button } from "./ui/button";
import { ScrollArea } from "./ui/scroll-area";
import { toast } from "sonner";

const categoryIcons = {
  food: "🍴",
  activity: "🎯",
  transport: "🚗",
  accommodation: "🏨",
};

export function SavedItinerariesView() {
  const { items, loading, removeItem } = useSavedItineraryItems();

  const handleRemoveItem = async (itemId: string, itemName: string) => {
    const { error } = await removeItem(itemId);
    if (error) {
      toast.error("Failed to remove item");
    } else {
      toast.success(`Removed "${itemName}" from saved itineraries`);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-background pb-24">
        <div className="px-6 pt-12 pb-8 max-w-md mx-auto">
          <div className="text-center text-muted-foreground py-8">
            Loading saved itineraries...
          </div>
        </div>
      </div>
    );
  }

  if (items.length === 0) {
    return (
      <div className="min-h-screen bg-background pb-24">
        <div className="px-6 pt-12 pb-8 max-w-md mx-auto">
          <h1 className="text-foreground mb-2">Saved Itineraries</h1>
          <p className="text-muted-foreground mb-6">
            Activities you've saved from the community
          </p>
          <div className="bg-card rounded-3xl p-8 shadow-lg border border-border text-center">
            <p className="text-muted-foreground">
              No saved itineraries yet. Browse the community section to save
              activities to your itinerary!
            </p>
          </div>
        </div>
      </div>
    );
  }

  const groupedByLocation = items.reduce((acc, item) => {
    const location = item.source_trip_location || "Unknown Location";
    if (!acc[location]) {
      acc[location] = [];
    }
    acc[location].push(item);
    return acc;
  }, {} as Record<string, typeof items>);

  return (
    <div className="min-h-screen bg-background pb-24">
      <div
        className="px-6 pt-12 pb-8"
        style={{
          background: "var(--ouest-gradient-soft)",
        }}
      >
        <div className="max-w-md mx-auto">
          <h1 className="text-foreground mb-2">Saved Itineraries</h1>
          <p className="text-muted-foreground">
            Activities you've saved from the community
          </p>
        </div>
      </div>

      <div className="px-6 -mt-4 max-w-md mx-auto">
        <ScrollArea className="h-[calc(100vh-200px)]">
          <div className="space-y-6 pb-6">
            {Object.entries(groupedByLocation).map(([location, locationItems], locationIndex) => (
              <motion.div
                key={location}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: locationIndex * 0.1 }}
                className="bg-card rounded-3xl shadow-lg border border-border overflow-hidden"
              >
                <div className="p-4 border-b border-border">
                  <div className="flex items-center gap-2">
                    <MapPin className="w-4 h-4" style={{ color: "var(--ouest-blue)" }} />
                    <h3 className="text-foreground font-semibold">{location}</h3>
                    {locationItems[0]?.source_trip_user && (
                      <span className="text-muted-foreground text-sm">
                        from {locationItems[0].source_trip_user}
                      </span>
                    )}
                  </div>
                </div>

                <div className="p-4 space-y-3">
                  {locationItems.map((item, index) => (
                    <motion.div
                      key={item.id}
                      initial={{ opacity: 0, x: -20 }}
                      animate={{ opacity: 1, x: 0 }}
                      transition={{ delay: locationIndex * 0.1 + index * 0.05 }}
                      className="p-4 rounded-xl bg-muted/50 border border-border"
                    >
                      <div className="flex items-start justify-between gap-3">
                        <div className="flex-1">
                          <div className="flex items-center gap-2 mb-2">
                            <span className="text-2xl">
                              {categoryIcons[item.activity_category]}
                            </span>
                            <h4 className="text-foreground font-semibold">
                              {item.activity_name}
                            </h4>
                          </div>

                          <div className="space-y-1.5 text-sm">
                            <div className="flex items-center gap-2 text-muted-foreground">
                              <MapPin className="w-3 h-3" />
                              <span>{item.activity_location}</span>
                            </div>

                            {item.activity_time && (
                              <div className="flex items-center gap-2 text-muted-foreground">
                                <Clock className="w-3 h-3" />
                                <span>{item.activity_time}</span>
                              </div>
                            )}

                            {item.activity_cost && (
                              <div className="flex items-center gap-2 text-muted-foreground">
                                <DollarSign className="w-3 h-3" />
                                <span>{item.activity_cost}</span>
                              </div>
                            )}

                            {item.activity_description && (
                              <p className="text-muted-foreground mt-2">
                                {item.activity_description}
                              </p>
                            )}

                            {item.day && (
                              <div className="flex items-center gap-2 text-muted-foreground mt-2">
                                <Calendar className="w-3 h-3" />
                                <span>Day {item.day}</span>
                              </div>
                            )}
                          </div>
                        </div>

                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handleRemoveItem(item.id, item.activity_name)}
                          className="text-muted-foreground hover:text-destructive"
                        >
                          <X className="w-4 h-4" />
                        </Button>
                      </div>
                    </motion.div>
                  ))}
                </div>
              </motion.div>
            ))}
          </div>
        </ScrollArea>
      </div>
    </div>
  );
}

