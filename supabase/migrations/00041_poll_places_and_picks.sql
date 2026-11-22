-- Poll kinds, place options and the group pick.
--
-- Polls exist to get a group to a decision about where to go. Until now an
-- option was a line of text and a closed poll was the end of the road:
-- someone still had to retype the winner into the itinerary.
--
-- 1. polls.kind: text (as before), yes_no or place.
-- 2. An option can carry a real place, so the winner can become an
--    itinerary activity without anyone typing it again.
-- 3. After voting closes an owner or editor breaks a tie, adds the pick to
--    a day, or dismisses it. These go through functions: an editor who did
--    not create the poll cannot update it directly, and adding the pick
--    writes the activity and the poll together or not at all.
-- 4. Members hear when voting closes and what the group picked.

-- ============================================================
-- 1. Kind and place fields
-- ============================================================
ALTER TABLE public.polls
    ADD COLUMN IF NOT EXISTS kind text NOT NULL DEFAULT 'text';

ALTER TABLE public.polls DROP CONSTRAINT IF EXISTS polls_kind_check;
ALTER TABLE public.polls
    ADD CONSTRAINT polls_kind_check CHECK (kind IN ('text', 'yes_no', 'place'));

ALTER TABLE public.poll_options
    ADD COLUMN IF NOT EXISTS location_name text,
    ADD COLUMN IF NOT EXISTS latitude      float8,
    ADD COLUMN IF NOT EXISTS longitude     float8,
    ADD COLUMN IF NOT EXISTS category      text;

ALTER TABLE public.poll_options DROP CONSTRAINT IF EXISTS poll_options_location_name_length;
ALTER TABLE public.poll_options
    ADD CONSTRAINT poll_options_location_name_length
    CHECK (location_name IS NULL OR char_length(location_name) <= 300);

-- Half a coordinate cannot be put on a map.
ALTER TABLE public.poll_options DROP CONSTRAINT IF EXISTS poll_options_coordinate_pair;
ALTER TABLE public.poll_options
    ADD CONSTRAINT poll_options_coordinate_pair
    CHECK ((latitude IS NULL) = (longitude IS NULL));

-- The same categories an itinerary activity accepts, so the pick always fits.
ALTER TABLE public.poll_options DROP CONSTRAINT IF EXISTS poll_options_category_check;
ALTER TABLE public.poll_options
    ADD CONSTRAINT poll_options_category_check
    CHECK (category IS NULL
        OR category IN ('food', 'transport', 'activity', 'accommodation', 'other'));

