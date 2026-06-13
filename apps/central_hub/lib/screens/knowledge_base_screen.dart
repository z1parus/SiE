import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

import 'breathing_exercise_screen.dart';
import 'focus_protocol_screen.dart';
import 'habit_tracker_screen.dart';

// ── Knowledge Base Screen ─────────────────────────────────────

class KnowledgeBaseScreen extends ConsumerWidget {
  const KnowledgeBaseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _TopBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
                  children: [
                    const _SystemHeader(),
                    const SizedBox(height: 28),
                    const _NeonSectionLabel(label: 'МОДУЛИ СИСТЕМЫ'),
                    const SizedBox(height: 14),
                    _KbEntry(
                      moduleTag: 'M-01',
                      label: 'BREATHING',
                      subtitle: 'Сброс нервной системы',
                      body: _breathingBody,
                      onOpen: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const BreathingExerciseScreen(
                              openSettings: true),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _KbEntry(
                      moduleTag: 'M-02',
                      label: 'HABIT ARCHIVE',
                      subtitle: 'Архив нейронных связей',
                      body: _habitsBody,
                      onOpen: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const HabitTrackerScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _KbEntry(
                      moduleTag: 'M-03',
                      label: 'FOCUS PROTOCOL',
                      subtitle: 'Протокол глубокой работы',
                      body: _focusBody,
                      onOpen: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const FocusProtocolScreen(openSettings: true),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _NeonSectionLabel(label: 'ТАБЛИЦА ПРОГРЕССА'),
                    const SizedBox(height: 14),
                    const _XpTable(),
                    const SizedBox(height: 28),
                    const _NeonSectionLabel(label: 'КОРПОРАТИВНАЯ ЭТИКА'),
                    const SizedBox(height: 14),
                    const _EthicsSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SieGlassCard(
            padding: EdgeInsets.zero,
            width: 40,
            height: 40,
            onTap: () => Navigator.of(context).pop(),
            child: Icon(
              Icons.arrow_back_ios_new,
              color: c.accent,
              size: 18,
            ),
          ),
          Expanded(
            child: Text(
              'БАЗА ЗНАНИЙ',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: c.textPrimary,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

// ── Neon Section Label ────────────────────────────────────────

class _NeonSectionLabel extends ConsumerWidget {
  final String label;
  const _NeonSectionLabel({required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Row(
      children: [
        Container(
          width: 2,
          height: 12,
          decoration: BoxDecoration(
            color: c.accent,
            boxShadow: null,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 12,
                letterSpacing: 2,
                color: c.accent.withValues(alpha: 0.9),
              ),
        ),
      ],
    );
  }
}

// ── System Header ─────────────────────────────────────────────

class _SystemHeader extends ConsumerWidget {
  const _SystemHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return SieGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: c.accent,
                  boxShadow: null,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'SiE KNOWLEDGE MATRIX v1.0',
                style: TextStyle(
                  color: c.accent,
                  fontSize: 11,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w700,
                  shadows: null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Корпорация SiE — это экосистема саморазвития, построенная на '
            'научных протоколах. Каждый модуль системы воздействует на '
            'конкретные нейронные и физиологические механизмы. Изучи базу '
            'знаний, чтобы понять, как именно работает каждый инструмент и '
            'как максимизировать свой прогресс.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                  fontSize: 13,
                  color: c.textPrimary.withValues(alpha: 0.85),
                ),
          ),
        ],
      ),
    );
  }
}

// ── Expandable KB Entry ───────────────────────────────────────

class _KbEntry extends ConsumerStatefulWidget {
  final String moduleTag;
  final String label;
  final String subtitle;
  final String body;

  /// Optional deep-link — opens the corresponding module (and its settings).
  final VoidCallback? onOpen;

  const _KbEntry({
    required this.moduleTag,
    required this.label,
    required this.subtitle,
    required this.body,
    this.onOpen,
  });

  @override
  ConsumerState<_KbEntry> createState() => _KbEntryState();
}

class _KbEntryState extends ConsumerState<_KbEntry>
    with TickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;
  late final AnimationController _pressCtrl;
  late final Animation<double> _press;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _pressCtrl = AnimationController(vsync: this, value: 0.0);
    _press = CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _fadeCtrl.forward();
    } else {
      _fadeCtrl.reverse();
    }
  }

