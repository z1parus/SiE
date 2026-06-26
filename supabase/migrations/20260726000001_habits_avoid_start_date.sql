-- Add avoid_start_date to habits so users can set a custom counter start date
ALTER TABLE public.habits
  ADD COLUMN IF NOT EXISTS avoid_start_date TIMESTAMPTZ;
