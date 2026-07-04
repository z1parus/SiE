-- Ecosystem Stage 1: integrate the Meditation and Breathing modules.
-- Preliminary breathing now runs the real Breathing module and links to the
-- meditation it preceded. Columns are plain (no FK) — cross-linking is used for
-- display/metrics; the client generates the ids and stores them best-effort.

-- 1. Meditation presets: new breathing config (saved sequence OR quick params).
ALTER TABLE public.meditation_presets
  ADD COLUMN IF NOT EXISTS breathing_sequence_id UUID,
  ADD COLUMN IF NOT EXISTS breathing_config_json TEXT;

-- 2. Breathing sessions: the meditation this breathing was the prelude to.
ALTER TABLE public.breathing_sessions
  ADD COLUMN IF NOT EXISTS meditation_session_id UUID;

-- 3. Meditation logs: the breathing session that ran before this meditation.
ALTER TABLE public.meditation_logs
  ADD COLUMN IF NOT EXISTS breathing_session_id UUID;

-- 4. Extend the logging RPC to store the breathing link and fold the breathing
--    duration into the single unified reward (the client passes the total).
DROP FUNCTION IF EXISTS public.log_meditation_session(UUID, INT, INT, INT);

CREATE OR REPLACE FUNCTION public.log_meditation_session(
  p_preset_id           UUID,
  p_duration_seconds    INT,
  p_state_before        INT,
  p_state_after         INT,
  p_breathing_session_id UUID DEFAULT NULL
)
RETURNS TABLE(xp_awarded INT, dp_awarded INT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_xp     INT  := (p_duration_seconds / 60) * 5;
  v_dp     INT  := p_duration_seconds / 120;
  v_uid    UUID := auth.uid();
  v_last   DATE;
  v_streak INT;
BEGIN
  -- Insert session log
  INSERT INTO public.meditation_logs
    (user_id, preset_id, duration_seconds, xp_awarded, dp_awarded,
     state_before, state_after, breathing_session_id, completed_at)
  VALUES
    (v_uid, p_preset_id, p_duration_seconds, v_xp, v_dp,
     p_state_before, p_state_after, p_breathing_session_id, now());

  -- Award XP and DP
  PERFORM public.increment_xp(v_uid, v_xp);
  PERFORM public.add_design_points(v_dp);

  -- Update zen streak
  SELECT completed_at::date INTO v_last
  FROM public.meditation_logs
  WHERE user_id = v_uid
    AND completed_at < now()
  ORDER BY completed_at DESC
  LIMIT 1;

  SELECT zen_streak_days INTO v_streak
  FROM public.profiles
  WHERE id = v_uid;

  IF v_last = current_date - 1 THEN
    UPDATE public.profiles SET zen_streak_days = v_streak + 1 WHERE id = v_uid;
  ELSIF v_last IS NULL OR v_last < current_date - 1 THEN
    UPDATE public.profiles SET zen_streak_days = 1 WHERE id = v_uid;
  -- If same calendar day: streak unchanged
  END IF;

  RETURN QUERY SELECT v_xp, v_dp;
END;
$$;
