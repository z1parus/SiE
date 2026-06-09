import 'planning.dart';

// ─── Name registry ────────────────────────────────────────────────────────────

const _medalNames = <String, List<String>>{
  'learning':   ['Новичок', 'Адепт знаний', 'Магистр'],
  'health':     ['Бодрость', 'Атлет', 'Железная воля'],
  'project':    ['Первый чертёж', 'Инженер', 'Архитектор систем'],
  'lifestyle':  ['Турист', 'Путешественник', 'Первооткрыватель'],
  'discipline': ['Послушник', 'Страж', 'Мастер контроля'],
};

const _defaultMedalNames = ['Новобранец', 'Ветеран', 'Легенда'];

String medalName(GoalCategory? cat, int level) {
  final list = cat != null ? _medalNames[cat.name] : null;
  return (list ?? _defaultMedalNames)[level - 1];
}

int medalXpBonus(int level) => switch (level) {
      3 => 700,
      2 => 300,
      _ => 100,
    };

// ─── Model ────────────────────────────────────────────────────────────────────

class MissionMedal {
  const MissionMedal({
    required this.id,
    required this.userId,
    required this.goalId,
    required this.goalName,
    required this.category,
    required this.level,
    required this.name,
    required this.earnedAt,
    this.totalTaskWeight = 0,
    this.durationDays = 0,
  });

  final String id;
  final String userId;
  final String goalId;
  final String goalName;
  final GoalCategory? category;
  final int level; // 1=Bronze, 2=Silver, 3=Gold
  final String name;
  final DateTime earnedAt;
  final int totalTaskWeight;
  final int durationDays;

  int get xpBonus => medalXpBonus(level);

  factory MissionMedal.fromMap(Map<String, dynamic> m) {
    final catStr = m['category'] as String?;
    final cat = catStr != null && catStr != 'none'
        ? GoalCategory.values.where((e) => e.name == catStr).firstOrNull
        : null;
    return MissionMedal(
      id: m['id'] as String,
      userId: m['user_id'] as String,
      goalId: m['goal_id'] as String,
      goalName: m['goal_name'] as String? ?? '',
      category: cat,
      level: (m['level'] as num).toInt(),
      name: m['name'] as String,
      earnedAt: m['earned_at'] is String
          ? DateTime.parse(m['earned_at'] as String)
          : DateTime.fromMillisecondsSinceEpoch(m['earned_at'] as int),
      totalTaskWeight: (m['total_task_weight'] as num?)?.toInt() ?? 0,
      durationDays: (m['duration_days'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'id': id,
        'user_id': userId,
        'goal_id': goalId,
        'category': category?.name ?? 'none',
        'level': level,
        'name': name,
        'earned_at': earnedAt.toIso8601String(),
        'total_task_weight': totalTaskWeight,
        'duration_days': durationDays,
        // goal_name is not in DB — derived client-side
      };
}
