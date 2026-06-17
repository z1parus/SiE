-- Habit Module Evolution — Stage 2: quantitative and duration habit types.
--
-- Adds kind/target/unit/step to habits and a value column to logs.
-- Existing habits default to 'binary', existing logs default to value=1,
-- preserving all current behaviour.

ALTER TABLE public.habits
  ADD COLUMN IF NOT EXISTS kind         text NOT NULL DEFAULT 'binary',
  ADD COLUMN IF NOT EXISTS target_value double precision,
  ADD COLUMN IF NOT EXISTS unit         text,
  ADD COLUMN IF NOT EXISTS step         double precision;

ALTER TABLE public.habit_logs
  ADD COLUMN IF NOT EXISTS value double precision NOT NULL DEFAULT 1;
