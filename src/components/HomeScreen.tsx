"use client";

import { motion } from "motion/react";
import {
  Plus,
  MapPin,
  Calendar,
  Users,
  MessageCircle,
  Clock,
} from "lucide-react";
import { useState } from "react";
import { CreateTripForm } from "./CreateTripForm";
import { ChatDemoScreen } from "./ChatDemoScreen";
import { TripMembersModal } from "./TripMembersModal";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "./ui/tabs";
import { useTrips } from "../hooks/useTrips";
import { useProfileStats } from "../hooks/useProfileStats";
import { toast } from "sonner";

interface HomeScreenProps {
  onNavigateToBudget?: (tripName: string, tripId: string | number) => void;
}

interface Trip {
  id: string | number;
  name?: string;
  destination: string;
  dates?: string;
  image?: string;
  budget?: number | string | null;
  travelers?: number;
  coverImage?: string;
  cover_image?: string | null;
  startDate?: Date;
  start_date?: Date | string | null;
  endDate?: Date;
  end_date?: Date | string | null;
  currency?: string;
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
  const trips: Trip[] = rawTrips.map((trip) => {
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

    return {
      ...trip,
      startDate,
      endDate,
      dates,
      image: trip.image || getLocationEmoji(trip.destination),
      budget:
        typeof trip.budget === "number"
          ? `${trip.currency || "USD"} ${trip.budget}`
          : trip.budget || "No budget set",
      travelers: trip.travelers || 1,
    };
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
                <motion.div
                  key={trip.id}
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: index * 0.1 }}
                  whileTap={{ scale: 0.98 }}
                  onClick={() =>
                    onNavigateToBudget?.(trip.destination, trip.id)
                  }
                  className="bg-card rounded-3xl p-6 shadow-lg border border-border hover:shadow-xl transition-all cursor-pointer relative"
                >
                  {/* Chat Icon Button */}
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      setSelectedTripForChat(trip);
                      setShowChat(true);
                    }}
                    className="absolute top-4 right-4 p-2.5 rounded-full transition-all hover:scale-105 z-10"
                    style={{
                      background: "var(--ouest-gradient-main)",
                    }}
                  >
                    <MessageCircle className="w-5 h-5 text-white" />
                  </button>

                  <div className="flex items-start gap-4 mb-4">
                    <span className="text-5xl">{trip.image}</span>
                    <div className="flex-1 pr-10">
                      <h3 className="text-foreground mb-1">
                        {trip.destination}
                      </h3>
                      <div className="flex items-center gap-2 text-muted-foreground">
                        <Calendar className="w-4 h-4" />
                        <span style={{ fontSize: "14px" }}>{trip.dates}</span>
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-4 pt-4 border-t border-border">
                    <div className="flex items-center gap-2">
                      <div
                        className="p-2 rounded-lg"
                        style={{
                          background: "var(--ouest-gradient-soft)",
                        }}
                      >
                        <MapPin
                          className="w-4 h-4"
                          style={{ color: "var(--ouest-blue)" }}
                        />
                      </div>
                      <span className="text-foreground">{trip.budget}</span>
                    </div>

                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        setSelectedTripForMembers(trip);
                        setShowMembers(true);
                      }}
                      className="flex items-center gap-2 hover:scale-105 transition-all"
                    >
                      <div
                        className="p-2 rounded-lg"
                        style={{
                          background: "var(--ouest-gradient-soft)",
                        }}
                      >
                        <Users
                          className="w-4 h-4"
                          style={{ color: "var(--ouest-pink)" }}
                        />
                      </div>
                      <span className="text-foreground">
                        {trip.travelers} travelers
                      </span>
                    </button>
                  </div>
                </motion.div>
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
                <motion.div
                  key={trip.id}
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: index * 0.1 }}
                  whileTap={{ scale: 0.98 }}
                  onClick={() =>
                    onNavigateToBudget?.(trip.destination, trip.id)
                  }
                  className="bg-card rounded-3xl p-6 shadow-lg border border-border hover:shadow-xl transition-all cursor-pointer relative opacity-80"
                >
                  {/* Chat Icon Button */}
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      setSelectedTripForChat(trip);
                      setShowChat(true);
                    }}
                    className="absolute top-4 right-14 p-2.5 rounded-full transition-all hover:scale-105 z-10"
                    style={{
                      background: "var(--ouest-gradient-main)",
                    }}
                  >
                    <MessageCircle className="w-5 h-5 text-white" />
                  </button>

                  {/* Past trip indicator */}
                  <div className="absolute top-4 right-4 px-3 py-1 rounded-full bg-muted text-muted-foreground text-xs">
                    Completed
                  </div>

                  <div className="flex items-start gap-4 mb-4">
                    <span className="text-5xl grayscale">{trip.image}</span>
                    <div className="flex-1 pr-24">
                      <h3 className="text-foreground mb-1">
                        {trip.destination}
                      </h3>
                      <div className="flex items-center gap-2 text-muted-foreground">
                        <Clock className="w-4 h-4" />
                        <span style={{ fontSize: "14px" }}>{trip.dates}</span>
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-4 pt-4 border-t border-border">
                    <div className="flex items-center gap-2">
                      <div
                        className="p-2 rounded-lg"
                        style={{
                          background: "var(--ouest-gradient-soft)",
                        }}
                      >
                        <MapPin
                          className="w-4 h-4"
                          style={{ color: "var(--ouest-blue)" }}
                        />
                      </div>
                      <span className="text-foreground">{trip.budget}</span>
                    </div>

                    <div className="flex items-center gap-2">
                      <div
                        className="p-2 rounded-lg"
                        style={{
                          background: "var(--ouest-gradient-soft)",
                        }}
                      >
                        <Users
                          className="w-4 h-4"
                          style={{ color: "var(--ouest-pink)" }}
                        />
                      </div>
                      <span className="text-foreground">
                        {trip.travelers} travelers
                      </span>
                    </div>
                  </div>
                </motion.div>
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
