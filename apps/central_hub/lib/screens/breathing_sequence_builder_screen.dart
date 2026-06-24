import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

/// Internal holder pairing a round with a stable key so the ReorderableListView
/// can track items across reorders even when two rounds have identical params.
class _RoundItem {
  _RoundItem(this.key, this.round);
  final int key;
  BreathingRound round;
}

class BreathingSequenceBuilderScreen extends ConsumerStatefulWidget {
  const BreathingSequenceBuilderScreen({super.key, this.existing});

  /// When non-null, the screen edits this sequence in place; otherwise it
  /// creates a new one.
  final BreathingSequence? existing;

  @override
  ConsumerState<BreathingSequenceBuilderScreen> createState() =>
      _BreathingSequenceBuilderScreenState();
}

class _BreathingSequenceBuilderScreenState
    extends ConsumerState<BreathingSequenceBuilderScreen> {
  late final TextEditingController _nameCtrl;
  final List<_RoundItem> _items = [];
  int _nextKey = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    final initial = widget.existing?.rounds ?? const [BreathingRound()];
    for (final r in initial.isEmpty ? const [BreathingRound()] : initial) {
      _items.add(_RoundItem(_nextKey++, r));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  int get _totalSeconds =>
      _items.fold(0, (s, it) => s + it.round.estimatedSeconds);

  void _addRound() {
    // New round seeds from the last one for quick iteration.
    final seed = _items.isNotEmpty ? _items.last.round : const BreathingRound();
    setState(() => _items.add(_RoundItem(_nextKey++, seed)));
  }

  void _removeRound(int key) {
    if (_items.length <= 1) return;
    setState(() => _items.removeWhere((it) => it.key == key));
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  Future<void> _editRound(_RoundItem item) async {
    final c = ref.read(sieColorsProvider);
    final result = await showModalBottomSheet<BreathingRound>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RoundEditorSheet(
        round: item.round,
        index: _items.indexOf(item),
        c: c,
      ),
    );
    if (result != null) {
      setState(() => item.round = result);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название последовательности')),
      );
      return;
    }
    if (_items.isEmpty) return;
    setState(() => _saving = true);
    final rounds = _items.map((it) => it.round).toList();
    final notifier = ref.read(breathingSequencesProvider.notifier);
    if (widget.existing == null) {
      await notifier.createSequence(name: name, rounds: rounds);
    } else {
      await notifier
          .updateSequence(widget.existing!.copyWith(name: name, rounds: rounds));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    final isEdit = widget.existing != null;

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(bottom: BorderSide(color: c.border)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon:
                          Icon(Icons.arrow_back, color: c.textPrimary, size: 22),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isEdit
                            ? 'Редактирование'
                            : 'Новая последовательность',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: [
                    // Name
                    TextField(
                      controller: _nameCtrl,
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Название последовательности',
                        hintStyle:
                            TextStyle(color: c.textSecondary, fontSize: 17),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: c.border)),
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: c.accent)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'РАУНДЫ (${_items.length})',
                          style: TextStyle(
                            color: c.textSecondary.withValues(alpha: 0.7),
                            fontSize: 11,
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '≈ ${_fmt(_totalSeconds)}',
                          style: TextStyle(
                              color: c.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Зажмите блок и перетащите, чтобы изменить порядок.',
                      style: TextStyle(
                          color: c.textSecondary.withValues(alpha: 0.6),
                          fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: _items.length,
                      onReorder: _onReorder,
                      itemBuilder: (context, i) {
                        final item = _items[i];
                        return _RoundBlock(
                          key: ValueKey(item.key),
                          index: i,
                          round: item.round,
                          c: c,
                          canDelete: _items.length > 1,
                          onEdit: () => _editRound(item),
                          onDelete: () => _removeRound(item.key),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _AddRoundButton(c: c, onTap: _addRound),
                  ],
                ),
              ),
              // Save bar
              Container(
                padding: EdgeInsets.fromLTRB(
                    16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            isEdit ? 'СОХРАНИТЬ' : 'СОЗДАТЬ',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

// ─── Round block ──────────────────────────────────────────────────────────────

class _RoundBlock extends StatelessWidget {
  const _RoundBlock({
    required super.key,
    required this.index,
    required this.round,
    required this.c,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final BreathingRound round;
  final SieColors c;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border(
                left: BorderSide(color: c.accent.withValues(alpha: 0.7), width: 3),
                top: BorderSide(color: c.border),
                right: BorderSide(color: c.border),
                bottom: BorderSide(color: c.border),
              ),
            ),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.drag_indicator,
                        color: c.textSecondary.withValues(alpha: 0.6), size: 22),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'РАУНД ${index + 1}',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _stat(Icons.repeat, '${round.cyclesPerRound} циклов'),
                          _stat(Icons.south, '${round.inhaleSecs}с вдох'),
                          _stat(Icons.north, '${round.exhaleSecs}с выдох'),
                          _stat(Icons.pause_circle_outline,
                              '${round.exhaustRetentionSecs}с задержка'),
                          _stat(Icons.favorite_outline,
                              '${round.recoveryHoldSecs}с восст.'),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined,
                      color: c.textSecondary, size: 19),
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                ),
                if (canDelete)
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: c.textSecondary, size: 19),
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12)),
        ],
      );
}

