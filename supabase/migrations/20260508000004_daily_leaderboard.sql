-- ── leaderboard_winners — history of daily cycle champions ──────────────────
create table public.leaderboard_winners (
  id               uuid        primary key default gen_random_uuid(),
  winner_id        uuid        not null references public.profiles on delete cascade,
  xp_earned        integer     not null,
  competition_date date        not null,
  awarded_at       timestamptz not null default now(),
  unique (competition_date)
);

create index idx_leaderboard_winners_date
  on public.leaderboard_winners (competition_date desc);

alter table public.leaderboard_winners enable row level security;

create policy "anyone can read leaderboard_winners"
  on public.leaderboard_winners for select using (true);


-- ── get_server_time — anti-cheat: return authoritative UTC clock ──────────────
create or replace function public.get_server_time()
returns timestamptz
language sql
stable
security definer
set search_path = public
as $$
  select now();
$$;

grant execute on function public.get_server_time() to authenticated;


-- ── get_daily_leaderboard — top 50 operatives ranked by today's XP ───────────
create or replace function public.get_daily_leaderboard()
returns table (
  user_id                 uuid,
  username                text,
  avatar_url              text,
  equipped_frame_id       uuid,
  equipped_background_id  uuid,
  equipped_stat_style_id  uuid,
  total_xp                integer,
  daily_xp                integer,
  rank                    bigint
)
language sql
stable
security definer
set search_path = public
as $$
  with scores as (
    select
      p.id                        as user_id,
      p.username,
      p.avatar_url,
      p.equipped_frame_id,
      p.equipped_background_id,
      p.equipped_stat_style_id,
      p.total_xp,
      (
        coalesce(
          (select sum(hl.xp_awarded)
           from public.habit_logs hl
           where hl.user_id = p.id
             and hl.completed_at = current_date),
          0
        ) +
        coalesce(
          (select sum(fs.xp_gained)
           from public.focus_sessions fs
           where fs.user_id = p.id
             and fs.is_completed = true
             and (fs.created_at at time zone 'UTC')::date = current_date),
          0
        ) +
        coalesce(
          (select sum(a.xp_reward)
           from public.user_achievements ua
           join public.achievements a on a.id = ua.achievement_id
           where ua.user_id = p.id
             and (ua.earned_at at time zone 'UTC')::date = current_date),
          0
        )
      )::integer as daily_xp
    from public.profiles p
  )
  select
    user_id,
    username,
    avatar_url,
    equipped_frame_id,
    equipped_background_id,
    equipped_stat_style_id,
    total_xp,
    daily_xp,
    rank() over (order by daily_xp desc, total_xp desc) as rank
  from scores
  order by daily_xp desc, total_xp desc
  limit 50;
$$;

grant execute on function public.get_daily_leaderboard() to authenticated;


-- ── award_daily_winner — find yesterday's champion, pay 1 DP ─────────────────
create or replace function public.award_daily_winner()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_winner_id      uuid;
  v_winner_xp      integer;
  v_target_date    date := current_date - 1;
begin
  -- Idempotency: skip if already processed
  if exists(
    select 1 from public.leaderboard_winners
    where competition_date = v_target_date
  ) then
    return;
  end if;

  select ds.user_id, ds.daily_xp
  into v_winner_id, v_winner_xp
  from (
    select
      p.id as user_id,
      (
        coalesce(
          (select sum(hl.xp_awarded)
           from public.habit_logs hl
           where hl.user_id = p.id
             and hl.completed_at = v_target_date),
          0
        ) +
        coalesce(
          (select sum(fs.xp_gained)
           from public.focus_sessions fs
           where fs.user_id = p.id
             and fs.is_completed = true
             and (fs.created_at at time zone 'UTC')::date = v_target_date),
          0
        ) +
        coalesce(
          (select sum(a.xp_reward)
           from public.user_achievements ua
           join public.achievements a on a.id = ua.achievement_id
           where ua.user_id = p.id
             and (ua.earned_at at time zone 'UTC')::date = v_target_date),
          0
        )
      )::integer as daily_xp
    from public.profiles p
  ) ds
  where ds.daily_xp > 0
  order by ds.daily_xp desc, ds.user_id
  limit 1;

  if v_winner_id is not null then
    update public.profiles
    set design_points = design_points + 1
    where id = v_winner_id;

    insert into public.leaderboard_winners (winner_id, xp_earned, competition_date)
    values (v_winner_id, v_winner_xp, v_target_date);
  end if;
end;
$$;

-- pg_cron schedule — works on Supabase cloud; silently skipped locally
do $cron$
begin
  create extension if not exists pg_cron;
  perform cron.schedule(
    'award-daily-winner',
    '0 0 * * *',
    'select public.award_daily_winner()'
  );
exception when others then null;
end;
$cron$ language plpgsql;
