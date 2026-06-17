-- Stage 7: Break Bad Habits (avoidance / negative habits)
-- Adds polarity to habits and extends habit_logs.entry_type with 'lapse'.

ALTER TABLE public.habits
  ADD COLUMN IF NOT EXISTS polarity text NOT NULL DEFAULT 'build';

ALTER TABLE public.habits
  DROP CONSTRAINT IF EXISTS habits_polarity_check;
ALTER TABLE public.habits
  ADD CONSTRAINT habits_polarity_check
    CHECK (polarity IN ('build', 'avoid'));

-- Extend the entry_type check (from Stage 5) to allow 'lapse' for avoid habits.
ALTER TABLE public.habit_logs
  DROP CONSTRAINT IF EXISTS habit_logs_entry_type_check;
ALTER TABLE public.habit_logs
  ADD CONSTRAINT habit_logs_entry_type_check
    CHECK (entry_type IN ('done', 'rest', 'lapse'));
