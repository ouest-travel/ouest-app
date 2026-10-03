-- Auto-equip retroactive fix + update grant function to backfill unequipped stickers.

-- 1. Backfill: auto-equip existing unequipped stickers (up to 4 per user)
WITH ranked AS (
    SELECT id, user_id, equipped,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY unlocked_at ASC) AS rn,
           SUM(CASE WHEN equipped THEN 1 ELSE 0 END) OVER (PARTITION BY user_id) AS eq_count
    FROM public.user_stickers
)
UPDATE public.user_stickers us
SET equipped = true
FROM ranked r
WHERE us.id = r.id
  AND r.equipped = false
  AND r.rn <= 4;

-- 2. Replace the grant function with auto-equip-backfill at the end
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
    _equipped_count integer;
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

    -- How many are currently equipped? (for auto-equip logic)
    SELECT COUNT(*) INTO _equipped_count
    FROM public.user_stickers
    WHERE user_id = p_user_id AND equipped = true;

    -- first_trip: published 1+ trips
    IF _trip_count >= 1 THEN
        INSERT INTO public.user_stickers (user_id, sticker_id, equipped)
        VALUES (p_user_id, 'first_trip', _equipped_count < 4)
        ON CONFLICT (user_id, sticker_id) DO NOTHING;
        IF FOUND THEN
            _granted := _granted + 1;
            IF _equipped_count < 4 THEN _equipped_count := _equipped_count + 1; END IF;
        END IF;
    END IF;

    -- streak: created 3+ trips
    IF _trip_count >= 3 THEN
        INSERT INTO public.user_stickers (user_id, sticker_id, equipped)
        VALUES (p_user_id, 'streak', _equipped_count < 4)
        ON CONFLICT (user_id, sticker_id) DO NOTHING;
        IF FOUND THEN
            _granted := _granted + 1;
            IF _equipped_count < 4 THEN _equipped_count := _equipped_count + 1; END IF;
        END IF;
    END IF;

    -- globe_trotter: 5+ distinct destinations
    IF _distinct_destinations >= 5 THEN
        INSERT INTO public.user_stickers (user_id, sticker_id, equipped)
        VALUES (p_user_id, 'globe_trotter', _equipped_count < 4)
        ON CONFLICT (user_id, sticker_id) DO NOTHING;
        IF FOUND THEN
            _granted := _granted + 1;
            IF _equipped_count < 4 THEN _equipped_count := _equipped_count + 1; END IF;
        END IF;
    END IF;

    -- jet_setter: 10+ distinct destinations
    IF _distinct_destinations >= 10 THEN
        INSERT INTO public.user_stickers (user_id, sticker_id, equipped)
        VALUES (p_user_id, 'jet_setter', _equipped_count < 4)
        ON CONFLICT (user_id, sticker_id) DO NOTHING;
        IF FOUND THEN
            _granted := _granted + 1;
            IF _equipped_count < 4 THEN _equipped_count := _equipped_count + 1; END IF;
        END IF;
    END IF;

    -- shutterbug: 10+ photos
    IF _photo_count >= 10 THEN
        INSERT INTO public.user_stickers (user_id, sticker_id, equipped)
        VALUES (p_user_id, 'shutterbug', _equipped_count < 4)
        ON CONFLICT (user_id, sticker_id) DO NOTHING;
        IF FOUND THEN
            _granted := _granted + 1;
            IF _equipped_count < 4 THEN _equipped_count := _equipped_count + 1; END IF;
        END IF;
    END IF;

    -- social_butterfly: 20+ followers
    IF _follower_count >= 20 THEN
        INSERT INTO public.user_stickers (user_id, sticker_id, equipped)
        VALUES (p_user_id, 'social_butterfly', _equipped_count < 4)
        ON CONFLICT (user_id, sticker_id) DO NOTHING;
        IF FOUND THEN
            _granted := _granted + 1;
            IF _equipped_count < 4 THEN _equipped_count := _equipped_count + 1; END IF;
        END IF;
    END IF;

    -- storyteller: 5+ journal entries
    IF _journal_count >= 5 THEN
        INSERT INTO public.user_stickers (user_id, sticker_id, equipped)
        VALUES (p_user_id, 'storyteller', _equipped_count < 4)
        ON CONFLICT (user_id, sticker_id) DO NOTHING;
        IF FOUND THEN
            _granted := _granted + 1;
            IF _equipped_count < 4 THEN _equipped_count := _equipped_count + 1; END IF;
        END IF;
    END IF;

    -- decision_maker: 10+ polls
    IF _poll_count >= 10 THEN
        INSERT INTO public.user_stickers (user_id, sticker_id, equipped)
        VALUES (p_user_id, 'decision_maker', _equipped_count < 4)
        ON CONFLICT (user_id, sticker_id) DO NOTHING;
        IF FOUND THEN
            _granted := _granted + 1;
            IF _equipped_count < 4 THEN _equipped_count := _equipped_count + 1; END IF;
        END IF;
    END IF;

    -- crew_chief: invited 10+ unique members
    IF _invite_count >= 10 THEN
        INSERT INTO public.user_stickers (user_id, sticker_id, equipped)
        VALUES (p_user_id, 'crew_chief', _equipped_count < 4)
        ON CONFLICT (user_id, sticker_id) DO NOTHING;
        IF FOUND THEN
            _granted := _granted + 1;
            IF _equipped_count < 4 THEN _equipped_count := _equipped_count + 1; END IF;
        END IF;
    END IF;

    -- luxury_explorer: trip with $5,000+ expenses
    IF _max_trip_expense >= 5000 THEN
        INSERT INTO public.user_stickers (user_id, sticker_id, equipped)
        VALUES (p_user_id, 'luxury_explorer', _equipped_count < 4)
        ON CONFLICT (user_id, sticker_id) DO NOTHING;
        IF FOUND THEN
            _granted := _granted + 1;
            IF _equipped_count < 4 THEN _equipped_count := _equipped_count + 1; END IF;
        END IF;
    END IF;

    -- og: account created before 2026-07-01 (early adopter cutoff)
    IF _created_at < '2026-07-01T00:00:00Z'::timestamptz THEN
        INSERT INTO public.user_stickers (user_id, sticker_id, equipped)
        VALUES (p_user_id, 'og', _equipped_count < 4)
        ON CONFLICT (user_id, sticker_id) DO NOTHING;
        IF FOUND THEN
            _granted := _granted + 1;
            IF _equipped_count < 4 THEN _equipped_count := _equipped_count + 1; END IF;
        END IF;
    END IF;

    -- dev: manually granted only (no auto-check)

    -- Auto-equip any unequipped stickers if we still have room
    -- (handles retroactive grants from before auto-equip was added)
    SELECT COUNT(*) INTO _equipped_count
    FROM public.user_stickers
    WHERE user_id = p_user_id AND equipped = true;

    IF _equipped_count < 4 THEN
        UPDATE public.user_stickers
        SET equipped = true
        WHERE user_id = p_user_id
          AND equipped = false
          AND id IN (
              SELECT id FROM public.user_stickers
              WHERE user_id = p_user_id AND equipped = false
              ORDER BY unlocked_at ASC
              LIMIT (4 - _equipped_count)
          );
    END IF;

    RETURN _granted;
END;
$$;

-- Ensure authenticated users can call the function
GRANT EXECUTE ON FUNCTION public.check_and_grant_stickers(uuid) TO authenticated;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
