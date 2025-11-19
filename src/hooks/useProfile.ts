"use client";

import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { useDemoMode } from '../contexts/DemoModeContext';

interface Profile {
  id: string;
  email: string;
  display_name: string | null;
  handle: string | null;
  avatar_url: string | null;
  created_at: string;
}

const demoProfile: Profile = {
  id: 'demo-user',
  email: 'demo@ouest.app',
  display_name: 'Alex Taylor',
  handle: 'alextravels',
  avatar_url: null,
  created_at: new Date().toISOString(),
};

export function useProfile() {
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);
  const { user } = useAuth();
  const { isDemoMode } = useDemoMode();

  useEffect(() => {
    if (isDemoMode) {
      setProfile(demoProfile);
      setLoading(false);
      return;
    }

    if (!user) {
      setProfile(null);
      setLoading(false);
      return;
    }

    loadProfile();
  }, [user, isDemoMode]);

  const loadProfile = async () => {
    if (!user) return;

    setLoading(true);

    const { data, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .single();

    if (error) {
      console.error('Error loading profile:', error);
    } else {
      setProfile(data);
    }

    setLoading(false);
  };

  const updateProfile = async (updates: Partial<Profile>) => {
    if (isDemoMode) {
      setProfile((prev) => (prev ? { ...prev, ...updates } : null));
      return { error: null };
    }

    if (!user) {
      return { error: new Error('No user logged in') };
    }

    const { error } = await supabase
      .from('profiles')
      .update(updates)
      .eq('id', user.id);

    if (error) {
      console.error('Error updating profile:', error);
      return { error };
    }

    // Reload profile after update
    await loadProfile();
    return { error: null };
  };

  return {
    profile,
    loading,
    updateProfile,
    refreshProfile: loadProfile,
  };
}

