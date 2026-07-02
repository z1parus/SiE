-- Tips localization — store both Russian (canonical) and English copy so the
-- daily hint banner can be shown in the user's language. Existing rows hold
-- Russian text in title/description; the new *_en columns hold the English
-- version (the app falls back to the Russian copy when *_en is empty).

ALTER TABLE public.tips
  ADD COLUMN IF NOT EXISTS title_en       text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS description_en text NOT NULL DEFAULT '';

-- Backfill English copy for the seeded system tips.
UPDATE public.tips SET title_en = 'Home-screen widgets',
  description_en = 'You can place SiE widgets on your phone''s home screen for quick access to breathing, focus, habits and missions.'
  WHERE title = 'Виджеты на рабочем столе' AND title_en = '';

UPDATE public.tips SET title_en = 'Shared goals',
  description_en = 'Invite an operative to your mission and work on tasks together in real time on the Tactical Map.'
  WHERE title = 'Совместные цели' AND title_en = '';

UPDATE public.tips SET title_en = 'Breathing practices',
  description_en = 'The Wim Hof method is built right into the app — 3 minutes of breathing lowers stress and sharpens focus.'
  WHERE title = 'Дыхательные практики' AND title_en = '';

UPDATE public.tips SET title_en = 'Streak bonuses',
  description_en = 'Keep a habit streak for 7 days for a x1.5 multiplier and 30 days for x2.0 toward your goal progress.'
  WHERE title = 'Стрик-бонусы' AND title_en = '';

UPDATE public.tips SET title_en = 'Weekly review',
  description_en = 'Run a review every week — it builds a review streak and helps you stay focused on what matters most.'
  WHERE title = 'Еженедельный обзор' AND title_en = '';
