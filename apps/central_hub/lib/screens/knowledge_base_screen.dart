import 'package:flutter/material.dart';
import 'package:sie_core/sie_core.dart';

// ── Knowledge Base Screen ─────────────────────────────────────

class KnowledgeBaseScreen extends StatelessWidget {
  const KnowledgeBaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SieTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
                children: const [
                  _SystemHeader(),
                  SizedBox(height: 28),
                  SectionHeader(title: 'МОДУЛИ СИСТЕМЫ'),
                  SizedBox(height: 14),
                  _KbEntry(
                    moduleTag: 'M-01',
                    label: 'BREATHING',
                    subtitle: 'Сброс нервной системы',
                    body: _breathingBody,
                  ),
                  SizedBox(height: 10),
                  _KbEntry(
                    moduleTag: 'M-02',
                    label: 'HABIT ARCHIVE',
                    subtitle: 'Архив нейронных связей',
                    body: _habitsBody,
                  ),
                  SizedBox(height: 10),
                  _KbEntry(
                    moduleTag: 'M-03',
                    label: 'FOCUS PROTOCOL',
                    subtitle: 'Протокол глубокой работы',
                    body: _focusBody,
                  ),
                  SizedBox(height: 28),
                  SectionHeader(title: 'ТАБЛИЦА ПРОГРЕССА'),
                  SizedBox(height: 14),
                  _XpTable(),
                  SizedBox(height: 28),
                  SectionHeader(title: 'КОРПОРАТИВНАЯ ЭТИКА'),
                  SizedBox(height: 14),
                  _EthicsSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: SieTheme.textSecondary,
              size: 18,
            ),
          ),
          Expanded(
            child: Text(
              'БАЗА ЗНАНИЙ',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ── System Header ─────────────────────────────────────────────

class _SystemHeader extends StatelessWidget {
  const _SystemHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SieTheme.surface,
        border: Border.all(color: SieTheme.borderAccent),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 14, color: SieTheme.accent),
              const SizedBox(width: 10),
              Text(
                'SiE KNOWLEDGE MATRIX v1.0',
                style: TextStyle(
                  color: SieTheme.accent,
                  fontSize: 10,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w600,
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
                  fontSize: 12,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Expandable KB Entry ───────────────────────────────────────

class _KbEntry extends StatefulWidget {
  final String moduleTag;
  final String label;
  final String subtitle;
  final String body;

  const _KbEntry({
    required this.moduleTag,
    required this.label,
    required this.subtitle,
    required this.body,
  });

  @override
  State<_KbEntry> createState() => _KbEntryState();
}

class _KbEntryState extends State<_KbEntry>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SieTheme.surface,
        border: Border.all(
          color: _expanded ? SieTheme.borderAccent : SieTheme.borderDefault,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: SieTheme.borderAccent),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      widget.moduleTag,
                      style: TextStyle(
                        color: SieTheme.accent,
                        fontSize: 9,
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
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(
                      Icons.chevron_right,
                      color: SieTheme.borderAccent,
                      size: 18,
                    ),
                  ),
                ],
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
                      children: [
                        const Divider(
                          color: SieTheme.borderDefault,
                          height: 1,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            widget.body,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  height: 1.7,
                                  fontSize: 12,
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
    );
  }
}

// ── XP Table ──────────────────────────────────────────────────

class _XpTable extends StatelessWidget {
  const _XpTable();

  @override
  Widget build(BuildContext context) {
    const rows = [
      _XpRow('Завершение дыхательной сессии', '100 XP', 'Breathing'),
      _XpRow('Выход из дыхания ≥ 30 сек', '10–80 XP', 'Breathing'),
      _XpRow('Отметка привычки за день', '15 XP', 'Habits'),
      _XpRow('Создание первой привычки', '25 XP', 'Habits'),
      _XpRow('Страйк привычки 7 дней', '50 XP', 'Habits'),
      _XpRow('Завершение фокус-сессии', '30 XP', 'Focus'),
      _XpRow('Завершение блока отдыха', '5 XP', 'Focus'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: SieTheme.surface,
        border: Border.all(color: SieTheme.borderDefault),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: SieTheme.borderDefault),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'АКТИВНОСТЬ',
                    style: TextStyle(
                      color: SieTheme.textSecondary,
                      fontSize: 9,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'НАГРАДА',
                  style: TextStyle(
                    color: SieTheme.textSecondary,
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
                      color: SieTheme.textSecondary,
                      fontSize: 9,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Data rows
          ...rows.asMap().entries.map((e) {
            final isLast = e.key == rows.length - 1;
            return _XpTableRow(row: e.value, isLast: isLast);
          }),
          // Footnote
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '1000 XP = LEVEL UP  ·  Уровень определяет ранг оперативника в иерархии SiE',
              style: TextStyle(
                color: SieTheme.textSecondary.withValues(alpha: 0.6),
                fontSize: 10,
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
  const _XpTableRow({required this.row, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: SieTheme.borderDefault, width: 0.5),
              ),
            ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              row.activity,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            row.reward,
            style: TextStyle(
              color: SieTheme.accent,
              fontSize: 11,
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
                color: SieTheme.textSecondary,
                fontSize: 10,
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

class _EthicsSection extends StatelessWidget {
  const _EthicsSection();

  @override
  Widget build(BuildContext context) {
    const paragraphs = [
      'SiE — Self-improvement Ecosystem — не приложение, это операционная система личного роста. Каждое действие здесь является вкладом в долгосрочную архитектуру твоей эффективности.',
      'Мы верим в науку, а не в мотивацию. Мотивация нестабильна — системы и протоколы постоянны. Каждый модуль SiE построен на верифицированных механиках: нейробиологии дыхания, психологии формирования привычек и когнитивной науке концентрации.',
      'Оперативник SiE принимает ответственность за свой прогресс. XP — это не игровая механика, это количественная мера вложенных усилий. Уровень — это ранг в иерархии тех, кто выбрал системный подход к себе.',
      'Корпоративный девиз: "Дисциплина — это форма уважения к своему будущему я."',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SieTheme.surface,
        border: Border.all(color: SieTheme.borderDefault),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < paragraphs.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            Text(
              paragraphs[i],
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.7,
                    fontSize: 12,
                    fontStyle: i == paragraphs.length - 1
                        ? FontStyle.italic
                        : FontStyle.normal,
                    color: i == paragraphs.length - 1
                        ? SieTheme.accent
                        : null,
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
