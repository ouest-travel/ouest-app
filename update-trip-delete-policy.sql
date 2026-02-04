-- Update trip delete policy to allow trip members to delete trips
-- This allows all members of a trip (not just the creator) to delete inactive trips
-- Note: The application code prevents deletion of past trips (status='completed' or end_date in the past)

-- Drop the existing delete policy
DROP POLICY IF EXISTS "Users can delete their own trips" ON trips;

-- Create a new policy that allows both creators and members to delete trips
CREATE POLICY "Users can delete trips they are part of" ON trips FOR DELETE 
USING (
  created_by = auth.uid() OR
  EXISTS (
    SELECT 1 FROM trip_members 
    WHERE trip_members.trip_id = trips.id 
    AND trip_members.user_id = auth.uid()
  )
);
