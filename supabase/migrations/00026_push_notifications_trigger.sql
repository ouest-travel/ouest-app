-- Fire APNs pushes automatically whenever a row is inserted into
-- public.notifications. The existing trigger functions (00016, 00021) already
-- create notification rows on trip invites, expenses, polls, comments, etc.
-- — this migration just hooks them up to the push-notification Edge Function
-- so devices actually buzz.
--
-- One-time configuration (run from the Supabase SQL editor, NOT committed):
--
--   ALTER DATABASE postgres
--     SET app.settings.supabase_url = 'https://YOUR-PROJECT.supabase.co';
--   ALTER DATABASE postgres
--     SET app.settings.service_role_key = 'YOUR-SERVICE-ROLE-KEY';
--
-- These persist across restarts. The trigger reads them at runtime; if they
-- are unset (e.g. local dev without secrets configured) the trigger no-ops
-- gracefully and the notification INSERT still succeeds.

-- pg_net is bundled with Supabase but not enabled by default.
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION public.send_push_for_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    project_url   text;
    service_key   text;
    request_id    bigint;
BEGIN
    -- Read configuration. `true` flag = don't error if the setting is missing
    -- so local dev environments without secrets configured still work.
    project_url := current_setting('app.settings.supabase_url',   true);
    service_key := current_setting('app.settings.service_role_key', true);

    -- No config → graceful no-op. We never want a push-config issue to block
    -- the underlying notification INSERT.
    IF project_url IS NULL
       OR project_url = ''
       OR service_key IS NULL
       OR service_key = ''
    THEN
        RETURN NEW;
    END IF;

    -- Fire-and-forget HTTP call. pg_net is async — it queues the request and
    -- the trigger returns immediately, so this never slows down INSERTs.
    -- If the Edge Function fails for any reason, the in-app notification row
    -- still landed; the user just doesn't get the push.
    SELECT extensions.net.http_post(
        url     := project_url || '/functions/v1/push-notification',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || service_key
        ),
        body    := jsonb_build_object(
            'user_ids', jsonb_build_array(NEW.user_id::text),
            'title',    NEW.title,
            'body',     NEW.body,
            'data',     COALESCE(NEW.data, '{}'::jsonb)
        )
    )
    INTO request_id;

    RETURN NEW;
END;
$$;

-- Idempotent: drop and re-create so re-running this migration is safe.
DROP TRIGGER IF EXISTS send_push_after_notification_insert ON public.notifications;

CREATE TRIGGER send_push_after_notification_insert
    AFTER INSERT ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION public.send_push_for_notification();

-- Reload PostgREST schema cache so the new trigger is recognised immediately.
NOTIFY pgrst, 'reload schema';
