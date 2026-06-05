-- Replace the existing habit_id+completed_at unique constraint with one that
-- explicitly includes user_id. Functionally equivalent given that each habit
-- belongs to exactly one user, but makes the intent clear and ensures
-- (user_id, habit_id, completed_at) is always enforced at the DB level —
-- matching the client-side duplicate-log guard added in the same fix.

alter table public.habit_logs
  drop constraint if exists habit_logs_habit_id_completed_at_key;

alter table public.habit_logs
  add constraint habit_logs_user_habit_date_unique
  unique (user_id, habit_id, completed_at);
