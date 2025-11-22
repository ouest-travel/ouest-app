"use client";

import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { useDemoMode } from '../contexts/DemoModeContext';

interface ProfileStats {
  countriesVisited: number;
  totalTrips: number;
  memories: number;
  savedItineraries: number;
}

const demoStats: ProfileStats = {
  countriesVisited: 12,
  totalTrips: 24,
  memories: 156,
  savedItineraries: 8,
};

export function useProfileStats() {
  const [stats, setStats] = useState<ProfileStats>({
    countriesVisited: 0,
    totalTrips: 0,
    memories: 0,
    savedItineraries: 0,
  });
  const [loading, setLoading] = useState(true);
  const { user } = useAuth();
  const { isDemoMode } = useDemoMode();

  useEffect(() => {
    if (isDemoMode) {
      setStats(demoStats);
      setLoading(false);
      return;
    }

    if (!user) {
      setStats({
        countriesVisited: 0,
        totalTrips: 0,
        memories: 0,
        savedItineraries: 0,
      });
      setLoading(false);
      return;
    }

    loadStats();
  }, [user, isDemoMode]);

  const loadStats = async () => {
    if (!user) return;

    setLoading(true);

    try {
      // Fetch countries visited count
      const { count: countriesCount, error: countriesError } = await supabase
        .from('countries_visited')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id);

      if (countriesError) {
        console.error('Error loading countries visited:', countriesError);
      }

      // Fetch total trips count (all trips, not just upcoming)
      const { count: tripsCount, error: tripsError } = await supabase
        .from('trips')
        .select('*', { count: 'exact', head: true })
        .eq('created_by', user.id);

      if (tripsError) {
        console.error('Error loading trips:', tripsError);
      }

      // Fetch total expenses count (memories) across all user's trips
      const { data: userTrips, error: userTripsError } = await supabase
        .from('trips')
        .select('id')
        .eq('created_by', user.id);

      if (userTripsError) {
        console.error('Error loading user trips for memories:', userTripsError);
      }

      let memoriesCount = 0;
      if (userTrips && userTrips.length > 0) {
        const tripIds = userTrips.map(trip => trip.id);
        const { count: expensesCount, error: expensesError } = await supabase
          .from('expenses')
          .select('*', { count: 'exact', head: true })
          .in('trip_id', tripIds);

        if (expensesError) {
          console.error('Error loading expenses (memories):', expensesError);
        } else {
          memoriesCount = expensesCount || 0;
        }
      }

      // Fetch saved itinerary items count
      const { count: savedItinerariesCount, error: savedItinerariesError } = await supabase
        .from('saved_itinerary_items')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id);

      if (savedItinerariesError) {
        console.error('Error loading saved itineraries:', savedItinerariesError);
      }

      setStats({
        countriesVisited: countriesCount || 0,
        totalTrips: tripsCount || 0,
        memories: memoriesCount,
        savedItineraries: savedItinerariesCount || 0,
      });
    } catch (error) {
      console.error('Error loading profile stats:', error);
    } finally {
      setLoading(false);
    }
  };

  return {
    stats,
    loading,
    refreshStats: loadStats,
  };
}

