-- Trip Photo Gallery
-- Shared photo gallery for trip members to upload and browse trip photos.

-- ============================================================
-- 1. trip_photos table
-- ============================================================
CREATE TABLE IF NOT EXISTS public.trip_photos (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id      uuid NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    uploaded_by  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    image_url    text NOT NULL,
    caption      text CHECK (caption IS NULL OR char_length(caption) <= 500),
    created_at   timestamptz NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_trip_photos_trip ON public.trip_photos(trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_photos_created ON public.trip_photos(created_at DESC);

-- ============================================================
-- 2. RLS policies
-- ============================================================
ALTER TABLE public.trip_photos ENABLE ROW LEVEL SECURITY;

-- Drop policies if they exist (idempotent re-apply)
DROP POLICY IF EXISTS "Trip members can view gallery photos" ON public.trip_photos;
DROP POLICY IF EXISTS "Trip members can upload gallery photos" ON public.trip_photos;
DROP POLICY IF EXISTS "Uploaders and owners can delete gallery photos" ON public.trip_photos;

-- Read: trip members + public trip viewers
CREATE POLICY "Trip members can view gallery photos"
    ON public.trip_photos FOR SELECT TO authenticated
    USING (public.is_trip_member(trip_id, auth.uid()) OR public.is_public_trip(trip_id));

-- Insert: any trip member can upload (owner, editor, viewer), must be own upload
CREATE POLICY "Trip members can upload gallery photos"
    ON public.trip_photos FOR INSERT TO authenticated
    WITH CHECK (
        public.is_trip_member(trip_id, auth.uid())
        AND uploaded_by = auth.uid()
    );

-- Delete: photo uploader or trip owner
CREATE POLICY "Uploaders and owners can delete gallery photos"
    ON public.trip_photos FOR DELETE TO authenticated
    USING (
        uploaded_by = auth.uid()
        OR public.get_trip_member_role(trip_id, auth.uid()) = 'owner'
    );

-- ============================================================
-- 3. Storage bucket for gallery photos
-- ============================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('trip-gallery', 'trip-gallery', true, 5242880,
        ARRAY['image/jpeg','image/png','image/webp','image/heic'])
ON CONFLICT (id) DO NOTHING;

-- Storage RLS (drop first for idempotency)
DROP POLICY IF EXISTS "Anyone can view gallery photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload gallery photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their gallery photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their gallery photos" ON storage.objects;

CREATE POLICY "Anyone can view gallery photos"
    ON storage.objects FOR SELECT TO public
    USING (bucket_id = 'trip-gallery');

CREATE POLICY "Authenticated users can upload gallery photos"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'trip-gallery');

CREATE POLICY "Users can update their gallery photos"
    ON storage.objects FOR UPDATE TO authenticated
    USING (bucket_id = 'trip-gallery');

CREATE POLICY "Users can delete their gallery photos"
    ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'trip-gallery');

-- Force PostgREST to pick up the new table
NOTIFY pgrst, 'reload schema';
