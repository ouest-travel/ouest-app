-- Restore the trip_members.role CHECK constraint to the original vocabulary.
--
-- At some point the live constraint was changed out-of-band from
--   CHECK (role IN ('owner', 'editor', 'viewer'))   -- migration 00002
-- to
--   CHECK (role IN ('owner', 'admin',  'member'))
--
-- The iOS code, the Swift MemberRole enum, AND multiple RLS policies in
-- migrations 00004 / 00008 / 00017 all still reference 'owner' / 'editor' /
-- 'viewer'. So the live constraint rejects every legitimate INSERT from the
-- app (causing the "Couldn't send invite — violates trip_members_role_check"
-- error testers saw), and any pre-existing rows with role = 'admin' or
-- 'member' silently fail RLS checks like get_trip_member_role(...) IN
-- ('owner', 'editor').
--
-- This migration:
--   1. Drops the broken constraint
--   2. Migrates any stray 'admin'/'member' rows to their semantic equivalents
--      ('admin' → 'editor', 'member' → 'viewer'); this is the natural mapping
--      based on permission level (admin = can edit, member = can view).
--   3. Re-adds the original constraint
--
-- All three steps are idempotent / safe to re-run.

ALTER TABLE public.trip_members
    DROP CONSTRAINT IF EXISTS trip_members_role_check;

UPDATE public.trip_members SET role = 'editor' WHERE role = 'admin';
UPDATE public.trip_members SET role = 'viewer' WHERE role = 'member';

ALTER TABLE public.trip_members
    ADD CONSTRAINT trip_members_role_check
    CHECK (role IN ('owner', 'editor', 'viewer'));

NOTIFY pgrst, 'reload schema';
