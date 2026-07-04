-- Ecosystem Pillar 3: life area on goals (shared taxonomy across modules).
ALTER TABLE public.goals
  ADD COLUMN IF NOT EXISTS area TEXT;
