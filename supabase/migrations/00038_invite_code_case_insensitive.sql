-- Invite codes: match case-insensitively.
--
-- Codes are generated mixed-case (base62 minus confusables) but the
-- "Join with Code" sheet upper-cases what the user types and forces a
-- capitals keyboard, and codes read aloud or copied from a screenshot lose
-- their case. Both lookups compared `code = _code` exactly, so manual entry
-- failed for any code containing a lowercase letter. Compare on lower()
-- instead; 8 chars of base62 folded to case-insensitive is still ~2.8e12
-- combinations, and existing codes have no case-insensitive collisions.

CREATE INDEX IF NOT EXISTS trip_invites_code_lower_idx
    ON public.trip_invites (lower(code));

-- Also enforce case-insensitive uniqueness going forward so two codes can
-- never differ only by case.
CREATE UNIQUE INDEX IF NOT EXISTS trip_invites_code_lower_key
    ON public.trip_invites (lower(code));

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
    WHERE lower(code) = lower(_code)
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
    WHERE lower(public.trip_invites.code) = lower(_code) AND is_active = true;

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

NOTIFY pgrst, 'reload schema';
