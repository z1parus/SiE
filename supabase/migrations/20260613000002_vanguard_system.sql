-- ── Vanguard System ──────────────────────────────────────────────────────────
-- Timezone-aware daily leaderboard cycle with top-3 awards.

-- 1. Store each user's timezone in their profile
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS timezone_offset_minutes integer NOT NULL DEFAULT 0;


-- 2. Top-3 results per (date, timezone) — one row per place
CREATE TABLE IF NOT EXISTS public.vanguard_results (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  competition_date    date        NOT NULL,
  tz_offset_minutes   integer     NOT NULL,
  rank                integer     NOT NULL CHECK (rank BETWEEN 1 AND 3),
  user_id             uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  xp_earned           integer     NOT NULL DEFAULT 0,
  dp_awarded          integer     NOT NULL,
  awarded_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE (competition_date, tz_offset_minutes, rank)
);

CREATE INDEX IF NOT EXISTS idx_vanguard_results_date_tz
  ON public.vanguard_results (competition_date DESC, tz_offset_minutes);

ALTER TABLE public.vanguard_results ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anyone can read vanguard_results"
  ON public.vanguard_results FOR SELECT USING (true);


-- 3. Allow vanguard medals with no associated goal
ALTER TABLE public.mission_medals
  ALTER COLUMN goal_id DROP NOT NULL;

ALTER TABLE public.mission_medals
  ADD COLUMN IF NOT EXISTS medal_type text NOT NULL DEFAULT 'goal'
    CHECK (medal_type IN ('goal', 'vanguard'));


-- 4. Save timezone offset to user profile (called from client on tz change)
CREATE OR REPLACE FUNCTION public.update_timezone_offset(p_offset_minutes integer)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE public.profiles
  SET timezone_offset_minutes = p_offset_minutes
  WHERE id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION public.update_timezone_offset(integer) TO authenticated;


-- 5. Timezone-filtered daily leaderboard
--    p_tz_offset_minutes: user's UTC offset in minutes (e.g. 180 = UTC+3)
DROP FUNCTION IF EXISTS public.get_daily_leaderboard();

