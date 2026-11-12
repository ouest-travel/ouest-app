-- Multi-currency expenses with frozen FX rate.
--
-- When a user records an expense in a currency other than the trip's currency
-- (e.g. paying in USD on a CAD trip), the app fetches a live FX rate at
-- submission time and converts both the expense total and per-person splits
-- into the trip's currency before storage. The original-currency amount,
-- original currency code, and exchange rate used are persisted on the expense
-- row for display and audit purposes.
--
-- Storage shape: `amount` and `expense_splits.amount` continue to hold the
-- trip-currency figures, so existing balance/settlement math keeps working
-- without changes. The three new columns are nullable — NULL means the
-- expense was entered in the trip's own currency and no conversion happened.

ALTER TABLE public.expenses
    ADD COLUMN IF NOT EXISTS original_amount NUMERIC(12, 2)
        CHECK (original_amount IS NULL OR original_amount > 0),
    ADD COLUMN IF NOT EXISTS original_currency TEXT
        CHECK (original_currency IS NULL OR char_length(original_currency) = 3),
    ADD COLUMN IF NOT EXISTS fx_rate NUMERIC(14, 8)
        CHECK (fx_rate IS NULL OR fx_rate > 0);

-- Either all three FX columns are set, or none of them are.
ALTER TABLE public.expenses
    ADD CONSTRAINT expenses_fx_fields_all_or_none
    CHECK (
        (original_amount IS NULL AND original_currency IS NULL AND fx_rate IS NULL)
     OR (original_amount IS NOT NULL AND original_currency IS NOT NULL AND fx_rate IS NOT NULL)
    );
