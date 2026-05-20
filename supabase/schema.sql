-- ============================================================
-- SiE — полная схема базы данных
-- ============================================================
-- Единый файл для развёртывания на чистом проекте Supabase.
-- Применять: через SQL-редактор в дашборде или командой:
--   supabase db reset  (если файл находится в supabase/migrations/)
--
-- О суточном XP:
--   Колонка daily_xp в profiles НЕ используется. XP за текущие
--   сутки вычисляется динамически через RPC get_daily_leaderboard()
--   путём агрегации habit_logs, focus_sessions и user_achievements
--   за current_date. Это Вариант А из спецификации: при смене
--   даты данные «сбрасываются» автоматически — никакого ручного
--   UPDATE не требуется. В 00:00 UTC запускается award_daily_winner()
--   (pg_cron / edge-function), которая находит победителя вчерашнего
--   дня и начисляет ему 1 DP.
-- ============================================================


/* ══════════════════════════════════════════════════════════════
   0. РАСШИРЕНИЯ
   ══════════════════════════════════════════════════════════════ */

-- Тригонометрический поиск по имени пользователя (ILIKE fast path)
create extension if not exists pg_trgm with schema extensions;


/* ══════════════════════════════════════════════════════════════
   1. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
   ══════════════════════════════════════════════════════════════ */

-- Автоматическое обновление поля updated_at при каждом UPDATE
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;


/* ══════════════════════════════════════════════════════════════
   2. ПЕРЕЧИСЛЕНИЯ (ENUM)
   ══════════════════════════════════════════════════════════════ */

create type public.cosmetic_rarity as enum ('common', 'rare', 'epic', 'legendary');


/* ══════════════════════════════════════════════════════════════
   3. КАТАЛОГИ КОСМЕТИКИ
   (создаются раньше profiles, т.к. profiles ссылается на них)
   ══════════════════════════════════════════════════════════════ */

-- ── Рамки аватара ─────────────────────────────────────────────
create table public.avatar_frames (
  id           uuid                   primary key default gen_random_uuid(),
  slug         text                   not null unique,
  name         text                   not null,
  image_url    text,
  rarity       public.cosmetic_rarity not null default 'common',
  style_config jsonb                  not null default '{}',
  price_dp     integer                not null default 0
);

alter table public.avatar_frames enable row level security;

create policy "public read avatar_frames"
  on public.avatar_frames for select using (true);

grant select on public.avatar_frames to authenticated, anon;


-- ── Фоны профиля ──────────────────────────────────────────────
create table public.profile_backgrounds (
  id           uuid                   primary key default gen_random_uuid(),
  slug         text                   not null unique,
  name         text                   not null,
  image_url    text,
  rarity       public.cosmetic_rarity not null default 'common',
  style_config jsonb                  not null default '{}',
  price_dp     integer                not null default 0
);

alter table public.profile_backgrounds enable row level security;

create policy "public read profile_backgrounds"
  on public.profile_backgrounds for select using (true);

grant select on public.profile_backgrounds to authenticated, anon;


-- ── Стили статистики ──────────────────────────────────────────
create table public.stat_styles (
  id           uuid                   primary key default gen_random_uuid(),
  slug         text                   not null unique,
  name         text                   not null,
  rarity       public.cosmetic_rarity not null default 'common',
  style_config jsonb                  not null default '{}',
  price_dp     integer                not null default 0
);

alter table public.stat_styles enable row level security;

create policy "public read stat_styles"
  on public.stat_styles for select using (true);

grant select on public.stat_styles to authenticated, anon;


/* ══════════════════════════════════════════════════════════════
   4. ПРОФИЛИ
   ══════════════════════════════════════════════════════════════ */