  void _onPressDown(PointerDownEvent _) {
    _pressCtrl.animateTo(
      1.0,
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeIn,
    );
  }

  void _onPressUp(PointerUpEvent _) => _onRelease();
  void _onPressCancel(PointerCancelEvent _) => _onRelease();

  void _onRelease() {
    _pressCtrl.animateTo(
      0.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _press,
        builder: (_, child) => Transform.scale(
          scale: 1.0 - 0.03 * _press.value,
          child: child,
        ),
        child: SieGlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Listener(
                onPointerDown: _onPressDown,
                onPointerUp: _onPressUp,
                onPointerCancel: _onPressCancel,
                child: GestureDetector(
                  onTap: _toggle,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: c.accent.withValues(alpha: 0.6),
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: null,
                          ),
                          child: Text(
                            widget.moduleTag,
                            style: TextStyle(
                              color: c.accent,
                              fontSize: 10,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.label,
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.subtitle,
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedRotation(
                          turns: _expanded ? 0.25 : 0,
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            Icons.chevron_right,
                            color: _expanded
                                ? c.accent
                                : c.textSecondary.withValues(alpha: 0.6),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _expanded
                    ? FadeTransition(
                        opacity: _fade,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    c.accent.withValues(alpha: 0.0),
                                    c.accent.withValues(alpha: 0.4),
                                    c.accentSecondary.withValues(alpha: 0.4),
                                    c.accentSecondary.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                widget.body,
                                style: TextStyle(
                                  color: c.textPrimary,
                                  height: 1.7,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (widget.onOpen != null)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Semantics(
                                    button: true,
                                    label: 'Открыть модуль',
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        SieHaptics.selection();
                                        widget.onOpen!();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border:
                                              Border.all(color: c.accent),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'ОТКРЫТЬ МОДУЛЬ',
                                              style: TextStyle(
                                                color: c.accent,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 1.5,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Icon(Icons.arrow_forward,
                                                color: c.accent, size: 14),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── XP Table ──────────────────────────────────────────────────

class _XpTable extends ConsumerWidget {
  const _XpTable();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    const rows = [
      _XpRow('Завершение дыхательной сессии', '100 XP', 'Breathing'),
      _XpRow('Выход из дыхания ≥ 30 сек', '10–80 XP', 'Breathing'),
      _XpRow('Отметка привычки за день', '15 XP', 'Habits'),
      _XpRow('Создание первой привычки', '25 XP', 'Habits'),
      _XpRow('Страйк привычки 7 дней', '50 XP', 'Habits'),
      _XpRow('Завершение фокус-сессии', '30 XP', 'Focus'),
      _XpRow('Завершение блока отдыха', '5 XP', 'Focus'),
    ];

    return SieGlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: c.accent.withValues(alpha: 0.2)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'АКТИВНОСТЬ',
                    style: TextStyle(
                      color: c.accent.withValues(alpha: 0.6),
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'НАГРАДА',
                  style: TextStyle(
                    color: c.accent.withValues(alpha: 0.6),
                    fontSize: 9,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 62,
                  child: Text(
                    'МОДУЛЬ',
                    style: TextStyle(
                      color: c.accent.withValues(alpha: 0.6),
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...rows.asMap().entries.map((e) {
            final isLast = e.key == rows.length - 1;
            return _XpTableRow(row: e.value, isLast: isLast, c: c);
          }),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '1000 XP = LEVEL UP  ·  Уровень определяет ранг оперативника в иерархии SiE',
              style: TextStyle(
                color: c.textSecondary.withValues(alpha: 0.7),
                fontSize: 11,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _XpRow {
  final String activity;
  final String reward;
  final String module;
  const _XpRow(this.activity, this.reward, this.module);
}

class _XpTableRow extends StatelessWidget {
  final _XpRow row;
  final bool isLast;
  final SieColors c;
  const _XpTableRow({required this.row, required this.isLast, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: c.border,
                  width: 0.5,
                ),
              ),
            ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              row.activity,
              style: TextStyle(color: c.textPrimary, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            row.reward,
            style: TextStyle(
              color: c.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 62,
            child: Text(
              row.module,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 11,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ethics Section ────────────────────────────────────────────

class _EthicsSection extends ConsumerWidget {
  const _EthicsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    const paragraphs = [
      'SiE — Self-improvement Ecosystem — не приложение, это операционная система личного роста. Каждое действие здесь является вкладом в долгосрочную архитектуру твоей эффективности.',
      'Мы верим в науку, а не в мотивацию. Мотивация нестабильна — системы и протоколы постоянны. Каждый модуль SiE построен на верифицированных механиках: нейробиологии дыхания, психологии формирования привычек и когнитивной науке концентрации.',
      'Оперативник SiE принимает ответственность за свой прогресс. XP — это не игровая механика, это количественная мера вложенных усилий. Уровень — это ранг в иерархии тех, кто выбрал системный подход к себе.',
      'Корпоративный девиз: "Дисциплина — это форма уважения к своему будущему я."',
    ];

    return SieGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < paragraphs.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            Text(
              paragraphs[i],
              style: TextStyle(
                color: i == paragraphs.length - 1
                    ? c.accent
                    : c.textPrimary.withValues(alpha: 0.85),
                height: 1.7,
                fontSize: 13,
                fontStyle: i == paragraphs.length - 1
                    ? FontStyle.italic
                    : FontStyle.normal,
                shadows: null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── KB Content Strings ────────────────────────────────────────

const _breathingBody =
    'Дыхательные практики модуля SiE основаны на методе Вима Хофа — '
    'технике гипервентиляции с последующей задержкой дыхания.\n\n'
    'Физиологически: серия быстрых вдохов снижает уровень CO₂ в крови, '
    'повышает pH (алкалоз). Задержка дыхания на выдохе вызывает управляемый '
    'гипоксический стресс, стимулируя митохондриальные адаптации и выброс '
    'адреналина из надпочечников.\n\n'
    'Доказанные эффекты (рандомизированные исследования):\n'
    '→ Снижение субъективного стресса до 30% уже после одной сессии\n'
    '→ Повышение болевого порога и иммунного ответа\n'
    '→ Улучшение энергетического тонуса за счёт насыщения тканей кислородом\n\n'
    'Рекомендованный протокол: 3 раунда по 30 циклов. Минимальная '
    'эффективная сессия — 30 секунд активной практики.';

const _habitsBody =
    'Привычка — это поведение, перенесённое в базальные ганглии: нейронную '
    'структуру, отвечающую за автоматизацию действий. Когда привычка '
    'сформирована, она не требует волевых ресурсов.\n\n'
    'Механика формирования (модель Ч. Дахигга):\n'
    '→ Триггер → Рутина → Награда\n\n'
    'Для образования устойчивой нейронной связи требуется в среднем '
    '66 дней регулярного выполнения (исследование Lally et al., UCL). '
    'Ключевой показатель — стрик: непрерывная серия отметок.\n\n'
    'Стратегия SiE: начинай с микро-привычек (2-минутное правило). Малые '
    'победы накапливают поведенческий импульс. Система трекинга и пины для '
    'приоритетных протоколов помогают управлять вниманием.';

const _focusBody =
    'Метод Помодоро (Франческо Чирилло, 1980-е) использует временны́е блоки '
    'для защиты состояния глубокого потока от прерываний.\n\n'
    'Нейробиология: в течение 25-минутного блока мозг входит в '
    'состояние устойчивой активации префронтальной коры. Периоды отдыха '
    'необходимы для консолидации рабочей памяти и предотвращения '
    'когнитивного истощения.\n\n'
    'Настройки протокола SiE:\n'
    '→ Рабочий блок: 15–60 минут (по умолчанию 25)\n'
    '→ Короткий отдых: 5–15 минут (по умолчанию 5)\n'
    '→ Длинный отдых: 15–30 минут через каждые 4 сессии\n\n'
    'Исследования показывают: 4 завершённые помодоро в день коррелируют '
    'с 2× продуктивностью по сравнению с непрерывной работой того же '
    'суммарного времени.';
