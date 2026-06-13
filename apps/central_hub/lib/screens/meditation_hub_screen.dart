import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'meditation_preflight_screen.dart';
import 'meditation_preset_builder_screen.dart';

class MeditationHubScreen extends ConsumerStatefulWidget {
  const MeditationHubScreen({super.key});

  @override
  ConsumerState<MeditationHubScreen> createState() =>
      _MeditationHubScreenState();
}

class _MeditationHubScreenState extends ConsumerState<MeditationHubScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final c            = ref.watch(sieColorsProvider);
    final presetsAsync = ref.watch(meditationPresetsProvider);
    final statsAsync   = ref.watch(meditationStatsProvider);

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.accent),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'ДЕФРАГМЕНТАЦИЯ',
            style: TextStyle(
              color: c.accent,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),
          centerTitle: true,
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const MeditationPresetBuilderScreen()),
          ),
          backgroundColor: c.accent,
          foregroundColor: c.background,
          child: const Icon(Icons.add_rounded),
        ),
        body: Column(
          children: [
            statsAsync.when(
              data:    (s) => _MiniStatsWidget(stats: s, c: c),
              loading: () => const SizedBox(height: 72),
              error:   (_, __) => const SizedBox(height: 72),
            ),
            const SizedBox(height: 8),
            presetsAsync.when(
              data: (state) {
                final sys =
                    state.presets.where((p) => p.isSystem).toList();
                return _QuickStartStrip(presets: sys, c: c);
              },
              loading: () => const SizedBox(height: 90),
              error:   (_, __) => const SizedBox(height: 90),
            ),
            const SizedBox(height: 12),
            _FilterRow(
              selected: _filter,
              onSelected: (v) => setState(() => _filter = v),
              c: c,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: presetsAsync.when(
                data: (state) {
                  final filtered = _filteredPresets(state.presets);
                  if (filtered.isEmpty) {
                    final noneAtAll = state.presets.isEmpty;
                    return SieEmptyState(
                      icon: Icons.self_improvement_rounded,
                      title: noneAtAll
                          ? 'Нет пресетов'
                          : 'Ничего не найдено',
                      subtitle: noneAtAll
                          ? 'Создайте свой первый пресет медитации'
                          : 'Под выбранный фильтр пресетов нет',
                      action: noneAtAll
                          ? null
                          : TextButton(
                              onPressed: () =>
                                  setState(() => _filter = 'all'),
                              child: Text(
                                'СБРОСИТЬ ФИЛЬТР',
                                style: TextStyle(
                                  color: c.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                    );
                  }
                  return ListView.separated(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _PresetCard(
                      preset: filtered[i],
                      packs: state.affirmationPacks,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MeditationPreflightScreen(
                              preset: filtered[i]),
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: SieSkeletonList(itemCount: 4, itemHeight: 80),
                ),
                error: (e, _) => Center(
                  child: Text('Ошибка загрузки',
                      style: TextStyle(color: c.textSecondary)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MeditationPreset> _filteredPresets(List<MeditationPreset> all) {
    final hour = DateTime.now().hour;
    List<MeditationPreset> list;
    switch (_filter) {
      case 'breathing':
        list = all.where((p) => p.hasBreathing).toList();
      case 'affirmations':
        list = all.where((p) => p.meditationType == 'affirmations').toList();
      default:
        list = List.of(all);
    }
    list.sort((a, b) {
      int priority(MeditationPreset p) {
        if (hour < 12) {
          if (p.affirmationPackId != null) return -1;
          if (p.hasBreathing) return 0;
        } else if (hour >= 18) {
          if (!p.hasBreathing && p.meditationType == 'unguided') return -1;
        }
        return p.isSystem ? 0 : 1;
      }
      return priority(a).compareTo(priority(b));
    });
    return list;
  }
}

// ── Mini stats ──────────────────────────────────────────────────
class _MiniStatsWidget extends StatelessWidget {
  final MeditationStats stats;
  final SieColors c;
  const _MiniStatsWidget({required this.stats, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFFF6B35),
            label: '${stats.zenStreakDays}',
            sub: 'дней',
            c: c,
          ),
          _divider(),
          _StatChip(
            icon: Icons.access_time_rounded,
            iconColor: c.accent,
            label: _fmtMins(stats.claritySecondsThisWeek),
            sub: 'мин/нед',
            c: c,
          ),
          _divider(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'CLARITY LVL ${stats.clarityXpLevel}',
                  style: TextStyle(
                      color: c.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: stats.clarityXpProgress,
                    backgroundColor: c.border,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(c.accent),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: c.border,
      );

  String _fmtMins(int secs) {
    final m = secs ~/ 60;
    return m < 60 ? '$m' : '${m ~/ 60}ч ${m % 60}';
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String sub;
  final SieColors c;
  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sub,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            Text(sub,
                style: TextStyle(color: c.textSecondary, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

// ── Quick start strip ───────────────────────────────────────────
class _QuickStartStrip extends StatelessWidget {
  final List<MeditationPreset> presets;
  final SieColors c;
  const _QuickStartStrip({required this.presets, required this.c});

  @override
  Widget build(BuildContext context) {
    if (presets.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 88,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: presets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final p = presets[i];
          return GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MeditationPreflightScreen(preset: p),
              ),
            ),
            child: Container(
              width: 140,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: c.accent.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_presetIcon(p), color: c.accent, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${p.totalDurationMin} МИН',
                        style: TextStyle(
                            color: c.accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    p.name,
                    style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _presetIcon(MeditationPreset p) {
    if (p.hasBreathing) return Icons.air_rounded;
    if (p.meditationType == 'affirmations')
      return Icons.format_quote_rounded;
    return Icons.self_improvement_rounded;
  }
}

// ── Filter row ──────────────────────────────────────────────────
class _FilterRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  final SieColors c;
  const _FilterRow({
    required this.selected,
    required this.onSelected,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _Chip('all', 'Все', selected, onSelected, c),
          const SizedBox(width: 8),
          _Chip('breathing', 'С дыханием', selected, onSelected, c),
          const SizedBox(width: 8),
          _Chip('affirmations', 'Аффирмации', selected, onSelected, c),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String value;
  final String label;
  final String selected;
  final ValueChanged<String> onSelected;
  final SieColors c;
  const _Chip(this.value, this.label, this.selected, this.onSelected, this.c);

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onSelected(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? c.accent.withValues(alpha: 0.2)
              : c.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? c.accent : c.border, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? c.accent : c.textSecondary,
            fontSize: 12,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Preset card ─────────────────────────────────────────────────
class _PresetCard extends ConsumerWidget {
  final MeditationPreset preset;
  final List<AffirmationPack> packs;
  final VoidCallback onTap;
  const _PresetCard({
    required this.preset,
    required this.packs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showActions(context, ref, c),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.accent.withValues(alpha: 0.12),
                border: Border.all(
                    color: c.accent.withValues(alpha: 0.4)),
              ),
              child: Icon(_icon, color: c.accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        preset.name,
                        style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                      if (preset.isSystem) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'SYS',
                            style: TextStyle(
                                color: c.accent,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _subtitle,
                    style: TextStyle(
                        color: c.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${preset.totalDurationMin} мин',
                  style: TextStyle(
                      color: c.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
                if (preset.hasBreathing)
                  Text(
                    preset.breathingPatternId?.toUpperCase() ?? '',
                    style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 9,
                        letterSpacing: 1),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _showActions(context, ref, c),
              behavior: HitTestBehavior.opaque,
              child: Semantics(
                button: true,
                label: 'Действия с пресетом',
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 8),
                  child: Icon(Icons.more_vert,
                      color: c.textSecondary, size: 18),
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: c.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  IconData get _icon {
    if (preset.hasBreathing) return Icons.air_rounded;
    if (preset.meditationType == 'affirmations')
      return Icons.format_quote_rounded;
    return Icons.self_improvement_rounded;
  }

  String get _subtitle {
    final parts = <String>[];
    if (preset.hasBreathing) {
      parts.add('Дыхание ${preset.breathingDurationMin} мин');
    }
    parts.add('Медитация ${preset.meditationDurationMin} мин');
    return parts.join(' · ');
  }

  void _showActions(BuildContext context, WidgetRef ref, SieColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PresetActionsSheet(
        preset: preset,
        c: c,
        onLaunch: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MeditationPreflightScreen(preset: preset),
          ));
        },
        onEdit: preset.isSystem
            ? null
            : () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MeditationPresetBuilderScreen(
                      editPreset: preset),
                ));
              },
        onDuplicate: () {
          Navigator.of(context).pop();
          _duplicatePreset(context, ref, c);
        },
        onDelete: preset.isSystem
            ? null
            : () async {
                Navigator.of(context).pop();
                final ok = await confirmDestructive(
                  context,
                  ref,
                  title: 'Удалить пресет?',
                  message: 'Пресет «${preset.name}» будет удалён без '
                      'возможности восстановления.',
                  confirmLabel: 'Удалить',
                );
                if (!ok) return;
                ref
                    .read(meditationPresetsProvider.notifier)
                    .deletePreset(preset.id);
              },
      ),
    );
  }

  void _duplicatePreset(
      BuildContext context, WidgetRef ref, SieColors c) async {
    final nameCtrl =
        TextEditingController(text: '${preset.name} (копия)');
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Дублировать пресет',
            style: TextStyle(color: c.textPrimary)),
        content: TextField(
          controller: nameCtrl,
          style: TextStyle(color: c.textPrimary),
          decoration: InputDecoration(
            labelText: 'Название',
            labelStyle: TextStyle(color: c.textSecondary),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена',
                style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, nameCtrl.text.trim()),
            child:
                Text('Создать', style: TextStyle(color: c.accent)),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await ref
          .read(meditationPresetsProvider.notifier)
          .duplicatePreset(preset, newName);
    }
  }
}

class _PresetActionsSheet extends StatelessWidget {
  final MeditationPreset preset;
  final SieColors c;
  final VoidCallback onLaunch;
  final VoidCallback? onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback? onDelete;
  const _PresetActionsSheet({
    required this.preset,
    required this.c,
    required this.onLaunch,
    this.onEdit,
    required this.onDuplicate,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              preset.name,
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _ActionTile(
              icon: Icons.play_arrow_rounded,
              label: 'Запустить сессию',
              color: c.accent,
              onTap: onLaunch,
            ),
            if (onEdit != null)
              _ActionTile(
                icon: Icons.edit_rounded,
                label: 'Редактировать',
                color: c.textPrimary,
                onTap: onEdit!,
              ),
            _ActionTile(
              icon: Icons.copy_rounded,
              label: 'Дублировать',
              color: c.textPrimary,
              onTap: onDuplicate,
            ),
            if (onDelete != null)
              _ActionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Удалить',
                color: Colors.redAccent,
                onTap: onDelete!,
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(label, style: TextStyle(color: color, fontSize: 14)),
      onTap: onTap,
      dense: true,
    );
  }
}