create table public.profiles (
  -- Идентификация
  id            uuid        primary key references auth.users on delete cascade,
  updated_at    timestamptz,
  username      text        unique,
  full_name     text,
  avatar_url    text,

  -- Прогресс
  total_xp      integer     not null default 0,
  design_points integer     not null default 0,
  is_lab_member boolean     not null default false,

  -- Флаги онбординга
  has_seen_welcome              boolean not null default false,
  has_seen_onboarding_breathing boolean not null default false,
  has_seen_onboarding_habits    boolean not null default false,
  has_seen_onboarding_focus     boolean not null default false,

  -- Активная косметика (FK на каталоги)
  equipped_frame_id       uuid references public.avatar_frames(id)       on delete set null,
  equipped_background_id  uuid references public.profile_backgrounds(id)  on delete set null,
  equipped_stat_style_id  uuid references public.stat_styles(id)          on delete set null
);

create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

create index idx_profiles_username_trgm
  on public.profiles using gin (username extensions.gin_trgm_ops);

alter table public.profiles enable row level security;

-- Открытое чтение нужно для поиска оперативников и публичного досье
create policy "anyone can read profiles"
  on public.profiles for select using (true);

create policy "owner can update own profile"
  on public.profiles for update using (auth.uid() = id);


/* ══════════════════════════════════════════════════════════════
   5. ТРИГГЕР: АВТОСОЗДАНИЕ ПРОФИЛЯ ПРИ РЕГИСТРАЦИИ
   ══════════════════════════════════════════════════════════════ */

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, username, full_name, avatar_url)
  values (
    new.id,
    new.raw_user_meta_data ->> 'username',
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'avatar_url'
  );
  return new;
end;
$$;

create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


/* ══════════════════════════════════════════════════════════════
   6. ОТДЕЛЫ (BRANCHES)
   ══════════════════════════════════════════════════════════════ */

create table public.branches (
  id          uuid primary key default gen_random_uuid(),
  slug        text not null unique,
  name        text not null,
  description text,
  icon_url    text
);

alter table public.branches enable row level security;

create policy "anyone can read branches"
  on public.branches for select using (true);


-- ── Прогресс пользователя по отделам ─────────────────────────
create table public.user_branches (
  id                    uuid        primary key default gen_random_uuid(),
  user_id               uuid        not null references public.profiles on delete cascade,
  branch_id             uuid        not null references public.branches  on delete cascade,
  level                 integer     not null default 1 check (level >= 1),
  virtual_clients_count integer     not null default 0,
  last_activity         timestamptz,
  updated_at            timestamptz,
  unique (user_id, branch_id)
);

create index idx_user_branches_user_id on public.user_branches (user_id);

create trigger trg_user_branches_updated_at
  before update on public.user_branches
  for each row execute function public.set_updated_at();

alter table public.user_branches enable row level security;

create policy "owner can read own user_branches"
  on public.user_branches for select using (auth.uid() = user_id);

create policy "owner can insert own user_branches"
  on public.user_branches for insert with check (auth.uid() = user_id);

create policy "owner can update own user_branches"
  on public.user_branches for update using (auth.uid() = user_id);

create policy "owner can delete own user_branches"
  on public.user_branches for delete using (auth.uid() = user_id);


/* ══════════════════════════════════════════════════════════════
   7. ДОСТИЖЕНИЯ
   ══════════════════════════════════════════════════════════════ */

create table public.achievements (
  id          uuid    primary key default gen_random_uuid(),
  slug        text    not null unique,
  name        text    not null,
  description text,
  xp_reward   integer not null default 0,
  icon_emoji  text    not null default '🏆'
);

alter table public.achievements enable row level security;

create policy "anyone can read achievements"
  on public.achievements for select using (true);


-- ── Полученные достижения ─────────────────────────────────────
create table public.user_achievements (
  id             uuid        primary key default gen_random_uuid(),
  user_id        uuid        not null references public.profiles     on delete cascade,
  achievement_id uuid        not null references public.achievements on delete cascade,
  earned_at      timestamptz not null default now(),
  unique (user_id, achievement_id)
);

create index idx_user_achievements_user_id on public.user_achievements (user_id);

alter table public.user_achievements enable row level security;

-- Открытое чтение для аутентифицированных — нужно для публичного досье
create policy "authenticated can read user_achievements"
  on public.user_achievements for select using (auth.uid() is not null);

