"use client";

import { motion } from "motion/react";
import { Plus } from "lucide-react";
import { useState } from "react";
import { CreateTripForm } from "./CreateTripForm";
import { ChatDemoScreen } from "./ChatDemoScreen";
import { TripMembersModal } from "./TripMembersModal";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "./ui/tabs";
import { useTrips } from "../hooks/useTrips";
import { useProfileStats } from "../hooks/useProfileStats";
import { toast } from "sonner";
import { Trip } from "../types/trip";
import { ActiveTripCard } from "./ActiveTripCard";



interface HomeScreenProps {
  onNavigateToBudget?: (tripName: string, tripId: string | number) => void;
}

const getLocationEmoji = (location: string) => {
  const countryEmojis: Record<string, string> = {
    japan: "🇯🇵",
    tokyo: "🇯🇵",
    france: "🇫🇷",
    paris: "🇫🇷",
    spain: "🇪🇸",
    barcelona: "🇪🇸",
    italy: "🇮🇹",
    rome: "🇮🇹",
    portugal: "🇵🇹",
    lisbon: "🇵🇹",
    usa: "🇺🇸",
    "new york": "🇺🇸",
    uk: "🇬🇧",
    london: "🇬🇧",
    mexico: "🇲🇽",
    greece: "🇬🇷",
    thailand: "🇹🇭",
    bali: "🇮🇩",
    indonesia: "🇮🇩",
  };

  const lowerLocation = location.toLowerCase();
  for (const [key, emoji] of Object.entries(countryEmojis)) {
    if (lowerLocation.includes(key)) {
      return emoji;
    }
  }
  return "🌍"; // Default globe emoji
};

