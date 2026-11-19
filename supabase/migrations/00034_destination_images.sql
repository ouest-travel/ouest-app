-- Stock destination covers (Unsplash) for trips without a user-uploaded image.
--
-- The `destination-image` Edge Function searches Unsplash once per unique
-- destination, caches the pick here, and writes it onto the trip. Caching
-- keeps us well inside Unsplash's rate limit and means every trip to
-- "Lisbon" shares one request, not one each.

-- ============================================================
-- 1. destination_images: server-side cache, service role only
-- ============================================================
CREATE TABLE IF NOT EXISTS public.destination_images (
    query text PRIMARY KEY,              -- normalised destination (lowercased, trimmed)
    image_url text,                      -- NULL = Unsplash had no match; retried after 7 days
    photographer text,
    photographer_url text,
    photo_url text,
    download_location text,              -- Unsplash endpoint to ping when the photo is used
    fetched_at timestamptz NOT NULL DEFAULT now()
);

-- RLS on with no policies: only the Edge Function's service-role client
-- can read or write. The app never touches this table directly.
ALTER TABLE public.destination_images ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 2. trips: attribution for stock covers
-- ============================================================
-- Both NULL for user-uploaded covers. Non-NULL marks the cover as stock,
-- which is what lets us safely replace it when the destination changes
-- (we never overwrite a photo the user chose themselves).
ALTER TABLE public.trips
    ADD COLUMN IF NOT EXISTS cover_attribution text,
    ADD COLUMN IF NOT EXISTS cover_attribution_url text;
