-- Phase 12: Notification Enhancements
-- 1. DELETE policy so users can remove their own notifications
-- 2. should_notify() helper to check user preferences before inserting
-- 3. Updated trigger functions that respect notification preferences

-- ============================================================
-- 1. Allow users to delete their own notifications
-- ============================================================
DROP POLICY IF EXISTS "Users can delete their own notifications" ON public.notifications;

CREATE POLICY "Users can delete their own notifications"
    ON public.notifications FOR DELETE TO authenticated
    USING (user_id = auth.uid());

-- ============================================================
-- 2. Preference enforcement helper
-- ============================================================
CREATE OR REPLACE FUNCTION public.should_notify(_user_id UUID, _pref_column TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
DECLARE
    _pref BOOLEAN;
BEGIN
    EXECUTE format(
        'SELECT %I FROM public.notification_preferences WHERE user_id = $1',
        _pref_column
    ) INTO _pref USING _user_id;
    -- Default to true if no preference row exists
    RETURN COALESCE(_pref, true);
END;
$$;

-- ============================================================
-- 3. Updated trigger functions (with preference checks)
-- ============================================================

-- 3a. Trip invite notification
CREATE OR REPLACE FUNCTION public.notify_trip_invite()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    _trip_title TEXT;
    _inviter_name TEXT;
BEGIN
    IF NOT public.should_notify(NEW.user_id, 'trip_invites') THEN
        RETURN NEW;
    END IF;

    SELECT title INTO _trip_title FROM public.trips WHERE id = NEW.trip_id;
    _inviter_name := COALESCE(public.get_profile_name(NEW.invited_by), 'Someone');

    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
        NEW.user_id,
        'trip_invite',
        'Trip Invitation',
        _inviter_name || ' invited you to ' || COALESCE(_trip_title, 'a trip'),
        jsonb_build_object('trip_id', NEW.trip_id)
    );

    RETURN NEW;
END;
$$;

-- 3b. New expense notification
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
BEGIN
    SELECT title INTO _trip_title FROM public.trips WHERE id = NEW.trip_id;
    _payer_name := public.get_profile_name(NEW.paid_by);

    FOR _member IN
        SELECT user_id FROM public.trip_members WHERE trip_id = NEW.trip_id AND user_id != NEW.paid_by
    LOOP
        IF public.should_notify(_member.user_id, 'new_expenses') THEN
            INSERT INTO public.notifications (user_id, type, title, body, data)
            VALUES (
                _member.user_id,
                'new_expense',
                'New Expense',
                _payer_name || ' added ' || NEW.title,
                jsonb_build_object('trip_id', NEW.trip_id, 'expense_id', NEW.id)
            );
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$;

-- 3c. New comment notification (notify trip creator)
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
BEGIN
    SELECT created_by, title INTO _trip_owner, _trip_title
    FROM public.trips WHERE id = NEW.trip_id;

    IF _trip_owner IS NOT NULL AND _trip_owner != NEW.user_id THEN
        IF NOT public.should_notify(_trip_owner, 'new_comments') THEN
            RETURN NEW;
        END IF;

        _commenter_name := public.get_profile_name(NEW.user_id);

        INSERT INTO public.notifications (user_id, type, title, body, data)
        VALUES (
            _trip_owner,
            'new_comment',
            'New Comment',
            _commenter_name || ' commented on ' || COALESCE(_trip_title, 'your trip'),
            jsonb_build_object('trip_id', NEW.trip_id, 'comment_id', NEW.id)
        );
    END IF;

    RETURN NEW;
END;
$$;

-- 3d. Trip liked notification
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
BEGIN
    SELECT created_by, title INTO _trip_owner, _trip_title
    FROM public.trips WHERE id = NEW.trip_id;

    IF _trip_owner IS NOT NULL AND _trip_owner != NEW.user_id THEN
        IF NOT public.should_notify(_trip_owner, 'trip_likes') THEN
            RETURN NEW;
        END IF;

        _liker_name := public.get_profile_name(NEW.user_id);

        INSERT INTO public.notifications (user_id, type, title, body, data)
        VALUES (
            _trip_owner,
            'trip_liked',
            'Trip Liked',
            _liker_name || ' liked ' || COALESCE(_trip_title, 'your trip'),
            jsonb_build_object('trip_id', NEW.trip_id)
        );
    END IF;

    RETURN NEW;
END;
$$;

-- 3e. New follower notification
CREATE OR REPLACE FUNCTION public.notify_new_follower()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    _follower_name TEXT;
BEGIN
    IF NOT public.should_notify(NEW.following_id, 'new_followers') THEN
        RETURN NEW;
    END IF;

    _follower_name := public.get_profile_name(NEW.follower_id);

    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
        NEW.following_id,
        'new_follower',
        'New Follower',
        _follower_name || ' started following you',
        jsonb_build_object('follower_id', NEW.follower_id)
    );

    RETURN NEW;
END;
$$;

-- 3f. New poll notification
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
BEGIN
    SELECT title INTO _trip_title FROM public.trips WHERE id = NEW.trip_id;
    _creator_name := public.get_profile_name(NEW.created_by);

    FOR _member IN
        SELECT user_id FROM public.trip_members WHERE trip_id = NEW.trip_id AND user_id != NEW.created_by
    LOOP
        IF public.should_notify(_member.user_id, 'new_polls') THEN
            INSERT INTO public.notifications (user_id, type, title, body, data)
            VALUES (
                _member.user_id,
                'new_poll',
                'New Poll',
                _creator_name || ' created a poll: ' || NEW.title,
                jsonb_build_object('trip_id', NEW.trip_id, 'poll_id', NEW.id)
            );
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$;

-- 3g. New journal entry notification
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
BEGIN
    SELECT title INTO _trip_title FROM public.trips WHERE id = NEW.trip_id;
    _author_name := public.get_profile_name(NEW.created_by);

    FOR _member IN
        SELECT user_id FROM public.trip_members WHERE trip_id = NEW.trip_id AND user_id != NEW.created_by
    LOOP
        IF public.should_notify(_member.user_id, 'journal_entries') THEN
            INSERT INTO public.notifications (user_id, type, title, body, data)
            VALUES (
                _member.user_id,
                'new_journal_entry',
                'New Journal Entry',
                _author_name || ' added a journal entry in ' || COALESCE(_trip_title, 'your trip'),
                jsonb_build_object('trip_id', NEW.trip_id, 'entry_id', NEW.id)
            );
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$;

-- Force PostgREST to pick up changes
NOTIFY pgrst, 'reload schema';
