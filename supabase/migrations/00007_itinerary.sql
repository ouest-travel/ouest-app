-- Phase 3: Itinerary Builder
-- Tables: itinerary_days, itinerary_activities
-- RLS uses existing is_trip_member() and get_trip_member_role() from 00004

-- ============================================================
-- Table: itinerary_days
-- ============================================================

CREATE TABLE IF NOT EXISTS public.itinerary_days (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id     uuid NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    day_number  int NOT NULL CHECK (day_number >= 1),
    date        date,
    title       text DEFAULT '' CHECK (char_length(title) <= 200),
    notes       text DEFAULT '' CHECK (char_length(notes) <= 2000),
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT unique_trip_day UNIQUE (trip_id, day_number)
);

CREATE INDEX IF NOT EXISTS idx_itinerary_days_trip_id ON public.itinerary_days(trip_id);

-- updated_at trigger
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'set_updated_at_itinerary_days'
    ) THEN
        CREATE TRIGGER set_updated_at_itinerary_days
            BEFORE UPDATE ON public.itinerary_days
            FOR EACH ROW
            EXECUTE FUNCTION public.set_updated_at();
    END IF;
END $$;

-- ============================================================
-- Table: itinerary_activities
-- ============================================================

CREATE TABLE IF NOT EXISTS public.itinerary_activities (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    day_id          uuid NOT NULL REFERENCES public.itinerary_days(id) ON DELETE CASCADE,
    title           text NOT NULL CHECK (char_length(title) >= 1 AND char_length(title) <= 200),
    description     text DEFAULT '' CHECK (char_length(description) <= 2000),
    location_name   text DEFAULT '' CHECK (char_length(location_name) <= 300),
    latitude        float8,
    longitude       float8,
    start_time      time,
    end_time        time,
    category        text NOT NULL DEFAULT 'other'
                        CHECK (category IN ('food','transport','activity','accommodation','other')),
    cost_estimate   numeric(12,2),
    currency        text DEFAULT 'USD' CHECK (char_length(currency) <= 3),
    sort_order      int NOT NULL DEFAULT 0,
    created_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_itinerary_activities_day_id ON public.itinerary_activities(day_id);
CREATE INDEX IF NOT EXISTS idx_itinerary_activities_sort ON public.itinerary_activities(day_id, sort_order);

-- updated_at trigger
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'set_updated_at_itinerary_activities'
    ) THEN
        CREATE TRIGGER set_updated_at_itinerary_activities
            BEFORE UPDATE ON public.itinerary_activities
            FOR EACH ROW
            EXECUTE FUNCTION public.set_updated_at();
    END IF;
END $$;

-- ============================================================
-- Helper: resolve trip_id from a day_id (for activity-level RLS)
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_trip_id_for_day(_day_id UUID)
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
    SELECT trip_id FROM public.itinerary_days WHERE id = _day_id LIMIT 1;
$$;

-- ============================================================
-- RLS: itinerary_days
-- ============================================================

ALTER TABLE public.itinerary_days ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public trip days are viewable' AND tablename = 'itinerary_days') THEN
        CREATE POLICY "Public trip days are viewable"
            ON public.itinerary_days FOR SELECT TO authenticated
            USING (trip_id IN (SELECT id FROM public.trips WHERE is_public = true));
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Members can view itinerary days' AND tablename = 'itinerary_days') THEN
        CREATE POLICY "Members can view itinerary days"
            ON public.itinerary_days FOR SELECT TO authenticated
            USING (public.is_trip_member(trip_id, auth.uid()));
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Editors can insert itinerary days' AND tablename = 'itinerary_days') THEN
        CREATE POLICY "Editors can insert itinerary days"
            ON public.itinerary_days FOR INSERT TO authenticated
            WITH CHECK (public.get_trip_member_role(trip_id, auth.uid()) IN ('owner', 'editor'));
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Editors can update itinerary days' AND tablename = 'itinerary_days') THEN
        CREATE POLICY "Editors can update itinerary days"
            ON public.itinerary_days FOR UPDATE TO authenticated
            USING (public.get_trip_member_role(trip_id, auth.uid()) IN ('owner', 'editor'));
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Editors can delete itinerary days' AND tablename = 'itinerary_days') THEN
        CREATE POLICY "Editors can delete itinerary days"
            ON public.itinerary_days FOR DELETE TO authenticated
            USING (public.get_trip_member_role(trip_id, auth.uid()) IN ('owner', 'editor'));
    END IF;
END $$;

-- ============================================================
-- RLS: itinerary_activities
-- ============================================================

ALTER TABLE public.itinerary_activities ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public trip activities are viewable' AND tablename = 'itinerary_activities') THEN
        CREATE POLICY "Public trip activities are viewable"
            ON public.itinerary_activities FOR SELECT TO authenticated
            USING (public.get_trip_id_for_day(day_id) IN (SELECT id FROM public.trips WHERE is_public = true));
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Members can view activities' AND tablename = 'itinerary_activities') THEN
        CREATE POLICY "Members can view activities"
            ON public.itinerary_activities FOR SELECT TO authenticated
            USING (public.is_trip_member(public.get_trip_id_for_day(day_id), auth.uid()));
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Editors can insert activities' AND tablename = 'itinerary_activities') THEN
        CREATE POLICY "Editors can insert activities"
            ON public.itinerary_activities FOR INSERT TO authenticated
            WITH CHECK (public.get_trip_member_role(public.get_trip_id_for_day(day_id), auth.uid()) IN ('owner', 'editor'));
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Editors can update activities' AND tablename = 'itinerary_activities') THEN
        CREATE POLICY "Editors can update activities"
            ON public.itinerary_activities FOR UPDATE TO authenticated
            USING (public.get_trip_member_role(public.get_trip_id_for_day(day_id), auth.uid()) IN ('owner', 'editor'));
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Editors can delete activities' AND tablename = 'itinerary_activities') THEN
        CREATE POLICY "Editors can delete activities"
            ON public.itinerary_activities FOR DELETE TO authenticated
            USING (public.get_trip_member_role(public.get_trip_id_for_day(day_id), auth.uid()) IN ('owner', 'editor'));
    END IF;
END $$;