CREATE OR REPLACE FUNCTION public.get_daily_leaderboard(
  p_tz_offset_minutes integer DEFAULT 0
)
RETURNS TABLE (
  user_id                 uuid,
  username                text,
  avatar_url              text,
  equipped_frame_id       uuid,
  equipped_background_id  uuid,
  equipped_stat_style_id  uuid,
  total_xp                integer,
  daily_xp                integer,
  rank                    bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH
    local_today AS (
      SELECT (NOW() AT TIME ZONE 'UTC'
              + (p_tz_offset_minutes * INTERVAL '1 minute'))::date AS d
    ),
    scores AS (
      SELECT
        p.id                       AS user_id,
        p.username,
        p.avatar_url,
        p.equipped_frame_id,
        p.equipped_background_id,
        p.equipped_stat_style_id,
        p.total_xp,
        (
          COALESCE((
            SELECT SUM(hl.xp_awarded) FROM public.habit_logs hl
            WHERE hl.user_id = p.id
              AND hl.completed_at = (SELECT d FROM local_today)
          ), 0) +
          COALESCE((
            SELECT SUM(fs.xp_gained) FROM public.focus_sessions fs
            WHERE fs.user_id = p.id
              AND fs.is_completed = true
              AND (fs.created_at AT TIME ZONE 'UTC'
                   + (p_tz_offset_minutes * INTERVAL '1 minute'))::date
                  = (SELECT d FROM local_today)
          ), 0) +
          COALESCE((
            SELECT SUM(a.xp_reward)
            FROM public.user_achievements ua
            JOIN public.achievements a ON a.id = ua.achievement_id
            WHERE ua.user_id = p.id
              AND (ua.earned_at AT TIME ZONE 'UTC'
                   + (p_tz_offset_minutes * INTERVAL '1 minute'))::date
                  = (SELECT d FROM local_today)
          ), 0)
        )::integer AS daily_xp
      FROM public.profiles p
      WHERE p.timezone_offset_minutes = p_tz_offset_minutes
        AND p.username IS NOT NULL
    )
  SELECT
    user_id, username, avatar_url,
    equipped_frame_id, equipped_background_id, equipped_stat_style_id,
    total_xp, daily_xp,
    rank() OVER (ORDER BY daily_xp DESC, total_xp DESC) AS rank
  FROM scores
  ORDER BY daily_xp DESC, total_xp DESC
  LIMIT 50;
$$;

GRANT EXECUTE ON FUNCTION public.get_daily_leaderboard(integer) TO authenticated;


-- 6. Award vanguard cycle: idempotent top-3 awards for a given date + timezone
--    Awards DP (1000/500/250) and a vanguard medal to each of the top 3.
--    Returns the top-3 winner rows (whether just awarded or already stored).
CREATE OR REPLACE FUNCTION public.award_vanguard_cycle(
  p_competition_date  date,
  p_tz_offset_minutes integer
)
RETURNS TABLE (
  place        integer,
  winner_id    uuid,
  winner_name  text,
  avatar_url   text,
  xp_earned    integer,
  dp_awarded   integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_dp         integer;
  v_medal_name text;
  v_row        RECORD;
BEGIN
  -- Guard: only allow awarding completed cycles (yesterday or earlier)
  IF p_competition_date >= current_date THEN
    RETURN;
  END IF;

  -- Idempotency: if already awarded, just return stored results
  IF EXISTS (
    SELECT 1 FROM public.vanguard_results
    WHERE competition_date = p_competition_date
      AND tz_offset_minutes = p_tz_offset_minutes
  ) THEN
    RETURN QUERY
      SELECT vr.rank, vr.user_id, p.username, p.avatar_url,
             vr.xp_earned, vr.dp_awarded
      FROM public.vanguard_results vr
      JOIN public.profiles p ON p.id = vr.user_id
      WHERE vr.competition_date = p_competition_date
        AND vr.tz_offset_minutes = p_tz_offset_minutes
      ORDER BY vr.rank;
    RETURN;
  END IF;

  -- Compute and award top 3 for this tz + date
  FOR v_row IN (
    WITH ranked AS (
      SELECT
        p.id         AS uid,
        p.username,
        p.avatar_url,
        ROW_NUMBER() OVER (ORDER BY xp_sum DESC, p.id) AS rn,
        xp_sum
      FROM (
        SELECT
          p.id, p.username, p.avatar_url,
          (
            COALESCE((
              SELECT SUM(hl.xp_awarded) FROM public.habit_logs hl
              WHERE hl.user_id = p.id
                AND hl.completed_at = p_competition_date
            ), 0) +
            COALESCE((
              SELECT SUM(fs.xp_gained) FROM public.focus_sessions fs
              WHERE fs.user_id = p.id
                AND fs.is_completed = true
                AND (fs.created_at AT TIME ZONE 'UTC'
                     + (p_tz_offset_minutes * INTERVAL '1 minute'))::date
                    = p_competition_date
            ), 0) +
            COALESCE((
              SELECT SUM(a.xp_reward)
              FROM public.user_achievements ua
              JOIN public.achievements a ON a.id = ua.achievement_id
              WHERE ua.user_id = p.id
                AND (ua.earned_at AT TIME ZONE 'UTC'
                     + (p_tz_offset_minutes * INTERVAL '1 minute'))::date
                    = p_competition_date
            ), 0)
          )::integer AS xp_sum
        FROM public.profiles p
        WHERE p.timezone_offset_minutes = p_tz_offset_minutes
          AND p.username IS NOT NULL
      ) p
      WHERE xp_sum > 0
    )
    SELECT * FROM ranked WHERE rn <= 3
    ORDER BY rn
  )
  LOOP
    v_dp := CASE v_row.rn
      WHEN 1 THEN 1000
      WHEN 2 THEN 500
      ELSE        250
    END;
    v_medal_name := CASE v_row.rn
      WHEN 1 THEN 'Лучший оперативник Авангарда'
      WHEN 2 THEN 'Второй оперативник Авангарда'
      ELSE        'Замыкающий Авангарда'
    END;

    -- Award DP
    UPDATE public.profiles
    SET design_points = design_points + v_dp
    WHERE id = v_row.uid;

    -- Award vanguard medal (level maps to rank: 1st=gold/3, 2nd=silver/2, 3rd=bronze/1)
    INSERT INTO public.mission_medals (
      user_id, goal_id, category, level, name,
      earned_at, total_task_weight, duration_days, medal_type
    ) VALUES (
      v_row.uid, NULL, 'none',
      (4 - v_row.rn::integer),   -- 1st→3, 2nd→2, 3rd→1
      v_medal_name,
      NOW(), v_row.xp_sum, 0, 'vanguard'
    );

    -- Record result
    INSERT INTO public.vanguard_results (
      competition_date, tz_offset_minutes, rank,
      user_id, xp_earned, dp_awarded
    ) VALUES (
      p_competition_date, p_tz_offset_minutes, v_row.rn::integer,
      v_row.uid, v_row.xp_sum, v_dp
    )
    ON CONFLICT (competition_date, tz_offset_minutes, rank) DO NOTHING;
  END LOOP;

  -- Return whatever was awarded (may be empty if no XP that day)
  RETURN QUERY
    SELECT vr.rank, vr.user_id, p.username, p.avatar_url,
           vr.xp_earned, vr.dp_awarded
    FROM public.vanguard_results vr
    JOIN public.profiles p ON p.id = vr.user_id
    WHERE vr.competition_date = p_competition_date
      AND vr.tz_offset_minutes = p_tz_offset_minutes
    ORDER BY vr.rank;
END;
$$;

GRANT EXECUTE ON FUNCTION public.award_vanguard_cycle(date, integer) TO authenticated;
