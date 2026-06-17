-- Stage 9 — Weekly review ritual + meaning layer ("why").
-- A guided weekly review writes a journal row, awards XP/DP and keeps a
-- review streak (mirrors the meditation zen_streak pattern). The goal "why"
-- is stored in the existing goals.settings JSON, so no goals column is needed.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS review_streak int NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS public.weekly_reviews (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  week_start      date        NOT NULL,
  completed_tasks int         NOT NULL DEFAULT 0,
  notes           text,
  focus_goal_ids  jsonb       NOT NULL DEFAULT '[]',
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, week_start)
);

ALTER TABLE public.weekly_reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Read own weekly reviews"
  ON public.weekly_reviews FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Insert own weekly reviews"
  ON public.weekly_reviews FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- RPC: logs the review (idempotent per week), awards XP/DP and updates the
-- review streak. Returns the granted amounts.
CREATE OR REPLACE FUNCTION public.log_weekly_review(
  p_week_start     date,
  p_completed_tasks int,
  p_notes          text,
  p_focus_goal_ids jsonb
)
RETURNS TABLE(xp_awarded int, dp_awarded int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid    uuid := auth.uid();
  v_xp     int  := 200;
  v_dp     int  := 30;
  v_last   date;
  v_streak int;
  v_existed boolean;
BEGIN
  -- Antifarm: a review already exists for this week → award nothing.
  SELECT EXISTS(
    SELECT 1 FROM weekly_reviews
    WHERE user_id = v_uid AND week_start = p_week_start
  ) INTO v_existed;

  IF v_existed THEN
    RETURN QUERY SELECT 0, 0;
    RETURN;
  END IF;

  INSERT INTO weekly_reviews(user_id, week_start, completed_tasks, notes, focus_goal_ids)
  VALUES (v_uid, p_week_start, COALESCE(p_completed_tasks, 0), p_notes,
          COALESCE(p_focus_goal_ids, '[]'::jsonb));

  PERFORM increment_xp(v_uid, v_xp);
  PERFORM add_design_points(v_dp);

  -- Review streak: consecutive ISO weeks.
  SELECT week_start INTO v_last
  FROM weekly_reviews
  WHERE user_id = v_uid AND week_start < p_week_start
  ORDER BY week_start DESC LIMIT 1;

  SELECT review_streak INTO v_streak FROM profiles WHERE id = v_uid;

  IF v_last = p_week_start - 7 THEN
    UPDATE profiles SET review_streak = COALESCE(v_streak, 0) + 1 WHERE id = v_uid;
  ELSE
    UPDATE profiles SET review_streak = 1 WHERE id = v_uid;
  END IF;

  RETURN QUERY SELECT v_xp, v_dp;
END;
$$;

GRANT EXECUTE ON FUNCTION public.log_weekly_review(date, int, text, jsonb) TO authenticated;
