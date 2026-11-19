-- Fire APNs pushes automatically whenever a row is inserted into
-- public.notifications. The existing trigger functions (00016, 00021) already
-- create notification rows on trip invites, expenses, polls, comments, etc.
-- — this migration just hooks them up to the push-notification Edge Function
-- so devices actually buzz.
--
-- One-time configuration (run from the Supabase SQL editor, NOT committed):
--
--   select vault.create_secret(
--     'https://YOUR-PROJECT.supabase.co',
--     'project_url'
--   );
--   select vault.create_secret(
--     'YOUR-SERVICE-ROLE-KEY',
--     'service_role_key'
--   );
--
-- If you need to update an existing secret:
--   select vault.update_secret(
--     (select id from vault.secrets where name = 'service_role_key'),
--     'NEW-KEY-VALUE'
--   );
--
-- The trigger reads these at runtime via vault.decrypted_secrets. If either
-- is missing the trigger no-ops gracefully and the notification INSERT still
-- succeeds — so local dev without push secrets keeps working.

-- pg_net is bundled with Supabase but not enabled by default.
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION public.send_push_for_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, vault, extensions
AS $$
DECLARE
    project_url   text;
    service_key   text;
    request_id    bigint;
BEGIN
    -- Pull project URL + service role key from Vault. These are encrypted at
    -- rest and never appear in pg_dump output, function definitions, or this
    -- migration's source.
    SELECT decrypted_secret INTO project_url
    FROM vault.decrypted_secrets
    WHERE name = 'project_url'
    LIMIT 1;

    SELECT decrypted_secret INTO service_key
    FROM vault.decrypted_secrets
    WHERE name = 'service_role_key'
    LIMIT 1;

    -- Graceful no-op when either secret is missing. We never want a push-
    -- config issue to block the underlying notification INSERT.
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
