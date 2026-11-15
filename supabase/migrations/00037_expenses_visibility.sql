-- Expenses visibility on public trips
-- Until now, making a trip public also showed its expenses and who owes
-- whom to every signed-in user. That is the group's money, and it was the
-- main reason not to share a trip. The owner now chooses: `expenses_public`
-- decides whether people outside the trip can read them.
--
-- Default is false, so EXISTING public trips stop showing expenses to
-- non-members when this is applied. Members are unaffected: their access
-- comes from the "Members can view ..." policies, which are not touched.

ALTER TABLE public.trips
    ADD COLUMN IF NOT EXISTS expenses_public boolean NOT NULL DEFAULT false;

-- ============================================================
-- RLS: outsiders read expenses only when the trip is public AND opted in
-- ============================================================

DROP POLICY IF EXISTS "Public trip expenses are viewable" ON public.expenses;
CREATE POLICY "Public trip expenses are viewable"
    ON public.expenses FOR SELECT TO authenticated
    USING (trip_id IN (
        SELECT id FROM public.trips WHERE is_public = true AND expenses_public = true
    ));

DROP POLICY IF EXISTS "Public trip splits are viewable" ON public.expense_splits;
CREATE POLICY "Public trip splits are viewable"
    ON public.expense_splits FOR SELECT TO authenticated
    USING (public.get_trip_id_for_expense(expense_id) IN (
        SELECT id FROM public.trips WHERE is_public = true AND expenses_public = true
    ));

-- Force PostgREST to pick up the new column
NOTIFY pgrst, 'reload schema';
