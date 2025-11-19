import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { useDemoMode } from '../contexts/DemoModeContext';

interface ProfileStats {
  countriesVisited: number;
  tripsPlanned: number;
  wishlistItems: number;
}

const demoStats: ProfileStats = {
  countriesVisited: 12,
  tripsPlanned: 24,
  wishlistItems: 47,
};

export function useProfileStats() {
  const [stats, setStats] = useState<ProfileStats>({
    countriesVisited: 0,
    tripsPlanned: 0,
    wishlistItems: 0,
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
        tripsPlanned: 0,
        wishlistItems: 0,
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

      // Fetch trips planned count (upcoming and active trips)
      const now = new Date().toISOString();
      const { count: tripsCount, error: tripsError } = await supabase
        .from('trips')
        .select('*', { count: 'exact', head: true })
        .eq('created_by', user.id)
        .or(`end_date.gte.${now},end_date.is.null`);

      if (tripsError) {
        console.error('Error loading trips:', tripsError);
      }

      // Fetch wishlist items count
      const { count: wishlistCount, error: wishlistError } = await supabase
        .from('wishlist')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id);

      if (wishlistError) {
        console.error('Error loading wishlist:', wishlistError);
      }

      setStats({
        countriesVisited: countriesCount || 0,
        tripsPlanned: tripsCount || 0,
        wishlistItems: wishlistCount || 0,
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

