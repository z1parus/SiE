import 'life_area.dart';

/// A curated, ready-made habit configuration (Stage 8 — habit library).
///
/// Instantiating a template = creating a [Habit] with its pre-filled
/// type/target/unit/schedule/icon/colour/polarity, removing the friction of
/// configuring a habit from scratch.
class HabitTemplate {
  final String id;
  final String name;
  final String? description;
  final LifeArea? area;
  final String kind; // 'binary' | 'count' | 'duration'
  final double? targetValue; // duration stored in seconds
  final String? unit;
  final double? step;
  final String defaultSchedule; // 'daily' | 'weekdays:…' | 'weekly:N' | 'interval:N'
  final String? icon;
  final String color;
  final String polarity; // 'build' | 'avoid'
  final int sortOrder;

  const HabitTemplate({
    required this.id,
    required this.name,
    this.description,
    this.area,
    this.kind = 'binary',
    this.targetValue,
    this.unit,
    this.step,
    this.defaultSchedule = 'daily',
    this.icon,
    this.color = '#5AADA0',
    this.polarity = 'build',
    this.sortOrder = 0,
  });

  bool get isMetric => kind == 'count' || kind == 'duration';
  bool get isAvoid => polarity == 'avoid';

  /// Short human preview, e.g. "8 стак. · ежедневно" or "10 мин · ежедневно".
  String get summary {
    final parts = <String>[];
    if (isAvoid) {
      parts.add('избегать');
    } else if (kind == 'duration' && targetValue != null) {
      parts.add('${(targetValue! / 60).round()} мин');
    } else if (kind == 'count' && targetValue != null) {
      final t = targetValue! % 1 == 0
          ? targetValue!.toStringAsFixed(0)
          : targetValue!.toStringAsFixed(1);
      parts.add('$t ${unit ?? ''}'.trim());
    }
    parts.add(_scheduleLabel(defaultSchedule));
    return parts.join(' · ');
  }

  static String _scheduleLabel(String s) {
    if (s == 'daily' || s.isEmpty) return 'ежедневно';
    if (s.startsWith('weekly:')) {
      return '${s.substring('weekly:'.length)}×/нед';
    }
    if (s.startsWith('interval:')) {
      return 'каждые ${s.substring('interval:'.length)} дн';
    }
    if (s.startsWith('weekdays:')) return 'по дням';
    return s;
  }

  factory HabitTemplate.fromMap(Map<dynamic, dynamic> m) => HabitTemplate(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        description: m['description']?.toString(),
        area: LifeAreaX.fromString(m['area']?.toString()),
        kind: (m['kind']?.toString().isNotEmpty ?? false)
            ? m['kind'].toString()
            : 'binary',
        targetValue: (m['target_value'] as num?)?.toDouble(),
        unit: m['unit']?.toString(),
        step: (m['step'] as num?)?.toDouble(),
        defaultSchedule:
            (m['default_schedule']?.toString().isNotEmpty ?? false)
                ? m['default_schedule'].toString()
                : 'daily',
        icon: m['icon']?.toString(),
        color: m['color']?.toString() ?? '#5AADA0',
        polarity: (m['polarity']?.toString().isNotEmpty ?? false)
            ? m['polarity'].toString()
            : 'build',
        sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
      );

