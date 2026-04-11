-- Phase 13: Profile Stickers / Achievement Badges
-- Collectible tokens users unlock through activity, displayed on profile banner.

-- ============================================================
-- 1. user_stickers table
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_stickers (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    sticker_id  text NOT NULL,
    unlocked_at timestamptz NOT NULL DEFAULT now(),
    equipped    boolean NOT NULL DEFAULT false,
    CONSTRAINT unique_user_sticker UNIQUE (user_id, sticker_id)
);

-- Partial index for fast "show banner stickers" queries
CREATE INDEX idx_user_stickers_equipped
    ON public.user_stickers(user_id)
    WHERE equipped = true;

ALTER TABLE public.user_stickers ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 2. RLS Policies
-- ============================================================

-- Anyone authenticated can see equipped stickers (for public profiles)
-- Users can also see all their own stickers (including unequipped)
CREATE POLICY "Users can view equipped stickers or own stickers"
    ON public.user_stickers FOR SELECT TO authenticated
    USING (equipped = true OR user_id = auth.uid());

-- Users can update equipped flag on their own stickers only
CREATE POLICY "Users can equip their own stickers"
    ON public.user_stickers FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Only service_role / DB functions can INSERT or DELETE
CREATE POLICY "Service can manage stickers"
    ON public.user_stickers FOR ALL TO service_role
    USING (true)
    WITH CHECK (true);

-- ============================================================
-- 3. Max 4 equipped stickers trigger
-- ============================================================
CREATE OR REPLACE FUNCTION public.enforce_max_equipped()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    _count INTEGER;
BEGIN
    IF NEW.equipped = true THEN
        SELECT COUNT(*) INTO _count
        FROM public.user_stickers
        WHERE user_id = NEW.user_id
          AND equipped = true
          AND id != NEW.id;

        IF _count >= 4 THEN
            RAISE EXCEPTION 'Maximum 4 equipped stickers allowed';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enforce_max_equipped
    BEFORE INSERT OR UPDATE ON public.user_stickers
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_max_equipped();

