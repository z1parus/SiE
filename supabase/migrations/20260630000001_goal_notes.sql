-- Journal of Notes (Журнал Заметок) for Planning goals.
-- Each goal has a journal of quick notes (title + body) — fast memos the user
-- doesn't want to forget. Notes are shared with the goal: visible and editable
-- by the owner and any accepted collaborator, exactly like tasks/attachments.

CREATE TABLE IF NOT EXISTS public.goal_notes (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id    uuid NOT NULL REFERENCES public.goals(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE, -- author
  title      text,
  body       text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_goal_notes_goal ON public.goal_notes(goal_id);

ALTER TABLE public.goal_notes ENABLE ROW LEVEL SECURITY;

-- SELECT: goal owner OR any accepted collaborator.
CREATE POLICY "goal_notes: select own or collaborator" ON public.goal_notes
  FOR SELECT USING (
    goal_id IN (
      SELECT id FROM public.goals WHERE user_id = auth.uid()
      UNION
      SELECT goal_id FROM public.goal_collaborators
        WHERE user_id = auth.uid() AND status = 'accepted'
    )
  );

-- INSERT: owner or accepted editor; author must be the current user.
CREATE POLICY "goal_notes: insert own or editor" ON public.goal_notes
  FOR INSERT WITH CHECK (
    user_id = auth.uid() AND (
      goal_id IN (SELECT id FROM public.goals WHERE user_id = auth.uid())
      OR goal_id IN (
        SELECT goal_id FROM public.goal_collaborators
          WHERE user_id = auth.uid() AND status = 'accepted' AND role = 'editor'
      )
    )
  );

-- UPDATE: owner or accepted editor (anyone with edit rights on the goal).
CREATE POLICY "goal_notes: update own or editor" ON public.goal_notes
  FOR UPDATE USING (
    goal_id IN (
      SELECT id FROM public.goals WHERE user_id = auth.uid()
      UNION
      SELECT goal_id FROM public.goal_collaborators
        WHERE user_id = auth.uid() AND status = 'accepted' AND role = 'editor'
    )
  );

-- DELETE: the goal owner OR the note's author.
CREATE POLICY "goal_notes: delete owner or author" ON public.goal_notes
  FOR DELETE USING (
    user_id = auth.uid() OR
    goal_id IN (SELECT id FROM public.goals WHERE user_id = auth.uid())
  );