class _AddRoundButton extends StatelessWidget {
  const _AddRoundButton({required this.c, required this.onTap});
  final SieColors c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: c.accent.withValues(alpha: 0.5),
                width: 1.2,
                style: BorderStyle.solid),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: c.accent, size: 20),
              const SizedBox(width: 8),
              Text('ДОБАВИТЬ РАУНД',
                  style: TextStyle(
                      color: c.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Round editor sheet ───────────────────────────────────────────────────────

class _RoundEditorSheet extends StatefulWidget {
  const _RoundEditorSheet(
      {required this.round, required this.index, required this.c});
  final BreathingRound round;
  final int index;
  final SieColors c;

  @override
  State<_RoundEditorSheet> createState() => _RoundEditorSheetState();
}

class _RoundEditorSheetState extends State<_RoundEditorSheet> {
  late BreathingRound _r;

  @override
  void initState() {
    super.initState();
    _r = widget.round;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('РАУНД ${widget.index + 1}',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5)),
              const SizedBox(height: 16),
              _StepperRow(
                label: 'ЦИКЛОВ ДЫХАНИЯ',
                value: _r.cyclesPerRound,
                min: 5,
                max: 60,
                step: 5,
                c: c,
                onChanged: (v) => setState(() => _r = _r.copyWith(cyclesPerRound: v)),
              ),
              _StepperRow(
                label: 'ВДОХ (СЕК)',
                value: _r.inhaleSecs,
                min: 1,
                max: 10,
                c: c,
                onChanged: (v) => setState(() => _r = _r.copyWith(inhaleSecs: v)),
              ),
              _StepperRow(
                label: 'ВЫДОХ (СЕК)',
                value: _r.exhaleSecs,
                min: 1,
                max: 10,
                c: c,
                onChanged: (v) => setState(() => _r = _r.copyWith(exhaleSecs: v)),
              ),
              _StepperRow(
                label: 'ЗАДЕРЖКА НА ВЫДОХЕ (СЕК)',
                value: _r.exhaustRetentionSecs,
                min: 10,
                max: 300,
                step: 10,
                c: c,
                onChanged: (v) =>
                    setState(() => _r = _r.copyWith(exhaustRetentionSecs: v)),
              ),
              _StepperRow(
                label: 'ВОССТАНОВИТЕЛЬНАЯ ЗАДЕРЖКА (СЕК)',
                value: _r.recoveryHoldSecs,
                min: 5,
                max: 120,
                step: 5,
                c: c,
                onChanged: (v) =>
                    setState(() => _r = _r.copyWith(recoveryHoldSecs: v)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _r),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('ГОТОВО',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.c,
    required this.onChanged,
    this.step = 1,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final SieColors c;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(color: c.textSecondary, fontSize: 13)),
          ),
          _btn(Icons.remove, value > min, () {
            final v = (value - step).clamp(min, max);
            if (v != value) onChanged(v);
          }),
          SizedBox(
            width: 44,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700),
            ),
          ),
          _btn(Icons.add, value < max, () {
            final v = (value + step).clamp(min, max);
            if (v != value) onChanged(v);
          }),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, bool enabled, VoidCallback onTap) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: enabled ? c.accent.withValues(alpha: 0.12) : c.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
                color: enabled
                    ? c.accent.withValues(alpha: 0.4)
                    : c.border),
          ),
          child: Icon(icon,
              size: 18,
              color: enabled ? c.accent : c.textSecondary.withValues(alpha: 0.4)),
        ),
      );
}
