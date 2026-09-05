-- Refresh notification copy with a more playful, social tone.
--
-- Each event type now picks a random TITLE from a curated set of variants
-- (so the same alert doesn't read identically every time) while the BODY
-- keeps the factual "who did what to which trip" detail. This drives both
-- the in-app Activity feed and the APNs push (since the same row triggers
-- both via 00027_push_notifications_vault.sql).
--
-- Adding a small helper public.pick_random_text() keeps the trigger
-- functions readable.

-- ─────────────────────────────────────────────────────────────────────
-- Helper: pick a random string from a text[] array
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.pick_random_text(_options text[])
RETURNS text
LANGUAGE plpgsql
VOLATILE
AS $$
BEGIN
    IF _options IS NULL OR array_length(_options, 1) IS NULL THEN
        RETURN '';
    END IF;
    RETURN _options[1 + floor(random() * array_length(_options, 1))::int];
END;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- Trip invite — recruit / "adventures are better together"
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_trip_invite()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    _trip_title TEXT;
    _inviter_name TEXT;
    _title TEXT;
BEGIN
    IF NOT public.should_notify(NEW.user_id, 'trip_invites') THEN
        RETURN NEW;
    END IF;

    SELECT title INTO _trip_title FROM public.trips WHERE id = NEW.trip_id;
    _inviter_name := COALESCE(public.get_profile_name(NEW.invited_by), 'Someone');

    _title := public.pick_random_text(ARRAY[
        'Adventures are better together 🌍',
        'You''re being recruited ✈️',
        'New trip on the horizon 🌅',
        'The crew is forming 👀'
    ]);

    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
        NEW.user_id,
        'trip_invite',
        _title,
        _inviter_name || ' invited you to ' || COALESCE(_trip_title, 'a trip'),
        jsonb_build_object('trip_id', NEW.trip_id)
    );

    RETURN NEW;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- New expense — budget updates
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_new_expense()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    _trip_title TEXT;
    _payer_name TEXT;
    _member RECORD;
    _title TEXT;
BEGIN
    SELECT title INTO _trip_title FROM public.trips WHERE id = NEW.trip_id;
    _payer_name := public.get_profile_name(NEW.paid_by);

    FOR _member IN
        SELECT user_id FROM public.trip_members WHERE trip_id = NEW.trip_id AND user_id != NEW.paid_by
    LOOP
        IF public.should_notify(_member.user_id, 'new_expenses') THEN
            -- Re-pick per recipient so the same broadcast doesn't read
            -- identically across the whole group.
            _title := public.pick_random_text(ARRAY[
                'Budget updates just came in 💸',
                'Money moves 💰',
                'New expense logged ✍️',
                'Group budget +1 💳'
            ]);

            INSERT INTO public.notifications (user_id, type, title, body, data)
            VALUES (
                _member.user_id,
                'new_expense',
                _title,
                _payer_name || ' added ' || NEW.title,
                jsonb_build_object('trip_id', NEW.trip_id, 'expense_id', NEW.id)
            );
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- New comment — your crew is making moves
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_new_comment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    _trip_owner UUID;
    _trip_title TEXT;
    _commenter_name TEXT;
    _title TEXT;
BEGIN
    SELECT created_by, title INTO _trip_owner, _trip_title
    FROM public.trips WHERE id = NEW.trip_id;

    IF _trip_owner IS NOT NULL AND _trip_owner != NEW.user_id THEN
        IF NOT public.should_notify(_trip_owner, 'new_comments') THEN
            RETURN NEW;
        END IF;

        _commenter_name := public.get_profile_name(NEW.user_id);

        _title := public.pick_random_text(ARRAY[
            'Your crew is making moves 🌍',
            'Someone has thoughts 💭',
            'New comment dropped 👀',
            'Trip chat update 💬'
        ]);

        INSERT INTO public.notifications (user_id, type, title, body, data)
        VALUES (
            _trip_owner,
            'new_comment',
            _title,
            _commenter_name || ' commented on ' || COALESCE(_trip_title, 'your trip'),
            jsonb_build_object('trip_id', NEW.trip_id, 'comment_id', NEW.id)
        );
    END IF;

    RETURN NEW;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- Trip liked — somebody's feeling your trip
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_trip_liked()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    _trip_owner UUID;
    _trip_title TEXT;
    _liker_name TEXT;
    _title TEXT;
