-- Visual profile customization fields
alter table public.profiles
  add column if not exists avatar_frame_id      text,
  add column if not exists profile_background_url text;

-- Aggregate stats function — returns only counts, bypasses RLS on private tables.
-- Accessible to any authenticated user to power public dossier views.
create or replace function public.get_operative_stats(p_user_id uuid)
returns json
language sql
security definer
set search_path = public
as $$
  select json_build_object(
    'habit_completions', (
      select count(*)::int
      from public.habit_logs
      where user_id = p_user_id
    ),
    'focus_total_seconds', (
      select coalesce(sum(duration_seconds), 0)::int
      from public.focus_sessions
      where user_id = p_user_id
        and is_completed = true
    )
  );
$$;

grant execute on function public.get_operative_stats(uuid) to authenticated;
