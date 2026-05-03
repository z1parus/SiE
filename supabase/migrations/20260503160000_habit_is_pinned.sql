-- Add pin support to habits table.
-- Existing RLS update policy already covers all columns for the owner.
alter table public.habits
  add column if not exists is_pinned boolean not null default false;