-- ============================================================
-- 4. check_and_grant_stickers() — evaluates all criteria
-- ============================================================
CREATE OR REPLACE FUNCTION public.check_and_grant_stickers(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    _granted integer := 0;
    _trip_count integer;
    _photo_count integer;
    _follower_count integer;
    _journal_count integer;
    _poll_count integer;
    _invite_count integer;
    _distinct_destinations integer;
    _max_trip_expense numeric;
    _created_at timestamptz;
BEGIN
    -- Gather counts
    SELECT COUNT(*) INTO _trip_count
    FROM public.trips WHERE created_by = p_user_id;

    SELECT COUNT(*) INTO _photo_count
    FROM public.trip_photos WHERE uploaded_by = p_user_id;

    SELECT COUNT(*) INTO _follower_count
    FROM public.follows WHERE following_id = p_user_id;

    SELECT COUNT(*) INTO _journal_count
    FROM public.journal_entries WHERE created_by = p_user_id;

    SELECT COUNT(*) INTO _poll_count
    FROM public.polls WHERE created_by = p_user_id;

    SELECT COUNT(*) INTO _invite_count
    FROM public.trip_members WHERE invited_by = p_user_id AND user_id != p_user_id;

    SELECT COUNT(DISTINCT destination) INTO _distinct_destinations
    FROM public.trips WHERE created_by = p_user_id;

    SELECT COALESCE(MAX(trip_total), 0) INTO _max_trip_expense
    FROM (
        SELECT e.trip_id, SUM(e.amount) AS trip_total
        FROM public.expenses e
        JOIN public.trips t ON t.id = e.trip_id
        WHERE t.created_by = p_user_id
        GROUP BY e.trip_id
    ) sub;

    SELECT p.created_at INTO _created_at
    FROM public.profiles p WHERE p.id = p_user_id;

    -- first_trip: published 1+ trips
    IF _trip_count >= 1 THEN
        INSERT INTO public.user_stickers (user_id, sticker_id)
        VALUES (p_user_id, 'first_trip')
        ON CONFLICT (user_id, sticker_id) DO NOTHING;
        IF FOUND THEN _granted := _granted + 1; END IF;
    END IF;

    -- streak: created 3+ trips
    IF _trip_count >= 3 THEN
        INSERT INTO public.user_stickers (user_id, sticker_id)
        VALUES (p_user_id, 'streak')
        ON CONFLICT (user_id, sticker_id) DO NOTHING;
        IF FOUND THEN _granted := _granted + 1; END IF;
    END IF;

    -- globe_trotter: 5+ distinct destinations
    IF _distinct_destinations >= 5 THEN
        INSERT INTO public.user_stickers (user_id, sticker_id)
        VALUES (p_user_id, 'globe_trotter')
        ON CONFLICT (user_id, sticker_id) DO NOTHING;
        IF FOUND THEN _granted := _granted + 1; END IF;
    END IF;

    -- jet_setter: 10+ distinct destinations
    IF _distinct_destinations >= 10 THEN
        INSERT INTO public.user_stickers (user_id, sticker_id)
        VALUES (p_user_id, 'jet_setter')
        ON CONFLICT (user_id, sticker_id) DO NOTHING;
        IF FOUND THEN _granted := _granted + 1; END IF;
    END IF;

    -- shutterbug: 10+ photos
    IF _photo_count >= 10 THEN
        INSERT INTO public.user_stickers (user_id, sticker_id)
        VALUES (p_user_id, 'shutterbug')
        ON CONFLICT (user_id, sticker_id) DO NOTHING;
        IF FOUND THEN _granted := _granted + 1; END IF;
    END IF;

    -- social_butterfly: 20+ followers
    IF _follower_count >= 20 THEN
        INSERT INTO public.user_stickers (user_id, sticker_id)
        VALUES (p_user_id, 'social_butterfly')
        ON CONFLICT (user_id, sticker_id) DO NOTHING;
        IF FOUND THEN _granted := _granted + 1; END IF;
    END IF;

    -- storyteller: 5+ journal entries
    IF _journal_count >= 5 THEN
        INSERT INTO public.user_stickers (user_id, sticker_id)
        VALUES (p_user_id, 'storyteller')
        ON CONFLICT (user_id, sticker_id) DO NOTHING;
        IF FOUND THEN _granted := _granted + 1; END IF;
    END IF;

    -- decision_maker: 10+ polls
    IF _poll_count >= 10 THEN
        INSERT INTO public.user_stickers (user_id, sticker_id)
        VALUES (p_user_id, 'decision_maker')
        ON CONFLICT (user_id, sticker_id) DO NOTHING;
        IF FOUND THEN _granted := _granted + 1; END IF;
    END IF;

    -- crew_chief: invited 10+ unique members
    IF _invite_count >= 10 THEN
        INSERT INTO public.user_stickers (user_id, sticker_id)
        VALUES (p_user_id, 'crew_chief')
        ON CONFLICT (user_id, sticker_id) DO NOTHING;
        IF FOUND THEN _granted := _granted + 1; END IF;
    END IF;

    -- luxury_explorer: trip with $5,000+ expenses
    IF _max_trip_expense >= 5000 THEN
        INSERT INTO public.user_stickers (user_id, sticker_id)
        VALUES (p_user_id, 'luxury_explorer')
        ON CONFLICT (user_id, sticker_id) DO NOTHING;
        IF FOUND THEN _granted := _granted + 1; END IF;
    END IF;

    -- og: account created before 2025-06-01 (early tester cutoff)
    IF _created_at < '2025-06-01T00:00:00Z'::timestamptz THEN
        INSERT INTO public.user_stickers (user_id, sticker_id)
        VALUES (p_user_id, 'og')
        ON CONFLICT (user_id, sticker_id) DO NOTHING;
        IF FOUND THEN _granted := _granted + 1; END IF;
    END IF;

    -- dev: manually granted only (no auto-check)

    RETURN _granted;
END;
$$;

-- Force PostgREST to pick up the new function
NOTIFY pgrst, 'reload schema';
