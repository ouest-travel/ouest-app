-- Moderation (report + block, App Store Guideline 1.2) and two RLS tightenings
-- found in the pre-submission audit.

-- ============================================================
-- 1. notifications: only SECURITY DEFINER triggers may insert
-- ============================================================
-- The original policy was `WITH CHECK (true)`, which let any signed-in user
-- write arbitrary rows into anyone else's inbox. Every notify_* trigger runs
-- as SECURITY DEFINER and bypasses RLS, so no client-facing policy is needed.
DROP POLICY IF EXISTS "System can insert notifications" ON public.notifications;

-- ============================================================
-- 2. storage: scope journal + gallery object writes to trip members
-- ============================================================
-- Both buckets store objects at `<trip_id>/<file_id>.jpg`. The previous
-- policies checked only `bucket_id`, so any authenticated user could upload
-- into, overwrite, or delete any trip's photos.

DROP POLICY IF EXISTS "Authenticated users can upload journal photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their journal photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their journal photos" ON storage.objects;

CREATE POLICY "Trip members can upload journal photos"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'trip-journal'
        AND public.is_trip_member(((storage.foldername(name))[1])::uuid, auth.uid())
    );

CREATE POLICY "Trip members can update journal photos"
    ON storage.objects FOR UPDATE TO authenticated
    USING (
        bucket_id = 'trip-journal'
        AND public.is_trip_member(((storage.foldername(name))[1])::uuid, auth.uid())
    );

CREATE POLICY "Trip members can delete journal photos"
    ON storage.objects FOR DELETE TO authenticated
    USING (
        bucket_id = 'trip-journal'
        AND public.is_trip_member(((storage.foldername(name))[1])::uuid, auth.uid())
    );

DROP POLICY IF EXISTS "Authenticated users can upload gallery photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their gallery photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their gallery photos" ON storage.objects;

CREATE POLICY "Trip members can upload gallery photos"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'trip-gallery'
        AND public.is_trip_member(((storage.foldername(name))[1])::uuid, auth.uid())
    );

CREATE POLICY "Trip members can update gallery photos"
    ON storage.objects FOR UPDATE TO authenticated
    USING (
        bucket_id = 'trip-gallery'
        AND public.is_trip_member(((storage.foldername(name))[1])::uuid, auth.uid())
    );

CREATE POLICY "Trip members can delete gallery photos"
    ON storage.objects FOR DELETE TO authenticated
    USING (
        bucket_id = 'trip-gallery'
        AND public.is_trip_member(((storage.foldername(name))[1])::uuid, auth.uid())
    );

-- ============================================================
-- 3. reports — user-filed reports on trips, comments and profiles
-- ============================================================
CREATE TABLE IF NOT EXISTS public.reports (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id   uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    target_type   text NOT NULL CHECK (target_type IN ('trip', 'comment', 'profile')),
    target_id     uuid NOT NULL,
    reason        text NOT NULL CHECK (char_length(reason) BETWEEN 1 AND 500),
    created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS reports_target_idx ON public.reports (target_type, target_id);

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can file reports" ON public.reports;
CREATE POLICY "Users can file reports"
    ON public.reports FOR INSERT TO authenticated
    WITH CHECK (reporter_id = auth.uid());

DROP POLICY IF EXISTS "Users can view own reports" ON public.reports;
CREATE POLICY "Users can view own reports"
    ON public.reports FOR SELECT TO authenticated
    USING (reporter_id = auth.uid());

-- ============================================================
-- 4. blocked_users — one-directional block list
-- ============================================================
-- Filtering is done client-side for now (feed, comments, people search read
-- this list and drop matching authors). Server-side enforcement can follow
-- once the table is in place.
CREATE TABLE IF NOT EXISTS public.blocked_users (
    blocker_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    blocked_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (blocker_id, blocked_id),
    CONSTRAINT blocked_users_not_self CHECK (blocker_id <> blocked_id)
);

ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own block list" ON public.blocked_users;
CREATE POLICY "Users can view own block list"
    ON public.blocked_users FOR SELECT TO authenticated
    USING (blocker_id = auth.uid());

DROP POLICY IF EXISTS "Users can block" ON public.blocked_users;
CREATE POLICY "Users can block"
    ON public.blocked_users FOR INSERT TO authenticated
    WITH CHECK (blocker_id = auth.uid());

DROP POLICY IF EXISTS "Users can unblock" ON public.blocked_users;
CREATE POLICY "Users can unblock"
    ON public.blocked_users FOR DELETE TO authenticated
    USING (blocker_id = auth.uid());

NOTIFY pgrst, 'reload schema';
