-- ── goal_collaborators table ──────────────────────────────────────────────────

CREATE TABLE public.goal_collaborators (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id     UUID NOT NULL REFERENCES public.goals(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  invited_by  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role        TEXT NOT NULL DEFAULT 'viewer' CHECK (role IN ('viewer', 'editor')),
  status      TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(goal_id, user_id)
);

ALTER TABLE public.goal_collaborators ENABLE ROW LEVEL SECURITY;

-- Читать: владелец цели, сам приглашённый, пригласивший
CREATE POLICY "gc_select" ON public.goal_collaborators FOR SELECT
  USING (
    auth.uid() = user_id OR
    auth.uid() = invited_by OR
    EXISTS (SELECT 1 FROM public.goals g WHERE g.id = goal_id AND g.user_id = auth.uid())
  );

-- Вставлять: только владелец цели
CREATE POLICY "gc_insert" ON public.goal_collaborators FOR INSERT
  WITH CHECK (
    auth.uid() = invited_by AND
    EXISTS (SELECT 1 FROM public.goals g WHERE g.id = goal_id AND g.user_id = auth.uid())
  );

-- Обновлять: владелец цели (меняет роль) ИЛИ приглашённый (меняет статус)
CREATE POLICY "gc_update" ON public.goal_collaborators FOR UPDATE
  USING (
    auth.uid() = user_id OR
    EXISTS (SELECT 1 FROM public.goals g WHERE g.id = goal_id AND g.user_id = auth.uid())
  );

-- Удалять: владелец цели ИЛИ сам участник
CREATE POLICY "gc_delete" ON public.goal_collaborators FOR DELETE
  USING (
    auth.uid() = user_id OR
    EXISTS (SELECT 1 FROM public.goals g WHERE g.id = goal_id AND g.user_id = auth.uid())
  );

-- ── Лимит 10 коллабораторов на цель ──────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.check_collaborator_limit()
  RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF (
    SELECT COUNT(*) FROM public.goal_collaborators
    WHERE goal_id = NEW.goal_id AND status != 'declined'
  ) >= 10 THEN
    RAISE EXCEPTION 'collaborator_limit_exceeded';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER collaborator_limit_check
  BEFORE INSERT ON public.goal_collaborators
  FOR EACH ROW EXECUTE FUNCTION public.check_collaborator_limit();

-- ── Обновлённые RLS для goals ─────────────────────────────────────────────────

DROP POLICY "own goals" ON public.goals;

-- SELECT: владелец ИЛИ принятый коллаборатор
CREATE POLICY "goals_select" ON public.goals FOR SELECT
  USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM public.goal_collaborators gc
      WHERE gc.goal_id = goals.id
        AND gc.user_id = auth.uid()
        AND gc.status = 'accepted'
    )
  );

-- Запись: только владелец
CREATE POLICY "goals_insert" ON public.goals FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "goals_update" ON public.goals FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "goals_delete" ON public.goals FOR DELETE
  USING (auth.uid() = user_id);

-- ── Обновлённые RLS для sub_goals ────────────────────────────────────────────

DROP POLICY "own sub_goals" ON public.sub_goals;

CREATE POLICY "sub_goals_select" ON public.sub_goals FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.goals g
      WHERE g.id = sub_goals.goal_id
        AND (
          g.user_id = auth.uid() OR
          EXISTS (
            SELECT 1 FROM public.goal_collaborators gc
            WHERE gc.goal_id = g.id AND gc.user_id = auth.uid() AND gc.status = 'accepted'
          )
        )
    )
  );

CREATE POLICY "sub_goals_insert" ON public.sub_goals FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.goals g
      LEFT JOIN public.goal_collaborators gc
        ON gc.goal_id = g.id AND gc.user_id = auth.uid()
           AND gc.status = 'accepted' AND gc.role = 'editor'
      WHERE g.id = sub_goals.goal_id
        AND (g.user_id = auth.uid() OR gc.id IS NOT NULL)
    )
  );

CREATE POLICY "sub_goals_update" ON public.sub_goals FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.goals g
      LEFT JOIN public.goal_collaborators gc
        ON gc.goal_id = g.id AND gc.user_id = auth.uid()
           AND gc.status = 'accepted' AND gc.role = 'editor'
      WHERE g.id = sub_goals.goal_id
        AND (g.user_id = auth.uid() OR gc.id IS NOT NULL)
    )
  );

CREATE POLICY "sub_goals_delete" ON public.sub_goals FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.goals g
      LEFT JOIN public.goal_collaborators gc
        ON gc.goal_id = g.id AND gc.user_id = auth.uid()
           AND gc.status = 'accepted' AND gc.role = 'editor'
      WHERE g.id = sub_goals.goal_id
        AND (g.user_id = auth.uid() OR gc.id IS NOT NULL)
    )
  );

-- ── Обновлённые RLS для planning_tasks ───────────────────────────────────────

DROP POLICY "own planning_tasks" ON public.planning_tasks;

CREATE POLICY "planning_tasks_select" ON public.planning_tasks FOR SELECT
  USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM public.sub_goals sg
      JOIN public.goals g ON g.id = sg.goal_id
      WHERE sg.id = planning_tasks.sub_goal_id
        AND (
          g.user_id = auth.uid() OR
          EXISTS (
            SELECT 1 FROM public.goal_collaborators gc
            WHERE gc.goal_id = g.id AND gc.user_id = auth.uid() AND gc.status = 'accepted'
          )
        )
    )
  );

