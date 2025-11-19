import { motion } from "motion/react";
import { Users, Globe, Heart, MessageCircle, Eye } from "lucide-react";
import { useState } from "react";
import { ImageWithFallback } from "./figma/ImageWithFallback";
import { ItineraryView } from "./ItineraryView";
import { Button } from "./ui/button";

export function CommunityScreen() {
  const [showItinerary, setShowItinerary] = useState(false);
  const [selectedTrip, setSelectedTrip] = useState<any>(null);
  const [addedActivityIds, setAddedActivityIds] = useState<number[]>([]);

  const posts = [
    {
      id: 1,
      user: "Sarah Chen",
      avatar: "👩🏻",
      location: "Santorini, Greece",
      dates: "Oct 10 - Oct 17, 2024",
      budget: "€2,100",
      image: "https://images.unsplash.com/photo-1613395877344-13d4a8e0d49e?w=800&q=80",
      caption: "Sunset views that take your breath away 🌅",
      likes: 234,
      comments: 45,
      activities: [
        { id: 1, name: "Sunset at Oia", time: "7:00 PM", location: "Oia", cost: "Free", description: "Watch the famous Santorini sunset", category: "activity" as const, day: 1 },
        { id: 2, name: "Wine Tasting Tour", time: "2:00 PM", location: "Santo Wines", cost: "€45", description: "Sample local wines with caldera views", category: "activity" as const, day: 2 },
        { id: 3, name: "Traditional Greek Dinner", time: "8:00 PM", location: "Ammoudi Bay", cost: "€60", description: "Fresh seafood by the water", category: "food" as const, day: 2 },
      ],
    },
    {
      id: 2,
      user: "Mike Rodriguez",
      avatar: "👨🏽",
      location: "Kyoto, Japan",
      dates: "Nov 5 - Nov 12, 2024",
      budget: "¥180,000",
      image: "https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=800&q=80",
      caption: "Temple hopping in the most serene city",
      likes: 189,
      comments: 32,
      activities: [
        { id: 4, name: "Fushimi Inari Shrine", time: "9:00 AM", location: "Fushimi-ku", cost: "Free", description: "Walk through 10,000 torii gates", category: "activity" as const, day: 1 },
        { id: 5, name: "Arashiyama Bamboo Grove", time: "11:00 AM", location: "Arashiyama", cost: "Free", description: "Peaceful bamboo forest walk", category: "activity" as const, day: 1 },
        { id: 6, name: "Kaiseki Dinner", time: "7:00 PM", location: "Gion", cost: "¥12,000", description: "Traditional multi-course Japanese meal", category: "food" as const, day: 1 },
        { id: 7, name: "Kinkaku-ji Temple", time: "10:00 AM", location: "Kita-ku", cost: "¥500", description: "The famous Golden Pavilion", category: "activity" as const, day: 2 },
      ],
    },
    {
      id: 3,
      user: "Emma Wilson",
      avatar: "👩🏼",
      location: "Bali, Indonesia",
      dates: "Dec 1 - Dec 8, 2024",
      budget: "IDR 15,000,000",
      image: "https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=800&q=80",
      caption: "Rice terrace mornings hit different ✨",
      likes: 412,
      comments: 67,
      activities: [
        { id: 8, name: "Tegallalang Rice Terraces", time: "8:00 AM", location: "Ubud", cost: "IDR 15,000", description: "Stunning rice paddies", category: "activity" as const, day: 1 },
        { id: 9, name: "Ubud Monkey Forest", time: "11:00 AM", location: "Ubud", cost: "IDR 80,000", description: "Sacred forest with monkeys", category: "activity" as const, day: 1 },
        { id: 10, name: "Balinese Cooking Class", time: "3:00 PM", location: "Ubud", cost: "IDR 350,000", description: "Learn to cook traditional dishes", category: "food" as const, day: 2 },
      ],
    },
  ];

  const groups = [
    { name: "🇯🇵 Japan Travel", members: 1234 },
    { name: "✈️ Digital Nomads", members: 892 },
    { name: "🏔️ Adventure Seekers", members: 2156 },
  ];

  const handleViewItinerary = (post: any) => {
    setSelectedTrip(post);
    setShowItinerary(true);
  };

  const handleAddActivity = (activity: any) => {
    setAddedActivityIds((prev) => [...prev, activity.id]);
  };

  const handleRemoveActivity = (activityId: number) => {
    setAddedActivityIds((prev) => prev.filter((id) => id !== activityId));
  };

  return (
    <div className="min-h-screen bg-background pb-24">
      {/* Header */}
      <div
        className="px-6 pt-12 pb-8"
        style={{
          background: "var(--ouest-gradient-soft)",
        }}
      >
        <div className="max-w-md mx-auto">
          <h1 className="text-foreground mb-2">Community</h1>
          <p className="text-muted-foreground">
            Connect with travelers worldwide
          </p>
        </div>
      </div>

      <div className="px-6 -mt-4 max-w-md mx-auto">
        {/* Groups Card */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-card rounded-3xl p-6 shadow-lg border border-border mb-6"
        >
          <div className="flex items-center gap-2 mb-4">
            <Users className="w-5 h-5" style={{ color: "var(--ouest-blue)" }} />
            <h3 className="text-foreground">Your Groups</h3>
          </div>

          <div className="space-y-3">
            {groups.map((group) => (
              <button
                key={group.name}
                className="w-full flex items-center justify-between p-3 rounded-xl bg-muted hover:bg-muted/70 transition-colors"
              >
                <span className="text-foreground">{group.name}</span>
                <span className="text-muted-foreground" style={{ fontSize: '13px' }}>
                  {group.members.toLocaleString()} members
                </span>
              </button>
            ))}
          </div>
        </motion.div>

        {/* Posts Feed */}
        <div className="space-y-6">
          <h3 className="text-foreground px-2">Recent Posts</h3>

          {posts.map((post, index) => (
            <motion.div
              key={post.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: index * 0.1 }}
              className="bg-card rounded-3xl shadow-lg border border-border overflow-hidden"
            >
              {/* Post Header */}
              <div className="p-4 flex items-center gap-3">
                <span className="text-3xl">{post.avatar}</span>
                <div className="flex-1">
                  <h4 className="text-foreground">{post.user}</h4>
                  <div className="flex items-center gap-1 text-muted-foreground">
                    <Globe className="w-3 h-3" />
                    <span style={{ fontSize: '13px' }}>{post.location}</span>
                  </div>
                </div>
              </div>

              {/* Post Image */}
              <ImageWithFallback
                src={post.image}
                alt={post.location}
                className="w-full aspect-square object-cover"
              />

              {/* Post Footer */}
              <div className="p-4">
                <p className="text-foreground mb-3">{post.caption}</p>

                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center gap-4">
                    <button className="flex items-center gap-2 text-muted-foreground hover:text-foreground transition-colors">
                      <Heart className="w-5 h-5" />
                      <span style={{ fontSize: '14px' }}>{post.likes}</span>
                    </button>

                    <button className="flex items-center gap-2 text-muted-foreground hover:text-foreground transition-colors">
                      <MessageCircle className="w-5 h-5" />
                      <span style={{ fontSize: '14px' }}>{post.comments}</span>
                    </button>
                  </div>
                </div>

                {/* View Itinerary Button */}
                <Button
                  onClick={() => handleViewItinerary(post)}
                  variant="outline"
                  className="w-full gap-2 border-2"
                  style={{
                    borderColor: "var(--ouest-blue)",
                  }}
                >
                  <Eye className="w-4 h-4" />
                  View Itinerary & Budget
                </Button>
              </div>
            </motion.div>
          ))}
        </div>
      </div>

      {/* Itinerary View Modal */}
      {showItinerary && selectedTrip && (
        <ItineraryView
          tripName={`${selectedTrip.user}'s ${selectedTrip.location} Trip`}
          tripLocation={selectedTrip.location}
          tripDates={selectedTrip.dates}
          budget={selectedTrip.budget}
          activities={selectedTrip.activities}
          onClose={() => {
            setShowItinerary(false);
            setSelectedTrip(null);
          }}
          isOwnTrip={false}
          onAddActivity={handleAddActivity}
          onRemoveActivity={handleRemoveActivity}
          addedActivityIds={addedActivityIds}
        />
      )}
    </div>
  );
}