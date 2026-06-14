-- Stage 8 — Task dependencies (blocks → unblocks).
-- A task may depend on one or more predecessor tasks of the SAME goal. The
-- denormalised goal_id/user_id keep RLS and querying simple. Cycle protection
-- is enforced client-side (DFS); this table only stores valid edges.

CREATE TABLE IF NOT EXISTS public.task_dependencies (
  task_id            uuid        NOT NULL REFERENCES public.planning_tasks(id) ON DELETE CASCADE,
  depends_on_task_id uuid        NOT NULL REFERENCES public.planning_tasks(id) ON DELETE CASCADE,
  goal_id            uuid        NOT NULL REFERENCES public.goals(id)          ON DELETE CASCADE,
  user_id            uuid        NOT NULL REFERENCES public.profiles(id)       ON DELETE CASCADE,
  created_at         timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (task_id, depends_on_task_id),
  CHECK (task_id <> depends_on_task_id)
);

CREATE INDEX IF NOT EXISTS idx_task_deps_goal    ON public.task_dependencies(goal_id);
CREATE INDEX IF NOT EXISTS idx_task_deps_depends ON public.task_dependencies(depends_on_task_id);

ALTER TABLE public.task_dependencies ENABLE ROW LEVEL SECURITY;

-- Read: goal owner or an accepted collaborator on that goal.
CREATE POLICY "Read dependencies for owned or shared goals"
  ON public.task_dependencies
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.goals g
      WHERE g.id = task_dependencies.goal_id
        AND (
          g.user_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM public.goal_collaborators gc
            WHERE gc.goal_id = g.id
              AND gc.user_id = auth.uid()
              AND gc.status = 'accepted'
              AND gc.role = 'editor'
          )
        )
    )
  );

-- Write: owner or editor of the goal (own user_id stamp on insert).
CREATE POLICY "Insert dependencies for editable goals"
  ON public.task_dependencies
  FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.goals g
      WHERE g.id = task_dependencies.goal_id
        AND (
          g.user_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM public.goal_collaborators gc
            WHERE gc.goal_id = g.id
              AND gc.user_id = auth.uid()
              AND gc.status = 'accepted'
              AND gc.role = 'editor'
          )
        )
    )
  );

CREATE POLICY "Delete dependencies for editable goals"
  ON public.task_dependencies
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.goals g
      WHERE g.id = task_dependencies.goal_id
        AND (
          g.user_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM public.goal_collaborators gc
            WHERE gc.goal_id = g.id
              AND gc.user_id = auth.uid()
              AND gc.status = 'accepted'
              AND gc.role = 'editor'
          )
        )
    )
  );
