-- Fix: the habit_templates seed used `ON CONFLICT DO NOTHING` but the table has
-- no unique key on `name` (and `id` defaults to a fresh uuid), so any re-apply
-- of the seed inserted duplicate rows — surfacing as duplicated habits in the
-- in-app Habit Library.
--
-- De-duplicate existing system templates (keep the earliest physical row per
-- name) and add a partial unique index so future seeds are truly idempotent.

DELETE FROM public.habit_templates a
USING public.habit_templates b
WHERE a.is_system = true
  AND b.is_system = true
  AND a.name = b.name
  AND a.ctid > b.ctid;

CREATE UNIQUE INDEX IF NOT EXISTS habit_templates_system_name_idx
  ON public.habit_templates (name)
  WHERE is_system = true;
