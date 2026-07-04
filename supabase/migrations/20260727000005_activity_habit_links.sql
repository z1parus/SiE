-- Ecosystem Pillar 1: activity → habit auto-completion.
-- A habit can be linked to an activity source ('focus'|'breathing'|
-- 'meditation'|'task'); completing that activity auto-logs the habit.

CREATE TABLE IF NOT EXISTS public.activity_habit_links (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  habit_id   UUID        NOT NULL REFERENCES public.habits(id) ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  source     TEXT        NOT NULL,
  min_value  REAL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_activity_habit_links_habit
  ON public.activity_habit_links(habit_id);
CREATE INDEX IF NOT EXISTS idx_activity_habit_links_user_source
  ON public.activity_habit_links(user_id, source);

ALTER TABLE public.activity_habit_links ENABLE ROW LEVEL SECURITY;

CREATE POLICY "activity_habit_links_select"
  ON public.activity_habit_links FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "activity_habit_links_insert"
  ON public.activity_habit_links FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "activity_habit_links_update"
  ON public.activity_habit_links FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "activity_habit_links_delete"
  ON public.activity_habit_links FOR DELETE
  USING (auth.uid() = user_id);
