-- Mission Medals: awarded when a goal (mission) is completed.
-- Level is determined client-side from task weight and duration.

CREATE TABLE IF NOT EXISTS public.mission_medals (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  goal_id    uuid        NOT NULL REFERENCES public.goals(id)    ON DELETE CASCADE,
  category   text        NOT NULL DEFAULT 'none',
  level      int         NOT NULL CHECK (level IN (1, 2, 3)),
  name       text        NOT NULL,
  earned_at  timestamptz NOT NULL DEFAULT now(),
  total_task_weight int  NOT NULL DEFAULT 0,
  duration_days     int  NOT NULL DEFAULT 0
);

ALTER TABLE public.mission_medals ENABLE ROW LEVEL SECURITY;

-- Owner can read/write their own medals
CREATE POLICY "own medals rw" ON public.mission_medals
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Any authenticated user can read medals (public profile display)
CREATE POLICY "public read medals" ON public.mission_medals
  FOR SELECT USING (true);

CREATE INDEX idx_mission_medals_user ON public.mission_medals(user_id);
