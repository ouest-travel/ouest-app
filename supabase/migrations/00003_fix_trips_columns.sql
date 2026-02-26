-- 00003_fix_trips_columns.sql
-- Fix column name mismatches between iOS app and pre-existing web app schema.
-- The trips table was created by the web app before migration 00002 ran,
-- so CREATE TABLE IF NOT EXISTS was a no-op. This migration renames columns
-- to match the iOS app's expected schema.

-- Rename columns to match iOS CodingKeys
ALTER TABLE public.trips RENAME COLUMN name TO title;
ALTER TABLE public.trips RENAME COLUMN cover_image TO cover_image_url;

-- Add CHECK constraints from 00002 that were never applied
-- (wrapped in DO blocks to be idempotent)
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints
        WHERE constraint_name = 'trips_title_length'
    ) THEN
        ALTER TABLE public.trips ADD CONSTRAINT trips_title_length
            CHECK (char_length(title) >= 1 AND char_length(title) <= 200);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints
        WHERE constraint_name = 'trips_destination_length'
    ) THEN
        ALTER TABLE public.trips ADD CONSTRAINT trips_destination_length
            CHECK (char_length(destination) >= 1 AND char_length(destination) <= 200);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints
        WHERE constraint_name = 'trips_description_length'
    ) THEN
        ALTER TABLE public.trips ADD CONSTRAINT trips_description_length
            CHECK (char_length(description) <= 2000);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints
        WHERE constraint_name = 'valid_dates'
    ) THEN
        ALTER TABLE public.trips ADD CONSTRAINT valid_dates
            CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date);
    END IF;
END $$;
