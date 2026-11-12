-- Phase 9: Collaborative Trip Polls
-- Tables: polls, poll_options, poll_votes
-- Lets trip members create polls and vote on group decisions.

-- ============================================================
-- 1. polls table (created first so helper function can reference it)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.polls (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id         uuid NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    title           text NOT NULL CHECK (char_length(title) >= 1 AND char_length(title) <= 200),
    description     text CHECK (char_length(description) <= 2000),
    status          text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
    allow_multiple  boolean NOT NULL DEFAULT false,
    created_by      uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    closed_at       timestamptz
);

CREATE INDEX IF NOT EXISTS idx_polls_trip ON public.polls(trip_id);

-- RLS
ALTER TABLE public.polls ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members can view polls" ON public.polls;
DROP POLICY IF EXISTS "Editors can create polls" ON public.polls;
DROP POLICY IF EXISTS "Creator or owner can update polls" ON public.polls;
DROP POLICY IF EXISTS "Creator or owner can delete polls" ON public.polls;

CREATE POLICY "Members can view polls"
    ON public.polls FOR SELECT TO authenticated
    USING (public.is_trip_member(trip_id, auth.uid()) OR public.is_public_trip(trip_id));

CREATE POLICY "Editors can create polls"
    ON public.polls FOR INSERT TO authenticated
    WITH CHECK (
        public.get_trip_member_role(trip_id, auth.uid()) IN ('owner', 'editor')
        AND created_by = auth.uid()
    );

CREATE POLICY "Creator or owner can update polls"
    ON public.polls FOR UPDATE TO authenticated
    USING (
        created_by = auth.uid()
        OR public.get_trip_member_role(trip_id, auth.uid()) = 'owner'
    );

CREATE POLICY "Creator or owner can delete polls"
    ON public.polls FOR DELETE TO authenticated
    USING (
        created_by = auth.uid()
        OR public.get_trip_member_role(trip_id, auth.uid()) = 'owner'
    );

-- Updated_at trigger
DROP TRIGGER IF EXISTS set_polls_updated_at ON public.polls;
CREATE TRIGGER set_polls_updated_at
    BEFORE UPDATE ON public.polls
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- 2. Helper function (for nested RLS lookups on child tables)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_trip_id_for_poll(_poll_id UUID)
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
    SELECT trip_id FROM public.polls WHERE id = _poll_id LIMIT 1;
$$;

-- ============================================================
-- 3. poll_options table
-- ============================================================
CREATE TABLE IF NOT EXISTS public.poll_options (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id     uuid NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
    title       text NOT NULL CHECK (char_length(title) >= 1 AND char_length(title) <= 200),
    sort_order  int NOT NULL DEFAULT 0,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_poll_options_poll ON public.poll_options(poll_id);

-- RLS
ALTER TABLE public.poll_options ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members can view poll options" ON public.poll_options;
DROP POLICY IF EXISTS "Editors can create poll options" ON public.poll_options;
DROP POLICY IF EXISTS "Editors can delete poll options" ON public.poll_options;

CREATE POLICY "Members can view poll options"
    ON public.poll_options FOR SELECT TO authenticated
    USING (
        public.is_trip_member(public.get_trip_id_for_poll(poll_id), auth.uid())
        OR public.is_public_trip(public.get_trip_id_for_poll(poll_id))
    );

CREATE POLICY "Editors can create poll options"
    ON public.poll_options FOR INSERT TO authenticated
    WITH CHECK (
        public.get_trip_member_role(public.get_trip_id_for_poll(poll_id), auth.uid()) IN ('owner', 'editor')
    );

CREATE POLICY "Editors can delete poll options"
    ON public.poll_options FOR DELETE TO authenticated
    USING (
        public.get_trip_member_role(public.get_trip_id_for_poll(poll_id), auth.uid()) IN ('owner', 'editor')
    );

-- ============================================================
-- 4. poll_votes table
-- ============================================================
CREATE TABLE IF NOT EXISTS public.poll_votes (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id     uuid NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
    option_id   uuid NOT NULL REFERENCES public.poll_options(id) ON DELETE CASCADE,
    user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT unique_poll_vote UNIQUE (poll_id, option_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_poll_votes_poll ON public.poll_votes(poll_id);
CREATE INDEX IF NOT EXISTS idx_poll_votes_option ON public.poll_votes(option_id);
CREATE INDEX IF NOT EXISTS idx_poll_votes_user ON public.poll_votes(user_id);

-- RLS
ALTER TABLE public.poll_votes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members can view poll votes" ON public.poll_votes;
DROP POLICY IF EXISTS "Members can vote" ON public.poll_votes;
DROP POLICY IF EXISTS "Users can remove their votes" ON public.poll_votes;

-- Any trip member can see votes (transparent voting)
CREATE POLICY "Members can view poll votes"
    ON public.poll_votes FOR SELECT TO authenticated
    USING (
        public.is_trip_member(public.get_trip_id_for_poll(poll_id), auth.uid())
        OR public.is_public_trip(public.get_trip_id_for_poll(poll_id))
    );

-- Any trip member can vote (including viewers — that's the point of polls)
CREATE POLICY "Members can vote"
    ON public.poll_votes FOR INSERT TO authenticated
    WITH CHECK (
        public.is_trip_member(public.get_trip_id_for_poll(poll_id), auth.uid())
        AND user_id = auth.uid()
    );

-- Users can only remove their own votes
CREATE POLICY "Users can remove their votes"
    ON public.poll_votes FOR DELETE TO authenticated
    USING (user_id = auth.uid());

-- Force PostgREST to pick up new tables
NOTIFY pgrst, 'reload schema';
