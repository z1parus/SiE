-- Breathing module: a permanent log of every breathing practice session.
-- Each row captures the session metrics (duration, breaths, rounds, the
-- longest/total exhale-retention hold) plus the user's post-practice
-- reflection (mood emoji + calmness/confidence 1-10). Private to the author.

CREATE TABLE IF NOT EXISTS public.breathing_sessions (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  duration_seconds     int  NOT NULL DEFAULT 0,
  breaths              int  NOT NULL DEFAULT 0,   -- total inhale/exhale cycles
  rounds               int  NOT NULL DEFAULT 0,   -- rounds completed
  longest_hold_seconds int  NOT NULL DEFAULT 0,   -- longest single exhale hold
  total_hold_seconds   int  NOT NULL DEFAULT 0,   -- summed exhale holds
  mood_emoji           text,                      -- curated mood emoji (nullable)
  calmness             int,                        -- 1..10 (nullable)
  confidence           int,                        -- 1..10 (nullable)
  xp_awarded           int  NOT NULL DEFAULT 0,
  dp_awarded           int  NOT NULL DEFAULT 0,
  completed_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_breathing_sessions_user_time
  ON public.breathing_sessions(user_id, completed_at DESC);

ALTER TABLE public.breathing_sessions ENABLE ROW LEVEL SECURITY;

-- Owner-only: a session log is fully private to its author.
CREATE POLICY "breathing_sessions: select own" ON public.breathing_sessions
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "breathing_sessions: insert own" ON public.breathing_sessions
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "breathing_sessions: update own" ON public.breathing_sessions
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "breathing_sessions: delete own" ON public.breathing_sessions
  FOR DELETE USING (user_id = auth.uid());
