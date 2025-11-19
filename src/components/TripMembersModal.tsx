import { motion } from "motion/react";
import { X, Crown, Mail } from "lucide-react";

interface TripMember {
  id: number;
  name: string;
  avatar: string;
  email: string;
  role?: "organizer" | "member";
}

interface TripMembersModalProps {
  trip: {
    destination: string;
    name?: string;
    travelers: number;
  };
  onClose: () => void;
}

export function TripMembersModal({ trip, onClose }: TripMembersModalProps) {
  const tripName = trip.name || trip.destination;
  
  // Generate members based on trip - You would fetch real data from your backend
  const getMembersForTrip = () => {
    // Default member pool
    const allMembers = [
      { id: 1, name: "Trey Anderson", avatar: "👨🏻", email: "trey@ouest.com", role: "organizer" as const },
      { id: 2, name: "Sandra Martinez", avatar: "👩🏽", email: "sandra@ouest.com", role: "member" as const },
      { id: 3, name: "Timmy Chen", avatar: "👨🏾", email: "timmy@ouest.com", role: "member" as const },
      { id: 4, name: "Jason Kim", avatar: "👨🏼", email: "jason@ouest.com", role: "member" as const },
      { id: 5, name: "Emma Wilson", avatar: "👩🏻", email: "emma@ouest.com", role: "member" as const },
      { id: 6, name: "Alex Johnson", avatar: "👨🏽", email: "alex@ouest.com", role: "member" as const },
    ];
    
    // Return members based on trip's traveler count
    return allMembers.slice(0, trip.travelers);
  };
  
  const members = getMembersForTrip();
  
  return (
    <div className="fixed inset-0 bg-black/50 flex items-end sm:items-center justify-center z-50 p-4">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0, y: 20 }}
        className="bg-background rounded-3xl max-w-md w-full max-h-[80vh] overflow-hidden shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div
          className="px-6 py-5 border-b border-border"
          style={{
            background: "var(--ouest-gradient-soft)",
          }}
        >
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-foreground mb-1">Trip Members</h2>
              <p className="text-muted-foreground" style={{ fontSize: "14px" }}>
                {tripName}
              </p>
            </div>
            <button
              onClick={onClose}
              className="p-2 rounded-full hover:bg-muted transition-colors"
            >
              <X className="w-5 h-5 text-foreground" />
            </button>
          </div>
        </div>

        {/* Members List */}
        <div className="p-6 overflow-y-auto max-h-[60vh]">
          <div className="space-y-3">
            {members.map((member, index) => (
              <motion.div
                key={member.id}
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: index * 0.05 }}
                className="flex items-center gap-4 p-4 rounded-2xl bg-card border border-border hover:shadow-md transition-all"
              >
                {/* Avatar */}
                <div
                  className="w-12 h-12 rounded-full flex items-center justify-center text-2xl"
                  style={{
                    background: "var(--ouest-gradient-soft)",
                  }}
                >
                  {member.avatar}
                </div>

                {/* Member Info */}
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <span className="text-foreground">{member.name}</span>
                    {member.role === "organizer" && (
                      <div
                        className="px-2 py-0.5 rounded-full flex items-center gap-1"
                        style={{
                          background: "var(--ouest-gradient-main)",
                        }}
                      >
                        <Crown className="w-3 h-3 text-white" />
                        <span className="text-white text-xs">Organizer</span>
                      </div>
                    )}
                  </div>
                  <div className="flex items-center gap-1.5 mt-1 text-muted-foreground">
                    <Mail className="w-3.5 h-3.5" />
                    <span style={{ fontSize: "13px" }}>{member.email}</span>
                  </div>
                </div>
              </motion.div>
            ))}
          </div>

          {/* Invite More Section */}
          <motion.button
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: members.length * 0.05 + 0.1 }}
            className="w-full mt-4 p-4 rounded-2xl border-2 border-dashed border-border hover:border-muted-foreground transition-all flex items-center justify-center gap-2 text-muted-foreground hover:text-foreground"
          >
            <span className="text-xl">➕</span>
            <span>Invite more travelers</span>
          </motion.button>
        </div>
      </motion.div>

      {/* Backdrop */}
      <div
        className="fixed inset-0 -z-10"
        onClick={onClose}
      />
    </div>
  );
}