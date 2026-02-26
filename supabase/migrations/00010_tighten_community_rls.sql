-- Fix: Tighten community RLS policies for public/private trip transitions
-- trip_likes SELECT was USING(true), letting anyone enumerate likes on private trips
-- trip_likes/trip_comments INSERT had no trip-visibility check

-- ============================================================
-- trip_likes: Fix SELECT (was too permissive)
-- ============================================================

DROP POLICY IF EXISTS "Anyone can view likes" ON public.trip_likes;

CREATE POLICY "View likes on accessible trips"
    ON public.trip_likes FOR SELECT TO authenticated
    USING (
        trip_id IN (SELECT id FROM public.trips WHERE is_public = true)
        OR public.is_trip_member(trip_id, auth.uid())
    );

-- ============================================================
-- trip_likes: Tighten INSERT (only public or member trips)
-- ============================================================

DROP POLICY IF EXISTS "Users can like trips" ON public.trip_likes;

CREATE POLICY "Users can like accessible trips"
    ON public.trip_likes FOR INSERT TO authenticated
    WITH CHECK (
        user_id = auth.uid()
        AND (
            trip_id IN (SELECT id FROM public.trips WHERE is_public = true)
            OR public.is_trip_member(trip_id, auth.uid())
        )
    );

-- ============================================================
-- trip_comments: Tighten INSERT (only public or member trips)
-- ============================================================

DROP POLICY IF EXISTS "Authenticated users can comment" ON public.trip_comments;

CREATE POLICY "Users can comment on accessible trips"
    ON public.trip_comments FOR INSERT TO authenticated
    WITH CHECK (
        user_id = auth.uid()
        AND (
            trip_id IN (SELECT id FROM public.trips WHERE is_public = true)
            OR public.is_trip_member(trip_id, auth.uid())
        )
    );
