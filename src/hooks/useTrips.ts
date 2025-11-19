import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useDemoMode } from '../contexts/DemoModeContext';
import { useAuth } from '../contexts/AuthContext';

interface Trip {
  id: string | number;
  name?: string;
  destination: string;
  dates?: string;
  start_date?: Date | string | null;
  end_date?: Date | string | null;
  budget?: number | string | null;
  currency?: string;
  image?: string;
  travelers?: number;
  cover_image?: string | null;
  created_by?: string;
  is_public?: boolean;
  voting_enabled?: boolean;
  description?: string | null;
}

// Demo data
const demoTrips: Trip[] = [
  {
    id: 1,
    destination: "Tokyo, Japan",
    dates: "Dec 15 - Dec 22, 2025",
    image: "🇯🇵",
    budget: "$2,400",
    travelers: 2,
    start_date: new Date(2025, 11, 15),
    end_date: new Date(2025, 11, 22),
  },
  {
    id: 2,
    destination: "Paris, France",
    dates: "Jan 10 - Jan 17, 2026",
    image: "🇫🇷",
    budget: "$3,200",
    travelers: 3,
    start_date: new Date(2026, 0, 10),
    end_date: new Date(2026, 0, 17),
  },
  {
    id: 3,
    destination: "Barcelona, Spain",
    dates: "Sep 1 - Sep 8, 2024",
    image: "🇪🇸",
    budget: "$1,800",
    travelers: 4,
    start_date: new Date(2024, 8, 1),
    end_date: new Date(2024, 8, 8),
  },
];

export function useTrips() {
  const [trips, setTrips] = useState<Trip[]>([]);
  const [loading, setLoading] = useState(true);
  const { isDemoMode } = useDemoMode();
  const { user } = useAuth();

  useEffect(() => {
    if (isDemoMode) {
      setTrips(demoTrips);
      setLoading(false);
      return;
    }

    if (!user) {
      setTrips([]);
      setLoading(false);
      return;
    }

    loadTrips();

    // Subscribe to real-time changes
    const subscription = supabase
      .channel('trips_channel')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'trips',
        },
        () => {
          loadTrips();
        }
      )
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  }, [isDemoMode, user]);

  const loadTrips = async () => {
    if (!user) return;

    setLoading(true);
    
    // Get trips where user is a member
    const { data: memberTrips, error: memberError } = await supabase
      .from('trip_members')
      .select('trip_id')
      .eq('user_id', user.id);

    if (memberError) {
      console.error('Error loading trip members:', memberError);
      setLoading(false);
      return;
    }

    const tripIds = memberTrips?.map((m) => m.trip_id) || [];

    if (tripIds.length === 0) {
      setTrips([]);
      setLoading(false);
      return;
    }

    const { data, error } = await supabase
      .from('trips')
      .select('*')
      .in('id', tripIds)
      .order('created_at', { ascending: false });

    if (error) {
      console.error('Error loading trips:', error);
    } else {
      setTrips(data || []);
    }
    
    setLoading(false);
  };

  const createTrip = async (tripData: Partial<Trip>) => {
    if (isDemoMode) {
      const newTrip: Trip = {
        ...tripData,
        id: Date.now(),
      } as Trip;
      setTrips((prev) => [newTrip, ...prev]);
      return { data: newTrip, error: null };
    }

    if (!user) {
      return { data: null, error: new Error('User not authenticated') };
    }

    const { data, error } = await supabase
      .from('trips')
      .insert({
        name: tripData.name || tripData.destination || '',
        destination: tripData.destination || '',
        start_date: tripData.start_date ? new Date(tripData.start_date).toISOString() : null,
        end_date: tripData.end_date ? new Date(tripData.end_date).toISOString() : null,
        budget: typeof tripData.budget === 'number' ? tripData.budget : null,
        currency: tripData.currency || 'USD',
        created_by: user.id,
        is_public: tripData.is_public || false,
        voting_enabled: tripData.voting_enabled || false,
        cover_image: tripData.cover_image || null,
        description: tripData.description || null,
      })
      .select()
      .single();

    if (error) {
      console.error('Error creating trip:', error);
      return { data: null, error };
    }

    // Trigger automatically adds user as trip owner, so we don't need to do it manually

    return { data, error: null };
  };

  const updateTrip = async (tripId: string | number, updates: Partial<Trip>) => {
    if (isDemoMode) {
      setTrips((prev) =>
        prev.map((trip) => (trip.id === tripId ? { ...trip, ...updates } : trip))
      );
      return { error: null };
    }

    const { error } = await supabase
      .from('trips')
      .update(updates)
      .eq('id', tripId);

    if (error) {
      console.error('Error updating trip:', error);
    }

    return { error };
  };

  const deleteTrip = async (tripId: string | number) => {
    if (isDemoMode) {
      setTrips((prev) => prev.filter((trip) => trip.id !== tripId));
      return { error: null };
    }

    const { error } = await supabase.from('trips').delete().eq('id', tripId);

    if (error) {
      console.error('Error deleting trip:', error);
    }

    return { error };
  };

  return {
    trips,
    loading,
    createTrip,
    updateTrip,
    deleteTrip,
    refreshTrips: loadTrips,
  };
}

