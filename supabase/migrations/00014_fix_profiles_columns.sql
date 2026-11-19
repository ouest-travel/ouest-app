-- Fix: Ensure all expected profile columns exist.
-- The profiles table may have been created (via Supabase dashboard or
-- auto-creation) before migration 00001 ran. Since 00001 uses
-- CREATE TABLE IF NOT EXISTS, it would have silently skipped creation,
-- leaving the table without full_name, handle, avatar_url, nationality, bio.

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'full_name'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN full_name text;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'handle'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN handle text UNIQUE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'avatar_url'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN avatar_url text;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'nationality'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN nationality text;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'bio'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN bio text;
    END IF;
END $$;

-- Ensure handle index exists
CREATE INDEX IF NOT EXISTS idx_profiles_handle ON public.profiles(handle);

-- Reload PostgREST schema cache so it picks up the new columns
NOTIFY pgrst, 'reload schema';
