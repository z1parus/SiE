-- Stage 5: Node assignees (task ↔ user, sub-goal ↔ user)
-- Many-to-many with denormalized goal_id for efficient RLS checks.

-- ── planning_task_assignees ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.planning_task_assignees (
  task_id       UUID NOT NULL REFERENCES public.planning_tasks(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES public.profiles(id)       ON DELETE CASCADE,
  goal_id       UUID NOT NULL REFERENCES public.goals(id)          ON DELETE CASCADE,
  assigned_by   UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (task_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_task_assignees_goal
  ON public.planning_task_assignees(goal_id);

-- ── sub_goal_assignees ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.sub_goal_assignees (
  sub_goal_id   UUID NOT NULL REFERENCES public.sub_goals(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES public.profiles(id)  ON DELETE CASCADE,
  goal_id       UUID NOT NULL REFERENCES public.goals(id)     ON DELETE CASCADE,
  assigned_by   UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (sub_goal_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_sub_goal_assignees_goal
  ON public.sub_goal_assignees(goal_id);

-- ── RLS: planning_task_assignees ──────────────────────────────────────────────
ALTER TABLE public.planning_task_assignees ENABLE ROW LEVEL SECURITY;

CREATE POLICY "task_assignees_select" ON public.planning_task_assignees
  FOR SELECT USING (
    goal_id IN (
      SELECT id FROM public.goals WHERE user_id = auth.uid()
      UNION
      SELECT goal_id FROM public.goal_collaborators
        WHERE user_id = auth.uid() AND status = 'accepted'
    )
  );

CREATE POLICY "task_assignees_insert" ON public.planning_task_assignees
  FOR INSERT WITH CHECK (
    goal_id IN (
      SELECT id FROM public.goals WHERE user_id = auth.uid()
      UNION
      SELECT goal_id FROM public.goal_collaborators
        WHERE user_id = auth.uid() AND status = 'accepted' AND role = 'editor'
    )
  );

CREATE POLICY "task_assignees_delete" ON public.planning_task_assignees
  FOR DELETE USING (
    goal_id IN (
      SELECT id FROM public.goals WHERE user_id = auth.uid()
      UNION
      SELECT goal_id FROM public.goal_collaborators
        WHERE user_id = auth.uid() AND status = 'accepted' AND role = 'editor'
    )
  );

-- ── RLS: sub_goal_assignees ───────────────────────────────────────────────────
ALTER TABLE public.sub_goal_assignees ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sub_goal_assignees_select" ON public.sub_goal_assignees
  FOR SELECT USING (
    goal_id IN (
      SELECT id FROM public.goals WHERE user_id = auth.uid()
      UNION
      SELECT goal_id FROM public.goal_collaborators
        WHERE user_id = auth.uid() AND status = 'accepted'
    )
  );

CREATE POLICY "sub_goal_assignees_insert" ON public.sub_goal_assignees
  FOR INSERT WITH CHECK (
    goal_id IN (
      SELECT id FROM public.goals WHERE user_id = auth.uid()
      UNION
      SELECT goal_id FROM public.goal_collaborators
        WHERE user_id = auth.uid() AND status = 'accepted' AND role = 'editor'
    )
  );

CREATE POLICY "sub_goal_assignees_delete" ON public.sub_goal_assignees
  FOR DELETE USING (
    goal_id IN (
      SELECT id FROM public.goals WHERE user_id = auth.uid()
      UNION
      SELECT goal_id FROM public.goal_collaborators
        WHERE user_id = auth.uid() AND status = 'accepted' AND role = 'editor'
    )
  );
