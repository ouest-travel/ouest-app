-- Switch the push-notification trigger from current_setting() / ALTER DATABASE
-- to Supabase Vault. The previous approach (00026) needed ALTER DATABASE …
-- SET app.settings.*, which managed Supabase doesn't allow non-superusers to
-- run.
--
-- One-time configuration via Supabase SQL editor (NOT committed):
--
--   select vault.create_secret(
--     'https://YOUR-PROJECT.supabase.co',
--     'project_url'
--   );
--   select vault.create_secret(
--     'YOUR-SERVICE-ROLE-KEY',
--     'service_role_key'
--   );

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

NOTIFY pgrst, 'reload schema';
