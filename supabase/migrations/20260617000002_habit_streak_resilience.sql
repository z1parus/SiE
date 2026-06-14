-- Stage 5: Streak Resilience
-- Adds entry_type to habit_logs to support explicit rest days that don't break streaks.
ALTER TABLE public.habit_logs
  ADD COLUMN IF NOT EXISTS entry_type text NOT NULL DEFAULT 'done';

-- Constraint: only valid values allowed.
ALTER TABLE public.habit_logs
  DROP CONSTRAINT IF EXISTS habit_logs_entry_type_check;
ALTER TABLE public.habit_logs
  ADD CONSTRAINT habit_logs_entry_type_check
    CHECK (entry_type IN ('done', 'rest'));
