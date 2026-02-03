"use client";

import { motion } from "motion/react";
import {
  Plus,
  MapPin,
  Calendar,
  Users,
  MessageCircle,
  Clock,
  Share2,
  MoreVertical,
  CheckCircle2,
} from "lucide-react";
import { useState } from "react";
import { CreateTripForm } from "./CreateTripForm";
import { ChatDemoScreen } from "./ChatDemoScreen";
import { TripMembersModal } from "./TripMembersModal";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "./ui/tabs";
import { useTrips } from "../hooks/useTrips";
import { useProfileStats } from "../hooks/useProfileStats";
import { useTripMembers } from "../hooks/useTripMembers";
import { getLocationImage } from "../utils/getLocationImage";
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

interface ActiveTripCardProps {
  trip: Trip & { city: string; country: string; locationImage: string };
  index: number;
  onNavigateToBudget?: (tripName: string, tripId: string | number) => void;
  onOpenChat: (trip: Trip) => void;
}

function ActiveTripCard({
  trip,
  index,
  onNavigateToBudget,
  onOpenChat,
}: ActiveTripCardProps) {
  const { members } = useTripMembers(trip.id);
  const displayMembers = members.slice(0, 3);

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: index * 0.1 }}
      whileTap={{ scale: 0.98 }}
      className="relative rounded-3xl overflow-hidden shadow-lg cursor-pointer group"
      style={{ minHeight: "300px" }}
    >
      {/* Blurred Background Image */}
      <div
        className="absolute inset-0 bg-cover bg-center"
        style={{
          backgroundImage: `url(${trip.locationImage})`,
        }}
      >
        {/* Progressive Blur - More visible at top, heavy blur at bottom */}
        {/* Light blur starting from middle */}
        <div 
          className="absolute inset-0"
          style={{
            maskImage: 'linear-gradient(to bottom, transparent 0%, transparent 50%, rgba(0,0,0,0.6) 70%, rgba(0,0,0,1) 100%)',
            WebkitMaskImage: 'linear-gradient(to bottom, transparent 0%, transparent 50%, rgba(0,0,0,0.6) 70%, rgba(0,0,0,1) 100%)',
            backdropFilter: 'blur(12px)',
            WebkitBackdropFilter: 'blur(12px)',
          }}
        />
        {/* Heavy blur at bottom */}
        <div 
          className="absolute inset-0"
          style={{
            maskImage: 'linear-gradient(to bottom, transparent 0%, transparent 60%, rgba(0,0,0,0.4) 75%, rgba(0,0,0,1) 100%)',
            WebkitMaskImage: 'linear-gradient(to bottom, transparent 0%, transparent 60%, rgba(0,0,0,0.4) 75%, rgba(0,0,0,1) 100%)',
            backdropFilter: 'blur(24px)',
            WebkitBackdropFilter: 'blur(24px)',
          }}
        />
        {/* Black gradient overlay - stronger at bottom for text readability */}
        <div 
          className="absolute inset-0"
          style={{
            background: `
              linear-gradient(to bottom, 
                rgba(0, 0, 0, 0.1) 0%,
                rgba(0, 0, 0, 0.2) 40%,
                rgba(0, 0, 0, 0.4) 60%,
                rgba(0, 0, 0, 0.65) 80%,
                rgba(0, 0, 0, 0.85) 100%
              )
            `,
          }}
        />
      </div>

      {/* Content Overlay */}
      <div className="relative z-10 p-5 h-full flex flex-col justify-between text-white">
        {/* Top Section - Location, Trip Name, Dates */}
        <div className="flex-1">
          {/* Action Icons - Top Right */}
          <div className="flex items-center gap-2 absolute top-4 right-4">
            <button
              onClick={(e) => {
                e.stopPropagation();
                toast.info("Share trip");
              }}
              className="p-2 rounded-full bg-black/30 backdrop-blur-sm hover:bg-black/50 transition-all"
            >
              <Share2 className="w-4 h-4 text-white" />
            </button>
            <button
              onClick={(e) => {
                e.stopPropagation();
                onOpenChat(trip);
              }}
              className="p-2 rounded-full bg-black/30 backdrop-blur-sm hover:bg-black/50 transition-all"
            >
              <MessageCircle className="w-4 h-4 text-white" />
            </button>
            <button
              onClick={(e) => {
                e.stopPropagation();
                toast.info("More options");
              }}
              className="p-2 rounded-full bg-black/30 backdrop-blur-sm hover:bg-black/50 transition-all"
            >
              <MoreVertical className="w-4 h-4 text-white" />
            </button>
          </div>

          {/* Location with Country Highlight */}
          <div className="pr-24 pt-1">
            <h2 className="text-2xl font-bold mb-1.5 leading-tight text-white">
              {trip.city}
              {trip.country && (
                <span className="text-white/90 font-normal ml-1">
                  {trip.country}
                </span>
              )}
            </h2>
            {trip.name && (
              <p className="text-white/90 text-sm mb-1.5">
                {trip.name}
              </p>
            )}
            <p className="text-white/90 text-sm">
              {trip.dates}
            </p>
          </div>
        </div>

        {/* Bottom Section - Avatars, Entry Requirements, and Itinerary Button */}
        <div className="flex flex-col gap-3 pt-4 pb-2">
          {/* User Avatars Row */}
          {displayMembers.length > 0 && (
            <div className="flex -space-x-2">
              {displayMembers.map((member, idx) => (
                <div
                  key={member.id}
                  className="w-10 h-10 rounded-full border-2 border-white/20 bg-white/10 backdrop-blur-sm flex items-center justify-center text-lg overflow-hidden"
                  style={{ zIndex: displayMembers.length - idx }}
                >
                  {member.profile?.avatar_url &&
                  !member.profile.avatar_url.startsWith("👤") &&
                  !member.profile.avatar_url.match(/^[\p{Emoji}]$/u) ? (
                    <img
                      src={member.profile.avatar_url}
                      alt={member.profile.display_name || "Member"}
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <span>
                      {member.profile?.avatar_url || "👤"}
                    </span>
                  )}
                </div>
              ))}
            </div>
          )}

          {/* Entry Requirements and Itinerary Button Row */}
          <div className="flex items-center justify-between gap-3">
            {/* Entry Requirements Status */}
            <div className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-black/60 backdrop-blur-md border border-white/10">
              <CheckCircle2 className="w-3.5 h-3.5 text-green-400" />
              <span className="text-white text-xs font-semibold whitespace-nowrap">
                Entry requirements met
              </span>
            </div>

            {/* View Itinerary Button */}
            <button
              onClick={(e) => {
                e.stopPropagation();
                onNavigateToBudget?.(trip.destination, trip.id);
              }}
              className="px-4 py-2.5 rounded-xl bg-black/70 backdrop-blur-md hover:bg-black/80 transition-all border border-white/10 text-white text-sm font-semibold whitespace-nowrap"
            >
              View Itinerary
            </button>
          </div>
        </div>
      </div>
    </motion.div>
  );
}

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

    // Format dates string for Figma design (e.g., "24 Jun 2025 - 24 July 2025")
    const formatDate = (date: Date | undefined) => {
      if (!date) return "";
      const day = date.getDate();
      const month = date.toLocaleDateString("en-US", { month: "short" });
      const year = date.getFullYear();
      return `${day} ${month} ${year}`;
    };

    const dates =
      startDate && endDate
        ? `${formatDate(startDate)} - ${formatDate(endDate)}`
        : trip.dates || "Dates TBD";
    
    // Extract city and country from destination
    const destinationParts = trip.destination.split(',').map(p => p.trim());
    const city = destinationParts[0] || trip.destination;
    const country = destinationParts[1] || '';

    return {
      ...trip,
      startDate,
      endDate,
      dates,
      city,
      country,
      image: trip.image || getLocationEmoji(trip.destination),
      locationImage: trip.cover_image || trip.coverImage || getLocationImage(trip.destination),
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
                <ActiveTripCard
                  key={trip.id}
                  trip={trip}
                  index={index}
                  onNavigateToBudget={onNavigateToBudget}
                  onOpenChat={(trip) => {
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
