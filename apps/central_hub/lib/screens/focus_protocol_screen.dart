import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

class FocusProtocolScreen extends ConsumerStatefulWidget {
  const FocusProtocolScreen({super.key});

  @override
  ConsumerState<FocusProtocolScreen> createState() =>
      _FocusProtocolScreenState();
}

class _FocusProtocolScreenState extends ConsumerState<FocusProtocolScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _skyCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  bool _onboardingDismissed = false;
  bool _showOnboardingManual = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _skyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 150),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _skyCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      ref.read(focusTimerProvider.notifier).handleForeground();
    }
    super.didChangeAppLifecycleState(lifecycleState);
  }

  void _onBack() {
    ref.read(focusTimerProvider.notifier).reset();
    Navigator.of(context).pop();
  }

  void _showSettings() {
    final timerState = ref.read(focusTimerProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: SieTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
        side: BorderSide(color: SieTheme.borderDefault),
      ),
      builder: (_) => _FocusSettingsSheet(
        settings: timerState.settings,
        isTimerActive: timerState.phase != FocusPhase.idle,
        onChanged: (s) =>
            ref.read(focusTimerProvider.notifier).updateSettings(s),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(focusTimerProvider);

    ref.listen(focusTimerProvider.select((s) => s.isRunning), (_, isRunning) {
      if (isRunning) {
        _pulseCtrl.repeat(reverse: true);
      } else {
        _pulseCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });

    final phaseColor = timerState.phase == FocusPhase.breakTime
        ? SieTheme.accentSecondary
        : SieTheme.accent;

    final onboardingProfile = ref.watch(userProfileProvider).valueOrNull;
    final showOnboarding = _showOnboardingManual ||
        (!_onboardingDismissed &&
            onboardingProfile != null &&
            !onboardingProfile.hasSeenOnboardingFocus);

    return Stack(
      children: [
        Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: StarrySkyBackground(animation: _skyCtrl),
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _TopBar(
                    completedSessions: timerState.completedSessions,
                    onBack: _onBack,
                    onInfo: () => setState(() => _showOnboardingManual = true),
                  ),
                ),
                Center(
                  child: AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, child) => Transform.scale(
                      scale: 1.0 + 0.03 * _pulseAnim.value,
                      child: _FocusRing(
                        progress: timerState.progress,
                        formattedTime: timerState.formattedTime,
                        phaseColor: phaseColor,
                        phase: timerState.phase,
                        glowOpacity: _pulseAnim.value * 0.35,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 40,
                  left: 32,
                  right: 32,
                  child: _BottomControls(
                    timerState: timerState,
                    phaseColor: phaseColor,
                    onStart: () =>
                        ref.read(focusTimerProvider.notifier).start(),
                    onPause: () =>
                        ref.read(focusTimerProvider.notifier).pause(),
                    onReset: () =>
                        ref.read(focusTimerProvider.notifier).reset(),
                    onSettings: _showSettings,
                  ),
                ),
                if (timerState.pendingResult != null)
                  _ResultOverlay(
                    result: timerState.pendingResult!,
                    onContinue: () =>
                        ref.read(focusTimerProvider.notifier).clearResult(),
                  ),
              ],
            ),
          ),
        ],
      ),
        ),
        Positioned.fill(
          child: OnboardingOverlay(
            visible: showOnboarding,
            moduleLabel: 'ФОКУС',
            description: 'Протокол глубокой работы.',
            benefit:
                'Тренировка концентрации и защита от выгорания. Временны́е блоки '
                'защищают состояние потока и консолидируют рабочую память.',
            onAccept: () {
              if (_showOnboardingManual) {
                setState(() => _showOnboardingManual = false);
              } else {
                setState(() => _onboardingDismissed = true);
                markOnboardingSeen('focus');
              }
            },
          ),
        ),
      ],
    );
  }
}

// ── Focus Ring ────────────────────────────────────────────────

class _FocusRing extends StatelessWidget {
  final double progress;
  final String formattedTime;
  final Color phaseColor;
  final FocusPhase phase;
  final double glowOpacity;

