-- Tool onboarding flags per module
alter table public.profiles
  add column if not exists has_seen_onboarding_breathing boolean not null default false,
  add column if not exists has_seen_onboarding_habits    boolean not null default false,
  add column if not exists has_seen_onboarding_focus     boolean not null default false;
