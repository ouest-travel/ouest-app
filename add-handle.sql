-- Add handle column to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS handle TEXT UNIQUE;

-- Create index for handle lookups
CREATE INDEX IF NOT EXISTS idx_profiles_handle ON profiles(handle);

-- Generate handles for existing users (based on display_name or email)
UPDATE profiles
SET handle = LOWER(REGEXP_REPLACE(
  COALESCE(display_name, split_part(email, '@', 1)),
  '[^a-zA-Z0-9]',
  '',
  'g'
))
WHERE handle IS NULL;

-- Make sure handles are unique by appending id if needed
UPDATE profiles p1
SET handle = handle || '_' || substring(id::text, 1, 6)
WHERE handle IS NOT NULL
AND EXISTS (
  SELECT 1 FROM profiles p2 
  WHERE p2.handle = p1.handle 
  AND p2.id < p1.id
);

