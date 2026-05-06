-- Allow any authenticated user to read user_achievements for public profile view.
-- The 'owner can read own achievements' policy is too restrictive for viewing
-- other operatives' earned badges. Replacing it with a broader authenticated read.
drop policy if exists "owner can read own achievements" on public.user_achievements;

create policy "authenticated can read user_achievements"
  on public.user_achievements for select
  using (auth.uid() is not null);

-- Trigram extension + index for fast ilike username search.
create extension if not exists pg_trgm with schema extensions;

create index if not exists idx_profiles_username_trgm
  on public.profiles using gin (username extensions.gin_trgm_ops);
