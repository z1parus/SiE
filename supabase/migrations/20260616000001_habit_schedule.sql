-- Habit Module Evolution — Stage 1: flexible scheduling.
--
-- Adds a compact schedule descriptor to habits. Existing habits default to
-- 'daily', preserving the legacy "every day" behaviour. Format:
--   'daily' | 'weekdays:1,3,5' (1=Mon … 7=Sun) | 'weekly:N' | 'interval:N'
--
-- RLS is inherited from the existing habits policies — no changes required.

ALTER TABLE public.habits
  ADD COLUMN IF NOT EXISTS schedule text NOT NULL DEFAULT 'daily';
