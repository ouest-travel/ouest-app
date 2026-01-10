"use client";

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
  status?: 'planning' | 'upcoming' | 'active' | 'completed';
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
    
    // Refetch trips after successful mutation
    await loadTrips();

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
      return { error };
    }

    // Refetch trips after successful mutation
    await loadTrips();

    return { error };
  };

  const deleteTrip = async (tripId: string | number) => {
    // First, check if trip is past using the trips we already have loaded
    const trip = trips.find(t => t.id === tripId);
    
    if (trip) {
      // Check if trip is past (completed or end_date in the past)
      const isPastTrip = trip.status === 'completed' || 
        (trip.end_date && new Date(trip.end_date) < new Date());

      if (isPastTrip) {
        return { error: { message: 'Cannot delete past trips. Past trips are preserved for your travel history.' } };
      }
    }

    if (isDemoMode) {
      setTrips((prev) => prev.filter((trip) => trip.id !== tripId));
      return { error: null };
    }

    // Try to delete the trip - RLS policy will handle permissions
    // If the user doesn't have permission, Supabase will return an error
    const { error } = await supabase
      .from('trips')
      .delete()
      .eq('id', tripId);

    if (error) {
      console.error('Error deleting trip:', {
        message: error.message,
        details: error.details,
        hint: error.hint,
        code: error.code,
        fullError: error,
      });
      
      // Provide more helpful error messages
      if (error.code === '42501' || error.message?.includes('permission') || error.message?.includes('policy')) {
        return { 
          error: { 
            message: 'Permission denied. You may not have permission to delete this trip. Make sure you are the trip creator or a member of the trip, and that the RLS policy allows trip members to delete trips.' 
          } 
        };
      }
      
      return { error };
    }

    // Refetch trips after successful mutation
    await loadTrips();

    return { error };
  };

  const loadPublicTrips = async () => {
    setLoading(true);
    
    try {
      // Fetch public trips with creator profile information
      const { data, error } = await supabase
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

      if (error) {
        console.error('Error loading public trips:', error);
        return { data: [], error };
      }

      return { data: data || [], error: null };
    } catch (error) {
      console.error('Error loading public trips:', error);
      return { data: [], error: error as Error };
    } finally {
      setLoading(false);
    }
  };

  return {
    trips,
    loading,
    createTrip,
    updateTrip,
    deleteTrip,
    refreshTrips: loadTrips,
    loadPublicTrips,
  };
}

