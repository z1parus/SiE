-- Stage 8b: Habit Stacking — generalise morning/evening routines into named
-- stacks with an anchor cue. Existing morning/evening rows are unchanged.

ALTER TABLE public.habit_routines
  ADD COLUMN IF NOT EXISTS name       text,
  ADD COLUMN IF NOT EXISTS anchor_cue text;

-- Allow the new 'stack' routine_type alongside the legacy values.
ALTER TABLE public.habit_routines
  DROP CONSTRAINT IF EXISTS habit_routines_routine_type_check;
ALTER TABLE public.habit_routines
  ADD CONSTRAINT habit_routines_routine_type_check
    CHECK (routine_type IN ('morning', 'evening', 'stack'));

-- Drop the one-row-per-type uniqueness so users can have many stacks.
ALTER TABLE public.habit_routines
  DROP CONSTRAINT IF EXISTS habit_routines_user_id_routine_type_key;

-- Partial unique index keeps the single-row guarantee for legacy
-- morning/evening only (stacks are unconstrained).
CREATE UNIQUE INDEX IF NOT EXISTS habit_routines_user_legacy_type_uniq
  ON public.habit_routines (user_id, routine_type)
  WHERE routine_type IN ('morning', 'evening');
