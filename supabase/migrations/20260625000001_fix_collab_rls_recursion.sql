-- Fix: shared goals stop loading after a collaborator accepts an invitation.
--
-- The `goals` SELECT policy references `goal_collaborators`, whose own SELECT
-- policy references `goals` back — a mutually-recursive policy graph. As long
-- as `auth.uid() = user_id` short-circuits (owner reading their own goals) the
-- recursive branch is never evaluated, so it "works". But once a user reads a
-- goal they do NOT own (a goal shared with them), Postgres must evaluate the
-- cross-table branch and raises:
--   "infinite recursion detected in policy for relation \"goals\""
-- The whole goals query then fails and the planning list falls back to (often
-- empty) local cache — i.e. goals "disappear" right after accepting an invite.
--
-- Canonical fix: move the cross-table checks into SECURITY DEFINER helper
-- functions. Inside a SECURITY DEFINER function RLS is not re-applied, so the
-- policy cycle is broken while behaviour stays identical.

-- ── Recursion-safe helpers ────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.is_accepted_collaborator(p_goal_id uuid)
  RETURNS boolean
  LANGUAGE sql
  SECURITY DEFINER
  STABLE
  SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.goal_collaborators gc
    WHERE gc.goal_id = p_goal_id
      AND gc.user_id = auth.uid()
      AND gc.status = 'accepted'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_goal_owner(p_goal_id uuid)
  RETURNS boolean
  LANGUAGE sql
  SECURITY DEFINER
  STABLE
  SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.goals g
    WHERE g.id = p_goal_id
      AND g.user_id = auth.uid()
  );
$$;

REVOKE ALL ON FUNCTION public.is_accepted_collaborator(uuid) FROM public;
REVOKE ALL ON FUNCTION public.is_goal_owner(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.is_accepted_collaborator(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_goal_owner(uuid) TO authenticated;

-- ── Break the cycle on goals ──────────────────────────────────────────────────

DROP POLICY IF EXISTS "goals_select" ON public.goals;
CREATE POLICY "goals_select" ON public.goals FOR SELECT
  USING (
    auth.uid() = user_id
    OR public.is_accepted_collaborator(id)
  );

-- ── Break the cycle on goal_collaborators ─────────────────────────────────────

DROP POLICY IF EXISTS "gc_select" ON public.goal_collaborators;
CREATE POLICY "gc_select" ON public.goal_collaborators FOR SELECT
  USING (
    auth.uid() = user_id
    OR auth.uid() = invited_by
    OR public.is_goal_owner(goal_id)
  );
