-- Habit Journaling: add note and emoji fields to habit_logs
ALTER TABLE public.habit_logs ADD COLUMN note  TEXT NULL;
ALTER TABLE public.habit_logs ADD COLUMN emoji TEXT NULL;

-- UPDATE policy was missing — needed to edit notes/emoji on existing logs
CREATE POLICY "owner can update own habit_logs"
  ON public.habit_logs FOR UPDATE
  USING (auth.uid() = user_id);

-- Index for habit detail timeline query (all logs for a specific habit, newest first)
CREATE INDEX IF NOT EXISTS idx_habit_logs_habit
  ON public.habit_logs (user_id, habit_id, completed_at DESC);
