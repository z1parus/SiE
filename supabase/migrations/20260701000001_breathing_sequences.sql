-- Breathing module: user-built round sequences. Each sequence is a named,
-- ordered list of rounds, where every round carries its own breathing params
-- (cycles, inhale/exhale length, exhale-retention, recovery hold). Audio stays
-- a device-level setting and is NOT part of a sequence. Private to the author.

CREATE TABLE IF NOT EXISTS public.breathing_sequences (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name       text NOT NULL,
  rounds     jsonb NOT NULL DEFAULT '[]'::jsonb,  -- ordered array of round configs
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_breathing_sequences_user
  ON public.breathing_sequences(user_id);

ALTER TABLE public.breathing_sequences ENABLE ROW LEVEL SECURITY;

-- Owner-only: a sequence is fully private to its author.
CREATE POLICY "breathing_sequences: select own" ON public.breathing_sequences
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "breathing_sequences: insert own" ON public.breathing_sequences
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "breathing_sequences: update own" ON public.breathing_sequences
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "breathing_sequences: delete own" ON public.breathing_sequences
  FOR DELETE USING (user_id = auth.uid());
