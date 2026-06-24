import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'breathing_exercise_screen.dart';
import 'breathing_sequence_builder_screen.dart';

String formatMinSec(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class BreathingSequencesScreen extends ConsumerWidget {
  const BreathingSequencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    final async = ref.watch(breathingSequencesProvider);

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openBuilder(context),
          backgroundColor: c.accent,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('СОЗДАТЬ',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(c: c),
              Expanded(
                child: async.when(
                  loading: () =>
                      Center(child: CircularProgressIndicator(color: c.accent)),
                  error: (_, __) => _Empty(
                    c: c,
                    icon: Icons.cloud_off_outlined,
                    text: 'Не удалось загрузить последовательности',
                  ),
                  data: (seqs) {
                    if (seqs.isEmpty) {
                      return _Empty(
                        c: c,
                        icon: Icons.format_list_numbered_rounded,
                        text: 'Пока нет сохранённых последовательностей.\n'
                            'Нажмите «Создать», чтобы собрать свою цепочку '
                            'раундов.',
                      );
                    }
                    return RefreshIndicator(
                      color: c.accent,
                      backgroundColor: c.isLightMode ? Colors.white : c.surface,
                      onRefresh: () async {
                        ref.invalidate(breathingSequencesProvider);
                        await ref.read(breathingSequencesProvider.future);
                      },
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: seqs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _SequenceCard(
                          seq: seqs[i],
                          c: c,
                          onRun: () => _run(context, seqs[i]),
                          onEdit: () => _openBuilder(context, existing: seqs[i]),
                          onDuplicate: () => ref
                              .read(breathingSequencesProvider.notifier)
                              .duplicateSequence(seqs[i].id),
                          onDelete: () => _confirmDelete(context, ref, seqs[i]),
                        ),
                      ),
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

  void _run(BuildContext context, BreathingSequence seq) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BreathingExerciseScreen(sequence: seq),
      ),
    );
  }

  void _openBuilder(BuildContext context, {BreathingSequence? existing}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BreathingSequenceBuilderScreen(existing: existing),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, BreathingSequence seq) async {
    final c = ref.read(sieColorsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Удалить последовательность?',
            style: TextStyle(color: c.textPrimary, fontSize: 17)),
        content: Text('«${seq.name}» будет удалена безвозвратно.',
            style: TextStyle(color: c.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Удалить', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(breathingSequencesProvider.notifier)
          .deleteSequence(seq.id);
    }
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.c});
  final SieColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: c.textPrimary, size: 22),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Мои последовательности',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.air_rounded, size: 20, color: c.textSecondary),
        ],
      ),
    );
  }
}

// ─── Sequence card ────────────────────────────────────────────────────────────

class _SequenceCard extends StatelessWidget {
  const _SequenceCard({
    required this.seq,
    required this.c,
    required this.onRun,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  final BreathingSequence seq;
  final SieColors c;
  final VoidCallback onRun;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onRun,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seq.name,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${seq.roundCount} ${_roundsWord(seq.roundCount)}  ·  '
                      '${seq.totalCycles} циклов  ·  ~${formatMinSec(seq.estimatedSeconds)}',
                      style: TextStyle(color: c.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < seq.rounds.length && i < 6; i++)
                          _RoundChip(round: seq.rounds[i], index: i, c: c),
                        if (seq.rounds.length > 6)
                          _MoreChip(count: seq.rounds.length - 6, c: c),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Icon(Icons.play_circle_fill_rounded,
                      color: c.accent, size: 30),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: c.textSecondary, size: 20),
                    color: c.surface,
                    onSelected: (v) {
                      switch (v) {
                        case 'edit':
                          onEdit();
                        case 'duplicate':
                          onDuplicate();
                        case 'delete':
                          onDelete();
                      }
                    },
                    itemBuilder: (_) => [
                      _menuItem('edit', Icons.edit_outlined, 'Редактировать', c),
                      _menuItem('duplicate', Icons.copy_all_outlined,
                          'Дублировать', c),
                      _menuItem('delete', Icons.delete_outline, 'Удалить', c,
                          danger: true),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label, SieColors c,
      {bool danger = false}) {
    final color = danger ? c.danger : c.textPrimary;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  String _roundsWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'раунд';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
      return 'раунда';
    }
    return 'раундов';
  }
}

class _RoundChip extends StatelessWidget {
  const _RoundChip({required this.round, required this.index, required this.c});
  final BreathingRound round;
  final int index;
  final SieColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.accent.withValues(alpha: 0.25)),
      ),
      child: Text(
        '${index + 1}: ${round.cyclesPerRound}ц · ${round.exhaustRetentionSecs}с',
        style: TextStyle(
            color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _MoreChip extends StatelessWidget {
  const _MoreChip({required this.count, required this.c});
  final int count;
  final SieColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Text('+$count',
          style: TextStyle(color: c.textSecondary, fontSize: 11)),
    );
  }
}

// ─── Empty ────────────────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  const _Empty({required this.c, required this.icon, required this.text});
  final SieColors c;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: c.textSecondary.withValues(alpha: 0.6)),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: c.textSecondary, fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
