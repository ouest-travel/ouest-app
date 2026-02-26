-- 00004_fix_rls_recursion.sql
-- Fix infinite recursion in RLS policies for trips & trip_members
--
-- Problem: Self-referencing SELECT policies on trip_members cause infinite
-- recursion when any query touches trip_members (e.g. creating a trip triggers
-- the handle_new_trip trigger which inserts into trip_members).
--
-- Solution: Create SECURITY DEFINER helper functions that bypass RLS to check
-- membership, then rewrite all policies to use these functions instead of
-- subqueries against trip_members.

-- ============================================================
-- STEP 1: Create SECURITY DEFINER helper functions
-- These run as the function owner (postgres), bypassing RLS.
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
-- STEP 2: Drop ALL existing policies on both tables
-- ============================================================

-- trips policies
DROP POLICY IF EXISTS "Public trips are viewable by all authenticated" ON public.trips;
DROP POLICY IF EXISTS "Trip members can view their trips" ON public.trips;
DROP POLICY IF EXISTS "Authenticated users can create trips" ON public.trips;
DROP POLICY IF EXISTS "Owner and editors can update trips" ON public.trips;
DROP POLICY IF EXISTS "Only owner can delete trips" ON public.trips;

-- trip_members policies
DROP POLICY IF EXISTS "Members can view trip members" ON public.trip_members;
DROP POLICY IF EXISTS "Owner and editors can add members" ON public.trip_members;
DROP POLICY IF EXISTS "Owner can update member roles" ON public.trip_members;
DROP POLICY IF EXISTS "Owner can remove members or self-remove" ON public.trip_members;

-- ============================================================
-- STEP 3: Recreate trips policies using helper functions
-- ============================================================

-- Anyone authenticated can see public trips (no change needed — doesn't reference trip_members)
CREATE POLICY "Public trips are viewable by all authenticated"
    ON public.trips FOR SELECT
    TO authenticated
    USING (is_public = true);

-- Trip members can see their trips (including private ones)
CREATE POLICY "Trip members can view their trips"
    ON public.trips FOR SELECT
    TO authenticated
    USING (public.is_trip_member(id, auth.uid()));

-- Any authenticated user can create a trip (no change needed)
CREATE POLICY "Authenticated users can create trips"
    ON public.trips FOR INSERT
    TO authenticated
    WITH CHECK (created_by = auth.uid());

-- Only owner/editor can update a trip
CREATE POLICY "Owner and editors can update trips"
    ON public.trips FOR UPDATE
    TO authenticated
    USING (public.get_trip_member_role(id, auth.uid()) IN ('owner', 'editor'));

-- Only owner can delete a trip
CREATE POLICY "Only owner can delete trips"
    ON public.trips FOR DELETE
    TO authenticated
    USING (public.get_trip_member_role(id, auth.uid()) = 'owner');

-- ============================================================
-- STEP 4: Recreate trip_members policies using helper functions
-- ============================================================

-- Members can see other members of their trips
CREATE POLICY "Members can view trip members"
    ON public.trip_members FOR SELECT
    TO authenticated
    USING (public.is_trip_member(trip_id, auth.uid()));

-- Owner/editor can add members, OR the inviter can add (for the trigger case)
CREATE POLICY "Owner and editors can add members"
    ON public.trip_members FOR INSERT
    TO authenticated
    WITH CHECK (
        public.get_trip_member_role(trip_id, auth.uid()) IN ('owner', 'editor')
        OR invited_by = auth.uid()
    );

-- Owner can update member roles
CREATE POLICY "Owner can update member roles"
    ON public.trip_members FOR UPDATE
    TO authenticated
    USING (public.get_trip_member_role(trip_id, auth.uid()) = 'owner');

-- Owner can remove members, members can remove themselves
CREATE POLICY "Owner can remove members or self-remove"
    ON public.trip_members FOR DELETE
    TO authenticated
    USING (
        user_id = auth.uid()
        OR public.get_trip_member_role(trip_id, auth.uid()) = 'owner'
    );
