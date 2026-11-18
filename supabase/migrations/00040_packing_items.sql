-- Packing list: one shared checklist per trip.
--
-- Every member can add items, tick them off and claim them ("who's
-- bringing the speaker"), because the list only works if the whole group
-- edits it. Deleting is limited to the item's creator or the trip owner.
-- The list is private to the group: it is never exposed on public trips.

CREATE TABLE IF NOT EXISTS public.packing_items (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id         uuid NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    title           text NOT NULL CHECK (char_length(title) >= 1 AND char_length(title) <= 120),
    category        text NOT NULL DEFAULT 'other'
                    CHECK (category IN ('essentials', 'clothing', 'toiletries', 'tech', 'documents', 'other')),
    assigned_to     uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    is_packed       boolean NOT NULL DEFAULT false,
    created_by      uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_packing_items_trip ON public.packing_items(trip_id);

ALTER TABLE public.packing_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members can view packing items" ON public.packing_items;
DROP POLICY IF EXISTS "Members can add packing items" ON public.packing_items;
DROP POLICY IF EXISTS "Members can update packing items" ON public.packing_items;
DROP POLICY IF EXISTS "Creator or owner can delete packing items" ON public.packing_items;

CREATE POLICY "Members can view packing items"
    ON public.packing_items FOR SELECT TO authenticated
    USING (public.is_trip_member(trip_id, auth.uid()));

CREATE POLICY "Members can add packing items"
    ON public.packing_items FOR INSERT TO authenticated
    WITH CHECK (
        public.is_trip_member(trip_id, auth.uid())
        AND created_by = auth.uid()
    );

CREATE POLICY "Members can update packing items"
    ON public.packing_items FOR UPDATE TO authenticated
    USING (public.is_trip_member(trip_id, auth.uid()))
    WITH CHECK (public.is_trip_member(trip_id, auth.uid()));

CREATE POLICY "Creator or owner can delete packing items"
    ON public.packing_items FOR DELETE TO authenticated
    USING (
        created_by = auth.uid()
        OR public.get_trip_member_role(trip_id, auth.uid()) = 'owner'
    );

DROP TRIGGER IF EXISTS set_packing_items_updated_at ON public.packing_items;
CREATE TRIGGER set_packing_items_updated_at
    BEFORE UPDATE ON public.packing_items
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

NOTIFY pgrst, 'reload schema';
