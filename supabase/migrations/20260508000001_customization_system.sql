-- ── Enums ────────────────────────────────────────────────────

create type public.cosmetic_rarity as enum ('common', 'rare', 'epic', 'legendary');

-- ── Catalog tables ────────────────────────────────────────────

create table public.avatar_frames (
  id           uuid              primary key default gen_random_uuid(),
  slug         text              not null unique,
  name         text              not null,
  image_url    text,
  rarity       public.cosmetic_rarity not null default 'common',
  style_config jsonb             not null default '{}'
);

create table public.profile_backgrounds (
  id           uuid              primary key default gen_random_uuid(),
  slug         text              not null unique,
  name         text              not null,
  image_url    text,
  rarity       public.cosmetic_rarity not null default 'common',
  style_config jsonb             not null default '{}'
);

create table public.stat_styles (
  id           uuid              primary key default gen_random_uuid(),
  slug         text              not null unique,
  name         text              not null,
  rarity       public.cosmetic_rarity not null default 'common',
  style_config jsonb             not null default '{}'
);

-- ── User inventory ────────────────────────────────────────────

create table public.user_inventory (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles on delete cascade,
  asset_type  text not null check (asset_type in ('avatar_frame','profile_background','stat_style')),
  asset_id    uuid not null,
  acquired_at timestamptz not null default now(),
  unique(user_id, asset_type, asset_id)
);

create index idx_user_inventory_user_id on public.user_inventory (user_id);

-- ── Drop legacy text columns, add UUID equipped slots ─────────

alter table public.profiles
  drop column if exists avatar_frame_id,
  drop column if exists profile_background_url,
  add column if not exists equipped_frame_id      uuid references public.avatar_frames(id)      on delete set null,
  add column if not exists equipped_background_id uuid references public.profile_backgrounds(id) on delete set null,
  add column if not exists equipped_stat_style_id uuid references public.stat_styles(id)         on delete set null;

-- ── RLS ───────────────────────────────────────────────────────

alter table public.avatar_frames       enable row level security;
alter table public.profile_backgrounds enable row level security;
alter table public.stat_styles         enable row level security;
alter table public.user_inventory      enable row level security;

create policy "public read avatar_frames"
  on public.avatar_frames for select using (true);

create policy "public read profile_backgrounds"
  on public.profile_backgrounds for select using (true);

create policy "public read stat_styles"
  on public.stat_styles for select using (true);

create policy "owner read own inventory"
  on public.user_inventory for select using (auth.uid() = user_id);

create policy "owner insert own inventory"
  on public.user_inventory for insert with check (auth.uid() = user_id);

create policy "owner delete own inventory"
  on public.user_inventory for delete using (auth.uid() = user_id);

grant select on public.avatar_frames       to authenticated, anon;
grant select on public.profile_backgrounds to authenticated, anon;
grant select on public.stat_styles         to authenticated, anon;
grant all    on public.user_inventory      to authenticated;

-- ── Seed: Avatar Frames ───────────────────────────────────────

insert into public.avatar_frames (slug, name, rarity, style_config) values
  ('default',    'Стандарт',   'common',    '{"border_color":"#005F80","border_width":1.5,"glow_radius":0}'),
  ('neon_blue',  'Неон Синий', 'rare',      '{"border_color":"#00C8FF","border_width":2.0,"glow_color":"#00C8FF55","glow_radius":14}'),
  ('gold',       'Золотой',    'epic',      '{"border_color":"#FFD700","border_width":2.5,"glow_color":"#FFD70055","glow_radius":16}'),
  ('crimson',    'Алый',       'legendary', '{"border_color":"#FF3333","border_width":2.5,"glow_color":"#FF333355","glow_radius":18}');

-- ── Seed: Profile Backgrounds ─────────────────────────────────

insert into public.profile_backgrounds (slug, name, rarity, style_config) values
  ('deep_navy',   'Глубина',          'common',    '{"gradient_colors":["#0D2A42","#071520"],"gradient_begin":"topLeft","gradient_end":"bottomRight"}'),
  ('data_stream', 'Поток данных',     'rare',      '{"gradient_colors":["#0A2218","#051510"],"gradient_begin":"topRight","gradient_end":"bottomLeft"}'),
  ('void_space',  'Пространство',     'epic',      '{"gradient_colors":["#150A2A","#080510"],"gradient_begin":"topCenter","gradient_end":"bottomCenter"}'),
  ('crimson_ops', 'Красная операция', 'legendary', '{"gradient_colors":["#2A0A0A","#150505"],"gradient_begin":"topLeft","gradient_end":"bottomRight"}');

-- ── Seed: Stat Styles ─────────────────────────────────────────

insert into public.stat_styles (slug, name, rarity, style_config) values
  ('terminal', 'Терминал', 'common',    '{"accent_color":"#00C8FF","border_color":"#1A3A5C","glow_color":null,"glow_radius":0}'),
  ('emerald',  'Изумруд',  'rare',      '{"accent_color":"#00FF88","border_color":"#1A3D2A","glow_color":"#00FF8820","glow_radius":6}'),
  ('crimson',  'Кармин',   'epic',      '{"accent_color":"#FF4444","border_color":"#3D1A1A","glow_color":"#FF444420","glow_radius":6}'),
  ('gold',     'Золото',   'legendary', '{"accent_color":"#FFD700","border_color":"#3D3000","glow_color":"#FFD70020","glow_radius":8}');
