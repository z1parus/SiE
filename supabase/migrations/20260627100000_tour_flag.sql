-- Interactive onboarding tour: per-user "seen" flag (cross-device), mirroring
-- the existing has_seen_onboarding_* columns.

alter table public.profiles
  add column if not exists has_seen_tour boolean not null default false;
