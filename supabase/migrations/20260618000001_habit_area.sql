ALTER TABLE public.habits
  ADD COLUMN IF NOT EXISTS area text;

ALTER TABLE public.habits
  DROP CONSTRAINT IF EXISTS habits_area_check;
ALTER TABLE public.habits
  ADD CONSTRAINT habits_area_check
    CHECK (area IS NULL OR area IN ('health','mind','productivity','relationships','finance','spirit'));
