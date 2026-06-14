import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'mission_detail_screen.dart';

// ─── Category helpers ──────────────────────────────────────────────────────────

({String label, IconData icon}) _categoryMeta(GoalCategory? cat) =>
    switch (cat) {
      GoalCategory.learning => (label: 'Обучение', icon: Icons.school_outlined),
      GoalCategory.health => (label: 'Здоровье', icon: Icons.favorite_outline),
      GoalCategory.project =>
        (label: 'Проект', icon: Icons.rocket_launch_outlined),
      GoalCategory.lifestyle => (label: 'Образ жизни', icon: Icons.spa_outlined),
      GoalCategory.discipline =>
        (label: 'Дисциплина', icon: Icons.bolt_outlined),
      null => (label: 'Прочее', icon: Icons.flag_outlined),
    };

Color _hexColor(String hex) =>
    Color(int.parse('0xFF${hex.replaceAll('#', '')}'));

// ─── Screen ────────────────────────────────────────────────────────────────────

class TemplateGalleryScreen extends ConsumerWidget {
  const TemplateGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(sieColorsProvider);
    final templatesAsync = ref.watch(missionTemplatesProvider);

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: sc.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Шаблоны миссий',
              style: TextStyle(color: sc.textPrimary, fontSize: 18)),
        ),
        body: templatesAsync.when(
          loading: () =>
              Center(child: CircularProgressIndicator(color: sc.accent)),
          error: (e, _) => Center(
            child: Text('Не удалось загрузить шаблоны',
                style: TextStyle(color: sc.textSecondary)),
          ),
          data: (templates) {
            if (templates.isEmpty) {
              return Center(
                child: Text('Пока нет доступных шаблонов',
                    style: TextStyle(color: sc.textSecondary)),
              );
            }

            // Group by category; "Мои шаблоны" surfaced separately at top.
            final mine = templates.where((t) => !t.isSystem).toList();
            final system = templates.where((t) => t.isSystem).toList();

            final byCategory = <GoalCategory?, List<MissionTemplate>>{};
            for (final t in system) {
              (byCategory[t.category] ??= []).add(t);
            }
            // Stable category order.
            final orderedCats = <GoalCategory?>[
              GoalCategory.learning,
              GoalCategory.health,
              GoalCategory.project,
              GoalCategory.lifestyle,
              GoalCategory.discipline,
              null,
            ].where(byCategory.containsKey).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (mine.isNotEmpty) ...[
                  _SectionLabel(label: 'МОИ ШАБЛОНЫ', sc: sc),
                  ...mine.map((t) => _TemplateCard(
                        template: t,
                        sc: sc,
                        deletable: true,
                      )),
                  const SizedBox(height: 16),
                ],
                for (final cat in orderedCats) ...[
                  _SectionLabel(
                      label: _categoryMeta(cat).label.toUpperCase(), sc: sc),
                  ...byCategory[cat]!.map((t) => _TemplateCard(
                        template: t,
                        sc: sc,
                        deletable: false,
                      )),
                  const SizedBox(height: 16),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.sc});
  final String label;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        label,
        style: TextStyle(
          color: sc.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _TemplateCard extends ConsumerWidget {
  const _TemplateCard({
    required this.template,
    required this.sc,
    required this.deletable,
  });

  final MissionTemplate template;
  final SieColors sc;
  final bool deletable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _hexColor(template.colorHex);
    final meta = _categoryMeta(template.category);
    final s = template.structure;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TemplatePreviewScreen(template: template)),
      ),
      onLongPress: deletable
          ? () => _confirmDelete(context, ref)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: sc.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sc.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(meta.icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: TextStyle(
                        color: sc.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${s.subGoalCount} этапов · ${s.taskCount} задач'
                    '${s.milestoneCount > 0 ? ' · ${s.milestoneCount} вех' : ''}',
                    style: TextStyle(color: sc.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: sc.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: sc.surface,
        title: Text('Удалить шаблон?',
            style: TextStyle(color: sc.textPrimary)),
        content: Text('«${template.name}» будет удалён из ваших шаблонов.',
            style: TextStyle(color: sc.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Отмена',
                  style: TextStyle(color: sc.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Удалить', style: TextStyle(color: sc.danger))),
        ],
      ),
    );
    if (confirm == true) {
      ref.read(missionTemplatesProvider.notifier).deleteTemplate(template.id);
    }
  }
}

// ─── Preview screen ─────────────────────────────────────────────────────────────

class TemplatePreviewScreen extends ConsumerWidget {
  const TemplatePreviewScreen({super.key, required this.template});

  final MissionTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(sieColorsProvider);
    final color = _hexColor(template.colorHex);
    final s = template.structure;

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: sc.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(template.name,
              style: TextStyle(color: sc.textPrimary, fontSize: 17)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            if (template.description != null) ...[
              Text(template.description!,
                  style: TextStyle(
                      color: sc.textSecondary, fontSize: 13, height: 1.4)),
              const SizedBox(height: 16),
            ],
            // Summary chips.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryChip(
                    icon: Icons.account_tree_outlined,
                    label: '${s.subGoalCount} этапов',
                    sc: sc),
                _SummaryChip(
                    icon: Icons.task_alt,
                    label: '${s.taskCount} задач',
                    sc: sc),
                if (s.milestoneCount > 0)
                  _SummaryChip(
                      icon: Icons.flag_outlined,
                      label: '${s.milestoneCount} вех',
                      sc: sc),
              ],
            ),
            const SizedBox(height: 20),

            // Sub-goal tree.
            Text('СТРУКТУРА',
                style: TextStyle(
                    color: sc.textSecondary,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...s.subGoals.map((sg) =>
                _SubGoalNode(sg: sg, sc: sc, color: color, depth: 0)),

            if (s.milestones.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('КОНТРОЛЬНЫЕ ТОЧКИ',
                  style: TextStyle(
                      color: sc.textSecondary,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ...s.milestones.map((m) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Icon(
                            m.kind == 'metric'
                                ? Icons.trending_up
                                : Icons.outlined_flag,
                            size: 16,
                            color: color),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            m.kind == 'metric' && m.targetValue != null
                                ? '${m.name} (цель: ${_fmt(m.targetValue!)}${m.unit != null ? ' ${m.unit}' : ''})'
                                : m.name,
                            style: TextStyle(
                                color: sc.textPrimary, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showCreateSheet(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('СОЗДАТЬ МИССИЮ',
                    style: TextStyle(
                        letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateFromTemplateSheet(template: template),
    );
  }

  static String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip(
      {required this.icon, required this.label, required this.sc});
  final IconData icon;
  final String label;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: sc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sc.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: sc.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: sc.textPrimary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _SubGoalNode extends StatelessWidget {
  const _SubGoalNode({
    required this.sg,
    required this.sc,
    required this.color,
    required this.depth,
  });

  final TemplateSubGoal sg;
  final SieColors sc;
  final Color color;
  final int depth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_outlined, size: 15, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(sg.name,
                    style: TextStyle(
                        color: sc.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ),
              if (sg.tasks.isNotEmpty)
                Text('${sg.tasks.length}',
                    style:
                        TextStyle(color: sc.textSecondary, fontSize: 12)),
            ],
          ),
          ...sg.tasks.map((t) => Padding(
                padding: const EdgeInsets.only(left: 23, top: 4),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 5, color: sc.textSecondary),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(t.name,
                          style: TextStyle(
                              color: sc.textSecondary, fontSize: 13)),
                    ),
                    _WeightDot(weight: t.weight, sc: sc),
                  ],
                ),
              )),
          ...sg.children.map((c) =>
              _SubGoalNode(sg: c, sc: sc, color: color, depth: depth + 1)),
        ],
      ),
    );
  }
}

class _WeightDot extends StatelessWidget {
  const _WeightDot({required this.weight, required this.sc});
  final int weight;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    final label = switch (weight) {
      5 => '×5',
      3 => '×3',
      _ => '×1',
    };
    return Text(label,
        style: TextStyle(
            color: sc.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600));
  }
}

