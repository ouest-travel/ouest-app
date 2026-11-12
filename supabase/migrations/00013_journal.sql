-- Phase 8: Travel Journal
-- Journal entries tied to trips with photos, location, and mood.

-- ============================================================
-- 1. journal_entries table
-- ============================================================
CREATE TABLE IF NOT EXISTS public.journal_entries (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id         uuid NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    entry_date      date NOT NULL DEFAULT CURRENT_DATE,
    title           text NOT NULL CHECK (char_length(title) >= 1 AND char_length(title) <= 200),
    content         text CHECK (char_length(content) <= 5000),
    image_url       text,
    location_name   text CHECK (char_length(location_name) <= 300),
    latitude        float8,
    longitude       float8,
    mood            text CHECK (mood IS NULL OR mood IN (
        'happy','excited','relaxed','nostalgic','adventurous','grateful','tired','reflective'
    )),
    created_by      uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

-- Indexes (IF NOT EXISTS for idempotency)
CREATE INDEX IF NOT EXISTS idx_journal_entries_trip ON public.journal_entries(trip_id);
CREATE INDEX IF NOT EXISTS idx_journal_entries_date ON public.journal_entries(entry_date DESC);

-- ============================================================
-- 2. RLS policies
-- ============================================================
ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY;

-- Drop policies if they exist (idempotent re-apply)
DROP POLICY IF EXISTS "Trip members can view journal entries" ON public.journal_entries;
DROP POLICY IF EXISTS "Editors can create journal entries" ON public.journal_entries;
DROP POLICY IF EXISTS "Authors can update their entries" ON public.journal_entries;
DROP POLICY IF EXISTS "Authors and owners can delete entries" ON public.journal_entries;

-- Read: trip members + public trip viewers
CREATE POLICY "Trip members can view journal entries"
    ON public.journal_entries FOR SELECT TO authenticated
    USING (public.is_trip_member(trip_id, auth.uid()) OR public.is_public_trip(trip_id));

-- Insert: editors/owners only, must be own entry
CREATE POLICY "Editors can create journal entries"
    ON public.journal_entries FOR INSERT TO authenticated
    WITH CHECK (
        public.get_trip_member_role(trip_id, auth.uid()) IN ('owner', 'editor')
        AND created_by = auth.uid()
    );

-- Update: only the author
CREATE POLICY "Authors can update their entries"
    ON public.journal_entries FOR UPDATE TO authenticated
    USING (created_by = auth.uid());

-- Delete: author or trip owner
CREATE POLICY "Authors and owners can delete entries"
    ON public.journal_entries FOR DELETE TO authenticated
    USING (
        created_by = auth.uid()
        OR public.get_trip_member_role(trip_id, auth.uid()) = 'owner'
    );

-- Updated_at trigger (drop first for idempotency)
DROP TRIGGER IF EXISTS set_journal_entries_updated_at ON public.journal_entries;
CREATE TRIGGER set_journal_entries_updated_at
    BEFORE UPDATE ON public.journal_entries
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- 3. Storage bucket for journal photos
-- ============================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('trip-journal', 'trip-journal', true, 5242880,
        ARRAY['image/jpeg','image/png','image/webp','image/heic'])
ON CONFLICT (id) DO NOTHING;

-- Storage RLS (drop first for idempotency)
DROP POLICY IF EXISTS "Anyone can view journal photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload journal photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their journal photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their journal photos" ON storage.objects;

CREATE POLICY "Anyone can view journal photos"
    ON storage.objects FOR SELECT TO public
    USING (bucket_id = 'trip-journal');

CREATE POLICY "Authenticated users can upload journal photos"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'trip-journal');

CREATE POLICY "Users can update their journal photos"
    ON storage.objects FOR UPDATE TO authenticated
    USING (bucket_id = 'trip-journal');

CREATE POLICY "Users can delete their journal photos"
    ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'trip-journal');

-- Force PostgREST to pick up the new table
NOTIFY pgrst, 'reload schema';
