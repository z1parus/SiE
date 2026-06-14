-- Stage 6 — Mission templates (blueprints).
-- Curated system templates + user-saved blueprints. Structure is stored as a
-- JSON document (sub-goal tree + tasks + milestones), decoupled from the
-- relational planning schema. is_public is reserved for a future community
-- library (no UI yet).

CREATE TABLE IF NOT EXISTS public.mission_templates (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid        REFERENCES public.profiles(id) ON DELETE CASCADE, -- NULL = system
  name           text        NOT NULL,
  description    text,
  category       text,
  is_system      boolean     NOT NULL DEFAULT false,
  is_public      boolean     NOT NULL DEFAULT false,
  color_hex      text        NOT NULL DEFAULT '#5AADA0',
  structure_json jsonb       NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mission_templates_user
  ON public.mission_templates(user_id);

ALTER TABLE public.mission_templates ENABLE ROW LEVEL SECURITY;

-- Read: own templates, system templates, or (future) public ones.
CREATE POLICY "Read own, system or public templates"
  ON public.mission_templates
  FOR SELECT
  USING (user_id = auth.uid() OR is_system = true OR is_public = true);

-- Insert/Update/Delete: owner only, never system templates.
CREATE POLICY "Insert own non-system templates"
  ON public.mission_templates
  FOR INSERT
  WITH CHECK (user_id = auth.uid() AND is_system = false);

CREATE POLICY "Update own non-system templates"
  ON public.mission_templates
  FOR UPDATE
  USING (user_id = auth.uid() AND is_system = false)
  WITH CHECK (user_id = auth.uid() AND is_system = false);

CREATE POLICY "Delete own non-system templates"
  ON public.mission_templates
  FOR DELETE
  USING (user_id = auth.uid() AND is_system = false);

-- ── Seed: curated system templates ──────────────────────────────────────────

INSERT INTO public.mission_templates (name, description, category, is_system, color_hex, structure_json)
VALUES
(
  'Выучить язык',
  'От алфавита до уверенного B1 — структура с лексикой, аудированием и разговорной практикой.',
  'learning', true, '#6A8ED8',
  '{
    "subGoals": [
      {"name": "Основы", "tasks": [
        {"name": "Алфавит и фонетика", "weight": 1},
        {"name": "Базовая грамматика", "weight": 3},
        {"name": "Первые 500 слов", "weight": 3}
      ]},
      {"name": "Понимание на слух", "tasks": [
        {"name": "Ежедневное аудирование", "weight": 1},
        {"name": "Подкасты для начинающих", "weight": 3},
        {"name": "Фильмы с субтитрами", "weight": 3}
      ]},
      {"name": "Говорение", "tasks": [
        {"name": "Языковой партнёр", "weight": 3},
        {"name": "Разговорный клуб", "weight": 5}
      ]}
    ],
    "milestones": [
      {"name": "Уровень A1", "kind": "binary"},
      {"name": "Словарный запас", "kind": "metric", "unit": "слов", "start_value": 0, "target_value": 2000, "direction": "up"},
      {"name": "Уровень B1", "kind": "binary"}
    ]
  }'::jsonb
),
(
  'Запустить пет-проект',
  'От идеи до первых пользователей: валидация, MVP, запуск и рост.',
  'project', true, '#5AADA0',
  '{
    "subGoals": [
      {"name": "Идея и план", "tasks": [
        {"name": "Валидация идеи", "weight": 3},
        {"name": "Определить scope MVP", "weight": 3}
      ]},
      {"name": "MVP", "tasks": [
        {"name": "Архитектура", "weight": 5},
        {"name": "Ключевые фичи", "weight": 5},
        {"name": "Базовый UI", "weight": 3}
      ]},
      {"name": "Запуск", "tasks": [
        {"name": "Деплой", "weight": 3},
        {"name": "Лендинг", "weight": 3}
      ]},
      {"name": "Рост", "tasks": [
        {"name": "Привлечь первых юзеров", "weight": 5},
        {"name": "Собрать фидбэк", "weight": 3}
      ]}
    ],
    "milestones": [
      {"name": "MVP готов", "kind": "binary"},
      {"name": "Первый пользователь", "kind": "binary"},
      {"name": "Пользователи", "kind": "metric", "unit": "юзеров", "start_value": 0, "target_value": 100, "direction": "up"}
    ]
  }'::jsonb
),
(
  'Подготовка к марафону',
  'Прогрессивный план: база, объёмы, пик и восстановление.',
  'health', true, '#E0A030',
  '{
    "subGoals": [
      {"name": "База", "tasks": [
        {"name": "Бег 3 раза в неделю", "weight": 3},
        {"name": "ОФП", "weight": 1}
      ]},
      {"name": "Объёмы", "tasks": [
        {"name": "Длинные пробежки", "weight": 5},
        {"name": "Темповые тренировки", "weight": 3}
      ]},
      {"name": "Пик и тейпер", "tasks": [
        {"name": "Контрольный полумарафон", "weight": 5},
        {"name": "Снижение нагрузки", "weight": 1}
      ]},
      {"name": "Восстановление", "tasks": [
        {"name": "Растяжка ежедневно", "weight": 1},
        {"name": "Сон и питание", "weight": 1}
      ]}
    ],
    "milestones": [
      {"name": "Пробежать 10 км", "kind": "binary"},
      {"name": "Полумарафон 21 км", "kind": "binary"},
      {"name": "Вес", "kind": "metric", "unit": "кг", "start_value": 85, "target_value": 78, "direction": "down"},
      {"name": "Марафон 42 км", "kind": "binary"}
    ]
  }'::jsonb
),
(
  'Финансовая подушка',
  'Учёт, оптимизация расходов и системное накопление резерва.',
  'project', true, '#5AADA0',
  '{
    "subGoals": [
      {"name": "Учёт", "tasks": [
        {"name": "Составить бюджет", "weight": 3},
        {"name": "Трекинг расходов", "weight": 1}
      ]},
      {"name": "Оптимизация", "tasks": [
        {"name": "Сократить подписки", "weight": 1},
        {"name": "Рефинансировать долги", "weight": 3}
      ]},
      {"name": "Накопление", "tasks": [
        {"name": "Автоплатёж на счёт", "weight": 3},
        {"name": "Дополнительный доход", "weight": 5}
      ]}
    ],
    "milestones": [
      {"name": "Накопления", "kind": "metric", "unit": "$", "start_value": 0, "target_value": 5000, "direction": "up"},
      {"name": "1 месяц расходов отложен", "kind": "binary"},
      {"name": "6 месяцев расходов отложено", "kind": "binary"}
    ]
  }'::jsonb
),
(
  'Прочитать N книг за год',
  'Список, ежедневная привычка чтения и конспекты.',
  'lifestyle', true, '#9B6AD8',
  '{
    "subGoals": [
      {"name": "Подготовка", "tasks": [
        {"name": "Составить список из 12 книг", "weight": 1}
      ]},
      {"name": "Привычка", "tasks": [
        {"name": "Читать 30 минут в день", "weight": 1},
        {"name": "Конспекты ключевых идей", "weight": 3}
      ]}
    ],
    "milestones": [
      {"name": "Прочитано книг", "kind": "metric", "unit": "книг", "start_value": 0, "target_value": 12, "direction": "up"}
    ]
  }'::jsonb
),
(
  'Сменить работу',
  'Резюме и портфолио, активный поиск, собеседования и оффер.',
  'project', true, '#6A8ED8',
  '{
    "subGoals": [
      {"name": "Подготовка", "tasks": [
        {"name": "Обновить резюме", "weight": 3},
        {"name": "Портфолио", "weight": 5},
        {"name": "Профиль LinkedIn", "weight": 1}
      ]},
      {"name": "Поиск", "tasks": [
        {"name": "Откликаться 5 раз в неделю", "weight": 3},
        {"name": "Нетворкинг", "weight": 3}
      ]},
      {"name": "Собеседования", "tasks": [
        {"name": "Подготовка к интервью", "weight": 5},
        {"name": "Тестовые задания", "weight": 5}
      ]},
      {"name": "Оффер", "tasks": [
        {"name": "Переговоры по условиям", "weight": 3}
      ]}
    ],
    "milestones": [
      {"name": "Резюме готово", "kind": "binary"},
      {"name": "Первое собеседование", "kind": "binary"},
      {"name": "Откликов отправлено", "kind": "metric", "unit": "откликов", "start_value": 0, "target_value": 50, "direction": "up"},
      {"name": "Оффер получен", "kind": "binary"}
    ]
  }'::jsonb
),
(
  'Ремонт квартиры',
  'От дизайн-проекта и сметы до чистовых работ и заселения.',
  'lifestyle', true, '#E0A030',
  '{
    "subGoals": [
      {"name": "Планирование", "tasks": [
        {"name": "Дизайн-проект", "weight": 5},
        {"name": "Смета", "weight": 3},
        {"name": "Выбор материалов", "weight": 3}
      ]},
      {"name": "Черновые работы", "tasks": [
        {"name": "Демонтаж", "weight": 3},
        {"name": "Электрика", "weight": 5},
        {"name": "Сантехника", "weight": 5}
      ]},
      {"name": "Чистовые работы", "tasks": [
        {"name": "Стены и потолок", "weight": 5},
        {"name": "Полы", "weight": 5}
      ]},
      {"name": "Финал", "tasks": [
        {"name": "Мебель", "weight": 3},
        {"name": "Декор", "weight": 1}
      ]}
    ],
    "milestones": [
      {"name": "Бюджет согласован", "kind": "binary"},
      {"name": "Черновые работы завершены", "kind": "binary"},
      {"name": "Заселение", "kind": "binary"}
    ]
  }'::jsonb
)
ON CONFLICT DO NOTHING;
