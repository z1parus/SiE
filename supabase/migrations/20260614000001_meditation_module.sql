-- ── Meditation Module ────────────────────────────────────────────────────────
-- Tables: affirmation_packs, meditation_presets, meditation_logs
-- RPC:    log_meditation_session (awards XP/DP, updates zen_streak)
-- Seeds:  3 affirmation packs, 3 system presets, branch record

-- 1. Affirmation packs (system + user-custom)
CREATE TABLE IF NOT EXISTS public.affirmation_packs (
  id        UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name      TEXT        NOT NULL,
  category  TEXT        NOT NULL DEFAULT 'general',
  phrases   TEXT[]      NOT NULL DEFAULT '{}',
  is_custom BOOLEAN     NOT NULL DEFAULT false,
  user_id   UUID        REFERENCES public.profiles(id) ON DELETE CASCADE
);

ALTER TABLE public.affirmation_packs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "affirmation_packs_select"
  ON public.affirmation_packs FOR SELECT
  USING (user_id = auth.uid() OR is_custom = false);

CREATE POLICY "affirmation_packs_insert"
  ON public.affirmation_packs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "affirmation_packs_update"
  ON public.affirmation_packs FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "affirmation_packs_delete"
  ON public.affirmation_packs FOR DELETE
  USING (auth.uid() = user_id);


-- 2. Meditation presets
CREATE TABLE IF NOT EXISTS public.meditation_presets (
  id                       UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                  UUID        REFERENCES public.profiles(id) ON DELETE CASCADE,
  name                     TEXT        NOT NULL,
  description              TEXT,
  is_system                BOOLEAN     NOT NULL DEFAULT false,
  has_breathing            BOOLEAN     NOT NULL DEFAULT false,
  breathing_pattern_id     TEXT,        -- 'box' | '4-7-8' | 'coherence'
  breathing_duration_min   INT         NOT NULL DEFAULT 5,
  meditation_type          TEXT        NOT NULL DEFAULT 'unguided',
  meditation_duration_min  INT         NOT NULL DEFAULT 15,
  base_music_id            TEXT,
  ambient_fx_id            TEXT,
  base_volume              REAL        NOT NULL DEFAULT 0.7,
  ambient_volume           REAL        NOT NULL DEFAULT 0.5,
  voice_volume             REAL        NOT NULL DEFAULT 0.6,
  affirmation_pack_id      UUID        REFERENCES public.affirmation_packs(id) ON DELETE SET NULL,
  affirmation_interval_secs INT        NOT NULL DEFAULT 30,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.meditation_presets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "meditation_presets_select"
  ON public.meditation_presets FOR SELECT
  USING (user_id = auth.uid() OR is_system = true);

CREATE POLICY "meditation_presets_insert"
  ON public.meditation_presets FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "meditation_presets_update"
  ON public.meditation_presets FOR UPDATE
  USING (auth.uid() = user_id AND is_system = false);

CREATE POLICY "meditation_presets_delete"
  ON public.meditation_presets FOR DELETE
  USING (auth.uid() = user_id AND is_system = false);


-- 3. Meditation logs (session history)
CREATE TABLE IF NOT EXISTS public.meditation_logs (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  preset_id        UUID        REFERENCES public.meditation_presets(id) ON DELETE SET NULL,
  duration_seconds INT         NOT NULL,
  xp_awarded       INT         NOT NULL DEFAULT 0,
  dp_awarded       INT         NOT NULL DEFAULT 0,
  state_before     INT,        -- 1–5 mood rating
  state_after      INT,        -- 1–5 mood rating
  completed_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_meditation_logs_user_completed
  ON public.meditation_logs (user_id, completed_at DESC);

ALTER TABLE public.meditation_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "meditation_logs_select"
  ON public.meditation_logs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "meditation_logs_insert"
  ON public.meditation_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);


-- 4. Zen streak column on profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS zen_streak_days INT NOT NULL DEFAULT 0;


-- 5. log_meditation_session RPC
--    Awards XP (5 per minute) + DP (~0.5 per minute), updates zen streak.
CREATE OR REPLACE FUNCTION public.log_meditation_session(
  p_preset_id        UUID,
  p_duration_seconds INT,
  p_state_before     INT,
  p_state_after      INT
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
     state_before, state_after, completed_at)
  VALUES
    (v_uid, p_preset_id, p_duration_seconds, v_xp, v_dp,
     p_state_before, p_state_after, now());

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

GRANT EXECUTE ON FUNCTION public.log_meditation_session(UUID, INT, INT, INT) TO authenticated;


-- 6. Seed: system affirmation packs
INSERT INTO public.affirmation_packs (name, category, phrases, is_custom) VALUES
  ('Уверенность', 'confidence', ARRAY[
    'Я способен на всё, что поставлю перед собой',
    'Моя воля сильнее любых препятствий',
    'Я действую с ясностью и решимостью',
    'Каждый шаг приближает меня к цели',
    'Я доверяю своим силам и интуиции'
  ], false),
  ('Спокойствие', 'calm', ARRAY[
    'Я нахожусь в состоянии полного покоя',
    'Моё дыхание — якорь в настоящем моменте',
    'Я отпускаю всё лишнее с каждым выдохом',
    'Внутри меня — тишина и ясность',
    'Спокойствие — моё естественное состояние'
  ], false),
  ('Энергия', 'energy', ARRAY[
    'Каждый вдох наполняет меня силой',
    'Я пробуждаю потенциал внутри себя',
    'Моя энергия обновляется с каждым моментом',
    'Я заряжен, сосредоточен и готов к действию',
    'Жизненная сила течёт через каждую клетку'
  ], false)
ON CONFLICT DO NOTHING;


-- 7. Seed: system presets (user_id NULL = global)
INSERT INTO public.meditation_presets
  (name, description, is_system, user_id,
   has_breathing, breathing_pattern_id, breathing_duration_min,
   meditation_type, meditation_duration_min,
   base_volume, ambient_volume)
VALUES
  ('Утренний Фокус',
   'Дыхание box + фокусировка для начала дня',
   true, NULL, true, 'box', 5, 'unguided', 10, 0.7, 0.5),
  ('Вечерний Дзен',
   'Глубокое расслабление перед сном',
   true, NULL, false, NULL, 0, 'unguided', 20, 0.6, 0.6),
  ('Быстрый Reset',
   'Экспресс-сброс напряжения за 5 минут',
   true, NULL, true, 'coherence', 3, 'unguided', 2, 0.7, 0.4)
ON CONFLICT DO NOTHING;


-- 8. Branch record for Operations Control screen
INSERT INTO public.branches (slug, name, description)
VALUES ('meditation', 'Дефрагментация', 'Сессии погружения и осознанности')
ON CONFLICT (slug) DO NOTHING;
