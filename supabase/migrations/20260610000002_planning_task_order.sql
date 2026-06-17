-- Add order_index to planning_tasks for drag-to-reorder in list mode
ALTER TABLE public.planning_tasks
  ADD COLUMN IF NOT EXISTS order_index INTEGER DEFAULT 0;
