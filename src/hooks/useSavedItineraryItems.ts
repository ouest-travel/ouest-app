"use client";

import { useState, useEffect, useRef } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { useDemoMode } from '../contexts/DemoModeContext';
import { Database } from '../types/database';

type SavedItineraryItem = Database['public']['Tables']['saved_itinerary_items']['Row'];

interface Activity {
  id: number;
  name: string;
  time: string;
  location: string;
  cost: string;
  description: string;
  category: "food" | "activity" | "transport" | "accommodation";
  day: number;
}

const demoSavedItems: SavedItineraryItem[] = [
  {
    id: '1',
    user_id: 'demo-user',
    activity_name: 'Sunset at Oia',
    activity_location: 'Oia',
    activity_time: '7:00 PM',
    activity_cost: 'Free',
    activity_description: 'Watch the famous Santorini sunset',
    activity_category: 'activity',
    source_trip_location: 'Santorini, Greece',
    source_trip_user: 'Sarah Chen',
    day: 1,
    created_at: new Date().toISOString(),
  },
  {
    id: '2',
    user_id: 'demo-user',
    activity_name: 'Wine Tasting Tour',
    activity_location: 'Santo Wines',
    activity_time: '2:00 PM',
    activity_cost: '€45',
    activity_description: 'Sample local wines with caldera views',
    activity_category: 'activity',
    source_trip_location: 'Santorini, Greece',
    source_trip_user: 'Sarah Chen',
    day: 2,
    created_at: new Date().toISOString(),
  },
];

export function useSavedItineraryItems() {
  const [items, setItems] = useState<SavedItineraryItem[]>([]);
  const [loading, setLoading] = useState(true);
  const { user } = useAuth();
  const { isDemoMode } = useDemoMode();
  const demoInitialized = useRef(false);

  useEffect(() => {
    if (isDemoMode) {
      // Only initialize with demo items if we haven't already initialized
      // This preserves any items added during the session
      if (!demoInitialized.current) {
        setItems(demoSavedItems);
        demoInitialized.current = true;
      }
      setLoading(false);
      return;
    }

    // Reset demo flag when exiting demo mode
    demoInitialized.current = false;

    if (!user) {
      setItems([]);
      setLoading(false);
      return;
    }

    loadItems();
  }, [user, isDemoMode]);

  const loadItems = async () => {
    if (!user) return;

    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('saved_itinerary_items')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false });

      if (error) {
        console.error('Error loading saved itinerary items:', {
          message: error.message,
          details: error.details,
          hint: error.hint,
          code: error.code,
          fullError: error,
        });
      } else {
        setItems(data || []);
      }
    } catch (error) {
      console.error('Error loading saved itinerary items:', {
        message: error instanceof Error ? error.message : String(error),
        fullError: error,
      });
    } finally {
      setLoading(false);
    }
  };

  const addItem = async (
    activity: Activity,
    sourceTripLocation?: string,
    sourceTripUser?: string
  ) => {
    if (isDemoMode) {
      const newItem: SavedItineraryItem = {
        id: Date.now().toString(),
        user_id: 'demo-user',
        activity_name: activity.name,
        activity_location: activity.location,
        activity_time: activity.time,
        activity_cost: activity.cost,
        activity_description: activity.description,
        activity_category: activity.category,
        source_trip_location: sourceTripLocation || null,
        source_trip_user: sourceTripUser || null,
        day: activity.day,
        created_at: new Date().toISOString(),
      };
      setItems((prev) => [newItem, ...prev]);
      return { data: newItem, error: null };
    }

    if (!user) {
      return { data: null, error: { message: 'User not authenticated' } };
    }

    try {
      const insertData: Database['public']['Tables']['saved_itinerary_items']['Insert'] = {
        user_id: user.id,
        activity_name: activity.name,
        activity_location: activity.location,
        activity_time: activity.time,
        activity_cost: activity.cost,
        activity_description: activity.description,
        activity_category: activity.category,
        source_trip_location: sourceTripLocation || null,
        source_trip_user: sourceTripUser || null,
        day: activity.day,
      };

      // TODO: Remove 'as any' once Supabase types are regenerated from database schema
      // The table exists in database.ts but TypeScript needs types to be regenerated
      const { data, error } = await supabase
        .from('saved_itinerary_items')
        .insert(insertData as any)
        .select()
        .single();

      if (error) {
        console.error('Error adding saved itinerary item:', {
          message: error.message,
          details: error.details,
          hint: error.hint,
          code: error.code,
          fullError: error,
        });
        return { data: null, error };
      }

      if (data) {
        setItems((prev) => [data, ...prev]);
      }

      return { data, error: null };
    } catch (error) {
      console.error('Error adding saved itinerary item:', {
        message: error instanceof Error ? error.message : String(error),
        fullError: error,
      });
      return { data: null, error: error as Error };
    }
  };

  const removeItem = async (itemId: string) => {
    if (isDemoMode) {
      setItems((prev) => prev.filter((item) => item.id !== itemId));
      return { error: null };
    }

    if (!user) {
      return { error: { message: 'User not authenticated' } };
    }

    try {
      const { error } = await supabase
        .from('saved_itinerary_items')
        .delete()
        .eq('id', itemId)
        .eq('user_id', user.id);

      if (error) {
        console.error('Error removing saved itinerary item:', {
          message: error.message,
          details: error.details,
          hint: error.hint,
          code: error.code,
          fullError: error,
        });
        return { error };
      }

      setItems((prev) => prev.filter((item) => item.id !== itemId));
      return { error: null };
    } catch (error) {
      console.error('Error removing saved itinerary item:', {
        message: error instanceof Error ? error.message : String(error),
        fullError: error,
      });
      return { error: error as Error };
    }
  };

  const isActivitySaved = (activityName: string, sourceLocation?: string): boolean => {
    return items.some(
      (item) =>
        item.activity_name === activityName &&
        (!sourceLocation || item.source_trip_location === sourceLocation)
    );
  };

  return {
    items,
    loading,
    addItem,
    removeItem,
    isActivitySaved,
    refreshItems: loadItems,
  };
}

