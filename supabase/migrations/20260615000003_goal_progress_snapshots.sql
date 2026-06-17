-- Stage 5 — Momentum analytics.
-- Daily progress snapshots per goal, used client-side to compute velocity,
-- projected completion and burndown.

CREATE TABLE IF NOT EXISTS public.goal_progress_snapshots (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id         uuid        NOT NULL REFERENCES public.goals(id)    ON DELETE CASCADE,
  user_id         uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  progress        real        NOT NULL,
  completed_tasks int         NOT NULL DEFAULT 0,
  total_tasks     int         NOT NULL DEFAULT 0,
  captured_at     timestamptz NOT NULL DEFAULT now()
);

-- One snapshot per goal per day (idempotent same-day re-capture).
CREATE UNIQUE INDEX IF NOT EXISTS uq_snapshot_goal_day
  ON public.goal_progress_snapshots(goal_id, (captured_at::date));

CREATE INDEX IF NOT EXISTS idx_snapshot_goal_time
  ON public.goal_progress_snapshots(goal_id, captured_at DESC);

ALTER TABLE public.goal_progress_snapshots ENABLE ROW LEVEL SECURITY;

-- Read: goal owner or an accepted collaborator on that goal.
CREATE POLICY "Read snapshots for owned or shared goals"
  ON public.goal_progress_snapshots
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.goals g
      WHERE g.id = goal_progress_snapshots.goal_id
        AND (
          g.user_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM public.goal_collaborators gc
            WHERE gc.goal_id = g.id
              AND gc.user_id = auth.uid()
              AND gc.status = 'accepted'
          )
        )
    )
  );

-- Insert: only the snapshot's own user (goals capture their own owner's rows).
CREATE POLICY "Insert own snapshots"
  ON public.goal_progress_snapshots
  FOR INSERT
  WITH CHECK (user_id = auth.uid());
