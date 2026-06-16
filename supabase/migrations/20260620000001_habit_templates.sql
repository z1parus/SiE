-- Stage 8: Habit Library — curated, ready-made habit templates.

CREATE TABLE IF NOT EXISTS public.habit_templates (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name             text NOT NULL,
  description      text,
  area             text,
  kind             text NOT NULL DEFAULT 'binary',
  target_value     double precision,
  unit             text,
  step             double precision,
  default_schedule text NOT NULL DEFAULT 'daily',
  icon             text,
  color            text NOT NULL DEFAULT '#5AADA0',
  polarity         text NOT NULL DEFAULT 'build',
  sort_order       int  NOT NULL DEFAULT 0,
  is_system        boolean NOT NULL DEFAULT true,
  -- Reserved for future user-defined templates (out of MVP scope).
  user_id          uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT habit_templates_kind_check
    CHECK (kind IN ('binary', 'count', 'duration')),
  CONSTRAINT habit_templates_polarity_check
    CHECK (polarity IN ('build', 'avoid'))
);

ALTER TABLE public.habit_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS habit_templates_select ON public.habit_templates;
CREATE POLICY habit_templates_select ON public.habit_templates
  FOR SELECT
  USING (is_system = true OR user_id = auth.uid());

-- Seed system templates (idempotent on name for system rows).
INSERT INTO public.habit_templates
  (name, area, kind, target_value, unit, step, default_schedule, icon, color, polarity, sort_order)
VALUES
  ('Пить воду',          'health',        'count',    8,     'стак.', 1,    'daily',    '💧', '#6A8ED8', 'build', 10),
  ('10 000 шагов',       'health',        'count',    10000, 'шаг.',  1000, 'daily',    '🚶', '#5AAD6A', 'build', 11),
  ('Зарядка',            'health',        'duration', 600,   NULL,    300,  'daily',    '🤸', '#E07830', 'build', 12),
  ('Растяжка',           'health',        'duration', 300,   NULL,    60,   'daily',    '🧎', '#5AAD6A', 'build', 13),
  ('Сон 8 часов',        'health',        'binary',   NULL,  NULL,    NULL, 'daily',    '😴', '#6A8ED8', 'build', 14),
  ('Холодный душ',       'health',        'binary',   NULL,  NULL,    NULL, 'daily',    '🚿', '#4FB0C6', 'build', 15),
  ('Без сахара',         'health',        'binary',   NULL,  NULL,    NULL, 'daily',    '🍬', '#D98C6F', 'avoid', 16),
  ('Медитация',          'mind',          'duration', 600,   NULL,    300,  'daily',    '🧘', '#9B59B6', 'build', 20),
  ('Чтение',             'mind',          'duration', 1200,  NULL,    300,  'daily',    '📚', '#4A90D9', 'build', 21),
  ('Изучение языка',     'mind',          'duration', 900,   NULL,    300,  'daily',    '🗣️', '#4A90D9', 'build', 22),
  ('Без соцсетей',       'mind',          'binary',   NULL,  NULL,    NULL, 'daily',    '📵', '#D98C6F', 'avoid', 23),
  ('Планирование дня',   'productivity',  'binary',   NULL,  NULL,    NULL, 'daily',    '🗓️', '#C8A84B', 'build', 30),
  ('Глубокая работа',    'productivity',  'duration', 3600,  NULL,    600,  'daily',    '⚡', '#E07830', 'build', 31),
  ('Позвонить близким',  'relationships', 'binary',   NULL,  NULL,    NULL, 'weekly:2', '☎️', '#C05080', 'build', 40),
  ('Благодарность',      'relationships', 'binary',   NULL,  NULL,    NULL, 'daily',    '🙏', '#C05080', 'build', 41),
  ('Учёт расходов',      'finance',       'binary',   NULL,  NULL,    NULL, 'daily',    '💰', '#70B870', 'build', 50),
  ('Дневник',            'spirit',        'duration', 300,   NULL,    60,   'daily',    '✍️', '#9B59B6', 'build', 60)
ON CONFLICT DO NOTHING;
