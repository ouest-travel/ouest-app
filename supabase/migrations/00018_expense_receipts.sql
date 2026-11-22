-- Add receipt_url column to expenses for photo receipts
-- Also creates the storage bucket for receipt images

-- ============================================================
-- Add receipt_url to expenses
-- ============================================================

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'expenses' AND column_name = 'receipt_url'
    ) THEN
        ALTER TABLE public.expenses ADD COLUMN receipt_url text;
    END IF;
END $$;

-- ============================================================
-- Storage bucket: expense-receipts
-- ============================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('expense-receipts', 'expense-receipts', true)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to upload receipts
CREATE POLICY "Authenticated users can upload receipts"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'expense-receipts');

-- Public read access for receipts
CREATE POLICY "Public read access for receipts"
    ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'expense-receipts');

-- Users can update their own receipts
CREATE POLICY "Users can update own receipts"
    ON storage.objects FOR UPDATE TO authenticated
    USING (bucket_id = 'expense-receipts');

-- Users can delete their own receipts
CREATE POLICY "Users can delete own receipts"
    ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'expense-receipts');