create policy "owner can insert own achievements"
  on public.user_achievements for insert with check (auth.uid() = user_id);


/* ══════════════════════════════════════════════════════════════
   8. ПРИВЫЧКИ
   ══════════════════════════════════════════════════════════════ */

create table public.habits (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references public.profiles on delete cascade,
  title       text        not null,
  description text,
  color       text        not null default '#00C8FF',
  is_pinned   boolean     not null default false,
  created_at  timestamptz not null default now()
);

alter table public.habits enable row level security;

create policy "owner can read own habits"
  on public.habits for select using (auth.uid() = user_id);

create policy "owner can insert own habits"
  on public.habits for insert with check (auth.uid() = user_id);

create policy "owner can update own habits"
  on public.habits for update using (auth.uid() = user_id);

create policy "owner can delete own habits"
  on public.habits for delete using (auth.uid() = user_id);


-- ── Журнал выполнения привычек ────────────────────────────────
create table public.habit_logs (
  id           uuid    primary key default gen_random_uuid(),
  habit_id     uuid    not null references public.habits   on delete cascade,
  user_id      uuid    not null references public.profiles on delete cascade,
  completed_at date    not null default current_date,
  xp_awarded   integer not null default 50,
  unique (habit_id, completed_at)
);

create index idx_habit_logs_user_date on public.habit_logs (user_id, completed_at);

alter table public.habit_logs enable row level security;

create policy "owner can read own habit_logs"
  on public.habit_logs for select using (auth.uid() = user_id);

create policy "owner can insert own habit_logs"
  on public.habit_logs for insert with check (auth.uid() = user_id);

create policy "owner can delete own habit_logs"
  on public.habit_logs for delete using (auth.uid() = user_id);


/* ══════════════════════════════════════════════════════════════
   9. СЕССИИ ФОКУСА (POMODORO)
   ══════════════════════════════════════════════════════════════ */

create table public.focus_sessions (
  id               uuid        primary key default gen_random_uuid(),
  user_id          uuid        not null references public.profiles on delete cascade,
  duration_seconds integer     not null,
  is_completed     boolean     not null default false,
  xp_gained        integer     not null default 0,
  created_at       timestamptz not null default now()
);

create index idx_focus_sessions_user_id on public.focus_sessions (user_id);

alter table public.focus_sessions enable row level security;

create policy "owner can read own focus_sessions"
  on public.focus_sessions for select using (auth.uid() = user_id);

create policy "owner can insert own focus_sessions"
  on public.focus_sessions for insert with check (auth.uid() = user_id);


/* ══════════════════════════════════════════════════════════════
   10. ИНВЕНТАРЬ ПОЛЬЗОВАТЕЛЯ
   ══════════════════════════════════════════════════════════════ */

create table public.user_inventory (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references public.profiles on delete cascade,
  asset_type  text        not null check (asset_type in ('avatar_frame', 'profile_background', 'stat_style')),
  asset_id    uuid        not null,
  acquired_at timestamptz not null default now(),
  unique (user_id, asset_type, asset_id)
);

create index idx_user_inventory_user_id on public.user_inventory (user_id);

alter table public.user_inventory enable row level security;

create policy "owner read own inventory"
  on public.user_inventory for select using (auth.uid() = user_id);

create policy "owner insert own inventory"
  on public.user_inventory for insert with check (auth.uid() = user_id);

create policy "owner delete own inventory"
  on public.user_inventory for delete using (auth.uid() = user_id);

grant all on public.user_inventory to authenticated;


/* ══════════════════════════════════════════════════════════════
   11. ЛИДЕРБОРД
   ══════════════════════════════════════════════════════════════ */

-- История победителей суточного цикла.
-- Заполняется award_daily_winner() каждую ночь в 00:00 UTC.
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


/* ══════════════════════════════════════════════════════════════
   12. RPC-ФУНКЦИИ
   ══════════════════════════════════════════════════════════════ */

