-- Design Points (DP) — internal currency for cosmetic unlocks.

alter table public.profiles
  add column if not exists design_points integer not null default 0;

-- SECURITY DEFINER so clients can increment DP without direct UPDATE access.
create or replace function public.add_design_points(p_amount integer)
returns void
language sql
security definer
set search_path = public
as $$
  update public.profiles
  set design_points = design_points + p_amount
  where id = auth.uid();
$$;

grant execute on function public.add_design_points(integer) to authenticated;
