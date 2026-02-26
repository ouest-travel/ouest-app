-- 00002_trips.sql
-- Trip management: trips table + trip_members table
-- Idempotent: safe to re-run

-- ============================================================
-- HELPER: updated_at trigger function (if not created in 00001)
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- ============================================================
-- TRIPS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.trips (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    created_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title text NOT NULL CHECK (char_length(title) >= 1 AND char_length(title) <= 200),
    destination text NOT NULL CHECK (char_length(destination) >= 1 AND char_length(destination) <= 200),
    description text DEFAULT '' CHECK (char_length(description) <= 2000),
    cover_image_url text,
    start_date date,
    end_date date,
    status text NOT NULL DEFAULT 'planning' CHECK (status IN ('planning', 'active', 'completed')),
    is_public boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT valid_dates CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

-- Updated_at trigger
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'set_trips_updated_at'
    ) THEN
        CREATE TRIGGER set_trips_updated_at
            BEFORE UPDATE ON public.trips
            FOR EACH ROW
            EXECUTE FUNCTION public.set_updated_at();
    END IF;
END $$;

-- ============================================================
-- TRIP_MEMBERS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.trip_members (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id uuid NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role text NOT NULL DEFAULT 'viewer' CHECK (role IN ('owner', 'editor', 'viewer')),
    invited_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    joined_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT unique_trip_member UNIQUE (trip_id, user_id)
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_trips_created_by ON public.trips(created_by);
CREATE INDEX IF NOT EXISTS idx_trips_status ON public.trips(status);
CREATE INDEX IF NOT EXISTS idx_trips_is_public ON public.trips(is_public) WHERE is_public = true;
CREATE INDEX IF NOT EXISTS idx_trip_members_trip_id ON public.trip_members(trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_members_user_id ON public.trip_members(user_id);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_members ENABLE ROW LEVEL SECURITY;

-- TRIPS POLICIES

-- Anyone authenticated can see public trips
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Public trips are viewable by all authenticated'
        AND tablename = 'trips'
    ) THEN
        CREATE POLICY "Public trips are viewable by all authenticated"
            ON public.trips FOR SELECT
            TO authenticated
            USING (is_public = true);
    END IF;
END $$;

-- Trip members can see their trips (including private ones)
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Trip members can view their trips'
        AND tablename = 'trips'
    ) THEN
        CREATE POLICY "Trip members can view their trips"
            ON public.trips FOR SELECT
            TO authenticated
            USING (
                id IN (
                    SELECT trip_id FROM public.trip_members
                    WHERE user_id = auth.uid()
                )
            );
    END IF;
END $$;

-- Any authenticated user can create a trip
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Authenticated users can create trips'
        AND tablename = 'trips'
    ) THEN
        CREATE POLICY "Authenticated users can create trips"
            ON public.trips FOR INSERT
            TO authenticated
            WITH CHECK (created_by = auth.uid());
    END IF;
END $$;

-- Only owner/editor can update a trip
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Owner and editors can update trips'
        AND tablename = 'trips'
    ) THEN
        CREATE POLICY "Owner and editors can update trips"
            ON public.trips FOR UPDATE
            TO authenticated
            USING (
                id IN (
                    SELECT trip_id FROM public.trip_members
                    WHERE user_id = auth.uid() AND role IN ('owner', 'editor')
                )
            );
    END IF;
END $$;

-- Only owner can delete a trip
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Only owner can delete trips'
        AND tablename = 'trips'
    ) THEN
        CREATE POLICY "Only owner can delete trips"
            ON public.trips FOR DELETE
            TO authenticated
            USING (
                id IN (
                    SELECT trip_id FROM public.trip_members
                    WHERE user_id = auth.uid() AND role = 'owner'
                )
            );
    END IF;
END $$;

-- TRIP_MEMBERS POLICIES

-- Members can see other members of their trips
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Members can view trip members'
        AND tablename = 'trip_members'
    ) THEN
        CREATE POLICY "Members can view trip members"
            ON public.trip_members FOR SELECT
            TO authenticated
            USING (
                trip_id IN (
                    SELECT trip_id FROM public.trip_members
                    WHERE user_id = auth.uid()
                )
            );
    END IF;
END $$;

-- Owner/editor can add members
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Owner and editors can add members'
        AND tablename = 'trip_members'
    ) THEN
        CREATE POLICY "Owner and editors can add members"
            ON public.trip_members FOR INSERT
            TO authenticated
            WITH CHECK (
                trip_id IN (
                    SELECT trip_id FROM public.trip_members
                    WHERE user_id = auth.uid() AND role IN ('owner', 'editor')
                )
                OR invited_by = auth.uid()
            );
    END IF;
END $$;

-- Owner can update member roles
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Owner can update member roles'
        AND tablename = 'trip_members'
    ) THEN
        CREATE POLICY "Owner can update member roles"
            ON public.trip_members FOR UPDATE
            TO authenticated
            USING (
                trip_id IN (
                    SELECT trip_id FROM public.trip_members
                    WHERE user_id = auth.uid() AND role = 'owner'
                )
            );
    END IF;
END $$;

-- Owner can remove members, members can remove themselves
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Owner can remove members or self-remove'
        AND tablename = 'trip_members'
    ) THEN
        CREATE POLICY "Owner can remove members or self-remove"
            ON public.trip_members FOR DELETE
            TO authenticated
            USING (
                user_id = auth.uid()
                OR trip_id IN (
                    SELECT trip_id FROM public.trip_members
                    WHERE user_id = auth.uid() AND role = 'owner'
                )
            );
    END IF;
END $$;

-- ============================================================
-- FUNCTION: Auto-add creator as owner when trip is created
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_trip()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.trip_members (trip_id, user_id, role, invited_by)
    VALUES (NEW.id, NEW.created_by, 'owner', NEW.created_by)
    ON CONFLICT (trip_id, user_id) DO NOTHING;
    RETURN NEW;
END;
$$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'on_trip_created'
    ) THEN
        CREATE TRIGGER on_trip_created
            AFTER INSERT ON public.trips
            FOR EACH ROW
            EXECUTE FUNCTION public.handle_new_trip();
    END IF;
END $$;

-- ============================================================
-- STORAGE: Trip cover images bucket
-- ============================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'trip-covers',
    'trip-covers',
    true,
    5242880, -- 5MB
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for trip-covers bucket
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Authenticated users can upload trip covers'
        AND tablename = 'objects' AND schemaname = 'storage'
    ) THEN
        CREATE POLICY "Authenticated users can upload trip covers"
            ON storage.objects FOR INSERT
            TO authenticated
            WITH CHECK (bucket_id = 'trip-covers');
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Anyone can view trip covers'
        AND tablename = 'objects' AND schemaname = 'storage'
    ) THEN
        CREATE POLICY "Anyone can view trip covers"
            ON storage.objects FOR SELECT
            TO public
            USING (bucket_id = 'trip-covers');
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Users can update their own trip covers'
        AND tablename = 'objects' AND schemaname = 'storage'
    ) THEN
        CREATE POLICY "Users can update their own trip covers"
            ON storage.objects FOR UPDATE
            TO authenticated
            USING (bucket_id = 'trip-covers' AND (storage.foldername(name))[1] = auth.uid()::text);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Users can delete their own trip covers'
        AND tablename = 'objects' AND schemaname = 'storage'
    ) THEN
        CREATE POLICY "Users can delete their own trip covers"
            ON storage.objects FOR DELETE
            TO authenticated
            USING (bucket_id = 'trip-covers' AND (storage.foldername(name))[1] = auth.uid()::text);
    END IF;
END $$;
