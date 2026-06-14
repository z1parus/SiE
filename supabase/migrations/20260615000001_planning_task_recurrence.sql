-- Stage 3 — Recurring planning tasks.
-- Adds a compact recurrence rule to planning_tasks so a completed recurring
-- task can spawn its next instance. Format examples:
--   'daily' | 'weekly:1,3,5' | 'monthly:15' | 'every:3'
-- RLS is inherited from the existing planning_tasks policies (no change).

ALTER TABLE public.planning_tasks
  ADD COLUMN IF NOT EXISTS recurrence_rule      text,
  ADD COLUMN IF NOT EXISTS recurrence_until     timestamptz,
  ADD COLUMN IF NOT EXISTS recurrence_parent_id uuid;
