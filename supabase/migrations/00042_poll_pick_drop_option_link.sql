-- Fix: 00041 broke the polls list.
--
-- 00041 made polls.picked_option_id a foreign key to poll_options. That gave
-- the two tables a second link, alongside poll_options.poll_id. The app asks
-- the API for "polls with their poll_options", and with two links the API
-- can no longer tell which one is meant, so it refuses the whole request
-- (PGRST201). Every build's polls screen failed to load.
--
-- The link is not needed. A tie-break choice only counts while it is one of
-- the tied options: break_poll_tie checks that when it is set, and poll_pick
-- checks it again every time it is read, so an id that no longer matches an
-- option is simply ignored.
ALTER TABLE public.polls DROP CONSTRAINT IF EXISTS polls_picked_option_id_fkey;

NOTIFY pgrst, 'reload schema';
