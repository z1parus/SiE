import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

// Guided weekly review (light flow): Summary → Stuck/Overdue → Weekly focus →
// Reflection + reward.
class WeeklyReviewScreen extends ConsumerStatefulWidget {
  const WeeklyReviewScreen({super.key});

  @override
  ConsumerState<WeeklyReviewScreen> createState() =>
      _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends ConsumerState<WeeklyReviewScreen> {
  int _step = 0;
  final _notesCtrl = TextEditingController();
  final Set<String> _focusGoalIds = {};
  bool _submitting = false;
  WeeklyReviewResult? _result;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final result = await ref.read(weeklyReviewProvider.notifier).submit(
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          focusGoalIds: _focusGoalIds.toList(),
        );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _result = result;
      _step = 4; // reward screen
    });
    SieHaptics.success();
  }

  @override
  Widget build(BuildContext context) {
    final sc = ref.watch(sieColorsProvider);
    final async = ref.watch(weeklyReviewProvider);

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: sc.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Обзор недели',
              style: TextStyle(color: sc.textPrimary, fontSize: 18)),
        ),
        body: async.when(
          loading: () =>
              Center(child: CircularProgressIndicator(color: sc.accent)),
          error: (_, __) => Center(
            child: Text('Не удалось собрать данные недели',
                style: TextStyle(color: sc.textSecondary)),
          ),
          data: (data) {
            if (data.alreadyReviewed && _result == null) {
              return _AlreadyDone(sc: sc, data: data);
            }
            return Column(
              children: [
                if (_step < 4) _Progress(step: _step, sc: sc),
                Expanded(
                  child: switch (_step) {
                    0 => _SummaryStep(data: data, sc: sc),
                    1 => _StuckStep(data: data, sc: sc),
                    2 => _FocusStep(
                        sc: sc,
                        selected: _focusGoalIds,
                        onToggle: (id) => setState(() {
                          if (_focusGoalIds.contains(id)) {
                            _focusGoalIds.remove(id);
                          } else if (_focusGoalIds.length < 3) {
                            _focusGoalIds.add(id);
                          }
                        }),
                      ),
                    3 => _ReflectionStep(ctrl: _notesCtrl, sc: sc),
                    _ => _RewardStep(result: _result, data: data, sc: sc),
                  },
                ),
                if (_step < 4)
                  _NavBar(
                    sc: sc,
                    step: _step,
                    submitting: _submitting,
                    onBack: _step == 0 ? null : () => setState(() => _step--),
                    onNext: () {
                      if (_step < 3) {
                        setState(() => _step++);
                      } else {
                        _submit();
                      }
                    },
                  ),
                if (_step == 4)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: sc.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('ГОТОВО',
                            style: TextStyle(
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Progress dots ──────────────────────────────────────────────────────────

class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.sc});
  final int step;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: List.generate(4, (i) {
          final active = i <= step;
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: active ? sc.accent : sc.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Step 1: Summary ────────────────────────────────────────────────────────

class _SummaryStep extends StatelessWidget {
  const _SummaryStep({required this.data, required this.sc});
  final WeeklyReviewData data;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _StepTitle('Итоги недели', Icons.insights_outlined, sc),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _MetricBox(
                    value: '${data.completedTasks}',
                    label: 'задач выполнено',
                    color: sc.accent,
                    sc: sc)),
            const SizedBox(width: 12),
            Expanded(
                child: _MetricBox(
                    value: '${data.reviewStreak}',
                    label: 'недель подряд',
                    color: sc.accentSecondary,
                    sc: sc)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: sc.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sc.border),
          ),
          child: Row(
            children: [
              Icon(Icons.self_improvement, color: sc.accent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data.completedTasks == 0
                      ? 'Тихая неделя — это нормально. Перезагрузимся и наметим фокус.'
                      : 'Отличная работа на этой неделе. Сделаем паузу и оглянёмся.',
                  style: TextStyle(
                      color: sc.textSecondary, fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Step 2: Stuck + Overdue ────────────────────────────────────────────────

class _StuckStep extends ConsumerWidget {
  const _StuckStep({required this.data, required this.sc});
  final WeeklyReviewData data;
  final SieColors sc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _StepTitle('Застрявшее и просроченное', Icons.warning_amber_outlined,
            sc),
        const SizedBox(height: 16),
        if (data.stallingGoals.isEmpty && data.overdue.isEmpty)
          _EmptyHint('Ничего не застряло — чисто! 🎯', sc)
        else ...[
          if (data.stallingGoals.isNotEmpty) ...[
            Text('ТЕРЯЮТ ТЕМП',
                style: TextStyle(
                    color: sc.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 8),
            ...data.stallingGoals.map((g) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: sc.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sc.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: g.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(g.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: sc.textPrimary, fontSize: 14)),
                      ),
                      Icon(Icons.trending_down, size: 16, color: sc.warning),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
          ],
          if (data.overdue.isNotEmpty) ...[
            Row(
              children: [
                Text('ПРОСРОЧЕНО (${data.overdue.length})',
                    style: TextStyle(
                        color: sc.danger,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2)),
              ],
            ),
            const SizedBox(height: 8),
            ...data.overdue.take(5).map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 5, color: sc.danger),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(item.task.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: sc.textPrimary, fontSize: 13)),
                      ),
                    ],
                  ),
                )),
            if (data.overdue.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 13),
                child: Text('…и ещё ${data.overdue.length - 5}',
                    style:
                        TextStyle(color: sc.textSecondary, fontSize: 12)),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _rescheduleAll(context, ref),
                icon: Icon(Icons.event_available, size: 18, color: sc.accent),
                label: Text('Перенести всё на сегодня',
                    style: TextStyle(color: sc.accent)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: sc.accent.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _rescheduleAll(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(planningProvider.notifier);
    final today = DateUtils.dateOnly(DateTime.now());
    for (final item in data.overdue) {
      await notifier.rescheduleTask(
          item.task.id, item.subGoalId, item.goal.id, today);
    }
    if (context.mounted) {
      SieHaptics.success();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Перенесено задач: ${data.overdue.length}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: sc.surface,
        ),
      );
    }
  }
}

// ─── Step 3: Weekly focus ───────────────────────────────────────────────────

class _FocusStep extends ConsumerWidget {
  const _FocusStep({
    required this.sc,
    required this.selected,
    required this.onToggle,
  });
  final SieColors sc;
  final Set<String> selected;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals =
        ref.watch(planningProvider).valueOrNull?.activeGoals ?? const [];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _StepTitle('Фокус недели', Icons.star_outline, sc),
        const SizedBox(height: 4),
        Text('Выбери до 3 целей — они отметятся ⭐ в Повестке.',
            style: TextStyle(color: sc.textSecondary, fontSize: 13)),
        const SizedBox(height: 16),
        if (goals.isEmpty)
          _EmptyHint('Нет активных целей.', sc)
        else
          ...goals.map((g) {
            final isSel = selected.contains(g.id);
            return GestureDetector(
              onTap: () => onToggle(g.id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSel
                      ? sc.accent.withValues(alpha: 0.1)
                      : sc.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isSel ? sc.accent : sc.border),
                ),
                child: Row(
                  children: [
                    Icon(isSel ? Icons.star : Icons.star_outline,
                        size: 20, color: isSel ? sc.accent : sc.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(g.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(color: sc.textPrimary, fontSize: 14)),
                    ),
                    Text('${goalProgress(g).round()}%',
                        style: TextStyle(
                            color: sc.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ─── Step 4: Reflection ─────────────────────────────────────────────────────

class _ReflectionStep extends StatelessWidget {
  const _ReflectionStep({required this.ctrl, required this.sc});
  final TextEditingController ctrl;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _StepTitle('Главный вывод', Icons.edit_note_outlined, sc),
        const SizedBox(height: 4),
        Text('Одна мысль, которую стоит унести из этой недели (необязательно).',
            style: TextStyle(color: sc.textSecondary, fontSize: 13)),
        const SizedBox(height: 16),
        TextField(
          controller: ctrl,
          maxLines: 5,
          style: TextStyle(color: sc.textPrimary, fontSize: 15, height: 1.4),
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Например: меньше задач, больше глубины…',
            hintStyle: TextStyle(color: sc.textSecondary),
            filled: true,
            fillColor: sc.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: sc.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: sc.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: sc.accent),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Reward screen ──────────────────────────────────────────────────────────

class _RewardStep extends StatelessWidget {
  const _RewardStep({required this.result, required this.data, required this.sc});
  final WeeklyReviewResult? result;
  final WeeklyReviewData data;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sc.surface,
                border: Border.all(color: sc.accent, width: 1.5),
              ),
              child: Icon(Icons.explore_outlined, size: 40, color: sc.accent),
            ),
            const SizedBox(height: 24),
            Text('ОБЗОР ЗАВЕРШЁН',
                style: TextStyle(
                    color: sc.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Text('Неделя осмыслена. Курс намечен.',
                style: TextStyle(color: sc.textSecondary, fontSize: 13)),
            const SizedBox(height: 24),
            if (result != null && result!.xpGained > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: sc.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: sc.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('+${result!.xpGained} XP',
                        style: TextStyle(
                            color: sc.accent,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(width: 20),
                    Text('+${result!.dpGained} DP',
                        style: TextStyle(
                            color: sc.accentSecondary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Already done ───────────────────────────────────────────────────────────

class _AlreadyDone extends StatelessWidget {
  const _AlreadyDone({required this.sc, required this.data});
  final SieColors sc;
  final WeeklyReviewData data;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: sc.success, size: 56),
            const SizedBox(height: 16),
            Text('Обзор этой недели уже сделан',
                style: TextStyle(
                    color: sc.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Стрик обзоров: ${data.reviewStreak} нед.',
                style: TextStyle(color: sc.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ─── Shared bits ────────────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.sc,
    required this.step,
    required this.submitting,
    required this.onBack,
    required this.onNext,
  });
  final SieColors sc;
  final int step;
  final bool submitting;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            if (onBack != null)
              Expanded(
                child: OutlinedButton(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: sc.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Назад',
                      style: TextStyle(color: sc.textSecondary)),
                ),
              ),
            if (onBack != null) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: submitting ? null : onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: sc.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(step < 3 ? 'Далее' : 'Завершить обзор',
                        style: const TextStyle(
                            letterSpacing: 1, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle(this.title, this.icon, this.sc);
  final String title;
  final IconData icon;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: sc.accent, size: 22),
        const SizedBox(width: 10),
        Text(title,
            style: TextStyle(
                color: sc.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox(
      {required this.value,
      required this.label,
      required this.color,
      required this.sc});
  final String value;
  final String label;
  final Color color;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(color: sc.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text, this.sc);
  final String text;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(text,
            style: TextStyle(color: sc.textSecondary, fontSize: 14)),
      ),
    );
  }
}
