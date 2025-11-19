"use client";

import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useDemoMode } from '../contexts/DemoModeContext';
import { useAuth } from '../contexts/AuthContext';

export interface TripMember {
  id: string;
  trip_id?: string | number;
  user_id?: string;
  role: 'owner' | 'member';
  joined_at?: string;
  profile?: {
    display_name?: string;
    avatar_url?: string;
    email?: string;
  };
}

const demoMembers: TripMember[] = [
  {
    id: "1",
    user_id: "1",
    role: "owner",
    profile: {
      display_name: "Trey",
      avatar_url: "👨🏻",
    },
  },
  {
    id: "2",
    user_id: "2",
    role: "member",
    profile: {
      display_name: "Jason",
      avatar_url: "👨🏼",
    },
  },
  {
    id: "3",
    user_id: "3",
    role: "member",
    profile: {
      display_name: "Sandra",
      avatar_url: "👩🏽",
    },
  },
  {
    id: "4",
    user_id: "4",
    role: "member",
    profile: {
      display_name: "Timmy",
      avatar_url: "👨🏾",
    },
  },
];

export function useTripMembers(tripId: string | number | null) {
  const [members, setMembers] = useState<TripMember[]>([]);
  const [loading, setLoading] = useState(true);
  const { isDemoMode } = useDemoMode();
  const { user } = useAuth();

  useEffect(() => {
    if (isDemoMode) {
      setMembers(demoMembers);
      setLoading(false);
      return;
    }

    if (!user || !tripId) {
      setMembers([]);
      setLoading(false);
      return;
    }

    loadMembers();

    // Subscribe to real-time changes
    const subscription = supabase
      .channel(`trip_members_${tripId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'trip_members',
          filter: `trip_id=eq.${tripId}`,
        },
        () => {
          loadMembers();
        }
      )
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  }, [isDemoMode, user, tripId]);

  const loadMembers = async () => {
    if (!tripId) return;

    setLoading(true);

    const { data, error } = await supabase
      .from('trip_members')
      .select('*, profiles(display_name, avatar_url, email)')
      .eq('trip_id', tripId);

    if (error) {
      console.error('Error loading members:', error);
    } else {
      setMembers(data || []);
    }

    setLoading(false);
  };

  const addMember = async (userId: string, role: 'owner' | 'member' = 'member') => {
    if (isDemoMode) {
      const newMember: TripMember = {
        id: Date.now().toString(),
        user_id: userId,
        role,
        trip_id: tripId!,
      };
      setMembers((prev) => [...prev, newMember]);
      return { data: newMember, error: null };
    }

    if (!tripId) {
      return { data: null, error: new Error('Missing trip ID') };
    }

    const { data, error } = await supabase
      .from('trip_members')
      .insert({
        trip_id: tripId,
        user_id: userId,
        role,
      })
      .select()
      .single();

    if (error) {
      console.error('Error adding member:', error);
      return { data: null, error };
    }

    return { data, error: null };
  };

  const removeMember = async (memberId: string) => {
    if (isDemoMode) {
      setMembers((prev) => prev.filter((m) => m.id !== memberId));
      return { error: null };
    }

    const { error } = await supabase
      .from('trip_members')
      .delete()
      .eq('id', memberId);

    if (error) {
      console.error('Error removing member:', error);
    }

    return { error };
  };

  const updateMemberRole = async (memberId: string, role: 'owner' | 'member') => {
    if (isDemoMode) {
      setMembers((prev) =>
        prev.map((m) => (m.id === memberId ? { ...m, role } : m))
      );
      return { error: null };
    }

    const { error } = await supabase
      .from('trip_members')
      .update({ role })
      .eq('id', memberId);

    if (error) {
      console.error('Error updating member role:', error);
    }

    return { error };
  };

  return {
    members,
    loading,
    addMember,
    removeMember,
    updateMemberRole,
    refreshMembers: loadMembers,
  };
}

