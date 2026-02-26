-- Phase 4: Shared Expenses
-- Tables: expenses, expense_splits
-- RLS uses existing is_trip_member() and get_trip_member_role() from 00004

-- ============================================================
-- Table: expenses
-- ============================================================

CREATE TABLE IF NOT EXISTS public.expenses (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id     uuid NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    paid_by     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE SET NULL,
    title       text NOT NULL CHECK (char_length(title) >= 1 AND char_length(title) <= 200),
    description text DEFAULT '' CHECK (char_length(description) <= 2000),
    amount      numeric(12,2) NOT NULL CHECK (amount > 0),
    currency    text DEFAULT 'USD' CHECK (char_length(currency) <= 3),
    category    text NOT NULL DEFAULT 'other'
                    CHECK (category IN ('food','transport','accommodation','activity','shopping','entertainment','other')),
    date        date,
    split_type  text NOT NULL DEFAULT 'equal'
                    CHECK (split_type IN ('equal','custom','full')),
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_expenses_trip_id ON public.expenses(trip_id);
CREATE INDEX IF NOT EXISTS idx_expenses_paid_by ON public.expenses(paid_by);

-- updated_at trigger
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'set_updated_at_expenses'
    ) THEN
        CREATE TRIGGER set_updated_at_expenses
            BEFORE UPDATE ON public.expenses
            FOR EACH ROW
            EXECUTE FUNCTION public.set_updated_at();
    END IF;
END $$;

-- ============================================================
-- Table: expense_splits
-- ============================================================

CREATE TABLE IF NOT EXISTS public.expense_splits (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    expense_id  uuid NOT NULL REFERENCES public.expenses(id) ON DELETE CASCADE,
    user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount      numeric(12,2) NOT NULL CHECK (amount >= 0),
    is_settled  boolean NOT NULL DEFAULT false,
    settled_at  timestamptz,
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT unique_expense_user UNIQUE (expense_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_expense_splits_expense_id ON public.expense_splits(expense_id);
CREATE INDEX IF NOT EXISTS idx_expense_splits_user_id ON public.expense_splits(user_id);

-- ============================================================
-- Helper: resolve trip_id from an expense_id (for split-level RLS)
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_trip_id_for_expense(_expense_id UUID)
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
    SELECT trip_id FROM public.expenses WHERE id = _expense_id LIMIT 1;
$$;

-- ============================================================
-- RLS: expenses
-- ============================================================

ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public trip expenses are viewable' AND tablename = 'expenses') THEN
        CREATE POLICY "Public trip expenses are viewable"
            ON public.expenses FOR SELECT TO authenticated
            USING (trip_id IN (SELECT id FROM public.trips WHERE is_public = true));
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Members can view expenses' AND tablename = 'expenses') THEN
        CREATE POLICY "Members can view expenses"
            ON public.expenses FOR SELECT TO authenticated
            USING (public.is_trip_member(trip_id, auth.uid()));
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Editors can insert expenses' AND tablename = 'expenses') THEN
        CREATE POLICY "Editors can insert expenses"
            ON public.expenses FOR INSERT TO authenticated
            WITH CHECK (public.get_trip_member_role(trip_id, auth.uid()) IN ('owner', 'editor'));
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Editors can update expenses' AND tablename = 'expenses') THEN
        CREATE POLICY "Editors can update expenses"
            ON public.expenses FOR UPDATE TO authenticated
            USING (public.get_trip_member_role(trip_id, auth.uid()) IN ('owner', 'editor'));
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Editors can delete expenses' AND tablename = 'expenses') THEN
        CREATE POLICY "Editors can delete expenses"
            ON public.expenses FOR DELETE TO authenticated
            USING (public.get_trip_member_role(trip_id, auth.uid()) IN ('owner', 'editor'));
    END IF;
END $$;

-- ============================================================
-- RLS: expense_splits
-- ============================================================

ALTER TABLE public.expense_splits ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public trip splits are viewable' AND tablename = 'expense_splits') THEN
        CREATE POLICY "Public trip splits are viewable"
            ON public.expense_splits FOR SELECT TO authenticated
            USING (public.get_trip_id_for_expense(expense_id) IN (SELECT id FROM public.trips WHERE is_public = true));
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Members can view splits' AND tablename = 'expense_splits') THEN
        CREATE POLICY "Members can view splits"
            ON public.expense_splits FOR SELECT TO authenticated
            USING (public.is_trip_member(public.get_trip_id_for_expense(expense_id), auth.uid()));
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Editors can insert splits' AND tablename = 'expense_splits') THEN
        CREATE POLICY "Editors can insert splits"
            ON public.expense_splits FOR INSERT TO authenticated
            WITH CHECK (public.get_trip_member_role(public.get_trip_id_for_expense(expense_id), auth.uid()) IN ('owner', 'editor'));
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Editors can update splits' AND tablename = 'expense_splits') THEN
        CREATE POLICY "Editors can update splits"
            ON public.expense_splits FOR UPDATE TO authenticated
            USING (public.get_trip_member_role(public.get_trip_id_for_expense(expense_id), auth.uid()) IN ('owner', 'editor'));
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Editors can delete splits' AND tablename = 'expense_splits') THEN
        CREATE POLICY "Editors can delete splits"
            ON public.expense_splits FOR DELETE TO authenticated
            USING (public.get_trip_member_role(public.get_trip_id_for_expense(expense_id), auth.uid()) IN ('owner', 'editor'));
    END IF;
END $$;