-- ── Начисление XP ─────────────────────────────────────────────
-- Вызывается при выполнении привычки, завершении сессии фокуса
-- и получении достижения. SECURITY DEFINER: клиент не имеет
-- прямого UPDATE на profiles.
create or replace function public.increment_xp(p_user_id uuid, p_amount integer)
returns void
language sql
security definer
set search_path = public
as $$
  update public.profiles
  set total_xp = total_xp + p_amount
  where id = p_user_id;
$$;

grant execute on function public.increment_xp(uuid, integer) to authenticated;


-- ── Начисление Design Points ──────────────────────────────────
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


-- ── Атомарная покупка предмета ────────────────────────────────
-- Проверяет баланс DP, списывает цену и добавляет в инвентарь.
-- Выбрасывает INSUFFICIENT_DP если баланса не хватает.
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
  v_user_id uuid    := auth.uid();
  v_balance  integer;
begin
  select design_points
  into   v_balance
  from   public.profiles
  where  id = v_user_id
  for update;

  if not found then
    raise exception 'PROFILE_NOT_FOUND';
  end if;

  if p_price_dp > 0 and v_balance < p_price_dp then
    raise exception 'INSUFFICIENT_DP';
  end if;

  update public.profiles
  set    design_points = design_points - p_price_dp
  where  id = v_user_id;

  insert into public.user_inventory (user_id, asset_type, asset_id)
  values (v_user_id, p_asset_type, p_asset_id)
  on conflict (user_id, asset_type, asset_id) do nothing;
end;
$$;

grant execute on function public.purchase_asset(uuid, text, integer) to authenticated;


-- ── Публичная статистика оперативника ────────────────────────
-- Обходит RLS habit_logs и focus_sessions для просмотра
-- публичного досье любого пользователя.
create or replace function public.get_operative_stats(p_user_id uuid)
returns json
language sql
stable
security definer
set search_path = public
as $$
  select json_build_object(
    'habit_completions',   (
      select count(*)::integer
      from   public.habit_logs
      where  user_id = p_user_id
    ),
    'focus_total_seconds', (
      select coalesce(sum(duration_seconds), 0)::integer
      from   public.focus_sessions
      where  user_id      = p_user_id
        and  is_completed = true
    )
  );
$$;

grant execute on function public.get_operative_stats(uuid) to authenticated;


-- ── Авторитетное серверное время ──────────────────────────────
-- Клиент запрашивает один раз, вычисляет offset до UTC-полуночи
-- и тикает локально — защита от накруток через смену часового
-- пояса на устройстве.
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


