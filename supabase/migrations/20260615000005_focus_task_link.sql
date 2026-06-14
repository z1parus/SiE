-- Stage 7 — Focus ↔ Planning link.
-- Attributes a focus session to a planning task / goal so invested time can be
-- aggregated per task and per goal. ON DELETE SET NULL keeps goal-level totals
-- correct even after a task is deleted (its time stays counted on the goal).

ALTER TABLE public.focus_sessions
  ADD COLUMN IF NOT EXISTS task_id uuid REFERENCES public.planning_tasks(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS goal_id uuid REFERENCES public.goals(id)          ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_focus_goal ON public.focus_sessions(goal_id);
CREATE INDEX IF NOT EXISTS idx_focus_task ON public.focus_sessions(task_id);
