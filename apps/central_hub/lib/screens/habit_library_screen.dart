import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

/// Stage 8 — curated habit library. Browse ready-made templates grouped by
/// life area and add them to your tracker in one tap.
class HabitLibraryScreen extends ConsumerStatefulWidget {
  const HabitLibraryScreen({super.key});

  @override
  ConsumerState<HabitLibraryScreen> createState() => _HabitLibraryScreenState();
}

class _HabitLibraryScreenState extends ConsumerState<HabitLibraryScreen> {
  // Template ids already instantiated in this session (for visual feedback).
  final Set<String> _added = {};

  static Color _hex(String hex) {
    final h = hex.replaceAll('#', '').padLeft(6, '0');
    return Color(int.tryParse('FF$h', radix: 16) ?? 0xFF5AADA0);
  }

  Future<void> _addTemplate(HabitTemplate t) async {
    SieHaptics.success();
    setState(() => _added.add(t.id));
    await ref.read(habitsProvider.notifier).addHabit(
          title: t.name,
          description: t.description,
          color: t.color,
          icon: t.icon,
          schedule: t.defaultSchedule,
          kind: t.kind,
          targetValue: t.targetValue,
          unit: t.unit,
          step: t.step,
          area: t.area,
          polarity: t.polarity,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Text('«${t.name}» добавлена'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sc        = ref.watch(sieColorsProvider);
    final accent    = sc.accent;
    final templates = ref.watch(habitTemplatesProvider);

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(Icons.arrow_back_ios_new,
                          color: sc.textSecondary, size: 15),
                    ),
                    const SizedBox(width: 16),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'HABIT ',
                            style: TextStyle(
                              color: accent,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          TextSpan(
                            text: 'LIBRARY',
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 3.0,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: templates.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text('Не удалось загрузить библиотеку',
                        style: TextStyle(color: sc.textSecondary)),
                  ),
                  data: (list) {
                    // Group by area, known areas first then "no area".
                    final grouped = <LifeArea?, List<HabitTemplate>>{};
                    for (final t in list) {
                      grouped.putIfAbsent(t.area, () => []).add(t);
                    }
                    final order = <LifeArea?>[...LifeArea.values, null];
                    final sections = <Widget>[];
                    for (final area in order) {
                      final items = grouped[area];
                      if (items == null || items.isEmpty) continue;
                      sections.add(Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 12),
                        child: Text(
                          area == null
                              ? '— БЕЗ СФЕРЫ'
                              : '${area.icon} ${area.label.toUpperCase()}',
                          style: TextStyle(
                            color: sc.textSecondary.withValues(alpha: 0.55),
                            fontSize: 9,
                            letterSpacing: 2.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ));
                      for (final t in items) {
                        sections.add(Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TemplateCard(
                            sc: sc,
                            template: t,
                            accent: _hex(t.color),
                            added: _added.contains(t.id),
                            onAdd: () => _addTemplate(t),
                          ),
                        ));
                      }
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                      children: sections,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final SieColors sc;
  final HabitTemplate template;
  final Color accent;
  final bool added;
  final VoidCallback onAdd;

  const _TemplateCard({
    required this.sc,
    required this.template,
    required this.accent,
    required this.added,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return SieGlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            alignment: Alignment.center,
            child: template.icon != null
                ? Text(template.icon!, style: const TextStyle(fontSize: 18))
                : Icon(
                    template.isAvoid ? Icons.shield_outlined : Icons.bolt,
                    color: accent,
                    size: 18,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: sc.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  template.summary,
                  style: TextStyle(
                    color: sc.textSecondary.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: added ? null : onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: added ? sc.border : accent.withValues(alpha: 0.6),
                ),
                color: added
                    ? Colors.transparent
                    : accent.withValues(alpha: 0.12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    added ? Icons.check : Icons.add,
                    size: 14,
                    color: added
                        ? sc.textSecondary.withValues(alpha: 0.6)
                        : accent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    added ? 'ДОБАВЛЕНО' : 'ДОБАВИТЬ',
                    style: TextStyle(
                      color: added
                          ? sc.textSecondary.withValues(alpha: 0.6)
                          : accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
