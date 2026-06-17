-- Add is_pinned to goals for pinning to top of list
ALTER TABLE public.goals
  ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT false;