-- ============================================================
-- 2. What happened to the pick
-- ============================================================
-- picked_option_id is only set to break a tie. A clear winner needs no row
-- of its own: it is whichever option has the most votes.
--
-- Both references clear themselves if the option or the activity is deleted,
-- so removing the activity from the itinerary puts the pick back on offer.
ALTER TABLE public.polls
    ADD COLUMN IF NOT EXISTS picked_option_id  uuid REFERENCES public.poll_options(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS added_activity_id uuid REFERENCES public.itinerary_activities(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS pick_dismissed_at timestamptz;

-- ============================================================
-- 3. Helpers
-- ============================================================
-- The options with the most votes. Empty when nobody voted: a poll with no
-- votes has no pick, and nobody gets to invent one.
CREATE OR REPLACE FUNCTION public.poll_leading_options(_poll_id uuid)
RETURNS uuid[]
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
    WITH counts AS (
        SELECT o.id, o.sort_order, count(v.id) AS votes
        FROM public.poll_options o
        LEFT JOIN public.poll_votes v ON v.option_id = o.id
        WHERE o.poll_id = _poll_id
        GROUP BY o.id, o.sort_order
    )
    SELECT coalesce(array_agg(id ORDER BY sort_order), '{}')
    FROM counts
    WHERE votes > 0 AND votes = (SELECT max(votes) FROM counts);
$$;

-- The group's pick: the clear winner, or the option chosen to break a tie.
-- NULL while a tie is unbroken or nobody voted.
CREATE OR REPLACE FUNCTION public.poll_pick(_poll_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
DECLARE
    _leaders uuid[] := public.poll_leading_options(_poll_id);
    _picked  uuid;
BEGIN
    IF cardinality(_leaders) = 1 THEN
        RETURN _leaders[1];
    END IF;
    SELECT picked_option_id INTO _picked FROM public.polls WHERE id = _poll_id;
    IF _picked = ANY (_leaders) THEN
        RETURN _picked;
    END IF;
    RETURN NULL;
END;
$$;

-- Shared gate for the three actions below: the caller organises this trip
-- and voting is over. Returns the poll's trip.
CREATE OR REPLACE FUNCTION public.require_poll_organiser(_poll_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
DECLARE
    _trip_id uuid;
BEGIN
    SELECT trip_id INTO _trip_id FROM public.polls WHERE id = _poll_id;
    IF _trip_id IS NULL THEN
        RAISE EXCEPTION 'Poll not found' USING ERRCODE = 'P0002';
    END IF;
    IF coalesce(public.get_trip_member_role(_trip_id, auth.uid()), '') NOT IN ('owner', 'editor') THEN
        RAISE EXCEPTION 'Only an owner or editor can do this' USING ERRCODE = '42501';
    END IF;
    IF public.is_poll_open(_poll_id) THEN
        RAISE EXCEPTION 'Voting is still open' USING ERRCODE = 'P0001';
    END IF;
    RETURN _trip_id;
END;
$$;

-- ============================================================
-- 4. Break a tie, add the pick to a day, dismiss it
-- ============================================================
CREATE OR REPLACE FUNCTION public.break_poll_tie(_poll_id uuid, _option_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    _leaders uuid[];
BEGIN
    PERFORM public.require_poll_organiser(_poll_id);
    _leaders := public.poll_leading_options(_poll_id);

    -- Only between the options that tied. The group's votes still decide
    -- the shortlist; the organiser only settles what they left level.
    IF cardinality(_leaders) < 2 OR NOT (_option_id = ANY (_leaders)) THEN
        RAISE EXCEPTION 'That option is not part of a tie' USING ERRCODE = 'P0001';
    END IF;

    UPDATE public.polls
    SET picked_option_id = _option_id, pick_dismissed_at = NULL
    WHERE id = _poll_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.add_poll_pick_to_day(_poll_id uuid, _day_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    _trip_id     uuid := public.require_poll_organiser(_poll_id);
    _pick        uuid := public.poll_pick(_poll_id);
    _option      public.poll_options%ROWTYPE;
    _kind        text;
    _activity_id uuid;
BEGIN
    IF _pick IS NULL THEN
        RAISE EXCEPTION 'This poll has no pick yet' USING ERRCODE = 'P0001';
    END IF;
    IF public.get_trip_id_for_day(_day_id) IS DISTINCT FROM _trip_id THEN
        RAISE EXCEPTION 'That day is not part of this trip' USING ERRCODE = 'P0001';
    END IF;
    -- One pick, one activity. Adding twice would put it in the plan twice.
    IF (SELECT added_activity_id FROM public.polls WHERE id = _poll_id FOR UPDATE) IS NOT NULL THEN
        RAISE EXCEPTION 'The pick is already in the itinerary' USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO _option FROM public.poll_options WHERE id = _pick;
    SELECT kind INTO _kind FROM public.polls WHERE id = _poll_id;

    -- In a yes or no poll the options are the words Yes and No. Only an
    -- answer that carries a place gives the itinerary something to hold,
    -- and that place's name is the activity, not the word "Yes".
    IF _kind = 'yes_no' AND _option.latitude IS NULL THEN
        RAISE EXCEPTION 'This answer has nothing to add to the itinerary' USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO public.itinerary_activities
        (day_id, title, location_name, latitude, longitude, category, sort_order, created_by)
    VALUES (
        _day_id,
        CASE WHEN _kind = 'yes_no'
             THEN coalesce(nullif(_option.location_name, ''), _option.title)
             ELSE _option.title END,
        coalesce(_option.location_name, ''),
        _option.latitude,
        _option.longitude,
        coalesce(_option.category, 'other'),
        -- Last in the day.
        (SELECT coalesce(max(sort_order), -1) + 1
         FROM public.itinerary_activities WHERE day_id = _day_id),
        auth.uid()
    )
    RETURNING id INTO _activity_id;

    UPDATE public.polls
    SET added_activity_id = _activity_id, pick_dismissed_at = NULL
    WHERE id = _poll_id;

    RETURN _activity_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.dismiss_poll_pick(_poll_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    PERFORM public.require_poll_organiser(_poll_id);
    UPDATE public.polls SET pick_dismissed_at = now() WHERE id = _poll_id;
END;
$$;

-- The helpers are internal. The three actions are for signed-in users only,
-- and each checks the caller's role itself.
REVOKE EXECUTE ON FUNCTION public.poll_leading_options(uuid)   FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.poll_pick(uuid)              FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.require_poll_organiser(uuid) FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.break_poll_tie(uuid, uuid)       FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_poll_pick_to_day(uuid, uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.dismiss_poll_pick(uuid)          FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.break_poll_tie(uuid, uuid)       TO authenticated;
GRANT  EXECUTE ON FUNCTION public.add_poll_pick_to_day(uuid, uuid) TO authenticated;
GRANT  EXECUTE ON FUNCTION public.dismiss_poll_pick(uuid)          TO authenticated;

-- ============================================================
-- 5. Tell the group when voting closes
-- ============================================================
-- Fires for a deadline and for a poll closed by hand, because both end in
-- the same status change. Sent as `new_poll` with `kind: poll_closed`, the
-- way the reminder is, so older app builds still open the right trip.
CREATE OR REPLACE FUNCTION public.notify_poll_closed()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    _leaders uuid[] := public.poll_leading_options(NEW.id);
    _body    text;
    _member  RECORD;
BEGIN
    IF cardinality(_leaders) = 1 THEN
        SELECT 'The group picked ' || title || ' for: ' || NEW.title
        INTO _body FROM public.poll_options WHERE id = _leaders[1];
    ELSIF cardinality(_leaders) > 1 THEN
        _body := 'It''s a tie on: ' || NEW.title || '. An organiser will settle it.';
    ELSE
        _body := 'Voting closed with no votes on: ' || NEW.title;
    END IF;

    FOR _member IN
        SELECT user_id FROM public.trip_members
        WHERE trip_id = NEW.trip_id
          -- Whoever closed it by hand already knows. Nobody is signed in
          -- when the deadline job closes it, so then everyone hears.
          AND user_id IS DISTINCT FROM auth.uid()
    LOOP
        IF public.should_notify(_member.user_id, 'new_polls') THEN
            INSERT INTO public.notifications (user_id, type, title, body, data)
            VALUES (
                _member.user_id,
                'new_poll',
                'The votes are in 🗳️',
                _body,
                jsonb_build_object(
                    'trip_id', NEW.trip_id,
                    'poll_id', NEW.id,
                    'kind', 'poll_closed'
                )
            );
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.notify_poll_closed() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS on_poll_closed ON public.polls;
CREATE TRIGGER on_poll_closed
    AFTER UPDATE OF status ON public.polls
    FOR EACH ROW
    WHEN (OLD.status = 'open' AND NEW.status = 'closed')
    EXECUTE FUNCTION public.notify_poll_closed();

NOTIFY pgrst, 'reload schema';
