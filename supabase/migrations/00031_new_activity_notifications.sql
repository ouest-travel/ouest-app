-- "New activity added to the itinerary" notifications.
--
-- Fires when someone other than you adds activities to a trip you're a member
-- of. Uses a STATEMENT-level trigger with a transition table so that AI bulk
-- inserts (e.g. 12 activities in one INSERT statement) produce ONE summary
-- notification per recipient instead of spamming twelve.
--
-- Body adapts to count:
--   1 activity        → "Tim added Sagrada Familia"
--   1 activity (food) → "Tim added a new restaurant: La Boqueria"
--   N activities      → "Tim added 12 activities to Summer in Paris"
--
-- Title rotates from a playful pool (matches the tone introduced in 00030).

-- ─────────────────────────────────────────────────────────────────────
-- 1. Add the preference column so users can opt out
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE public.notification_preferences
    ADD COLUMN IF NOT EXISTS new_activities boolean NOT NULL DEFAULT true;

-- ─────────────────────────────────────────────────────────────────────
-- 2. Trigger function — statement-level with transition table
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_new_activity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    _row_count    int;
    _trip_id      uuid;
    _trip_title   text;
    _author       uuid;
    _author_name  text;
    _sample_title text;
    _sample_cat   text;
    _member       RECORD;
    _title        text;
    _body         text;
BEGIN
    -- 1. Total new activities in this statement (could be 1 or many).
    SELECT count(*) INTO _row_count FROM new_activities;
    IF _row_count = 0 THEN
        RETURN NULL;
    END IF;

    -- 2. Pull the trip id (all new rows share a trip via their day_id).
    SELECT d.trip_id, t.title
      INTO _trip_id, _trip_title
      FROM new_activities a
      JOIN public.itinerary_days d ON d.id = a.day_id
      JOIN public.trips t          ON t.id = d.trip_id
      LIMIT 1;

    IF _trip_id IS NULL THEN
        RETURN NULL;
    END IF;

    -- 3. Pull the creator (assume all new rows in the same statement share
    --    one creator, which is the case for both manual adds and the AI
    --    bulk-insert path in the Edge Function).
    SELECT created_by INTO _author
      FROM new_activities
      WHERE created_by IS NOT NULL
      LIMIT 1;

    -- If no creator (system / anonymous insert), bail — we have no name
    -- to put in the body and no one obvious to exclude from the broadcast.
    IF _author IS NULL THEN
        RETURN NULL;
    END IF;

    _author_name := COALESCE(public.get_profile_name(_author), 'Someone');

    -- 4. For single-row inserts, sample title + category so we can write
    --    a specific body. For bulk inserts, we just say "N activities".
    IF _row_count = 1 THEN
        SELECT title, category
          INTO _sample_title, _sample_cat
          FROM new_activities
          LIMIT 1;
    END IF;

    -- 5. Compose body based on count + category.
    IF _row_count = 1 AND _sample_cat = 'food' THEN
        _body := _author_name || ' added a new spot: ' || _sample_title;
    ELSIF _row_count = 1 THEN
        _body := _author_name || ' added ' || _sample_title;
    ELSE
        _body := _author_name || ' added ' || _row_count
              || ' activities to ' || COALESCE(_trip_title, 'your trip');
    END IF;

    -- 6. Broadcast to every other trip member who hasn't opted out.
    FOR _member IN
        SELECT user_id
          FROM public.trip_members
         WHERE trip_id = _trip_id
           AND user_id <> _author
    LOOP
        IF NOT public.should_notify(_member.user_id, 'new_activities') THEN
            CONTINUE;
        END IF;

        -- Pick a fresh title per recipient so the same broadcast doesn't
        -- read identically across the group.
        IF _row_count = 1 AND _sample_cat = 'food' THEN
            _title := public.pick_random_text(ARRAY[
                'New restaurant added to the trip 🍜',
                'New spot on the menu 🍷',
                'A new bite for the trip 🍴',
                'Crew dropped a food find 🍝'
            ]);
        ELSIF _row_count = 1 THEN
            _title := public.pick_random_text(ARRAY[
                'New activity suggestion dropped 👀',
                'Somebody just found a hidden gem 💎',
                'Your crew added new plans ✈️',
                'Trip itinerary got an upgrade 🌍'
            ]);
        ELSE
            _title := public.pick_random_text(ARRAY[
                'The itinerary is finally coming together 🙌',
                'Your friends are building the itinerary right now 👀',
                'Trip planning chaos becoming organized 🌍',
                'Your crew just made big moves ✨'
            ]);
        END IF;

        INSERT INTO public.notifications (user_id, type, title, body, data)
        VALUES (
            _member.user_id,
            'new_activity',
            _title,
            _body,
            jsonb_build_object('trip_id', _trip_id)
        );
    END LOOP;

    RETURN NULL;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 3. Attach the trigger
-- ─────────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_notify_new_activity ON public.itinerary_activities;

CREATE TRIGGER trg_notify_new_activity
    AFTER INSERT ON public.itinerary_activities
    REFERENCING NEW TABLE AS new_activities
    FOR EACH STATEMENT
    EXECUTE FUNCTION public.notify_new_activity();

NOTIFY pgrst, 'reload schema';
