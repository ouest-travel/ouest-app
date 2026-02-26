-- Phase 6: Profile avatar storage bucket
-- Allows users to upload and manage their profile avatar images.

-- ============================================================
-- Create the profile-avatars storage bucket
-- ============================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'profile-avatars',
    'profile-avatars',
    true,
    2097152, -- 2 MB
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- Storage RLS policies
-- ============================================================

-- Anyone can view profile avatars (public bucket)
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE policyname = 'Anyone can view profile avatars'
        AND tablename = 'objects' AND schemaname = 'storage'
    ) THEN
        CREATE POLICY "Anyone can view profile avatars"
            ON storage.objects FOR SELECT
            TO public
            USING (bucket_id = 'profile-avatars');
    END IF;
END $$;

-- Authenticated users can upload their own avatar
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE policyname = 'Users can upload their own avatar'
        AND tablename = 'objects' AND schemaname = 'storage'
    ) THEN
        CREATE POLICY "Users can upload their own avatar"
            ON storage.objects FOR INSERT
            TO authenticated
            WITH CHECK (
                bucket_id = 'profile-avatars'
                AND (storage.foldername(name))[1] = auth.uid()::text
            );
    END IF;
END $$;

-- Users can update their own avatar
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE policyname = 'Users can update their own avatar'
        AND tablename = 'objects' AND schemaname = 'storage'
    ) THEN
        CREATE POLICY "Users can update their own avatar"
            ON storage.objects FOR UPDATE
            TO authenticated
            USING (
                bucket_id = 'profile-avatars'
                AND (storage.foldername(name))[1] = auth.uid()::text
            );
    END IF;
END $$;

-- Users can delete their own avatar
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE policyname = 'Users can delete their own avatar'
        AND tablename = 'objects' AND schemaname = 'storage'
    ) THEN
        CREATE POLICY "Users can delete their own avatar"
            ON storage.objects FOR DELETE
            TO authenticated
            USING (
                bucket_id = 'profile-avatars'
                AND (storage.foldername(name))[1] = auth.uid()::text
            );
    END IF;
END $$;
