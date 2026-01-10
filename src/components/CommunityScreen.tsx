"use client";

import { motion } from "motion/react";
import { Users, Globe, Heart, MessageCircle, Eye } from "lucide-react";
import { useState, useEffect } from "react";
import { ImageWithFallback } from "./figma/ImageWithFallback";
import { ItineraryView } from "./ItineraryView";
import { Button } from "./ui/button";
import { useSavedItineraryItems } from "../hooks/useSavedItineraryItems";
import { toast } from "sonner";
import { supabase } from "../lib/supabase";

// Currency symbols mapping
const currencySymbols: Record<string, string> = {
  USD: "$",
  CAD: "$",
  EUR: "€",
  GBP: "£",
  JPY: "¥",
  AUD: "$",
  CHF: "Fr",
  CNY: "¥",
  INR: "₹",
  MXN: "$",
};

// Format currency amount with symbol
function formatCurrency(amount: number, currency: string = "CAD"): string {
  const symbol = currencySymbols[currency] || currency;
  if (currency === "JPY") {
    return `${symbol}${Math.round(amount).toLocaleString()}`;
  }
  return `${symbol}${amount.toFixed(2)}`;
}

export function CommunityScreen() {
  const [showItinerary, setShowItinerary] = useState(false);
  const [selectedTrip, setSelectedTrip] = useState<any>(null);
  const [publicTrips, setPublicTrips] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const { items: savedItems, addItem, removeItem } = useSavedItineraryItems();

  useEffect(() => {
    loadPublicTripsData();

    // Subscribe to real-time changes for public trips
    const subscription = supabase
      .channel('public_trips_channel')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'trips',
          filter: 'is_public=eq.true',
        },
        () => {
          loadPublicTripsData();
        }
      )
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  }, []);

  const loadPublicTripsData = async () => {
    setLoading(true);
    try {
      // Fetch public trips with creator profile
      const { data: tripsData, error: tripsError } = await supabase
        .from('trips')
        .select(`
          *,
          creator:profiles!trips_created_by_fkey(
            id,
            display_name,
            avatar_url
          )
        `)
        .eq('is_public', true)
        .order('created_at', { ascending: false });

      if (tripsError) {
        console.error('Error loading public trips:', tripsError);
        setPublicTrips([]);
        setLoading(false);
        return;
      }

      // Transform trips to post format
      const transformedTrips = await Promise.all(
        (tripsData || []).map(async (trip) => {
          // Get expenses for this trip to calculate total spent and show activities
          const { data: expensesData } = await supabase
            .from('expenses')
            .select('title, amount, category, date, description')
            .eq('trip_id', trip.id)
            .order('date', { ascending: true });

          const totalSpent = expensesData?.reduce((sum, exp) => sum + (exp.amount || 0), 0) || 0;
          const budget = trip.budget ? formatCurrency(trip.budget, trip.currency || 'USD') : null;
          const spent = totalSpent > 0 ? formatCurrency(totalSpent, trip.currency || 'USD') : null;

          // Format dates
          const formatDate = (date: Date | string | null) => {
            if (!date) return "";
            const d = typeof date === 'string' ? new Date(date) : date;
            return d.toLocaleDateString("en-US", { month: "short", day: "numeric" });
          };

          const startDate = trip.start_date ? (typeof trip.start_date === 'string' ? new Date(trip.start_date) : trip.start_date) : null;
          const endDate = trip.end_date ? (typeof trip.end_date === 'string' ? new Date(trip.end_date) : trip.end_date) : null;
          
          const dates = startDate && endDate
            ? `${formatDate(startDate)} - ${formatDate(endDate)}, ${endDate.getFullYear()}`
            : "Dates TBD";

          // Get activities from expenses (convert expenses to activities format)
          const activities = (expensesData || []).map((expense: any, index: number) => {
            // Calculate day based on expense date relative to trip start
            let day = 1;
            if (expense.date && startDate) {
              const expenseDate = typeof expense.date === 'string' ? new Date(expense.date) : expense.date;
              const daysDiff = Math.ceil((expenseDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24));
              day = Math.max(1, daysDiff + 1);
            }

            return {
              id: index + 1,
              name: expense.title || 'Activity',
              time: 'TBD',
              location: trip.destination,
              cost: expense.amount ? formatCurrency(expense.amount, trip.currency || 'USD') : 'Free',
              description: expense.description || expense.title || '',
              category: (expense.category || 'activity') as const,
              day,
            };
          });

          return {
            id: trip.id,
            user: trip.creator?.display_name || 'Traveler',
            avatar: trip.creator?.avatar_url || '👤',
            location: trip.destination,
            dates,
            budget,
            spent,
            totalBudget: trip.budget,
            currency: trip.currency || 'USD',
            image: trip.cover_image || "https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=800",
            caption: trip.description || `Exploring ${trip.destination} ✈️`,
            likes: 0, // Could be added later
            comments: 0, // Could be added later
            activities: activities.length > 0 ? activities : [
              // Fallback activities if no expenses
              { id: 1, name: "Trip Activities", time: "TBD", location: trip.destination, cost: "See budget", description: trip.description || '', category: "activity" as const, day: 1 }
            ],
            tripId: trip.id,
          };
        })
      );

      setPublicTrips(transformedTrips);
    } catch (error) {
      console.error('Error loading public trips:', error);
      setPublicTrips([]);
    } finally {
      setLoading(false);
    }
  };

  const groups = [
    { name: "🇯🇵 Japan Travel", members: 1234 },
    { name: "✈️ Digital Nomads", members: 892 },
    { name: "🏔️ Adventure Seekers", members: 2156 },
  ];

  const handleViewItinerary = (post: any) => {
    setSelectedTrip(post);
    setShowItinerary(true);
  };

  const handleAddActivity = async (activity: any) => {
    await addItem(activity, selectedTrip?.location, selectedTrip?.user);
  };

  const handleRemoveActivity = async (activityId: number) => {
    const activity = selectedTrip?.activities?.find((a: any) => a.id === activityId);
    if (!activity) return;

    const savedItem = savedItems.find(
      (item) =>
        item.activity_name === activity.name &&
        item.source_trip_location === selectedTrip.location
    );
    if (savedItem) {
      await removeItem(savedItem.id);
    }
  };

  const handleAddItinerary = async () => {
    if (!selectedTrip?.activities) return;
    
    let addedCount = 0;
    for (const activity of selectedTrip.activities) {
      const result = await addItem(activity, selectedTrip.location, selectedTrip.user);
      if (result.data && !result.error) {
        addedCount++;
      }
    }
    
    if (addedCount > 0) {
      toast.success(`Added ${addedCount} ${addedCount === 1 ? 'activity' : 'activities'} to your itinerary`);
    }
  };

  const getAddedActivityIds = (): number[] => {
    if (!selectedTrip) return [];
    return (
      selectedTrip.activities
        ?.filter((activity: any) =>
          savedItems.some(
            (item) =>
              item.activity_name === activity.name &&
              item.source_trip_location === selectedTrip.location
          )
        )
        .map((activity: any) => activity.id) || []
    );
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

          {loading ? (
            <div className="text-center py-12">
              <p className="text-muted-foreground">Loading public trips...</p>
            </div>
          ) : publicTrips.length === 0 ? (
            <div className="text-center py-12">
              <p className="text-muted-foreground">No public trips yet. Create a public trip to share with the community!</p>
            </div>
          ) : (
            publicTrips.map((post, index) => (
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

                {/* Budget Info */}
                {(post.budget || post.spent) && (
                  <div className="mb-3 p-3 rounded-xl bg-muted/50 border border-border">
                    <div className="flex items-center justify-between text-sm">
                      {post.budget && (
                        <div>
                          <span className="text-muted-foreground">Budget: </span>
                          <span className="text-foreground font-medium">{post.budget}</span>
                        </div>
                      )}
                      {post.spent && (
                        <div>
                          <span className="text-muted-foreground">Spent: </span>
                          <span className="text-foreground font-medium">{post.spent}</span>
                        </div>
                      )}
                    </div>
                  </div>
                )}

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
            ))
          )}
        </div>
      </div>

      {/* Itinerary View Modal */}
      {showItinerary && selectedTrip && (
        <ItineraryView
          tripName={`${selectedTrip.user}'s ${selectedTrip.location} Trip`}
          tripLocation={selectedTrip.location}
          tripDates={selectedTrip.dates}
          budget={selectedTrip.budget}
          spent={selectedTrip.spent}
          activities={selectedTrip.activities}
          onClose={() => {
            setShowItinerary(false);
            setSelectedTrip(null);
          }}
          isOwnTrip={false}
          onAddActivity={handleAddActivity}
          onRemoveActivity={handleRemoveActivity}
          onAddItinerary={handleAddItinerary}
          addedActivityIds={getAddedActivityIds()}
        />
      )}
    </div>
  );
}