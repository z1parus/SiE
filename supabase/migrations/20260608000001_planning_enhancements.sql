-- Add updated_at trigger for goals table (stagnation tracking)
create or replace function update_updated_at_column()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger goals_updated_at
  before update on public.goals
  for each row execute procedure update_updated_at_column();

-- Add boost_value to goal_habit_links (habit synergy daily boost)
alter table public.goal_habit_links
  add column if not exists boost_value real not null default 0.5;
