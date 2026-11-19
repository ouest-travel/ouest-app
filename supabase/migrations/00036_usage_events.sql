-- Usage events
-- First-party counters for the handful of product questions we cannot answer
-- from the data itself: is Explore opened, do people open trips from it, do
-- shared links bring people in, does the share prompt work. Saves, likes and
-- comments are NOT recorded here; their own tables already carry a timestamp.
--
-- Rows are written by the app (UsageService) and read only from the dashboard
-- or the service role. Nothing leaves Supabase.

CREATE TABLE IF NOT EXISTS public.usage_events (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Filled in by the database, so a client can only ever record itself.
    user_id     uuid NOT NULL DEFAULT auth.uid() REFERENCES public.profiles(id) ON DELETE CASCADE,
    name        text NOT NULL CHECK (name ~ '^[a-z_]{1,40}$'),   -- e.g. 'explore_opened'
    -- The trip the event is about, when there is one. Kept as NULL if the
    -- trip is deleted so the count survives.
    trip_id     uuid REFERENCES public.trips(id) ON DELETE SET NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- Every report is "how many of event X per day".
CREATE INDEX IF NOT EXISTS idx_usage_events_name_time
    ON public.usage_events (name, created_at DESC);

-- ============================================================
-- RLS
-- ============================================================
ALTER TABLE public.usage_events ENABLE ROW LEVEL SECURITY;

-- Drop first so the migration is idempotent on re-apply.
DROP POLICY IF EXISTS "Users record own usage" ON public.usage_events;

-- Insert only. There is deliberately no SELECT, UPDATE or DELETE policy:
-- nobody can read another person's activity through the API, or edit history.
CREATE POLICY "Users record own usage"
    ON public.usage_events FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

-- Force PostgREST to pick up the new table
NOTIFY pgrst, 'reload schema';
