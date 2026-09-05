-- Phase 10: Push Notifications
-- Tables: device_tokens, notifications, notification_preferences
-- Trigger functions: insert into notifications on key events

-- ============================================================
-- 1. device_tokens table
-- ============================================================
CREATE TABLE IF NOT EXISTS public.device_tokens (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    token       text NOT NULL,
    platform    text NOT NULL DEFAULT 'ios',
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT unique_user_token UNIQUE (user_id, token)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON public.device_tokens(user_id);

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own tokens" ON public.device_tokens;
DROP POLICY IF EXISTS "Users can insert own tokens" ON public.device_tokens;
DROP POLICY IF EXISTS "Users can update own tokens" ON public.device_tokens;
DROP POLICY IF EXISTS "Users can delete own tokens" ON public.device_tokens;

CREATE POLICY "Users can view own tokens"
    ON public.device_tokens FOR SELECT TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "Users can insert own tokens"
    ON public.device_tokens FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own tokens"
    ON public.device_tokens FOR UPDATE TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "Users can delete own tokens"
    ON public.device_tokens FOR DELETE TO authenticated
    USING (user_id = auth.uid());

-- updated_at trigger
DROP TRIGGER IF EXISTS set_device_tokens_updated_at ON public.device_tokens;
CREATE TRIGGER set_device_tokens_updated_at
    BEFORE UPDATE ON public.device_tokens
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- 2. notifications table
-- ============================================================
CREATE TABLE IF NOT EXISTS public.notifications (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    type        text NOT NULL,
    title       text NOT NULL,
    body        text NOT NULL,
    data        jsonb NOT NULL DEFAULT '{}',
    is_read     boolean NOT NULL DEFAULT false,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON public.notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON public.notifications(user_id, created_at DESC);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
DROP POLICY IF EXISTS "System can insert notifications" ON public.notifications;

CREATE POLICY "Users can view own notifications"
    ON public.notifications FOR SELECT TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "Users can update own notifications"
    ON public.notifications FOR UPDATE TO authenticated
    USING (user_id = auth.uid());

-- Allow trigger functions (SECURITY DEFINER) to insert notifications
-- Regular users cannot insert directly; only triggers can
CREATE POLICY "System can insert notifications"
    ON public.notifications FOR INSERT TO authenticated
    WITH CHECK (true);

-- ============================================================
-- 3. notification_preferences table
-- ============================================================
CREATE TABLE IF NOT EXISTS public.notification_preferences (
    user_id         uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    trip_invites    boolean NOT NULL DEFAULT true,
    new_expenses    boolean NOT NULL DEFAULT true,
    new_comments    boolean NOT NULL DEFAULT true,
    trip_likes      boolean NOT NULL DEFAULT true,
    new_followers   boolean NOT NULL DEFAULT true,
    new_polls       boolean NOT NULL DEFAULT true,
    journal_entries boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own preferences" ON public.notification_preferences;
DROP POLICY IF EXISTS "Users can insert own preferences" ON public.notification_preferences;
DROP POLICY IF EXISTS "Users can update own preferences" ON public.notification_preferences;

CREATE POLICY "Users can view own preferences"
    ON public.notification_preferences FOR SELECT TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "Users can insert own preferences"
    ON public.notification_preferences FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own preferences"
    ON public.notification_preferences FOR UPDATE TO authenticated
    USING (user_id = auth.uid());

-- updated_at trigger
DROP TRIGGER IF EXISTS set_notification_preferences_updated_at ON public.notification_preferences;
CREATE TRIGGER set_notification_preferences_updated_at
    BEFORE UPDATE ON public.notification_preferences
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- 4. Notification trigger functions
-- ============================================================

-- Helper: get profile name for notification text
CREATE OR REPLACE FUNCTION public.get_profile_name(_user_id UUID)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
    SELECT COALESCE(full_name, 'Someone') FROM public.profiles WHERE id = _user_id LIMIT 1;
$$;

-- 4a. Trip invite notification
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

DROP TRIGGER IF EXISTS trg_notify_trip_invite ON public.trip_members;
CREATE TRIGGER trg_notify_trip_invite
    AFTER INSERT ON public.trip_members
    FOR EACH ROW
    WHEN (NEW.invited_by IS NOT NULL AND NEW.user_id != NEW.invited_by)
    EXECUTE FUNCTION public.notify_trip_invite();

-- 4b. New expense notification
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
        INSERT INTO public.notifications (user_id, type, title, body, data)
        VALUES (
            _member.user_id,
            'new_expense',
            'New Expense',
            _payer_name || ' added ' || NEW.title,
            jsonb_build_object('trip_id', NEW.trip_id, 'expense_id', NEW.id)
        );
    END LOOP;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_new_expense ON public.expenses;
CREATE TRIGGER trg_notify_new_expense
    AFTER INSERT ON public.expenses
    FOR EACH ROW EXECUTE FUNCTION public.notify_new_expense();

-- 4c. New comment notification (notify trip creator)
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

    -- Only notify if commenter is not the trip creator
    IF _trip_owner IS NOT NULL AND _trip_owner != NEW.user_id THEN
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

DROP TRIGGER IF EXISTS trg_notify_new_comment ON public.trip_comments;
CREATE TRIGGER trg_notify_new_comment
    AFTER INSERT ON public.trip_comments
    FOR EACH ROW EXECUTE FUNCTION public.notify_new_comment();

-- 4d. Trip liked notification
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

    -- Only notify if liker is not the trip creator
    IF _trip_owner IS NOT NULL AND _trip_owner != NEW.user_id THEN
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

DROP TRIGGER IF EXISTS trg_notify_trip_liked ON public.trip_likes;
CREATE TRIGGER trg_notify_trip_liked
    AFTER INSERT ON public.trip_likes
    FOR EACH ROW EXECUTE FUNCTION public.notify_trip_liked();

-- 4e. New follower notification
CREATE OR REPLACE FUNCTION public.notify_new_follower()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    _follower_name TEXT;
BEGIN
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

DROP TRIGGER IF EXISTS trg_notify_new_follower ON public.follows;
CREATE TRIGGER trg_notify_new_follower
    AFTER INSERT ON public.follows
    FOR EACH ROW EXECUTE FUNCTION public.notify_new_follower();

-- 4f. New poll notification
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
        INSERT INTO public.notifications (user_id, type, title, body, data)
        VALUES (
            _member.user_id,
            'new_poll',
            'New Poll',
            _creator_name || ' created a poll: ' || NEW.title,
            jsonb_build_object('trip_id', NEW.trip_id, 'poll_id', NEW.id)
        );
    END LOOP;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_new_poll ON public.polls;
CREATE TRIGGER trg_notify_new_poll
    AFTER INSERT ON public.polls
    FOR EACH ROW EXECUTE FUNCTION public.notify_new_poll();

-- 4g. New journal entry notification
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
        INSERT INTO public.notifications (user_id, type, title, body, data)
        VALUES (
            _member.user_id,
            'new_journal_entry',
            'New Journal Entry',
            _author_name || ' added a journal entry in ' || COALESCE(_trip_title, 'your trip'),
            jsonb_build_object('trip_id', NEW.trip_id, 'entry_id', NEW.id)
        );
    END LOOP;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_new_journal_entry ON public.journal_entries;
CREATE TRIGGER trg_notify_new_journal_entry
    AFTER INSERT ON public.journal_entries
    FOR EACH ROW EXECUTE FUNCTION public.notify_new_journal_entry();

-- Force PostgREST to pick up new tables
NOTIFY pgrst, 'reload schema';