-- ── Топ-50 оперативников за текущие сутки ────────────────────
-- daily_xp — это сумма XP из habit_logs + focus_sessions +
-- user_achievements, отфильтрованных по current_date (UTC).
-- Отдельного столбца daily_xp нет: при смене даты данные
-- «сбрасываются» автоматически.
create or replace function public.get_daily_leaderboard()
returns table (
  user_id                uuid,
  username               text,
  avatar_url             text,
  equipped_frame_id      uuid,
  equipped_background_id uuid,
  equipped_stat_style_id uuid,
  total_xp               integer,
  daily_xp               integer,
  rank                   bigint
)
language sql
stable
security definer
set search_path = public
as $$
  with scores as (
    select
      p.id                       as user_id,
      p.username,
      p.avatar_url,
      p.equipped_frame_id,
      p.equipped_background_id,
      p.equipped_stat_style_id,
      p.total_xp,
      (
        coalesce(
          (select sum(hl.xp_awarded)
           from   public.habit_logs hl
           where  hl.user_id      = p.id
             and  hl.completed_at = current_date),
          0
        ) +
        coalesce(
          (select sum(fs.xp_gained)
           from   public.focus_sessions fs
           where  fs.user_id      = p.id
             and  fs.is_completed = true
             and  (fs.created_at at time zone 'UTC')::date = current_date),
          0
        ) +
        coalesce(
          (select sum(a.xp_reward)
           from   public.user_achievements ua
           join   public.achievements      a on a.id = ua.achievement_id
           where  ua.user_id  = p.id
             and  (ua.earned_at at time zone 'UTC')::date = current_date),
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
  from  scores
  order by daily_xp desc, total_xp desc
  limit 50;
$$;

grant execute on function public.get_daily_leaderboard() to authenticated;


-- ── Награждение победителя предыдущего суточного цикла ────────
-- Идемпотентна: повторный вызов за одну и ту же дату — no-op.
-- Запускается pg_cron в 00:00 UTC или edge-функцией daily-winner.
create or replace function public.award_daily_winner()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_winner_id   uuid;
  v_winner_xp   integer;
  v_target_date date := current_date - 1;
begin
  -- Пропустить, если победитель за этот день уже определён
  if exists (
    select 1 from public.leaderboard_winners
    where  competition_date = v_target_date
  ) then
    return;
  end if;

  -- Найти оперативника с максимальным XP за вчерашний день
  select ds.user_id, ds.daily_xp
  into   v_winner_id, v_winner_xp
  from (
    select
      p.id as user_id,
      (
        coalesce(
          (select sum(hl.xp_awarded)
           from   public.habit_logs hl
           where  hl.user_id      = p.id
             and  hl.completed_at = v_target_date),
          0
        ) +
        coalesce(
          (select sum(fs.xp_gained)
           from   public.focus_sessions fs
           where  fs.user_id      = p.id
             and  fs.is_completed = true
             and  (fs.created_at at time zone 'UTC')::date = v_target_date),
          0
        ) +
        coalesce(
          (select sum(a.xp_reward)
           from   public.user_achievements ua
           join   public.achievements      a on a.id = ua.achievement_id
           where  ua.user_id  = p.id
             and  (ua.earned_at at time zone 'UTC')::date = v_target_date),
          0
        )
      )::integer as daily_xp
    from public.profiles p
  ) ds
  where  ds.daily_xp > 0
  order  by ds.daily_xp desc, ds.user_id  -- детерминированная сортировка при ничье
  limit  1;

  if v_winner_id is not null then
    -- Начислить 1 Design Point победителю
    update public.profiles
    set    design_points = design_points + 1
    where  id = v_winner_id;

    -- Записать в историю
    insert into public.leaderboard_winners (winner_id, xp_earned, competition_date)
    values (v_winner_id, v_winner_xp, v_target_date);
  end if;
end;
$$;


/* ══════════════════════════════════════════════════════════════
   13. STORAGE
   ══════════════════════════════════════════════════════════════ */

-- Публичный бакет для аватаров (максимум 5 МБ, только изображения)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

create policy "public read avatars"
  on storage.objects for select
  using (bucket_id = 'avatars');

create policy "users insert own avatar"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "users update own avatar"
  on storage.objects for update
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "users delete own avatar"
  on storage.objects for delete
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );


/* ══════════════════════════════════════════════════════════════
   14. НАЧАЛЬНЫЕ ДАННЫЕ (SEED)
   ══════════════════════════════════════════════════════════════ */

-- ── Отделы ────────────────────────────────────────────────────
insert into public.branches (slug, name, description) values
  ('breathing_practices', 'Breathing Practices',
   'Дыхательные практики по методу Вима Хофа. Контроль тела через дыхание.'),
  ('habit_archive',       'Habit Archive',
   'Система ежедневных привычек. Формируй дисциплину через повторение.'),
  ('focus_protocol',      'Focus Protocol',
   'Pomodoro-таймер для глубокой концентрации. 25 минут работы, 5 минут отдыха.'),
  ('progress_hub',        'Progress Hub',
   'Аналитика активности: тепловая карта, графики роста XP и статистика фокуса.')
on conflict (slug) do nothing;


-- ── Достижения ────────────────────────────────────────────────
insert into public.achievements (slug, name, description, xp_reward, icon_emoji) values
  ('first_breath',
   'Первый вдох корпорации',
   'Завершена первая сессия дыхательных практик по методу Вима Хофа.',
   50, '🌬️'),
  ('deep_focus_initiated',
   'Deep Focus Initiated',
   'Завершена первая 25-минутная сессия глубокой концентрации.',
   50, '🎯'),
  ('first_habit_created',
   'Первый Протокол Дисциплины',
   'Создана первая привычка в архиве. Начало положено.',
   25, '🌱'),
  ('data_analyst',
   'Data Analyst',
   'Открыт Центр Аналитики при наличии не менее 5 записей в логах.',
   75, '📊')
on conflict (slug) do nothing;


-- ── Рамки аватара ─────────────────────────────────────────────
insert into public.avatar_frames (slug, name, rarity, style_config, price_dp) values
  ('default',   'Стандарт',   'common',
   '{"border_color":"#005F80","border_width":1.5,"glow_radius":0}',               0),
  ('neon_blue', 'Неон Синий', 'rare',
   '{"border_color":"#00C8FF","border_width":2.0,"glow_color":"#00C8FF55","glow_radius":14}', 500),
  ('gold',      'Золотой',    'epic',
   '{"border_color":"#FFD700","border_width":2.5,"glow_color":"#FFD70055","glow_radius":16}', 1500),
  ('crimson',   'Алый',       'legendary',
   '{"border_color":"#FF3333","border_width":2.5,"glow_color":"#FF333355","glow_radius":18}', 4000)
on conflict (slug) do nothing;


-- ── Фоны профиля ──────────────────────────────────────────────
insert into public.profile_backgrounds (slug, name, rarity, style_config, price_dp) values
  ('deep_navy',   'Глубина',           'common',
   '{"gradient_colors":["#0D2A42","#071520"],"gradient_begin":"topLeft","gradient_end":"bottomRight"}',    0),
  ('data_stream', 'Поток данных',      'rare',
   '{"gradient_colors":["#0A2218","#051510"],"gradient_begin":"topRight","gradient_end":"bottomLeft"}',   500),
  ('void_space',  'Пространство',      'epic',
   '{"gradient_colors":["#150A2A","#080510"],"gradient_begin":"topCenter","gradient_end":"bottomCenter"}', 1500),
  ('crimson_ops', 'Красная операция',  'legendary',
   '{"gradient_colors":["#2A0A0A","#150505"],"gradient_begin":"topLeft","gradient_end":"bottomRight"}',   4000)
on conflict (slug) do nothing;


-- ── Стили статистики ──────────────────────────────────────────
insert into public.stat_styles (slug, name, rarity, style_config, price_dp) values
  ('terminal', 'Терминал', 'common',
   '{"accent_color":"#00C8FF","border_color":"#1A3A5C","glow_color":null,"glow_radius":0}',    0),
  ('emerald',  'Изумруд',  'rare',
   '{"accent_color":"#00FF88","border_color":"#1A3D2A","glow_color":"#00FF8820","glow_radius":6}',  500),
  ('crimson',  'Кармин',   'epic',
   '{"accent_color":"#FF4444","border_color":"#3D1A1A","glow_color":"#FF444420","glow_radius":6}',  1500),
  ('gold',     'Золото',   'legendary',
   '{"accent_color":"#FFD700","border_color":"#3D3000","glow_color":"#FFD70020","glow_radius":8}',  4000)
on conflict (slug) do nothing;


/* ══════════════════════════════════════════════════════════════
   15. РАСПИСАНИЕ (pg_cron)
   ══════════════════════════════════════════════════════════════
   pg_cron доступен на Supabase Cloud (Pro и выше).
   Локально (supabase CLI) блок выполняется, но при отсутствии
   расширения молча завершается без ошибки.
   Альтернатива: edge-функция supabase/functions/daily-winner/
   вызывается внешним cron-сервисом (GitHub Actions, cron-job.org).
   ══════════════════════════════════════════════════════════════ */

do $cron$
begin
  create extension if not exists pg_cron;
  perform cron.schedule(
    'award-daily-winner',         -- уникальное имя задачи
    '0 0 * * *',                  -- каждый день в 00:00 UTC
    'select public.award_daily_winner()'
  );
exception when others then null;
end;
$cron$ language plpgsql;