export function HomeScreen({ onNavigateToBudget }: HomeScreenProps = {}) {
  const [showBookTrip, setShowBookTrip] = useState(false);
  const [showChat, setShowChat] = useState(false);
  const [selectedTripForChat, setSelectedTripForChat] = useState<Trip | null>(
    null
  );
  const [showMembers, setShowMembers] = useState(false);
  const [selectedTripForMembers, setSelectedTripForMembers] =
    useState<Trip | null>(null);

  const { trips: rawTrips, createTrip } = useTrips();
  const { stats } = useProfileStats();

  // Transform trips data to ensure consistent format
  const trips = rawTrips.map((trip) => {
    const startDate = trip.start_date ? new Date(trip.start_date) : undefined;
    const endDate = trip.end_date ? new Date(trip.end_date) : undefined;

    // Format dates string
    const formatDate = (date: Date | undefined) => {
      if (!date) return "";
      return date.toLocaleDateString("en-US", {
        month: "short",
        day: "numeric",
      });
    };

    const dates =
      startDate && endDate
        ? `${formatDate(startDate)} - ${formatDate(
            endDate
          )}, ${endDate.getFullYear()}`
        : trip.dates || "Dates TBD";

    const parts = (trip.destination || "").split(",");
    const city = parts[0]?.trim() || trip.destination;
    const country = parts.length > 1 ? parts[parts.length - 1].trim() : "";

    return {
      ...trip,
      startDate,
      endDate,
      dates,
      image: trip.image || getLocationEmoji(trip.destination),
      city,
      country,
      locationImage: trip.cover_image || trip.image || "", 
      travelers: trip.travelers || 1,
    } as Trip & { city: string; country: string; locationImage: string };
  });

  // Separate active and past trips based on end date
  const now = new Date();
  const activeTrips = trips
    .filter((trip) => {
      if (!trip.endDate) return true; // If no end date, consider it active
      return trip.endDate >= now;
    })
    .sort((a, b) => {
      if (!a.startDate || !b.startDate) return 0;
      return a.startDate.getTime() - b.startDate.getTime();
    });

  const pastTrips = trips
    .filter((trip) => {
      if (!trip.endDate) return false;
      return trip.endDate < now;
    })
    .sort((a, b) => {
      if (!a.endDate || !b.endDate) return 0;
      return b.endDate.getTime() - a.endDate.getTime(); // Most recent first
    });

  const handleCreateTrip = async (tripData: any) => {
    const { error } = await createTrip({
      name: tripData.name,
      destination: tripData.location,
      start_date: tripData.startDate,
      end_date: tripData.endDate,
      budget: tripData.budget ? parseFloat(tripData.budget) : null,
      currency: tripData.currency || "USD",
      is_public: tripData.isPublic || false,
      voting_enabled: tripData.votingEnabled || false,
      cover_image: tripData.coverImage || null,
      description: tripData.description || null,
      image: getLocationEmoji(tripData.location),
      travelers: 1,
    });

    if (error) {
      toast.error("Failed to create trip");
    } else {
      toast.success("Trip created successfully!");
    }
  };

  return (
    <div className="min-h-screen bg-background pb-24">
      {/* Header with gradient */}
      <div
        className="px-6 pt-12 pb-8"
        style={{
          background: "var(--ouest-gradient-soft)",
        }}
      >
        <div className="max-w-md mx-auto">
          <div className="flex items-center gap-2 mb-6">
            <img
              src="/ouest-transparent.png"
              alt="Ouest Logo"
              className="w-8 h-8"
            />
            <h1 className="text-foreground">Ouest</h1>
          </div>

          <h2 className="text-foreground mb-2">Your Trips</h2>
          <p className="text-muted-foreground">
            Plan, track, and explore with friends
          </p>
        </div>
      </div>

      <div className="px-6 -mt-4 max-w-md mx-auto">
        {/* Create Trip CTA */}
        <motion.button
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          whileTap={{ scale: 0.98 }}
          className="w-full p-6 rounded-3xl shadow-lg mb-6 transition-all hover:shadow-xl"
          style={{
            background: "var(--ouest-gradient-main)",
          }}
          onClick={() => setShowBookTrip(true)}
        >
          <div className="flex items-center gap-4">
            <div className="p-3 bg-white/20 rounded-2xl">
              <Plus className="w-6 h-6 text-white" />
            </div>
            <div className="text-left">
              <h3 className="text-white mb-1">Create New Trip</h3>
              <p className="text-white/80" style={{ fontSize: "14px" }}>
                Start planning your next adventure
              </p>
            </div>
          </div>
        </motion.button>

        {/* Trips Tabs - Active and Past */}
        <Tabs defaultValue="active" className="space-y-4">
          <TabsList className="w-full grid grid-cols-2 bg-muted/50 p-1 rounded-2xl">
            <TabsTrigger
              value="active"
              className="rounded-xl data-[state=active]:bg-white data-[state=active]:shadow-sm"
            >
              Active ({activeTrips.length})
            </TabsTrigger>
            <TabsTrigger
              value="past"
              className="rounded-xl data-[state=active]:bg-white data-[state=active]:shadow-sm"
            >
              Past ({pastTrips.length})
            </TabsTrigger>
          </TabsList>

          <TabsContent value="active" className="space-y-4 mt-4">
            {activeTrips.length === 0 ? (
              <div className="text-center py-12 bg-card rounded-3xl border border-border">
                <p className="text-muted-foreground">No active trips yet</p>
                <p className="text-muted-foreground text-sm mt-1">
                  Create your first adventure!
                </p>
              </div>
            ) : (
              activeTrips.map((trip, index) => (
                <ActiveTripCard
                  key={trip.id}
                  trip={trip}
                  index={index}
                  onNavigateToBudget={onNavigateToBudget}
                  onOpenChat={() => {
                    setSelectedTripForChat(trip);
                    setShowChat(true);
                  }}
                />
              ))
            )}
          </TabsContent>

          <TabsContent value="past" className="space-y-4 mt-4">
            {pastTrips.length === 0 ? (
              <div className="text-center py-12 bg-card rounded-3xl border border-border">
                <p className="text-muted-foreground">No past trips yet</p>
                <p className="text-muted-foreground text-sm mt-1">
                  Your travel history will appear here
                </p>
              </div>
            ) : (
              pastTrips.map((trip, index) => (
                <ActiveTripCard
                  key={trip.id}
                  trip={trip}
                  index={index}
                  onNavigateToBudget={onNavigateToBudget}
                  onOpenChat={() => {
                    setSelectedTripForChat(trip);
                    setShowChat(true);
                  }}
                />
              ))
            )}
          </TabsContent>
        </Tabs>

        {/* Stats Card */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3 }}
          className="mt-6 p-6 rounded-3xl border border-border"
          style={{
            background: "var(--ouest-gradient-soft)",
          }}
        >
          <div className="grid grid-cols-3 gap-4">
            <div className="text-center">
              <div className="mb-1 text-foreground">
                {stats.countriesVisited}
              </div>
              <div
                className="text-muted-foreground"
                style={{ fontSize: "13px" }}
              >
                Countries
              </div>
            </div>
            <div className="text-center">
              <div className="mb-1 text-foreground">{stats.totalTrips}</div>
              <div
                className="text-muted-foreground"
                style={{ fontSize: "13px" }}
              >
                Trips
              </div>
            </div>
            <div className="text-center">
              <div className="mb-1 text-foreground">{stats.memories}</div>
              <div
                className="text-muted-foreground"
                style={{ fontSize: "13px" }}
              >
                Memories
              </div>
            </div>
          </div>
        </motion.div>
      </div>

      {/* Create Trip Form */}
      {showBookTrip && (
        <CreateTripForm
          onClose={() => setShowBookTrip(false)}
          onCreateTrip={(tripData) => {
            handleCreateTrip(tripData);
            setShowBookTrip(false);
          }}
        />
      )}

      {/* Chat Demo Screen */}
      {showChat && selectedTripForChat && (
        <ChatDemoScreen
          onClose={() => {
            setShowChat(false);
            setSelectedTripForChat(null);
          }}
          onNavigateToBudget={() => {
            setShowChat(false);
            onNavigateToBudget?.(
              selectedTripForChat.destination,
              selectedTripForChat.id
            );
          }}
          trip={selectedTripForChat}
        />
      )}

      {/* Trip Members Modal */}
      {showMembers && selectedTripForMembers && (
        <TripMembersModal
          onClose={() => {
            setShowMembers(false);
            setSelectedTripForMembers(null);
          }}
          trip={selectedTripForMembers}
        />
      )}
    </div>
  );
}
