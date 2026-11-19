-- Poll deadlines: an optional time after which voting closes.
--
-- Polls exist to get a group to a decision. Without a deadline a poll stays
-- open until someone remembers to close it, and the group never hears that
-- time is running out.
--
-- 1. polls.closes_at. NULL means no deadline, which is every existing poll.
-- 2. Votes are refused once a poll is closed or past its deadline. Until now
--    only the app stopped a vote on a closed poll; the database accepted it.
-- 3. A job each minute reminds members who have not voted when a quarter of
--    the voting time is left, and marks polls closed once the deadline passes.
--
-- The deadline itself never waits for that job. The vote policies compare
-- closes_at with the clock directly, so voting stops on time even if the job
-- is late or not running.

-- ============================================================
-- 1. Columns
-- ============================================================
ALTER TABLE public.polls
    ADD COLUMN IF NOT EXISTS closes_at        timestamptz,
    ADD COLUMN IF NOT EXISTS reminder_sent_at timestamptz;

ALTER TABLE public.polls DROP CONSTRAINT IF EXISTS polls_closes_after_created;
ALTER TABLE public.polls
    ADD CONSTRAINT polls_closes_after_created
    CHECK (closes_at IS NULL OR closes_at > created_at);

-- The job looks only at open polls that have a deadline.
CREATE INDEX IF NOT EXISTS idx_polls_open_deadline
    ON public.polls (closes_at)
    WHERE status = 'open' AND closes_at IS NOT NULL;

-- ============================================================
-- 2. Voting stops when the poll does
-- ============================================================
CREATE OR REPLACE FUNCTION public.is_poll_open(_poll_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.polls
        WHERE id = _poll_id
          AND status = 'open'
          AND (closes_at IS NULL OR closes_at > now())
    );
$$;

DROP POLICY IF EXISTS "Members can vote" ON public.poll_votes;
CREATE POLICY "Members can vote"
    ON public.poll_votes FOR INSERT TO authenticated
    WITH CHECK (
        public.is_trip_member(public.get_trip_id_for_poll(poll_id), auth.uid())
        AND user_id = auth.uid()
        AND public.is_poll_open(poll_id)
    );

-- A vote taken back after closing would change a result the group has
-- already seen, so removing one stops at the same moment as casting one.
DROP POLICY IF EXISTS "Users can remove their votes" ON public.poll_votes;
CREATE POLICY "Users can remove their votes"
    ON public.poll_votes FOR DELETE TO authenticated
    USING (user_id = auth.uid() AND public.is_poll_open(poll_id));

-- ============================================================
-- 3. Reminder and closing
-- ============================================================
-- The reminder is sent as `new_poll` with `kind: poll_closing`, the same way
-- trip edits ride on `new_activity`, so app builds that only know the
-- original notification types still decode it and open the right trip.
CREATE OR REPLACE FUNCTION public.process_poll_deadlines()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    _poll   RECORD;
    _member RECORD;
BEGIN
    -- Remind once, when a quarter of the voting time is left: 15 minutes
    -- before a one-hour poll closes, 18 hours before a three-day one.
    FOR _poll IN
        UPDATE public.polls
        SET reminder_sent_at = now()
        WHERE status = 'open'
          AND closes_at IS NOT NULL
          AND reminder_sent_at IS NULL
          AND closes_at > now()
          AND now() >= closes_at - (closes_at - created_at) / 4
        RETURNING id, trip_id, title
    LOOP
        -- Only members who have not voted. Everyone else has done their part.
        FOR _member IN
            SELECT m.user_id
            FROM public.trip_members m
            WHERE m.trip_id = _poll.trip_id
              AND NOT EXISTS (
                  SELECT 1 FROM public.poll_votes v
                  WHERE v.poll_id = _poll.id AND v.user_id = m.user_id
              )
        LOOP
            IF public.should_notify(_member.user_id, 'new_polls') THEN
                INSERT INTO public.notifications (user_id, type, title, body, data)
                VALUES (
                    _member.user_id,
                    'new_poll',
                    'Voting closes soon ⏳',
                    'Last call to vote on: ' || _poll.title,
                    jsonb_build_object(
                        'trip_id', _poll.trip_id,
                        'poll_id', _poll.id,
                        'kind', 'poll_closing'
                    )
                );
            END IF;
        END LOOP;
    END LOOP;

    -- Keep the stored status in step with the deadline.
    UPDATE public.polls
    SET status = 'closed', closed_at = closes_at
    WHERE status = 'open'
      AND closes_at IS NOT NULL
      AND closes_at <= now();
END;
$$;

-- Only the scheduler runs this. Without the revoke any signed-in user could
-- call it through the API.
REVOKE EXECUTE ON FUNCTION public.process_poll_deadlines() FROM PUBLIC, anon, authenticated;

-- ============================================================
-- 4. Schedule
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;

-- Unschedule first so running this migration again never leaves two copies.
SELECT cron.unschedule(jobid) FROM cron.job
WHERE jobname IN ('poll-deadlines', 'cron-history-cleanup');

SELECT cron.schedule(
    'poll-deadlines',
    '* * * * *',
    'SELECT public.process_poll_deadlines()'
);

-- pg_cron logs every run. A job each minute is 1,440 rows a day, so keep a week.
SELECT cron.schedule(
    'cron-history-cleanup',
    '15 4 * * *',
    $$DELETE FROM cron.job_run_details WHERE end_time < now() - interval '7 days'$$
);

NOTIFY pgrst, 'reload schema';
