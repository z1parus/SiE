import '../models/planning.dart';
import '../models/map_element.dart';

// ─────────────────────────────────────────────────────────────────────────────
// goalToMarkdown — pure serialiser, no Flutter dependencies.
// Converts a Goal + its full tree into GitHub-Flavored Markdown.
// ─────────────────────────────────────────────────────────────────────────────

String goalToMarkdown(Goal goal) {
  final buf = StringBuffer();

  // ── Header ─────────────────────────────────────────────────────────────────
  buf.writeln('# 🎯 ${goal.name}');

  final headerParts = [
    '**Статус:** ${_statusLabel(goal.status)}',
    '**Прогресс:** ${goalProgress(goal).round()}%',
  ];
  if (goal.deadline != null) {
    headerParts.add('**Дедлайн:** ${_fmtDate(goal.deadline!)}');
  }
  buf.writeln(headerParts.join(' · '));

  if (goal.settings.category != null) {
    buf.writeln('**Категория:** ${_categoryLabel(goal.settings.category!)}');
  }
  if (goal.settings.why != null && goal.settings.why!.isNotEmpty) {
    buf.writeln('> Зачем: ${goal.settings.why}');
  }
  if (goal.description != null && goal.description!.isNotEmpty) {
    buf.writeln();
    buf.writeln(goal.description);
  }

  // ── SubGoals tree ──────────────────────────────────────────────────────────
  final rootSubGoals =
      goal.subGoals.where((sg) => sg.parentSubGoalId == null).toList();
  if (rootSubGoals.isNotEmpty) {
    buf.writeln();
    buf.writeln('## Операции');
    for (final sg in rootSubGoals) {
      _writeSubGoal(buf, sg, 0);
    }
  }

  // ── Milestones ─────────────────────────────────────────────────────────────
  if (goal.milestones.isNotEmpty) {
    buf.writeln();
    buf.writeln('## Контрольные точки');
    for (final ms in goal.milestones) {
      _writeMilestone(buf, ms);
    }
  }

  // ── Blockers ───────────────────────────────────────────────────────────────
  final allTasks = _collectTasks(goal.subGoals);
  final blocked =
      allTasks.where((t) => t.dependsOn.isNotEmpty && !t.isCompleted).toList();
  if (blocked.isNotEmpty) {
    buf.writeln();
    buf.writeln('## Блокировки');
    final byId = {for (final t in allTasks) t.id: t};
    for (final t in blocked) {
      final names =
          t.dependsOn.map((id) => byId[id]?.name ?? id).join('», «');
      buf.writeln('- «${t.name}» ждёт: «$names»');
    }
  }

  // ── Map notes ──────────────────────────────────────────────────────────────
  final notes = goal.mapElements
      .where((e) =>
          e.kind == MapElementKind.note || e.kind == MapElementKind.label)
      .toList();
  if (notes.isNotEmpty) {
    buf.writeln();
    buf.writeln('## Заметки с карты');
    for (final n in notes) {
      if (n.content.isNotEmpty) buf.writeln('- 📌 «${n.content}»');
    }
  }

  // ── Habit links ────────────────────────────────────────────────────────────
  if (goal.habitLinks.isNotEmpty) {
    buf.writeln();
    buf.writeln('## Связанные привычки');
    for (final hl in goal.habitLinks) {
      buf.writeln('- Привычка `${hl.habitId}` · boost ×${hl.boostValue}');
    }
  }

  return buf.toString().trim();
}

// ── Helpers ──────────────────────────────────────────────────────────────────

void _writeSubGoal(StringBuffer buf, SubGoal sg, int depth) {
  final indent = '  ' * depth;
  final check = sg.isCompleted ? 'x' : ' ';
  final done = sg.tasks.where((t) => t.isCompleted).length;
  final total = sg.tasks.length;
  final prog = subGoalProgress(sg).round();
  final stats = total > 0 ? ' — $done/$total задач ($prog%)' : '';
  buf.writeln('$indent- [$check] **${sg.name}**$stats');

  for (final task in sg.tasks) {
    _writeTask(buf, task, depth + 1);
  }
  for (final child in sg.children) {
    _writeSubGoal(buf, child, depth + 1);
  }
}

void _writeTask(StringBuffer buf, PlanningTask task, int depth) {
  final indent = '  ' * depth;
  final check = task.isCompleted ? 'x' : ' ';
  final meta = <String>['×${task.weight}'];
  if (task.dueDate != null) meta.add('до ${_fmtDate(task.dueDate!)}');
  if (task.isRecurring && task.recurrenceRule != null) {
    meta.add(_recurrenceLabel(task.recurrenceRule!));
  }
  buf.writeln('$indent  - [$check] ${task.name}  ·  ${meta.join('  ·  ')}');
}

void _writeMilestone(StringBuffer buf, Milestone ms) {
  if (ms.isMetric) {
    final curr = ms.currentValue ?? ms.startValue ?? 0;
    final target = ms.targetValue ?? 0;
    final pct = target > 0 ? ((curr / target) * 100).round() : 0;
    final unitStr = ms.unit != null ? ' ${ms.unit}' : '';
    buf.writeln('- [ ] ${ms.name} — **$curr / $target$unitStr** ($pct%)');
  } else {
    final check = ms.isCompleted ? 'x' : ' ';
    final dateStr =
        ms.targetDate != null ? '  ·  до ${_fmtDate(ms.targetDate!)}' : '';
    buf.writeln('- [$check] ${ms.name}$dateStr');
  }
}

List<PlanningTask> _collectTasks(List<SubGoal> sgs) {
  final all = <PlanningTask>[];
  for (final sg in sgs) {
    all.addAll(sg.tasks);
    all.addAll(_collectTasks(sg.children));
  }
  return all;
}

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _statusLabel(String s) => switch (s) {
      'active' => 'активна',
      'completed' => 'завершена',
      'failed' => 'не достигнута',
      'frozen' => 'заморожена',
      _ => s,
    };

String _categoryLabel(GoalCategory cat) => switch (cat) {
      GoalCategory.learning => 'обучение',
      GoalCategory.health => 'здоровье',
      GoalCategory.project => 'проект',
      GoalCategory.lifestyle => 'образ жизни',
      GoalCategory.discipline => 'дисциплина',
    };

String _recurrenceLabel(String rule) {
  if (rule == 'daily') return '🔁 ежедневно';
  if (rule.startsWith('weekly:')) {
    const names = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final labels = rule.substring(7).split(',').map((d) {
      final idx = int.tryParse(d.trim());
      return (idx != null && idx >= 1 && idx <= 7) ? names[idx - 1] : d;
    });
    return '🔁 ${labels.join(',')}';
  }
  if (rule.startsWith('monthly:')) return '🔁 ${rule.substring(8)}-е числа';
  if (rule.startsWith('every:')) {
    return '🔁 каждые ${rule.substring(6)} дн.';
  }
  return '🔁 $rule';
}
