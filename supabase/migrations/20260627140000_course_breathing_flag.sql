-- Breathing module interactive course: per-user "seen" flag.
alter table public.profiles
  add column if not exists has_seen_course_breathing boolean not null default false;
