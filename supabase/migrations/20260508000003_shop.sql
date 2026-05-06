-- ── Price column ─────────────────────────────────────────────

alter table public.avatar_frames
  add column if not exists price_dp integer not null default 0;

alter table public.profile_backgrounds
  add column if not exists price_dp integer not null default 0;

alter table public.stat_styles
  add column if not exists price_dp integer not null default 0;

-- Seed prices (common=0/free, rare=500, epic=1500, legendary=4000)
update public.avatar_frames       set price_dp = 0    where slug = 'default';
update public.avatar_frames       set price_dp = 500  where slug = 'neon_blue';
update public.avatar_frames       set price_dp = 1500 where slug = 'gold';
update public.avatar_frames       set price_dp = 4000 where slug = 'crimson';

update public.profile_backgrounds set price_dp = 0    where slug = 'deep_navy';
update public.profile_backgrounds set price_dp = 500  where slug = 'data_stream';
update public.profile_backgrounds set price_dp = 1500 where slug = 'void_space';
update public.profile_backgrounds set price_dp = 4000 where slug = 'crimson_ops';

update public.stat_styles         set price_dp = 0    where slug = 'terminal';
update public.stat_styles         set price_dp = 500  where slug = 'emerald';
update public.stat_styles         set price_dp = 1500 where slug = 'crimson';
update public.stat_styles         set price_dp = 4000 where slug = 'gold';

-- ── Atomic purchase RPC ────────────────────────────────────────

create or replace function public.purchase_asset(
  p_asset_id   uuid,
  p_asset_type text,
  p_price_dp   integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_balance  integer;
begin
  select design_points into v_balance
    from public.profiles
   where id = v_user_id
     for update;

  if not found then
    raise exception 'PROFILE_NOT_FOUND';
  end if;

  if p_price_dp > 0 and v_balance < p_price_dp then
    raise exception 'INSUFFICIENT_DP';
  end if;

  update public.profiles
     set design_points = design_points - p_price_dp
   where id = v_user_id;

  insert into public.user_inventory (user_id, asset_type, asset_id)
  values (v_user_id, p_asset_type, p_asset_id)
  on conflict (user_id, asset_type, asset_id) do nothing;
end;
$$;

grant execute on function public.purchase_asset(uuid, text, integer) to authenticated;
