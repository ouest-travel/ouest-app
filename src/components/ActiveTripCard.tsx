
import { motion } from "motion/react";
import { Share2, MessageCircle, MoreVertical, CheckCircle2 } from "lucide-react";
import { toast } from "sonner";
import { useTripMembers } from "@/hooks/useTripMembers";
import { Trip } from "@/types/trip";

interface ActiveTripCardProps {
  trip: Trip & { city: string; country: string; locationImage: string };
  index: number;
  onNavigateToBudget?: (tripName: string, tripId: string | number) => void;
  onOpenChat: (trip: Trip) => void;
}

export function ActiveTripCard({
  trip,
  index,
  onNavigateToBudget,
  onOpenChat,
}: ActiveTripCardProps) {
  const { members } = useTripMembers(trip.id.toString());
  const displayMembers = members.slice(0, 3);
  
  // Provide default image if locationImage is missing or empty
  const bgImage = trip.locationImage || "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?q=80&w=2070&auto=format&fit=crop";

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
          backgroundImage: `url(${bgImage})`,
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
                  , {trip.country}
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