CREATE POLICY "planning_tasks_insert" ON public.planning_tasks FOR INSERT
  WITH CHECK (
    auth.uid() = user_id AND
    EXISTS (
      SELECT 1 FROM public.sub_goals sg
      JOIN public.goals g ON g.id = sg.goal_id
      LEFT JOIN public.goal_collaborators gc
        ON gc.goal_id = g.id AND gc.user_id = auth.uid()
           AND gc.status = 'accepted' AND gc.role = 'editor'
      WHERE sg.id = planning_tasks.sub_goal_id
        AND (g.user_id = auth.uid() OR gc.id IS NOT NULL)
    )
  );

CREATE POLICY "planning_tasks_update" ON public.planning_tasks FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.sub_goals sg
      JOIN public.goals g ON g.id = sg.goal_id
      LEFT JOIN public.goal_collaborators gc
        ON gc.goal_id = g.id AND gc.user_id = auth.uid()
           AND gc.status = 'accepted' AND gc.role = 'editor'
      WHERE sg.id = planning_tasks.sub_goal_id
        AND (g.user_id = auth.uid() OR gc.id IS NOT NULL)
    )
  );

CREATE POLICY "planning_tasks_delete" ON public.planning_tasks FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.sub_goals sg
      JOIN public.goals g ON g.id = sg.goal_id
      LEFT JOIN public.goal_collaborators gc
        ON gc.goal_id = g.id AND gc.user_id = auth.uid()
           AND gc.status = 'accepted' AND gc.role = 'editor'
      WHERE sg.id = planning_tasks.sub_goal_id
        AND (g.user_id = auth.uid() OR gc.id IS NOT NULL)
    )
  );

-- ── Обновлённые RLS для milestones ───────────────────────────────────────────

DROP POLICY "own milestones" ON public.milestones;

CREATE POLICY "milestones_select" ON public.milestones FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.goals g
      WHERE g.id = milestones.goal_id
        AND (
          g.user_id = auth.uid() OR
          EXISTS (
            SELECT 1 FROM public.goal_collaborators gc
            WHERE gc.goal_id = g.id AND gc.user_id = auth.uid() AND gc.status = 'accepted'
          )
        )
    )
  );

CREATE POLICY "milestones_insert" ON public.milestones FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.goals g
      LEFT JOIN public.goal_collaborators gc
        ON gc.goal_id = g.id AND gc.user_id = auth.uid()
           AND gc.status = 'accepted' AND gc.role = 'editor'
      WHERE g.id = milestones.goal_id
        AND (g.user_id = auth.uid() OR gc.id IS NOT NULL)
    )
  );

CREATE POLICY "milestones_update" ON public.milestones FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.goals g
      LEFT JOIN public.goal_collaborators gc
        ON gc.goal_id = g.id AND gc.user_id = auth.uid()
           AND gc.status = 'accepted' AND gc.role = 'editor'
      WHERE g.id = milestones.goal_id
        AND (g.user_id = auth.uid() OR gc.id IS NOT NULL)
    )
  );

CREATE POLICY "milestones_delete" ON public.milestones FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.goals g
      LEFT JOIN public.goal_collaborators gc
        ON gc.goal_id = g.id AND gc.user_id = auth.uid()
           AND gc.status = 'accepted' AND gc.role = 'editor'
      WHERE g.id = milestones.goal_id
        AND (g.user_id = auth.uid() OR gc.id IS NOT NULL)
    )
  );

-- ── Обновлённые RLS для goal_habit_links ─────────────────────────────────────

DROP POLICY "own goal_habit_links" ON public.goal_habit_links;

CREATE POLICY "goal_habit_links_select" ON public.goal_habit_links FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.goals g
      WHERE g.id = goal_habit_links.goal_id
        AND (
          g.user_id = auth.uid() OR
          EXISTS (
            SELECT 1 FROM public.goal_collaborators gc
            WHERE gc.goal_id = g.id AND gc.user_id = auth.uid() AND gc.status = 'accepted'
          )
        )
    )
  );

-- Ссылки на привычки — только владелец цели
CREATE POLICY "goal_habit_links_write" ON public.goal_habit_links FOR ALL
  USING (
    EXISTS (SELECT 1 FROM public.goals g WHERE g.id = goal_habit_links.goal_id AND g.user_id = auth.uid())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.goals g WHERE g.id = goal_habit_links.goal_id AND g.user_id = auth.uid())
  );

-- ── Триггер уведомлений о совместной работе ───────────────────────────────────

CREATE OR REPLACE FUNCTION public.create_collaboration_notifications()
  RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_goal_name TEXT;
BEGIN
  SELECT name INTO v_goal_name FROM public.goals WHERE id = NEW.goal_id;

  IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
    INSERT INTO public.notifications (user_id, type, from_user_id, payload)
    VALUES (
      NEW.user_id,
      'goal_collaboration_invite',
      NEW.invited_by,
      jsonb_build_object('goal_id', NEW.goal_id, 'goal_name', v_goal_name)
    );

  ELSIF TG_OP = 'UPDATE' AND OLD.status = 'pending' AND NEW.status = 'accepted' THEN
    INSERT INTO public.notifications (user_id, type, from_user_id, payload)
    VALUES (
      NEW.invited_by,
      'goal_collaboration_accepted',
      NEW.user_id,
      jsonb_build_object('goal_id', NEW.goal_id, 'goal_name', v_goal_name)
    );
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER collaboration_notifications
  AFTER INSERT OR UPDATE ON public.goal_collaborators
  FOR EACH ROW EXECUTE FUNCTION public.create_collaboration_notifications();
