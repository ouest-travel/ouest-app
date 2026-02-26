-- Phase 5: Community Feed
-- Tables: follows, trip_likes, trip_comments, saved_trips
-- Also adds travel_interests column to profiles

-- ============================================================
-- Add travel_interests to profiles
-- ============================================================

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'travel_interests'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN travel_interests text[] DEFAULT '{}';
    END IF;
END $$;

-- ============================================================
-- Table: follows
-- ============================================================

CREATE TABLE IF NOT EXISTS public.follows (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_id  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    following_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT unique_follow UNIQUE (follower_id, following_id),
    CONSTRAINT no_self_follow CHECK (follower_id != following_id)
);

CREATE INDEX IF NOT EXISTS idx_follows_follower ON public.follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following ON public.follows(following_id);

ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Anyone can view follows' AND tablename = 'follows') THEN
        CREATE POLICY "Anyone can view follows"
            ON public.follows FOR SELECT TO authenticated
            USING (true);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can follow others' AND tablename = 'follows') THEN
        CREATE POLICY "Users can follow others"
            ON public.follows FOR INSERT TO authenticated
            WITH CHECK (follower_id = auth.uid());
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can unfollow' AND tablename = 'follows') THEN
        CREATE POLICY "Users can unfollow"
            ON public.follows FOR DELETE TO authenticated
            USING (follower_id = auth.uid());
    END IF;
END $$;

-- ============================================================
-- Table: trip_likes
-- ============================================================

CREATE TABLE IF NOT EXISTS public.trip_likes (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id    uuid NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    user_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT unique_trip_like UNIQUE (trip_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_trip_likes_trip ON public.trip_likes(trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_likes_user ON public.trip_likes(user_id);

ALTER TABLE public.trip_likes ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Anyone can view likes' AND tablename = 'trip_likes') THEN
        CREATE POLICY "Anyone can view likes"
            ON public.trip_likes FOR SELECT TO authenticated
            USING (true);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can like trips' AND tablename = 'trip_likes') THEN
        CREATE POLICY "Users can like trips"
            ON public.trip_likes FOR INSERT TO authenticated
            WITH CHECK (user_id = auth.uid());
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can unlike trips' AND tablename = 'trip_likes') THEN
        CREATE POLICY "Users can unlike trips"
            ON public.trip_likes FOR DELETE TO authenticated
            USING (user_id = auth.uid());
    END IF;
END $$;

-- ============================================================
-- Table: trip_comments
-- ============================================================

CREATE TABLE IF NOT EXISTS public.trip_comments (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id    uuid NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    user_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content    text NOT NULL CHECK (char_length(content) >= 1 AND char_length(content) <= 1000),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_trip_comments_trip ON public.trip_comments(trip_id);

-- updated_at trigger
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'set_updated_at_trip_comments'
    ) THEN
        CREATE TRIGGER set_updated_at_trip_comments
            BEFORE UPDATE ON public.trip_comments
            FOR EACH ROW
            EXECUTE FUNCTION public.set_updated_at();
    END IF;
END $$;

ALTER TABLE public.trip_comments ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Anyone can view comments on public trips' AND tablename = 'trip_comments') THEN
        CREATE POLICY "Anyone can view comments on public trips"
            ON public.trip_comments FOR SELECT TO authenticated
            USING (trip_id IN (SELECT id FROM public.trips WHERE is_public = true));
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Members can view comments on their trips' AND tablename = 'trip_comments') THEN
        CREATE POLICY "Members can view comments on their trips"
            ON public.trip_comments FOR SELECT TO authenticated
            USING (public.is_trip_member(trip_id, auth.uid()));
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Authenticated users can comment' AND tablename = 'trip_comments') THEN
        CREATE POLICY "Authenticated users can comment"
            ON public.trip_comments FOR INSERT TO authenticated
            WITH CHECK (user_id = auth.uid());
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can update own comments' AND tablename = 'trip_comments') THEN
        CREATE POLICY "Users can update own comments"
            ON public.trip_comments FOR UPDATE TO authenticated
            USING (user_id = auth.uid());
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can delete own comments' AND tablename = 'trip_comments') THEN
        CREATE POLICY "Users can delete own comments"
            ON public.trip_comments FOR DELETE TO authenticated
            USING (user_id = auth.uid());
    END IF;
END $$;

-- ============================================================
-- Table: saved_trips (bookmarks)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.saved_trips (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    trip_id    uuid NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT unique_saved_trip UNIQUE (user_id, trip_id)
);

CREATE INDEX IF NOT EXISTS idx_saved_trips_user ON public.saved_trips(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_trips_trip ON public.saved_trips(trip_id);

ALTER TABLE public.saved_trips ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view own bookmarks' AND tablename = 'saved_trips') THEN
        CREATE POLICY "Users can view own bookmarks"
            ON public.saved_trips FOR SELECT TO authenticated
            USING (user_id = auth.uid());
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can save trips' AND tablename = 'saved_trips') THEN
        CREATE POLICY "Users can save trips"
            ON public.saved_trips FOR INSERT TO authenticated
            WITH CHECK (user_id = auth.uid());
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can unsave trips' AND tablename = 'saved_trips') THEN
        CREATE POLICY "Users can unsave trips"
            ON public.saved_trips FOR DELETE TO authenticated
            USING (user_id = auth.uid());
    END IF;
END $$;

-- ============================================================
-- Aggregate helper functions (SECURITY DEFINER)
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_trip_like_count(_trip_id UUID)
RETURNS INT
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
    SELECT COUNT(*)::INT FROM public.trip_likes WHERE trip_id = _trip_id;
$$;

CREATE OR REPLACE FUNCTION public.get_trip_comment_count(_trip_id UUID)
RETURNS INT
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
    SELECT COUNT(*)::INT FROM public.trip_comments WHERE trip_id = _trip_id;
$$;
