-- Add icon_emoji column and update existing seed data
alter table public.achievements
  add column if not exists icon_emoji text not null default '🏆';

update public.achievements set icon_emoji = '🌬️' where slug = 'first_breath';
