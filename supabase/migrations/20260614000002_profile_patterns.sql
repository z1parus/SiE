-- ── Profile patterns (animated overlays on top of the profile background) ────
--
-- A new cosmetic asset class. A pattern is rendered as an animated layer on top
-- of the equipped profile background in the profile hero card. The pattern hue
-- inherits the background accent colour, so style_config only carries the
-- pattern kind (`pattern_slug`) and overlay `opacity`.

create table public.profile_patterns (
  id           uuid                   primary key default gen_random_uuid(),
  slug         text                   not null unique,
  name         text                   not null,
  image_url    text,
  rarity       public.cosmetic_rarity not null default 'common',
  style_config jsonb                  not null default '{}',
  price_dp     integer                not null default 0
);

-- Equipped slot on the profile.
alter table public.profiles
  add column if not exists equipped_pattern_id uuid
    references public.profile_patterns(id) on delete set null;

-- Allow the new asset type in the inventory check constraint.
alter table public.user_inventory
  drop constraint if exists user_inventory_asset_type_check;

alter table public.user_inventory
  add constraint user_inventory_asset_type_check
  check (asset_type in ('avatar_frame','profile_background','stat_style','profile_pattern'));

-- ── RLS ───────────────────────────────────────────────────────
alter table public.profile_patterns enable row level security;

create policy "public read profile_patterns"
  on public.profile_patterns for select using (true);

grant select on public.profile_patterns to authenticated, anon;

-- ── Seed: Profile Patterns ────────────────────────────────────
-- Pricing/rarity (approved): iso_grid free starter, then ascending.
insert into public.profile_patterns (slug, name, rarity, style_config, price_dp) values
  ('iso_grid',       'Изо-сетка',      'common', '{"pattern_slug":"iso_grid","opacity":0.40}',       0),
  ('low_poly',       'Полигоны',       'rare',   '{"pattern_slug":"low_poly","opacity":0.40}',       500),
  ('dot_matrix',     'Точечный',       'epic',   '{"pattern_slug":"dot_matrix","opacity":0.40}',     1000),
  ('neural_threads', 'Нейронные нити', 'epic',   '{"pattern_slug":"neural_threads","opacity":0.40}', 1500);

-- Grant the free starter pattern to every existing operative so the catalogue
-- has an owned entry out of the box.
insert into public.user_inventory (user_id, asset_type, asset_id)
select p.id, 'profile_pattern', pat.id
  from public.profiles p
  cross join public.profile_patterns pat
 where pat.slug = 'iso_grid'
on conflict (user_id, asset_type, asset_id) do nothing;

-- ── Expose equipped_pattern_id on the daily leaderboard ───────
-- Profiles can be opened from the leaderboard, so the RPC must carry the
-- equipped pattern for the hero card to render it. Recreates the function from
-- 20260613000001_vanguard_system.sql with the extra column.
create or replace function public.get_daily_leaderboard(
  p_tz_offset_minutes integer default 0
)
returns table (
  user_id                 uuid,
  username                text,
  avatar_url              text,
  equipped_frame_id       uuid,
  equipped_background_id  uuid,
  equipped_stat_style_id  uuid,
  equipped_pattern_id     uuid,
  total_xp                integer,
  daily_xp                integer,
  rank                    bigint
)
language sql
stable
security definer
set search_path = public
as $$
  with
    local_today as (
      select (now() at time zone 'UTC'
              + (p_tz_offset_minutes * interval '1 minute'))::date as d
    ),
    scores as (
      select
        p.id                       as user_id,
        p.username,
        p.avatar_url,
        p.equipped_frame_id,
        p.equipped_background_id,
        p.equipped_stat_style_id,
        p.equipped_pattern_id,
        p.total_xp,
        (
          coalesce((
            select sum(hl.xp_awarded) from public.habit_logs hl
            where hl.user_id = p.id
              and hl.completed_at = (select d from local_today)
          ), 0) +
          coalesce((
            select sum(fs.xp_gained) from public.focus_sessions fs
            where fs.user_id = p.id
              and fs.is_completed = true
              and (fs.created_at at time zone 'UTC'
                   + (p_tz_offset_minutes * interval '1 minute'))::date
                  = (select d from local_today)
          ), 0) +
          coalesce((
            select sum(a.xp_reward)
            from public.user_achievements ua
            join public.achievements a on a.id = ua.achievement_id
            where ua.user_id = p.id
              and (ua.earned_at at time zone 'UTC'
                   + (p_tz_offset_minutes * interval '1 minute'))::date
                  = (select d from local_today)
          ), 0)
        )::integer as daily_xp
      from public.profiles p
      where p.timezone_offset_minutes = p_tz_offset_minutes
        and p.username is not null
    )
  select
    user_id, username, avatar_url,
    equipped_frame_id, equipped_background_id, equipped_stat_style_id,
    equipped_pattern_id,
    total_xp, daily_xp,
    rank() over (order by daily_xp desc, total_xp desc) as rank
  from scores
  order by daily_xp desc, total_xp desc
  limit 50;
$$;

grant execute on function public.get_daily_leaderboard(integer) to authenticated;
