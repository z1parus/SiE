-- Stage 4 — Quantitative (metric) milestones.
-- Adds metric fields to the milestones table and creates milestone_logs.

ALTER TABLE public.milestones
  ADD COLUMN IF NOT EXISTS kind          text NOT NULL DEFAULT 'binary',
  ADD COLUMN IF NOT EXISTS unit          text,
  ADD COLUMN IF NOT EXISTS start_value   double precision,
  ADD COLUMN IF NOT EXISTS target_value  double precision,
  ADD COLUMN IF NOT EXISTS current_value double precision,
  ADD COLUMN IF NOT EXISTS direction     text NOT NULL DEFAULT 'up';

CREATE TABLE IF NOT EXISTS public.milestone_logs (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_id uuid        NOT NULL REFERENCES public.milestones(id) ON DELETE CASCADE,
  user_id      uuid        NOT NULL REFERENCES public.profiles(id)   ON DELETE CASCADE,
  value        double precision NOT NULL,
  recorded_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_milestone_logs_ms
  ON public.milestone_logs(milestone_id, recorded_at DESC);

-- RLS: access controlled through the goal owner/editor relationship
ALTER TABLE public.milestone_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own milestone logs"
  ON public.milestone_logs
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
