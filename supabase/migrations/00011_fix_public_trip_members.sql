-- Fix: Allow viewing members of public trips + reload PostgREST schema cache
--
-- Problem 1: trip_members SELECT policy only allows members to see other members.
-- For the Explore feed, users need to see member previews of public trips they
-- don't belong to.
--
-- Problem 2: PostgREST's schema cache may be stale after migration 00009 added
-- 4 new tables (follows, trip_likes, trip_comments, saved_trips) with FK refs to
-- profiles. The FK disambiguation hints (e.g. profiles!trip_comments_user_id_fkey)
-- fail if the cache hasn't picked up the new constraints.

-- ============================================================
-- STEP 1: Helper function to check if a trip is public
-- SECURITY DEFINER avoids RLS recursion when used inside policies.
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_public_trip(_trip_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.trips
        WHERE id = _trip_id AND is_public = true
    );
$$;

-- ============================================================
-- STEP 2: Allow viewing members of public trips
-- ============================================================

-- Only create if it doesn't already exist
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE policyname = 'Anyone can view members of public trips'
        AND tablename = 'trip_members'
    ) THEN
        CREATE POLICY "Anyone can view members of public trips"
            ON public.trip_members FOR SELECT
            TO authenticated
            USING (public.is_public_trip(trip_id));
    END IF;
END $$;

-- ============================================================
-- STEP 3: Force PostgREST to reload its schema cache
-- This picks up all FK constraints from recent migrations,
-- ensuring disambiguation hints work correctly.
-- ============================================================

NOTIFY pgrst, 'reload schema';
