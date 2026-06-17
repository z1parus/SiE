-- Habit Module Evolution — Stage 3: reminder_time field.
--
-- Adds an optional 'HH:mm' reminder time to habits.
-- NULL means no reminder is set.

ALTER TABLE public.habits
  ADD COLUMN IF NOT EXISTS reminder_time text;