  /// Built-in fallback library used offline / on first run before the Supabase
  /// table is mirrored. Kept in sync with the migration seed.
  static const List<HabitTemplate> fallbackSeed = [
    // ── Health ───────────────────────────────────────────────────────────
    HabitTemplate(
      id: 'seed_water',
      name: 'Пить воду',
      area: LifeArea.health,
      kind: 'count',
      targetValue: 8,
      unit: 'стак.',
      step: 1,
      icon: '💧',
      color: '#6A8ED8',
      sortOrder: 10,
    ),
    HabitTemplate(
      id: 'seed_steps',
      name: '10 000 шагов',
      area: LifeArea.health,
      kind: 'count',
      targetValue: 10000,
      unit: 'шаг.',
      step: 1000,
      icon: '🚶',
      color: '#5AAD6A',
      sortOrder: 11,
    ),
    HabitTemplate(
      id: 'seed_workout',
      name: 'Зарядка',
      area: LifeArea.health,
      kind: 'duration',
      targetValue: 600,
      step: 300,
      icon: '🤸',
      color: '#E07830',
      sortOrder: 12,
    ),
    HabitTemplate(
      id: 'seed_stretch',
      name: 'Растяжка',
      area: LifeArea.health,
      kind: 'duration',
      targetValue: 300,
      step: 60,
      icon: '🧎',
      color: '#5AAD6A',
      sortOrder: 13,
    ),
    HabitTemplate(
      id: 'seed_sleep',
      name: 'Сон 8 часов',
      area: LifeArea.health,
      icon: '😴',
      color: '#6A8ED8',
      sortOrder: 14,
    ),
    HabitTemplate(
      id: 'seed_coldshower',
      name: 'Холодный душ',
      area: LifeArea.health,
      icon: '🚿',
      color: '#4FB0C6',
      sortOrder: 15,
    ),
    HabitTemplate(
      id: 'seed_nosugar',
      name: 'Без сахара',
      area: LifeArea.health,
      polarity: 'avoid',
      icon: '🍬',
      color: '#D98C6F',
      sortOrder: 16,
    ),
    // ── Mind ─────────────────────────────────────────────────────────────
    HabitTemplate(
      id: 'seed_meditation',
      name: 'Медитация',
      area: LifeArea.mind,
      kind: 'duration',
      targetValue: 600,
      step: 300,
      icon: '🧘',
      color: '#9B59B6',
      sortOrder: 20,
    ),
    HabitTemplate(
      id: 'seed_reading',
      name: 'Чтение',
      area: LifeArea.mind,
      kind: 'duration',
      targetValue: 1200,
      step: 300,
      icon: '📚',
      color: '#4A90D9',
      sortOrder: 21,
    ),
    HabitTemplate(
      id: 'seed_language',
      name: 'Изучение языка',
      area: LifeArea.mind,
      kind: 'duration',
      targetValue: 900,
      step: 300,
      icon: '🗣️',
      color: '#4A90D9',
      sortOrder: 22,
    ),
    HabitTemplate(
      id: 'seed_nosocial',
      name: 'Без соцсетей',
      area: LifeArea.mind,
      polarity: 'avoid',
      icon: '📵',
      color: '#D98C6F',
      sortOrder: 23,
    ),
    // ── Productivity ─────────────────────────────────────────────────────
    HabitTemplate(
      id: 'seed_planday',
      name: 'Планирование дня',
      area: LifeArea.productivity,
      icon: '🗓️',
      color: '#C8A84B',
      sortOrder: 30,
    ),
    HabitTemplate(
      id: 'seed_deepwork',
      name: 'Глубокая работа',
      area: LifeArea.productivity,
      kind: 'duration',
      targetValue: 3600,
      step: 600,
      icon: '⚡',
      color: '#E07830',
      sortOrder: 31,
    ),
    // ── Relationships ────────────────────────────────────────────────────
    HabitTemplate(
      id: 'seed_callfamily',
      name: 'Позвонить близким',
      area: LifeArea.relationships,
      defaultSchedule: 'weekly:2',
      icon: '☎️',
      color: '#C05080',
      sortOrder: 40,
    ),
    HabitTemplate(
      id: 'seed_gratitude',
      name: 'Благодарность',
      area: LifeArea.relationships,
      icon: '🙏',
      color: '#C05080',
      sortOrder: 41,
    ),
    // ── Finance ──────────────────────────────────────────────────────────
    HabitTemplate(
      id: 'seed_expenses',
      name: 'Учёт расходов',
      area: LifeArea.finance,
      icon: '💰',
      color: '#70B870',
      sortOrder: 50,
    ),
    // ── Spirit ───────────────────────────────────────────────────────────
    HabitTemplate(
      id: 'seed_journal',
      name: 'Дневник',
      area: LifeArea.spirit,
      kind: 'duration',
      targetValue: 300,
      step: 60,
      icon: '✍️',
      color: '#9B59B6',
      sortOrder: 60,
    ),
  ];
}
