import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sie_core/sie_core.dart';

// ─── State ────────────────────────────────────────────────────────────────────

enum _SheetStage { loading, preview, applying, error }

// ─── Sheet Entry Point ────────────────────────────────────────────────────────

Future<void> showAiDecompositionSheet(
    BuildContext context, Goal goal) async {
  final prefs = await SharedPreferences.getInstance();
  final accepted = prefs.getBool('ai_privacy_accepted') ?? false;

  if (!context.mounted) return;

  if (!accepted) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _PrivacyDialog(),
    );
    if (confirmed != true) return;
    await prefs.setBool('ai_privacy_accepted', true);
  }

  if (!context.mounted) return;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AiDecompositionSheet(goal: goal),
  );
}

// ─── Privacy Dialog ───────────────────────────────────────────────────────────

class _PrivacyDialog extends ConsumerWidget {
  const _PrivacyDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(sieColorsProvider);
    return AlertDialog(
      backgroundColor: sc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: sc.border),
      ),
      title: Row(
        children: [
          Icon(Icons.auto_awesome_outlined, color: sc.accent, size: 18),
          const SizedBox(width: 8),
          Text(
            'AI-СТРАТЕГ',
            style: TextStyle(
              color: sc.textPrimary,
              fontSize: 14,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: Text(
        'Название и описание цели будут отправлены в Groq AI для генерации плана.\n\nДанные используются только для этого запроса и не сохраняются сервисом.',
        style: TextStyle(color: sc.textSecondary, fontSize: 13, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('ОТМЕНА',
              style: TextStyle(color: sc.textSecondary, fontSize: 12)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('ПРОДОЛЖИТЬ',
              style: TextStyle(
                  color: sc.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ─── Main Sheet ───────────────────────────────────────────────────────────────

class AiDecompositionSheet extends ConsumerStatefulWidget {
  const AiDecompositionSheet({super.key, required this.goal});
  final Goal goal;

  @override
  ConsumerState<AiDecompositionSheet> createState() =>
      _AiDecompositionSheetState();
}

class _AiDecompositionSheetState
    extends ConsumerState<AiDecompositionSheet>
    with SingleTickerProviderStateMixin {
  _SheetStage _stage = _SheetStage.loading;
  DecompositionResult? _result;
  String? _errorMessage;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _startGeneration();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _startGeneration() async {
    setState(() {
      _stage = _SheetStage.loading;
      _errorMessage = null;
    });
    try {
      final result = await GroqService.instance.decomposeGoal(
        widget.goal.name,
        widget.goal.description,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _stage = _SheetStage.preview;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _formatError(e);
        _stage = _SheetStage.error;
      });
    }
  }

  String _formatError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('socketexception') || msg.contains('network') || msg.contains('connection refused')) {
      return 'Нет подключения к сети. Проверь интернет и повтори.';
    }
    if (msg.contains('401') || msg.contains('api_key') || msg.contains('unauthorized')) {
      return 'Ошибка авторизации API. Обратись к разработчику.';
    }
    if (msg.contains('429') || msg.contains('rate_limit') || msg.contains('too many')) {
      return 'Слишком много запросов. Подожди немного и повтори.';
    }
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'Сервер не ответил вовремя. Повтори попытку.';
    }
    return 'Не удалось получить план. Повтори попытку.';
  }

  Future<void> _apply() async {
    final result = _result;
    if (result == null) return;
    setState(() => _stage = _SheetStage.applying);
    try {
      await ref
          .read(planningProvider.notifier)
          .applyAiDecomposition(widget.goal.id, result);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Ошибка сохранения: $e';
        _stage = _SheetStage.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            _handle(c),
            _header(c),
            const Divider(height: 1),
            Expanded(child: _body(c, scrollController)),
            if (_stage == _SheetStage.preview || _stage == _SheetStage.applying)
              _actionBar(c),
          ],
        ),
      ),
    );
  }

  Widget _handle(SieColors c) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Container(
          width: 36,
          height: 3,
          decoration: BoxDecoration(
            color: c.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _header(SieColors c) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_outlined, color: c.accent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI СТРАТЕГ',
                    style: TextStyle(
                      color: c.accent,
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.goal.name,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: c.textSecondary, size: 20),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );

  Widget _body(SieColors c, ScrollController scrollController) {
    switch (_stage) {
      case _SheetStage.loading:
        return _loadingBody(c);
      case _SheetStage.preview:
        return _previewBody(c, scrollController);
      case _SheetStage.applying:
        return _applyingBody(c);
      case _SheetStage.error:
        return _errorBody(c);
    }
  }

  Widget _loadingBody(SieColors c) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Opacity(
                opacity: _pulseAnim.value,
                child: CircularProgressIndicator(
                  color: c.accent,
                  strokeWidth: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'AI СТРАТЕГ АНАЛИЗИРУЕТ ЦЕЛЬ...',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Обычно занимает 3–5 секунд',
              style: TextStyle(color: c.iconMuted, fontSize: 11),
            ),
          ],
        ),
      );

  Widget _applyingBody(SieColors c) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: c.accent, strokeWidth: 1.5),
            const SizedBox(height: 20),
            Text(
              'СОХРАНЕНИЕ ПЛАНА...',
              style: TextStyle(
                  color: c.textSecondary, fontSize: 11, letterSpacing: 1.5),
            ),
          ],
        ),
      );

  Widget _errorBody(SieColors c) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: c.danger, size: 40),
            const SizedBox(height: 16),
            Text(
              'ОШИБКА ГЕНЕРАЦИИ',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 13,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Неизвестная ошибка',
              style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: c.border),
                    foregroundColor: c.textSecondary,
                    textStyle:
                        const TextStyle(fontSize: 11, letterSpacing: 1),
                  ),
                  child: const Text('ЗАКРЫТЬ'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _startGeneration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: Colors.white,
                    textStyle:
                        const TextStyle(fontSize: 11, letterSpacing: 1),
                  ),
                  child: const Text('ПОВТОРИТЬ'),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _previewBody(SieColors c, ScrollController scrollController) {
    final result = _result!;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        _summaryChip(c, result),
        const SizedBox(height: 16),
        ...result.subGoals.asMap().entries.map(
              (e) => _SubGoalTile(
                index: e.key,
                sg: e.value,
                sc: c,
              ),
            ),
        if (result.milestones.isNotEmpty) ...[
          const SizedBox(height: 8),
          _milestonesSection(c, result.milestones),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _summaryChip(SieColors c, DecompositionResult result) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: c.accent, size: 14),
            const SizedBox(width: 8),
            Text(
              '${result.subGoals.length} этапа · ${result.totalTasks} задач · ${result.milestones.length} чекпоинта',
              style: TextStyle(
                color: c.accent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );

  Widget _milestonesSection(SieColors c, List<AiMilestone> milestones) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.flag_outlined, size: 14, color: c.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'КОНТРОЛЬНЫЕ ТОЧКИ',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ...milestones.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.diamond_outlined, size: 12, color: c.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      m.name,
                      style: TextStyle(color: c.textPrimary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _actionBar(SieColors c) => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: Row(
          children: [
            OutlinedButton(
              onPressed: _stage == _SheetStage.applying
                  ? null
                  : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.border),
                foregroundColor: c.textSecondary,
                textStyle: const TextStyle(fontSize: 11, letterSpacing: 1),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              child: const Text('ОТМЕНА'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _stage == _SheetStage.applying ? null : _startGeneration,
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('ПЕРЕГЕНЕРИРОВАТЬ'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.accent.withValues(alpha: 0.5)),
                foregroundColor: c.accent,
                textStyle: const TextStyle(fontSize: 11, letterSpacing: 1),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _stage == _SheetStage.applying ? null : _apply,
              icon: const Icon(Icons.check, size: 14),
              label: const Text('ПРИНЯТЬ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      );
}

// ─── Sub-goal Tile ────────────────────────────────────────────────────────────

class _SubGoalTile extends StatefulWidget {
  final int index;
  final AiSubGoal sg;
  final SieColors sc;
  const _SubGoalTile({required this.index, required this.sg, required this.sc});

  @override
  State<_SubGoalTile> createState() => _SubGoalTileState();
}

class _SubGoalTileState extends State<_SubGoalTile> {
  bool _expanded = true;

  Color _weightColor(int w) => switch (w) {
        1 => const Color(0xFF888898),
        3 => const Color(0xFFC8A84B),
        _ => const Color(0xFFE03050),
      };

  String _weightLabel(int w) => switch (w) {
        1 => '●',
        3 => '●●●',
        _ => '●●●●●',
      };

  @override
  Widget build(BuildContext context) {
    final c = widget.sc;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.flatCard(radius: 10).color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius:
                BorderRadius.vertical(top: const Radius.circular(10),
                    bottom: _expanded ? Radius.zero : const Radius.circular(10)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${widget.index + 1}',
                      style: TextStyle(
                        color: c.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.sg.name,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${widget.sg.tasks.length} задач',
                    style: TextStyle(color: c.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: c.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Column(
              children: widget.sg.tasks.map((t) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 30),
                      Icon(Icons.radio_button_unchecked,
                          size: 12, color: c.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.name,
                          style:
                              TextStyle(color: c.textSecondary, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: switch (t.weight) {
                          1 => 'Лёгкая задача',
                          3 => 'Средняя задача',
                          _ => 'Тяжёлая задача',
                        },
                        child: Text(
                          _weightLabel(t.weight),
                          style: TextStyle(
                            color: _weightColor(t.weight),
                            fontSize: 8,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
