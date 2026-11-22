-- "Trip updated" notifications.
--
-- When a member changes a trip's name, destination, dates, description,
-- budget, status or cover photo, every other member gets an alert (and the
-- push that the notifications INSERT trigger sends).
--
-- Compatibility: rows use type 'new_activity' with data.kind = 'trip_updated'.
-- App builds up to 19 decode the whole notifications list strictly, so a new
-- type string would make their Activity screen fail to load. 'new_activity'
-- already opens the trip, which is the right destination; newer builds read
-- data.kind and show it as "Trip Updated".
--
-- Skipped on purpose:
--   * updates with no signed-in user (service role / Edge Functions, e.g. the
--     destination-image stock cover), since there's no one to credit;
--   * is_public, country_codes, cover attribution and updated_at changes.

-- ─────────────────────────────────────────────────────────────────────
-- 1. Preference column so users can opt out
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE public.notification_preferences
    ADD COLUMN IF NOT EXISTS trip_updates boolean NOT NULL DEFAULT true;

-- ─────────────────────────────────────────────────────────────────────
-- 2. Trigger function
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_trip_updated()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    _editor       uuid := auth.uid();
    _editor_name  text;
    _changes      text[] := ARRAY[]::text[];
    _old          jsonb := to_jsonb(OLD);
    _new          jsonb := to_jsonb(NEW);
    _body         text;
    _member       RECORD;
BEGIN
    IF _editor IS NULL THEN
        RETURN NULL;
    END IF;

    -- What changed, in the order people care about. jsonb comparison keeps
    -- this working whichever optional columns (budget, currency) exist.
    IF _new->'title' IS DISTINCT FROM _old->'title' THEN
        _changes := array_append(_changes, 'name');
    END IF;
    IF _new->'destination' IS DISTINCT FROM _old->'destination' THEN
        _changes := array_append(_changes, 'destination');
    END IF;
    IF _new->'start_date' IS DISTINCT FROM _old->'start_date'
       OR _new->'end_date' IS DISTINCT FROM _old->'end_date' THEN
        _changes := array_append(_changes, 'dates');
    END IF;
    IF _new->'budget' IS DISTINCT FROM _old->'budget'
       OR _new->'currency' IS DISTINCT FROM _old->'currency' THEN
        _changes := array_append(_changes, 'budget');
    END IF;
    IF _new->'status' IS DISTINCT FROM _old->'status' THEN
        _changes := array_append(_changes, 'status');
    END IF;
    IF _new->'description' IS DISTINCT FROM _old->'description' THEN
        _changes := array_append(_changes, 'description');
    END IF;
    IF _new->'cover_image_url' IS DISTINCT FROM _old->'cover_image_url' THEN
        _changes := array_append(_changes, 'cover photo');
    END IF;

    IF cardinality(_changes) = 0 THEN
        RETURN NULL;
    END IF;

    _editor_name := COALESCE(public.get_profile_name(_editor), 'Someone');

    -- Specific copy for the common single changes, a list otherwise.
    IF cardinality(_changes) = 1 AND _changes[1] = 'name' THEN
        _body := _editor_name || ' renamed the trip to ' || NEW.title;
    ELSIF cardinality(_changes) = 1 AND _changes[1] = 'destination' THEN
        _body := _editor_name || ' changed the destination to ' || NEW.destination;
    ELSIF cardinality(_changes) = 1 AND _changes[1] = 'dates' THEN
        IF NEW.start_date IS NULL OR NEW.end_date IS NULL THEN
            _body := _editor_name || ' changed the dates of ' || NEW.title;
        ELSE
            _body := _editor_name || ' moved ' || NEW.title || ' to '
                  || to_char(NEW.start_date, 'Mon FMDD') || ' – '
                  || to_char(NEW.end_date, 'Mon FMDD');
        END IF;
    ELSIF cardinality(_changes) = 1 AND _changes[1] = 'status' THEN
        _body := _editor_name || ' marked ' || NEW.title || ' as ' || NEW.status;
    ELSIF cardinality(_changes) = 1 THEN
        _body := _editor_name || ' updated the ' || _changes[1] || ' of ' || NEW.title;
    ELSIF cardinality(_changes) = 2 THEN
        _body := _editor_name || ' updated the ' || _changes[1] || ' and '
              || _changes[2] || ' of ' || NEW.title;
    ELSE
        _body := _editor_name || ' updated the '
              || array_to_string(_changes[1:cardinality(_changes) - 1], ', ')
              || ' and ' || _changes[cardinality(_changes)] || ' of ' || NEW.title;
    END IF;

    FOR _member IN
        SELECT user_id
          FROM public.trip_members
         WHERE trip_id = NEW.id
           AND user_id <> _editor
    LOOP
        IF NOT public.should_notify(_member.user_id, 'trip_updates') THEN
            CONTINUE;
        END IF;

        INSERT INTO public.notifications (user_id, type, title, body, data)
        VALUES (
            _member.user_id,
            'new_activity',
            public.pick_random_text(ARRAY[
                'Heads up: trip plans changed ✏️',
                'Your trip just got an update 🗺️',
                'Plans shifted, take a look 👀',
                'Something changed on your trip ✨'
            ]),
            _body,
            jsonb_build_object(
                'trip_id', NEW.id,
                'kind', 'trip_updated',
                'changes', array_to_string(_changes, ',')
            )
        );
    END LOOP;

    RETURN NULL;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 3. Attach the trigger
-- ─────────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_notify_trip_updated ON public.trips;

CREATE TRIGGER trg_notify_trip_updated
    AFTER UPDATE ON public.trips
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_trip_updated();

NOTIFY pgrst, 'reload schema';
