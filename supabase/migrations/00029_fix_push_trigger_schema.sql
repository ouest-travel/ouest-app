-- Fix the push-notification trigger function: drop the over-qualified
-- `extensions.net.http_post(...)` call (which Postgres treats as a 3-part
-- database.schema.function reference and rejects with "cross-database
-- references are not implemented") in favour of the standard `net.http_post`
-- two-part call. pg_net always lives in a schema called `net` regardless of
-- which target schema the extension was installed into.
--
-- Surfaced today by an end-to-end test: now that the trip_members.role CHECK
-- constraint accepts 'viewer' again (migration 00028), the trip_members
-- INSERT actually succeeds, which fires the AFTER INSERT notification trigger
-- (from 00016/00021), which inserts a row into public.notifications, which
-- fires THIS trigger — and the broken extensions.net.http_post call inside
-- it bubbles all the way back as a transaction-level error, rolling the
-- whole INSERT back and surfacing as "Couldn't send invite" in the iOS app.

CREATE OR REPLACE FUNCTION public.send_push_for_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, vault, net
AS $$
DECLARE
    project_url   text;
    service_key   text;
    request_id    bigint;
BEGIN
    SELECT decrypted_secret INTO project_url
    FROM vault.decrypted_secrets
    WHERE name = 'project_url'
    LIMIT 1;

    SELECT decrypted_secret INTO service_key
    FROM vault.decrypted_secrets
    WHERE name = 'service_role_key'
    LIMIT 1;

    IF project_url IS NULL
       OR project_url = ''
       OR service_key IS NULL
       OR service_key = ''
    THEN
        RETURN NEW;
    END IF;

    -- net.http_post (two parts). pg_net's schema is always `net`, regardless
    -- of WHERE the extension was installed. extensions.net.http_post is a
    -- 3-part reference that Postgres rejects.
    SELECT net.http_post(
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

NOTIFY pgrst, 'reload schema';