  const _FocusRing({
    required this.progress,
    required this.formattedTime,
    required this.phaseColor,
    required this.phase,
    required this.glowOpacity,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(260, 260),
            painter: _FocusRingPainter(
              progress: progress,
              color: phaseColor,
              glowOpacity: glowOpacity,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formattedTime,
                style: TextStyle(
                  color: phaseColor,
                  fontSize: 52,
                  fontWeight: FontWeight.w100,
                  letterSpacing: 6,
                  height: 1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                phase == FocusPhase.breakTime ? 'BREAK' : 'FOCUS',
                style: TextStyle(
                  color: phaseColor.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double glowOpacity;

  _FocusRingPainter({
    required this.progress,
    required this.color,
    required this.glowOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 2.5;
    const startAngle = -math.pi / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (progress <= 0) return;

    final sweepAngle = 2 * math.pi * progress;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    if (glowOpacity > 0.01) {
      canvas.drawArc(
        arcRect,
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..color = color.withValues(alpha: glowOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 12
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    canvas.drawArc(
      arcRect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    final dotAngle = startAngle + sweepAngle;
    final dotX = center.dx + radius * math.cos(dotAngle);
    final dotY = center.dy + radius * math.sin(dotAngle);
    canvas.drawCircle(
      Offset(dotX, dotY),
      strokeWidth + 1,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.glowOpacity != glowOpacity;
}

// ── Top Bar ───────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int completedSessions;
  final VoidCallback onBack;
  final VoidCallback onInfo;

  const _TopBar({
    required this.completedSessions,
    required this.onBack,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: SieTheme.textSecondary,
              size: 18,
            ),
          ),
          const Spacer(),
          if (completedSessions > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: SieTheme.borderAccent),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                'SESSION $completedSessions',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          const Spacer(),
          IconButton(
            onPressed: onInfo,
            icon: Icon(
              Icons.help_outline,
              color: SieTheme.textSecondary.withValues(alpha: 0.7),
              size: 20,
            ),
            tooltip: 'INFO',
          ),
        ],
      ),
    );
  }
}

// ── Bottom Controls ───────────────────────────────────────────

class _BottomControls extends StatelessWidget {
  final FocusTimerState timerState;
  final Color phaseColor;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onReset;
  final VoidCallback onSettings;

  const _BottomControls({
    required this.timerState,
    required this.phaseColor,
    required this.onStart,
    required this.onPause,
    required this.onReset,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final isIdle = timerState.phase == FocusPhase.idle;
    final s = timerState.settings;
    final phaseLabel = timerState.phase == FocusPhase.breakTime
        ? 'BREAK TIME — ${s.breakMinutes} MIN'
        : 'FOCUS SESSION — ${s.workMinutes} MIN';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          phaseLabel,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          isIdle ? 'TAP TO INITIATE FOCUS PROTOCOL' : '',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: SieTheme.accent.withValues(alpha: 0.4),
                fontSize: 11,
                letterSpacing: 2,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _SettingsButton(onTap: onSettings),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ControlButton(
              label: timerState.isRunning ? 'PAUSE' : 'START',
              color: phaseColor,
              filled: true,
              onTap: timerState.isRunning ? onPause : onStart,
            ),
            if (!isIdle) ...[
              const SizedBox(width: 16),
              _ControlButton(
                label: 'RESET',
                color: SieTheme.textSecondary,
                filled: false,
                onTap: onReset,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ── Settings Button ───────────────────────────────────────────

class _SettingsButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SettingsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: SieTheme.borderDefault),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tune, size: 18, color: SieTheme.textSecondary),
              const SizedBox(width: 10),
              Text(
                'PROTOCOL SETTINGS',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Control Button ────────────────────────────────────────────

class _ControlButton extends StatefulWidget {
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _ControlButton({
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 70),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
          decoration: BoxDecoration(
            color: widget.filled
                ? widget.color.withValues(alpha: 0.12)
                : null,
            border: Border.all(
              color: widget.filled ? widget.color : SieTheme.borderDefault,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color:
                  widget.filled ? widget.color : SieTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Settings Sheet ────────────────────────────────────────────

class _FocusSettingsSheet extends StatefulWidget {
  final FocusSettings settings;
  final bool isTimerActive;
  final ValueChanged<FocusSettings> onChanged;

  const _FocusSettingsSheet({
    required this.settings,
    required this.isTimerActive,
    required this.onChanged,
  });

  @override
  State<_FocusSettingsSheet> createState() => _FocusSettingsSheetState();
}

class _FocusSettingsSheetState extends State<_FocusSettingsSheet> {
  late FocusSettings _s;

  @override
  void initState() {
    super.initState();
    _s = widget.settings;
  }

  void _update(FocusSettings s) {
    setState(() => _s = s);
    widget.onChanged(s);
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.isTimerActive;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'PROTOCOL SETTINGS',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (locked) ...[
            const SizedBox(height: 8),
            Text(
              'DURATION LOCKED DURING SESSION',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: SieTheme.textSecondary.withValues(alpha: 0.5),
                  ),
            ),
          ],
          const SizedBox(height: 20),
          _FocusSettingRow(
            label: 'FOCUS DURATION  (MIN)',
            value: _s.workMinutes,
            min: 5,
            max: 60,
            step: 5,
            enabled: !locked,
            onChanged: (v) => _update(_s.copyWith(workMinutes: v)),
          ),
          _FocusSettingRow(
            label: 'BREAK DURATION  (MIN)',
            value: _s.breakMinutes,
            min: 1,
            max: 15,
            step: 1,
            enabled: !locked,
            onChanged: (v) => _update(_s.copyWith(breakMinutes: v)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Divider(color: SieTheme.borderDefault, height: 1),
          ),
          _AmbientToggleRow(
            label: 'FOCUS MUSIC',
            icon: Icons.work_outline,
            value: _s.isWorkMusicEnabled,
            onChanged: (v) => _update(_s.copyWith(isWorkMusicEnabled: v)),
          ),
          _AmbientToggleRow(
            label: 'BREAK MUSIC',
            icon: Icons.coffee_outlined,
            value: _s.isBreakMusicEnabled,
            onChanged: (v) => _update(_s.copyWith(isBreakMusicEnabled: v)),
          ),
        ],
      ),
    );
  }
}

class _FocusSettingRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const _FocusSettingRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.35,
        child: Row(
          children: [
            Expanded(
              child:
                  Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            _StepBtn(
              icon: Icons.remove,
              active: enabled && value > min,
              onTap: enabled && value > min
                  ? () => onChanged((value - step).clamp(min, max))
                  : null,
            ),
            const SizedBox(width: 20),
            SizedBox(
              width: 36,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: SieTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(width: 20),
            _StepBtn(
              icon: Icons.add,
              active: enabled && value < max,
              onTap: enabled && value < max
                  ? () => onChanged((value + step).clamp(min, max))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbientToggleRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AmbientToggleRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: SieTheme.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: value
                    ? SieTheme.accent.withValues(alpha: 0.25)
                    : SieTheme.borderDefault,
                border: Border.all(
                  color: value ? SieTheme.accent : SieTheme.borderDefault,
                  width: 1.5,
                ),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment:
                    value ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: value ? SieTheme.accent : SieTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  const _StepBtn({required this.icon, required this.active, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border.all(
            color: active ? SieTheme.borderAccent : SieTheme.borderDefault,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Icon(
          icon,
          size: 16,
          color: active ? SieTheme.accent : SieTheme.textSecondary,
        ),
      ),
    );
  }
}

// ── Result Overlay ────────────────────────────────────────────

class _ResultOverlay extends StatefulWidget {
  final FocusSessionResult result;
  final VoidCallback onContinue;

  const _ResultOverlay({required this.result, required this.onContinue});

  @override
  State<_ResultOverlay> createState() => _ResultOverlayState();
}

class _ResultOverlayState extends State<_ResultOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _opacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        color: SieTheme.background.withValues(alpha: 0.88),
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: SieTheme.surface,
                      border:
                          Border.all(color: SieTheme.accent, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: SieTheme.accent.withValues(alpha: 0.4),
                          blurRadius: 36,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.psychology_outlined,
                      size: 44,
                      color: SieTheme.accent,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    'SESSION COMPLETE',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'FOCUS PROTOCOL EXECUTED',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: SieTheme.surface,
                      border: Border.all(color: SieTheme.borderAccent),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'XP GAINED',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              '+${widget.result.xpGained} XP',
                              style: const TextStyle(
                                color: SieTheme.accent,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                            height: 1,
                            color: SieTheme.borderDefault),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.palette_outlined,
                                    size: 14,
                                    color: SieTheme.dp.withValues(alpha: 0.85)),
                                const SizedBox(width: 6),
                                Text(
                                  'DP GAINED',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                            Text(
                              '+${widget.result.dpGained} DP',
                              style: const TextStyle(
                                color: SieTheme.dp,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (widget.result.newAchievement != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: SieTheme.surfaceAlt,
                        border: Border.all(
                          color: SieTheme.accent.withValues(alpha: 0.4),
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  SieTheme.accent.withValues(alpha: 0.1),
                              border: Border.all(color: SieTheme.accent),
                            ),
                            child: const Icon(
                              Icons.military_tech,
                              color: SieTheme.accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ACHIEVEMENT UNLOCKED',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.result.newAchievement!.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 36),
                  GestureDetector(
                    onTap: widget.onContinue,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 14),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: SieTheme.accentSecondary),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Text(
                        'START BREAK',
                        style: TextStyle(
                          color: SieTheme.accentSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
