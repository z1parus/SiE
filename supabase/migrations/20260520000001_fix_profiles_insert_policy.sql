-- Allow the postgres role (SECURITY DEFINER trigger owner) to insert new profiles.
-- Without this, handle_new_user() fails because RLS on profiles has no INSERT policy
-- and postgres is not a superuser in this Supabase instance.
create policy "postgres role can insert profiles"
  on public.profiles for insert
  to postgres
  with check (true);
