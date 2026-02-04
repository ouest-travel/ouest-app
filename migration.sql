-- ============================================
-- Ouest App - Fresh Database Migration
-- ============================================
-- Simply copy this entire file and paste into Supabase SQL Editor, then click RUN

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 1. PROFILES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  display_name TEXT,
  handle TEXT UNIQUE,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view profiles" ON profiles FOR SELECT USING (true);
CREATE POLICY "Users can insert their own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

-- Auto-create profile when user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  base_handle TEXT;
  final_handle TEXT;
  counter INT := 0;
BEGIN
  -- Generate base handle from display_name or email
  base_handle := LOWER(REGEXP_REPLACE(
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
    '[^a-zA-Z0-9]',
    '',
    'g'
  ));
  
  final_handle := base_handle;
  
  -- Make sure handle is unique
  WHILE EXISTS (SELECT 1 FROM profiles WHERE handle = final_handle) LOOP
    counter := counter + 1;
    final_handle := base_handle || counter;
  END LOOP;
  
  INSERT INTO public.profiles (id, email, display_name, handle)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
    final_handle
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- 2. TRIPS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS trips (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  destination TEXT NOT NULL,
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ,
  budget DECIMAL(10, 2),
  currency TEXT DEFAULT 'USD',
  created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  is_public BOOLEAN DEFAULT FALSE,
  voting_enabled BOOLEAN DEFAULT FALSE,
  cover_image TEXT,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE trips ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own trips" ON trips FOR SELECT USING (created_by = auth.uid());
CREATE POLICY "Users can create trips" ON trips FOR INSERT WITH CHECK (created_by = auth.uid());
CREATE POLICY "Users can update their own trips" ON trips FOR UPDATE USING (created_by = auth.uid());
CREATE POLICY "Users can delete their own trips" ON trips FOR DELETE USING (created_by = auth.uid());

-- ============================================
-- 3. TRIP MEMBERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS trip_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('owner', 'member')) DEFAULT 'member',
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(trip_id, user_id)
);

ALTER TABLE trip_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view trip members for their trips" ON trip_members FOR SELECT 
USING (
  user_id = auth.uid() OR
  EXISTS (SELECT 1 FROM trips WHERE trips.id = trip_members.trip_id AND trips.created_by = auth.uid())
);

CREATE POLICY "Trip creators can add members" ON trip_members FOR INSERT 
WITH CHECK (
  EXISTS (SELECT 1 FROM trips WHERE trips.id = trip_members.trip_id AND trips.created_by = auth.uid())
);

CREATE POLICY "Users can remove themselves" ON trip_members FOR DELETE 
USING (user_id = auth.uid());

-- Auto-add creator as trip member
CREATE OR REPLACE FUNCTION handle_new_trip()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO trip_members (trip_id, user_id, role)
  VALUES (NEW.id, NEW.created_by, 'owner');
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_trip_created ON trips;
CREATE TRIGGER on_trip_created
  AFTER INSERT ON trips
  FOR EACH ROW EXECUTE FUNCTION handle_new_trip();

-- ============================================
-- 4. EXPENSES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS expenses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  amount DECIMAL(10, 2) NOT NULL,
  currency TEXT DEFAULT 'USD',
  category TEXT NOT NULL CHECK (category IN ('food', 'transport', 'stay', 'activities', 'other')),
  paid_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  split_among UUID[] NOT NULL DEFAULT ARRAY[]::UUID[],
  notes TEXT,
  date TIMESTAMPTZ DEFAULT NOW(),
  has_chat BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view expenses for their trips" ON expenses FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM trip_members 
    WHERE trip_members.trip_id = expenses.trip_id 
    AND trip_members.user_id = auth.uid()
  )
);

CREATE POLICY "Trip members can add expenses" ON expenses FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM trip_members 
    WHERE trip_members.trip_id = expenses.trip_id 
    AND trip_members.user_id = auth.uid()
  )
);

CREATE POLICY "Users can update their own expenses" ON expenses FOR UPDATE
USING (paid_by = auth.uid());

CREATE POLICY "Users can delete their own expenses" ON expenses FOR DELETE
USING (paid_by = auth.uid());

-- ============================================
-- 5. CHAT MESSAGES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  message_type TEXT NOT NULL CHECK (message_type IN ('text', 'expense', 'summary')) DEFAULT 'text',
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view messages for their trips" ON chat_messages FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM trip_members 
    WHERE trip_members.trip_id = chat_messages.trip_id 
    AND trip_members.user_id = auth.uid()
  )
);

CREATE POLICY "Trip members can send messages" ON chat_messages FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM trip_members 
    WHERE trip_members.trip_id = chat_messages.trip_id 
    AND trip_members.user_id = auth.uid()
  )
);

CREATE POLICY "Users can delete their own messages" ON chat_messages FOR DELETE
USING (user_id = auth.uid());

-- ============================================
-- 6. SAVED ITINERARY ITEMS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS saved_itinerary_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  activity_name TEXT NOT NULL,
  activity_location TEXT NOT NULL,
  activity_time TEXT,
  activity_cost TEXT,
  activity_description TEXT,
  activity_category TEXT NOT NULL CHECK (activity_category IN ('food', 'activity', 'transport', 'accommodation')) DEFAULT 'activity',
  source_trip_location TEXT,
  source_trip_user TEXT,
  day INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE saved_itinerary_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own saved itinerary items" ON saved_itinerary_items FOR SELECT
USING (user_id = auth.uid());

CREATE POLICY "Users can insert their own saved itinerary items" ON saved_itinerary_items FOR INSERT
WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their own saved itinerary items" ON saved_itinerary_items FOR UPDATE
USING (user_id = auth.uid());

CREATE POLICY "Users can delete their own saved itinerary items" ON saved_itinerary_items FOR DELETE
USING (user_id = auth.uid());

-- ============================================
-- 7. INDEXES FOR PERFORMANCE
-- ============================================
CREATE INDEX IF NOT EXISTS idx_profiles_handle ON profiles(handle);
CREATE INDEX IF NOT EXISTS idx_trips_created_by ON trips(created_by);
CREATE INDEX IF NOT EXISTS idx_trip_members_trip_id ON trip_members(trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_members_user_id ON trip_members(user_id);
CREATE INDEX IF NOT EXISTS idx_expenses_trip_id ON expenses(trip_id);
CREATE INDEX IF NOT EXISTS idx_expenses_paid_by ON expenses(paid_by);
CREATE INDEX IF NOT EXISTS idx_chat_messages_trip_id ON chat_messages(trip_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_user_id ON chat_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_itinerary_items_user_id ON saved_itinerary_items(user_id);

-- ============================================
-- DONE! ✅
-- ============================================
-- Your database is now ready for the Ouest app!
