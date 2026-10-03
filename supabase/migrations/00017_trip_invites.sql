-- ============================================================
-- 00017_trip_invites.sql
-- Trip invite links & QR code sharing infrastructure
-- ============================================================

-- 1. Table: trip_invites
-- Stores shareable invite codes that let anyone join a trip.

CREATE TABLE IF NOT EXISTS public.trip_invites (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id     uuid NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    created_by  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    code        text NOT NULL UNIQUE,
    role        text NOT NULL DEFAULT 'viewer' CHECK (role IN ('editor', 'viewer')),
    expires_at  timestamptz,
    max_uses    int NOT NULL DEFAULT 0,
    use_count   int NOT NULL DEFAULT 0,
    is_active   boolean NOT NULL DEFAULT true,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- 2. Indexes
CREATE INDEX IF NOT EXISTS idx_trip_invites_trip_active
    ON public.trip_invites(trip_id, is_active);

-- 3. Enable RLS
ALTER TABLE public.trip_invites ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies

-- Trip owner/editors can view their trip's invites
DROP POLICY IF EXISTS "Trip editors can view invites" ON public.trip_invites;
CREATE POLICY "Trip editors can view invites"
    ON public.trip_invites FOR SELECT TO authenticated
    USING (
        public.get_trip_member_role(trip_id, auth.uid()) IN ('owner', 'editor')
    );

-- Any authenticated user can look up an invite by code (for validation/preview)
DROP POLICY IF EXISTS "Anyone can validate invite by code" ON public.trip_invites;
CREATE POLICY "Anyone can validate invite by code"
    ON public.trip_invites FOR SELECT TO authenticated
    USING (true);

-- Trip owner/editors can create invites
DROP POLICY IF EXISTS "Trip editors can create invites" ON public.trip_invites;
CREATE POLICY "Trip editors can create invites"
    ON public.trip_invites FOR INSERT TO authenticated
    WITH CHECK (
        public.get_trip_member_role(trip_id, auth.uid()) IN ('owner', 'editor')
        AND created_by = auth.uid()
    );

-- Trip owner/editors can update invites (for revoking)
DROP POLICY IF EXISTS "Trip editors can update invites" ON public.trip_invites;
CREATE POLICY "Trip editors can update invites"
    ON public.trip_invites FOR UPDATE TO authenticated
    USING (
        public.get_trip_member_role(trip_id, auth.uid()) IN ('owner', 'editor')
    );

-- 5. RPC Function: join_trip_via_invite
-- Atomically validates an invite code and adds the caller as a trip member.
-- Returns the trip_id on success.

CREATE OR REPLACE FUNCTION public.join_trip_via_invite(_code text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    _invite RECORD;
    _user_id uuid;
    _existing uuid;
BEGIN
    _user_id := auth.uid();

    IF _user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Lock the invite row to prevent race conditions
    SELECT * INTO _invite
    FROM public.trip_invites
    WHERE code = _code
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid invite code';
    END IF;

    IF NOT _invite.is_active THEN
        RAISE EXCEPTION 'This invite has been revoked';
    END IF;

    IF _invite.expires_at IS NOT NULL AND _invite.expires_at < now() THEN
        RAISE EXCEPTION 'This invite has expired';
    END IF;

    IF _invite.max_uses > 0 AND _invite.use_count >= _invite.max_uses THEN
        RAISE EXCEPTION 'This invite has reached its maximum uses';
    END IF;

    -- Check if user is already a member
    SELECT id INTO _existing
    FROM public.trip_members
    WHERE trip_id = _invite.trip_id AND user_id = _user_id;

    IF FOUND THEN
        RAISE EXCEPTION 'You are already a member of this trip';
    END IF;

    -- Insert new member (fires existing trg_notify_trip_invite trigger)
    INSERT INTO public.trip_members (trip_id, user_id, role, invited_by)
    VALUES (_invite.trip_id, _user_id, _invite.role, _invite.created_by);

    -- Increment use count
    UPDATE public.trip_invites
    SET use_count = use_count + 1
    WHERE id = _invite.id;

    RETURN _invite.trip_id;
END;
$$;

-- 6. RPC Function: validate_invite
-- Returns trip preview data for an invite code without joining.
-- Used by the JoinTripView to show a preview before the user commits.

CREATE OR REPLACE FUNCTION public.validate_invite(_code text)
RETURNS TABLE(
    trip_id uuid,
    trip_title text,
    trip_destination text,
    trip_cover_image_url text,
    role text,
    creator_name text,
    member_count bigint,
    is_already_member boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
DECLARE
    _invite RECORD;
    _user_id uuid;
BEGIN
    _user_id := auth.uid();

    SELECT * INTO _invite
    FROM public.trip_invites
    WHERE public.trip_invites.code = _code AND is_active = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid or revoked invite code';
    END IF;

    IF _invite.expires_at IS NOT NULL AND _invite.expires_at < now() THEN
        RAISE EXCEPTION 'This invite has expired';
    END IF;

    IF _invite.max_uses > 0 AND _invite.use_count >= _invite.max_uses THEN
        RAISE EXCEPTION 'This invite has reached its maximum uses';
    END IF;

    RETURN QUERY
    SELECT
        t.id,
        t.title,
        t.destination,
        t.cover_image_url,
        _invite.role,
        COALESCE(p.full_name, 'Someone'),
        (SELECT COUNT(*) FROM public.trip_members tm WHERE tm.trip_id = t.id),
        EXISTS(
            SELECT 1 FROM public.trip_members tm2
            WHERE tm2.trip_id = t.id AND tm2.user_id = _user_id
        )
    FROM public.trips t
    JOIN public.profiles p ON p.id = _invite.created_by
    WHERE t.id = _invite.trip_id;
END;
$$;

-- 7. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