BEGIN
    SELECT created_by, title INTO _trip_owner, _trip_title
    FROM public.trips WHERE id = NEW.trip_id;

    IF _trip_owner IS NOT NULL AND _trip_owner != NEW.user_id THEN
        IF NOT public.should_notify(_trip_owner, 'trip_likes') THEN
            RETURN NEW;
        END IF;

        _liker_name := public.get_profile_name(NEW.user_id);

        _title := public.pick_random_text(ARRAY[
            'Someone''s feeling your trip ❤️',
            'Trip love incoming 💕',
            'You''ve got a fan 👀',
            'Inspiration delivered 🌍'
        ]);

        INSERT INTO public.notifications (user_id, type, title, body, data)
        VALUES (
            _trip_owner,
            'trip_liked',
            _title,
            _liker_name || ' liked ' || COALESCE(_trip_title, 'your trip'),
            jsonb_build_object('trip_id', NEW.trip_id)
        );
    END IF;

    RETURN NEW;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- New follower — new travel buddy
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_new_follower()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    _follower_name TEXT;
    _title TEXT;
BEGIN
    IF NOT public.should_notify(NEW.following_id, 'new_followers') THEN
        RETURN NEW;
    END IF;

    _follower_name := public.get_profile_name(NEW.follower_id);

    _title := public.pick_random_text(ARRAY[
        'New travel buddy 🌍',
        'Someone''s following your adventures ✈️',
        'You''ve got a fan 👀',
        'New explorer in your orbit 🛫'
    ]);

    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
        NEW.following_id,
        'new_follower',
        _title,
        _follower_name || ' started following you',
        jsonb_build_object('follower_id', NEW.follower_id)
    );

    RETURN NEW;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- New poll — time to vote on the next adventure
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_new_poll()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    _trip_title TEXT;
    _creator_name TEXT;
    _member RECORD;
    _title TEXT;
BEGIN
    SELECT title INTO _trip_title FROM public.trips WHERE id = NEW.trip_id;
    _creator_name := public.get_profile_name(NEW.created_by);

    FOR _member IN
        SELECT user_id FROM public.trip_members WHERE trip_id = NEW.trip_id AND user_id != NEW.created_by
    LOOP
        IF public.should_notify(_member.user_id, 'new_polls') THEN
            _title := public.pick_random_text(ARRAY[
                'Time to vote on the next adventure 🗳️',
                'Decisions, decisions 🤔',
                'New poll dropped — your vote matters 🌍',
                'The group needs your input 👀'
            ]);

            INSERT INTO public.notifications (user_id, type, title, body, data)
            VALUES (
                _member.user_id,
                'new_poll',
                _title,
                _creator_name || ' created a poll: ' || NEW.title,
                jsonb_build_object('trip_id', NEW.trip_id, 'poll_id', NEW.id)
            );
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- New journal entry — memory unlocked
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_new_journal_entry()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    _trip_title TEXT;
    _author_name TEXT;
    _member RECORD;
    _title TEXT;
BEGIN
    SELECT title INTO _trip_title FROM public.trips WHERE id = NEW.trip_id;
    _author_name := public.get_profile_name(NEW.created_by);

    FOR _member IN
        SELECT user_id FROM public.trip_members WHERE trip_id = NEW.trip_id AND user_id != NEW.created_by
    LOOP
        IF public.should_notify(_member.user_id, 'journal_entries') THEN
            _title := public.pick_random_text(ARRAY[
                'Memory unlocked 📸',
                'Trip story update 📖',
                'A new chapter for the trip ✨',
                'Your crew added new memories 🌍'
            ]);

            INSERT INTO public.notifications (user_id, type, title, body, data)
            VALUES (
                _member.user_id,
                'new_journal_entry',
                _title,
                _author_name || ' added a journal entry in ' || COALESCE(_trip_title, 'your trip'),
                jsonb_build_object('trip_id', NEW.trip_id, 'entry_id', NEW.id)
            );
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$;

NOTIFY pgrst, 'reload schema';
