import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

/// Which tool screen a task links to.
enum BootcampTaskDestination { breathing, focusForge, habitArchive }

// ─────────────────────────────────────────────────────────────────────────────
// BootcampDailyActivity — today's real tool usage snapshot
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class BootcampDailyActivity {
  final int breathingSessionsToday;
  final int focusSessionsToday;
  final bool hasHabitLogToday;

  const BootcampDailyActivity({
    required this.breathingSessionsToday,
    required this.focusSessionsToday,
    required this.hasHabitLogToday,
  });

  /// Empty snapshot — used when user is unauthenticated or DB unavailable.
  static const empty = BootcampDailyActivity(
    breathingSessionsToday: 0,
    focusSessionsToday: 0,
    hasHabitLogToday: false,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// BootcampTask
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class BootcampTask {
  final String id;
  final String title;
  final String description;
  final BootcampTaskDestination destination;
  final IconData icon;

  const BootcampTask({
    required this.id,
    required this.title,
    required this.description,
    required this.destination,
    required this.icon,
  });

  /// Returns true when today's real activity satisfies this task.
  bool isAutoComplete(BootcampDailyActivity activity) =>
      switch (destination) {
        BootcampTaskDestination.breathing    => activity.breathingSessionsToday > 0,
        BootcampTaskDestination.focusForge   => activity.focusSessionsToday > 0,
        BootcampTaskDestination.habitArchive => activity.hasHabitLogToday,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// BootcampDay
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class BootcampDay {
  final int dayNumber;
  final String title;
  final String storyTransmission;
  final List<BootcampTask> tasks;

  const BootcampDay({
    required this.dayNumber,
    required this.title,
    required this.storyTransmission,
    required this.tasks,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// 7-Day Course Definition — static manifest
// ─────────────────────────────────────────────────────────────────────────────

const List<BootcampDay> kBootcampCourse = [
  // ── DAY 1 ──────────────────────────────────────────────────────────────────
  BootcampDay(
    dayNumber: 1,
    title: 'ДЫХАНИЕ КАК ОРУЖИЕ',
    storyTransmission:
        'ТРАНСМИССИЯ #001 — ВВОДНЫЙ ИНСТРУКТАЖ\n\n'
        'Оперативник. Вы подключились к системе.\n\n'
        'Корпорация SiE разработала 7-дневный протокол базовой '
        'психофизической подготовки. Каждый день — один новый инструмент. '
        'Каждый инструмент — прирост эффективности.\n\n'
        'Стресс — главный враг продуктивности. Техника дыхания 4-7-8 '
        'активирует парасимпатическую нервную систему за 90 секунд. '
        'Кортизол снижается. Фокус восстанавливается.\n\n'
        'Это не медитация. Это тактический протокол.',
    tasks: [
      BootcampTask(
        id: 'd1_breathing',
        title: 'Дыхательная практика',
        description: 'Выполни одну сессию дыхательной практики',
        destination: BootcampTaskDestination.breathing,
        icon: Icons.air,
      ),
    ],
  ),

  // ── DAY 2 ──────────────────────────────────────────────────────────────────
  BootcampDay(
    dayNumber: 2,
    title: 'ФОКУС-ПРОТОКОЛ',
    storyTransmission:
        'ТРАНСМИССИЯ #002 — ПРОТОКОЛ КОНЦЕНТРАЦИИ\n\n'
        'Данные дня первого получены. Дыхательный канал открыт.\n\n'
        'Большинство людей работают в режиме постоянного переключения '
        'между задачами. КПД — около 40%. Корпорация SiE работает иначе.\n\n'
        'Focus Forge — инструмент глубокого фокуса. 25 минут полного '
        'погружения в одну задачу. Без уведомлений. Без переключений. '
        'Нейронные паттерны перестраиваются уже после первой сессии.\n\n'
        'Запусти Focus Forge. Выбери задачу. Начни.',
    tasks: [
      BootcampTask(
        id: 'd2_focus',
        title: 'Фокус-сессия 25 минут',
        description: 'Проведи рабочую сессию не менее 25 минут через Focus Forge',
        destination: BootcampTaskDestination.focusForge,
        icon: Icons.timer_outlined,
      ),
    ],
  ),

  // ── DAY 3 ──────────────────────────────────────────────────────────────────
  BootcampDay(
    dayNumber: 3,
    title: 'АРХИВ ПРИВЫЧЕК',
    storyTransmission:
        'ТРАНСМИССИЯ #003 — СИСТЕМНАЯ ИНИЦИАЛИЗАЦИЯ\n\n'
        'Дыхание. Фокус. Теперь — системы.\n\n'
        'Корпорация SiE строится на одном принципе: великие результаты — '
        'следствие ежедневных микродействий. Не героических усилий раз в год.\n\n'
        'Habit Archive — инструмент отслеживания привычек. Создай первую '
        'привычку. Это может быть что угодно: стакан воды утром, '
        '10 отжиманий, 5 минут чтения. Важна не привычка — важна система.',
    tasks: [
      BootcampTask(
        id: 'd3_habit',
        title: 'Создай и отметь привычку',
        description: 'Открой Habit Archive, создай привычку и отметь её выполнение',
        destination: BootcampTaskDestination.habitArchive,
        icon: Icons.check_circle_outline,
      ),
      BootcampTask(
        id: 'd3_breathing',
        title: 'Дыхательная практика',
        description: 'Поддержи дыхательный протокол — ещё одна сессия',
        destination: BootcampTaskDestination.breathing,
        icon: Icons.air,
      ),
    ],
  ),

  // ── DAY 4 ──────────────────────────────────────────────────────────────────
  BootcampDay(
    dayNumber: 4,
    title: 'ДВОЙНОЙ ПРОТОКОЛ',
    storyTransmission:
        'ТРАНСМИССИЯ #004 — КОМБИНИРОВАННЫЙ РЕЖИМ\n\n'
        'Четыре дня. Нейронный паттерн закрепляется.\n\n'
        'Исследования нейрофизиологии: сочетание дыхательной практики '
        'перед рабочей сессией увеличивает качество фокуса на 31%. '
        'Дыхание снижает фоновый шум. Фокус использует эту тишину.\n\n'
        'Сегодня — двойной протокол. Сначала дыши. Потом работай.',
    tasks: [
      BootcampTask(
        id: 'd4_breathing',
        title: 'Дыхательная практика',
        description: 'Выполни дыхательную практику перед рабочей сессией',
        destination: BootcampTaskDestination.breathing,
        icon: Icons.air,
      ),
      BootcampTask(
        id: 'd4_focus',
        title: 'Фокус-сессия',
        description: 'Запусти фокус-сессию сразу после дыхательной практики',
        destination: BootcampTaskDestination.focusForge,
        icon: Icons.timer_outlined,
      ),
    ],
  ),

  // ── DAY 5 ──────────────────────────────────────────────────────────────────
  BootcampDay(
    dayNumber: 5,
    title: 'ТРОЙНОЙ ЦИКЛ',
    storyTransmission:
        'ТРАНСМИССИЯ #005 — ТОЧКА НЕВОЗВРАТА\n\n'
        'Пять дней. Поздравляем, оперативник.\n\n'
        'Психологи называют это точкой невозврата. После пяти дней '
        'последовательного действия вероятность продолжения превышает 80%.\n\n'
        'Ваш мозг начал переписывать нейронные дорожки. Инструменты SiE '
        'перестают быть "приложениями" — они становятся частью протокола. '
        'Сегодня — полный цикл: дыхание, фокус, привычки.',
    tasks: [
      BootcampTask(
        id: 'd5_breathing',
        title: 'Дыхательная практика',
        description: 'Стартовый дыхательный протокол дня',
        destination: BootcampTaskDestination.breathing,
        icon: Icons.air,
      ),
      BootcampTask(
        id: 'd5_focus',
        title: 'Фокус-сессия',
        description: 'Глубокая рабочая сессия',
        destination: BootcampTaskDestination.focusForge,
        icon: Icons.timer_outlined,
      ),
      BootcampTask(
        id: 'd5_habit',
        title: 'Отметь привычку',
        description: 'Зафиксируй ежедневное действие в Habit Archive',
        destination: BootcampTaskDestination.habitArchive,
        icon: Icons.check_circle_outline,
      ),
    ],
  ),

  // ── DAY 6 ──────────────────────────────────────────────────────────────────
  BootcampDay(
    dayNumber: 6,
    title: 'ПРЕДФИНАЛЬНЫЙ РУБЕЖ',
    storyTransmission:
        'ТРАНСМИССИЯ #006 — ПРЕДФИНАЛЬНЫЙ ПРОТОКОЛ\n\n'
        'Шестой день. Один остался.\n\n'
        'Большинство людей, начав что-то новое, останавливаются именно '
        'здесь — между "начал" и "завершил". Не потому что трудно. '
        'Потому что привычка ещё не стала автоматической.\n\n'
        'Вы дошли до шестого дня. Это уже статистика: верхние 20%.\n\n'
        'Завтра — финал. Значок ждёт.',
    tasks: [
      BootcampTask(
        id: 'd6_breathing',
        title: 'Дыхательная практика',
        description: 'Дыхательный протокол шестого дня',
        destination: BootcampTaskDestination.breathing,
        icon: Icons.air,
      ),
      BootcampTask(
        id: 'd6_focus',
        title: 'Фокус-сессия',
        description: 'Продуктивная рабочая сессия',
        destination: BootcampTaskDestination.focusForge,
        icon: Icons.timer_outlined,
      ),
      BootcampTask(
        id: 'd6_habit',
        title: 'Отметь привычку',
        description: 'Ежедневный ритуал в Habit Archive',
        destination: BootcampTaskDestination.habitArchive,
        icon: Icons.check_circle_outline,
      ),
    ],
  ),

  // ── DAY 7 ──────────────────────────────────────────────────────────────────
  BootcampDay(
    dayNumber: 7,
    title: 'ФИНАЛЬНАЯ СЕРТИФИКАЦИЯ',
    storyTransmission:
        'ТРАНСМИССИЯ #007 — ФИНАЛ\n\n'
        'Последний день базового протокола.\n\n'
        'Семь дней — один полный цикл трансформации. Корпорация SiE '
        'фиксирует: оперативник освоил базовый стек инструментов '
        'саморазвития.\n\n'
        'По завершении вы получите легендарный значок «Испытатель» — '
        'токен корпоративного доверия. Доступ к расширенным протоколам '
        'будет открыт.\n\n'
        'Завершите последний цикл. Получите сертификат.',
    tasks: [
      BootcampTask(
        id: 'd7_breathing',
        title: 'Финальная дыхательная практика',
        description: 'Завершающая дыхательная сессия протокола',
        destination: BootcampTaskDestination.breathing,
        icon: Icons.air,
      ),
      BootcampTask(
        id: 'd7_focus',
        title: 'Финальная фокус-сессия',
        description: 'Последняя сессия глубокого фокуса',
        destination: BootcampTaskDestination.focusForge,
        icon: Icons.timer_outlined,
      ),
      BootcampTask(
        id: 'd7_habit',
        title: 'Финальная отметка привычки',
        description: 'Зафиксируй последний день в Habit Archive',
        destination: BootcampTaskDestination.habitArchive,
        icon: Icons.check_circle_outline,
      ),
    ],
  ),
];
