-- AI Usage Log
-- Tracks every call to AI Edge Functions for rate limiting and cost analytics.
-- Rows are inserted at the start of each call (success=false) and updated to
-- success=true if the underlying AI call succeeds.

CREATE TABLE IF NOT EXISTS public.ai_usage_log (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    function    text NOT NULL,                  -- e.g. 'ai-itinerary'
    input_type  text NOT NULL,                  -- 'generate' | 'import'
    success     boolean NOT NULL DEFAULT false,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- Fast lookup for the "calls in the last 24h for this user" query.
CREATE INDEX IF NOT EXISTS idx_ai_usage_log_user_recent
    ON public.ai_usage_log (user_id, created_at DESC);

-- ============================================================
-- RLS
-- ============================================================
ALTER TABLE public.ai_usage_log ENABLE ROW LEVEL SECURITY;

-- Drop policies first so the migration is idempotent on re-apply.
DROP POLICY IF EXISTS "Users view own AI usage" ON public.ai_usage_log;
DROP POLICY IF EXISTS "Service writes AI usage" ON public.ai_usage_log;

-- Authenticated users can read their own usage rows (foundation for a future
-- "you have X generations left today" UI).
CREATE POLICY "Users view own AI usage"
    ON public.ai_usage_log FOR SELECT TO authenticated
    USING (user_id = auth.uid());

-- Only the service role (used by the Edge Function) can write.
CREATE POLICY "Service writes AI usage"
    ON public.ai_usage_log FOR ALL TO service_role
    USING (true)
    WITH CHECK (true);

-- Force PostgREST to pick up the new table
NOTIFY pgrst, 'reload schema';
