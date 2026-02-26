-- 00005_debug_and_fix_policies.sql
-- Nuclear approach: drop ALL policies on trips and trip_members regardless of name,
-- then recreate only the ones we need using SECURITY DEFINER helper functions.
-- This handles any leftover policies from the web app schema.

-- ============================================================
-- NUCLEAR DROP: Remove every single policy on both tables
-- ============================================================

DO $$
DECLARE
    pol RECORD;
BEGIN
    -- Drop ALL trips policies
    FOR pol IN
        SELECT p.policyname
        FROM pg_catalog.pg_policies p
        WHERE p.schemaname = 'public' AND p.tablename = 'trips'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.trips', pol.policyname);
    END LOOP;

    -- Drop ALL trip_members policies
    FOR pol IN
        SELECT p.policyname
        FROM pg_catalog.pg_policies p
        WHERE p.schemaname = 'public' AND p.tablename = 'trip_members'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.trip_members', pol.policyname);
    END LOOP;
END $$;

-- ============================================================
-- Ensure helper functions exist (idempotent)
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_trip_member(_trip_id UUID, _user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.trip_members
        WHERE trip_id = _trip_id AND user_id = _user_id
    );
$$;

CREATE OR REPLACE FUNCTION public.get_trip_member_role(_trip_id UUID, _user_id UUID)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
    SELECT role FROM public.trip_members
    WHERE trip_id = _trip_id AND user_id = _user_id
    LIMIT 1;
$$;

-- ============================================================
-- Recreate trips policies (using helper functions, no subqueries)
-- ============================================================

CREATE POLICY "Public trips viewable"
    ON public.trips FOR SELECT
    TO authenticated
    USING (is_public = true);

CREATE POLICY "Members can view trips"
    ON public.trips FOR SELECT
    TO authenticated
    USING (public.is_trip_member(id, auth.uid()));

CREATE POLICY "Users can create trips"
    ON public.trips FOR INSERT
    TO authenticated
    WITH CHECK (created_by = auth.uid());

CREATE POLICY "Editors can update trips"
    ON public.trips FOR UPDATE
    TO authenticated
    USING (public.get_trip_member_role(id, auth.uid()) IN ('owner', 'editor'));

CREATE POLICY "Owner can delete trips"
    ON public.trips FOR DELETE
    TO authenticated
    USING (public.get_trip_member_role(id, auth.uid()) = 'owner');

-- ============================================================
-- Recreate trip_members policies (using helper functions)
-- ============================================================

CREATE POLICY "Members can view members"
    ON public.trip_members FOR SELECT
    TO authenticated
    USING (public.is_trip_member(trip_id, auth.uid()));

CREATE POLICY "Editors can add members"
    ON public.trip_members FOR INSERT
    TO authenticated
    WITH CHECK (
        public.get_trip_member_role(trip_id, auth.uid()) IN ('owner', 'editor')
        OR invited_by = auth.uid()
    );

CREATE POLICY "Owner can update roles"
    ON public.trip_members FOR UPDATE
    TO authenticated
    USING (public.get_trip_member_role(trip_id, auth.uid()) = 'owner');

CREATE POLICY "Owner or self can remove"
    ON public.trip_members FOR DELETE
    TO authenticated
    USING (
        user_id = auth.uid()
        OR public.get_trip_member_role(trip_id, auth.uid()) = 'owner'
    );