// ─── Create-from-template sheet ─────────────────────────────────────────────────

class _CreateFromTemplateSheet extends ConsumerStatefulWidget {
  const _CreateFromTemplateSheet({required this.template});
  final MissionTemplate template;

  @override
  ConsumerState<_CreateFromTemplateSheet> createState() =>
      _CreateFromTemplateSheetState();
}

class _CreateFromTemplateSheetState
    extends ConsumerState<_CreateFromTemplateSheet> {
  late final TextEditingController _nameCtrl;
  DateTime? _deadline;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.template.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _creating) return;
    setState(() => _creating = true);

    final goalId = await ref
        .read(planningProvider.notifier)
        .createGoalFromTemplate(widget.template,
            name: name, deadline: _deadline);

    if (!mounted) return;
    final goal = ref
        .read(planningProvider)
        .valueOrNull
        ?.goals
        .where((g) => g.id == goalId)
        .firstOrNull;

    Navigator.pop(context); // close sheet
    if (goal != null && mounted) {
      // Replace the gallery/preview stack so back returns to the planning list.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MissionDetailScreen(goal: goal)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = ref.watch(sieColorsProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: sc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sc.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('СОЗДАТЬ ИЗ ШАБЛОНА',
              style: TextStyle(
                  color: sc.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2)),
          const SizedBox(height: 14),
          TextField(
            controller: _nameCtrl,
            style: TextStyle(color: sc.textPrimary, fontSize: 16),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Название миссии',
              hintStyle: TextStyle(color: sc.textSecondary, fontSize: 16),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: sc.border)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: sc.accent)),
            ),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 30)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: (sc.isLightMode
                            ? ColorScheme.light(primary: sc.accent)
                            : ColorScheme.dark(primary: sc.accent))
                        .copyWith(surface: sc.surface),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _deadline = picked);
            },
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 16, color: sc.accent),
                const SizedBox(width: 8),
                Text(
                  _deadline != null
                      ? 'Дедлайн: ${_deadline!.day}.${_deadline!.month.toString().padLeft(2, '0')}.${_deadline!.year}'
                      : 'Установить дедлайн (необязательно)',
                  style: TextStyle(color: sc.accent, fontSize: 13),
                ),
                if (_deadline != null) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _deadline = null),
                    child:
                        Icon(Icons.close, size: 14, color: sc.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _creating ? null : _create,
              style: ElevatedButton.styleFrom(
                backgroundColor: sc.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('РАЗВЕРНУТЬ МИССИЮ',
                      style: TextStyle(
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
