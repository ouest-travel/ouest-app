-- Add is_private column to profiles for private profile toggle
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'is_private'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN is_private boolean NOT NULL DEFAULT false;
    END IF;
END $$;
