-- 00006_fix_insert_returning.sql
-- Fix: PostgREST's "return=representation" uses INSERT...RETURNING which checks
-- SELECT policies BEFORE the AFTER INSERT trigger fires. Since the trigger adds
-- the creator to trip_members, is_trip_member() returns false at INSERT time.
--
-- Solution: Add a SELECT policy that allows the creator to see their own trip.
-- This is also correct semantically — the person who created a trip should
-- always be able to see it.

CREATE POLICY "Creator can view own trips"
    ON public.trips FOR SELECT
    TO authenticated
    USING (created_by = auth.uid());
