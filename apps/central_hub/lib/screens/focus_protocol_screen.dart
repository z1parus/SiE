import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

// mirrors provider constant — used only for HUD display
const _kFocusXp = 100;
const _kGold    = Color(0xFFFFD700);

// ─────────────────────────────────────────────────────────────────────────────
// FocusProtocolScreen
// ─────────────────────────────────────────────────────────────────────────────
class FocusProtocolScreen extends ConsumerStatefulWidget {
  const FocusProtocolScreen({super.key, this.openSettings = false});

  /// When true, the settings sheet auto-opens on entry — used by the
  /// Knowledge Base deep-link.
  final bool openSettings;

  @override
  ConsumerState<FocusProtocolScreen> createState() =>
      _FocusProtocolScreenState();
}

class _FocusProtocolScreenState extends ConsumerState<FocusProtocolScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  bool _onboardingDismissed  = false;
  bool _showOnboardingManual = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    if (widget.openSettings) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSettings();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(focusTimerProvider.notifier).handleForeground();
    }
    super.didChangeAppLifecycleState(state);
  }

  void _onBack() {
    ref.read(focusTimerProvider.notifier).reset();
    Navigator.of(context).pop();
  }

  void _showSettings() {
    final timerState = ref.read(focusTimerProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
    final c          = ref.watch(sieColorsProvider);

    ref.listen(focusTimerProvider.select((s) => s.isRunning), (_, isRunning) {
      if (isRunning) {
        // Skip the continuous pulse under reduce-motion.
        if (SieMotion.enabled(context)) {
          _pulseCtrl.repeat(reverse: true);
        } else {
          _pulseCtrl.value = 0;
        }
      } else {
        _pulseCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });

    final isBreak    = timerState.phase == FocusPhase.breakTime;
    final phaseColor = isBreak ? c.accentSecondary : c.accent;

    final onboardingProfile = ref.watch(userProfileProvider).valueOrNull;
    final showOnboarding = _showOnboardingManual ||
        (!_onboardingDismissed &&
            onboardingProfile != null &&
            !onboardingProfile.hasSeenOnboardingFocus);

    return Stack(
      children: [
        SieBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      _TopBar(
                        completedSessions: timerState.completedSessions,
                        phaseColor: phaseColor,
                        onBack: _onBack,
                        onInfo: () =>
                            setState(() => _showOnboardingManual = true),
                      ),
                      // Ring fills vertical space between the two chrome bars
                      Expanded(
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _pulseAnim,
                            builder: (_, _) => Transform.scale(
                              scale: 1.0 + 0.025 * _pulseAnim.value,
                              child: _FocusRing(
                                progress: timerState.progress,
                                formattedTime: timerState.formattedTime,
                                phaseColor: phaseColor,
                                phase: timerState.phase,
                                glowOpacity: _pulseAnim.value * 0.40,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          0,
                          24,
                          math.max(
                            MediaQuery.of(context).padding.bottom,
                            24,
                          ),
                        ),
                        child: _BottomHUD(
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
                    ],
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
        ),

        Positioned.fill(
          child: OnboardingOverlay(
            visible: showOnboarding,
            moduleLabel: 'ФОКУС',
            description: 'Протокол глубокой работы.',
            benefit:
                'Тренировка концентрации и защита от выгорания. Временны́е блоки '
                'защищают состояние потока и консолидируют рабочую память.',
            xpReward: 100,
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

// ─────────────────────────────────────────────────────────────────────────────
// Chrono-Ring — HD circular countdown display
// ─────────────────────────────────────────────────────────────────────────────
class _FocusRing extends ConsumerWidget {
  const _FocusRing({
    required this.progress,
    required this.formattedTime,
    required this.phaseColor,
    required this.phase,
    required this.glowOpacity,
  });

  final double     progress;
  final String     formattedTime;
  final Color      phaseColor;
  final FocusPhase phase;
  final double     glowOpacity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c          = ref.watch(sieColorsProvider);
    final trackColor = c.isLightMode
        ? c.border
        : Colors.white.withValues(alpha: 0.07);

    return SizedBox(
      width: 284,
      height: 284,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              size: const Size(284, 284),
              painter: _FocusRingPainter(
                progress: progress,
                phaseColor: phaseColor,
                glowOpacity: glowOpacity,
                trackColor: trackColor,
                isLightMode: c.isLightMode,
              ),
            ),
          ),

          // Timer core — countdown + phase label
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formattedTime,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 58,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  shadows: c.isLightMode
                      ? null
                      : [
                          Shadow(
                            color: phaseColor.withValues(alpha: 0.90),
                            blurRadius: 18,
                          ),
                          Shadow(
                            color: phaseColor.withValues(alpha: 0.45),
                            blurRadius: 44,
                          ),
                        ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: phaseColor.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  color: phaseColor.withValues(alpha: 0.06),
                ),
                child: Text(
                  phase == FocusPhase.breakTime ? 'BREAK' : 'FOCUS',
                  style: TextStyle(
                    color: phaseColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4.5,
                    shadows: c.isLightMode
                        ? null
                        : [
                            Shadow(
                              color: phaseColor.withValues(alpha: 0.65),
                              blurRadius: 8,
                            ),
                          ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chrono-Ring Painter — track + specular + neon arc + glow
// ─────────────────────────────────────────────────────────────────────────────
class _FocusRingPainter extends CustomPainter {
  final double progress;
  final Color  phaseColor;
  final double glowOpacity;
  final Color  trackColor;
  final bool   isLightMode;

  const _FocusRingPainter({
    required this.progress,
    required this.phaseColor,
    required this.glowOpacity,
    required this.trackColor,
    required this.isLightMode,
  });

  static const double _trackW = 10.0;
  static const double _arcW   = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20.0;
    const startAngle = -math.pi / 2; // 12 o'clock

    final trackRect = Rect.fromCircle(center: center, radius: radius);

    // ── Layer 1: Ring substrate ───────────────────────────────────
    // Ghost bloom corona
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = phaseColor.withValues(alpha: isLightMode ? 0.03 : 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _trackW + 8,
    );
    // Main track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = _trackW,
    );
    // Inner edge — sharp rim of the glass ring
    canvas.drawCircle(
      center,
      radius - _trackW / 2 + 1,
      Paint()
        ..color = isLightMode
            ? trackColor.withValues(alpha: 0.50)
            : Colors.white.withValues(alpha: 0.035)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // ── Layer 2: Glass specular — skip in light mode (no glass shader) ──
    if (!isLightMode) {
      canvas.drawArc(
        trackRect,
        -2.80, // ≈ 10 o'clock
        0.65,  // ≈ 37° arc span
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _trackW
          ..strokeCap = StrokeCap.round,
      );
    }

    if (progress <= 0) return;

    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);

    // ── Layer 3: Pulsed glow halo — skip in light mode ──────────
    if (!isLightMode && glowOpacity > 0.01) {
      canvas.drawArc(
        trackRect,
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..color = phaseColor.withValues(alpha: glowOpacity * 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _arcW + 20
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }

    // Ambient glow — softer in light mode
    canvas.drawArc(
      trackRect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = phaseColor.withValues(alpha: isLightMode ? 0.10 : 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isLightMode ? _arcW + 4 : _arcW + 10
        ..strokeCap = StrokeCap.round
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, isLightMode ? 5.0 : 9.0),
    );

    // ── Layer 4: Neon arc — SweepGradient for glass-edge shimmer ─
    final arcGradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: [
        phaseColor.withValues(alpha: 0.60),
        phaseColor,
      ],
    );
    canvas.drawArc(
      trackRect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..shader = arcGradient.createShader(trackRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _arcW
        ..strokeCap = StrokeCap.round,
    );

    // ── Layer 5: Tip glow + tip dot ───────────────────────────────
    final tipAngle = startAngle + sweepAngle;
    final tip = Offset(
      center.dx + radius * math.cos(tipAngle),
      center.dy + radius * math.sin(tipAngle),
    );

    if (!isLightMode) {
      canvas.drawCircle(
        tip,
        11,
        Paint()
          ..color = phaseColor.withValues(alpha: 0.50)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
    }
    canvas.drawCircle(
      tip,
      5.5,
      Paint()..color = isLightMode ? phaseColor : Colors.white,
    );
    canvas.drawCircle(
      Offset(tip.dx - 1.4, tip.dy - 1.4),
      1.8,
      Paint()..color = Colors.white.withValues(alpha: isLightMode ? 0.9 : 0.75),
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) =>
      old.progress != progress ||
      old.phaseColor != phaseColor ||
      old.glowOpacity != glowOpacity ||
      old.trackColor != trackColor ||
      old.isLightMode != isLightMode;
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar — circle buttons + session counter
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.completedSessions,
    required this.phaseColor,
    required this.onBack,
    required this.onInfo,
  });

  final int        completedSessions;
  final Color      phaseColor;
  final VoidCallback onBack;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _GlassCircleButton(icon: Icons.arrow_back_ios_new, onTap: onBack),
          const Spacer(),
          if (completedSessions > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                border:
                    Border.all(color: phaseColor.withValues(alpha: 0.40)),
                borderRadius: BorderRadius.circular(20),
                color: phaseColor.withValues(alpha: 0.08),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 11,
                    color: phaseColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'SESSION $completedSessions',
                    style: TextStyle(
                      color: phaseColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
          _GlassCircleButton(icon: Icons.help_outline, onTap: onInfo),
        ],
      ),
    );
  }
}

// Glass circle button — not inside a ScrollView, so useOwnLayer:true is safe.
class _GlassCircleButton extends ConsumerWidget {
  const _GlassCircleButton({required this.icon, required this.onTap});
  final IconData   icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: c.flatCard(radius: 19),
        child: Center(
          child: Icon(icon, color: c.textSecondary, size: 17),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom HUD — telemetry card + controls
// ─────────────────────────────────────────────────────────────────────────────
class _BottomHUD extends ConsumerWidget {
  const _BottomHUD({
    required this.timerState,
    required this.phaseColor,
    required this.onStart,
    required this.onPause,
    required this.onReset,
    required this.onSettings,
  });

  final FocusTimerState timerState;
  final Color           phaseColor;
  final VoidCallback    onStart;
  final VoidCallback    onPause;
  final VoidCallback    onReset;
  final VoidCallback    onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c       = ref.watch(sieColorsProvider);
    final isIdle  = timerState.phase == FocusPhase.idle;
    final isBreak = timerState.phase == FocusPhase.breakTime;
    final s       = timerState.settings;

    final phaseLabel = isBreak
        ? 'BREAK  ·  ${s.breakMinutes} MIN'
        : 'FOCUS PROTOCOL  ·  ${s.workMinutes} MIN';
    final stakeLabel = isBreak ? 'РЕЖИМ' : 'XP AT STAKE';
    final xpLabel = isBreak ? 'ОТДЫХ' : '+$_kFocusXp XP';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Telemetry card ──────────────────────────────────────
        SieGlassCard(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT PHASE',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 9,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      phaseLabel,
                      style: TextStyle(
                        color: phaseColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        shadows: c.isLightMode
                            ? null
                            : [
                                Shadow(
                                  color: phaseColor.withValues(alpha: 0.55),
                                  blurRadius: 8,
                                ),
                              ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 30,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: c.border,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    stakeLabel,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 9,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    xpLabel,
                    style: TextStyle(
                      color: c.accent,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      shadows: c.isLightMode
                          ? null
                          : [Shadow(color: c.accent, blurRadius: 10)],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Idle hint
        if (isIdle)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'TAP START TO INITIATE PROTOCOL',
              style: TextStyle(
                color: c.accent.withValues(alpha: 0.38),
                fontSize: 10,
                letterSpacing: 2.0,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        // ── Settings button ─────────────────────────────────────
        _SettingsButton(onTap: onSettings),

        const SizedBox(height: 10),

        // ── Primary / secondary control buttons ─────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SieGlassCard(
              padding: const EdgeInsets.symmetric(
                horizontal: 36,
                vertical: 14,
              ),
              onTap: () {
                SieHaptics.selection();
                (timerState.isRunning ? onPause : onStart)();
              },
              child: Text(
                timerState.isRunning
                    ? 'PAUSE'
                    : (isIdle ? 'START' : 'RESUME'),
                style: TextStyle(
                  color: phaseColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3.0,
                  shadows: c.isLightMode
                      ? null
                      : [
                          Shadow(
                            color: phaseColor.withValues(alpha: 0.65),
                            blurRadius: 12,
                          ),
                        ],
                ),
              ),
            ),
            if (!isIdle) ...[
              const SizedBox(width: 12),
              SieGlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                onTap: () {
                  SieHaptics.selection();
                  onReset();
                },
                child: Text(
                  'RESET',
                  style: TextStyle(
                    color: c.iconMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Button
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsButton extends ConsumerWidget {
  const _SettingsButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Center(
      child: SieGlassCard(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, size: 15, color: c.iconMuted),
            const SizedBox(width: 8),
            Text(
              'PROTOCOL SETTINGS',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Session Result Overlay — full-screen reward display
// ─────────────────────────────────────────────────────────────────────────────
class _ResultOverlay extends ConsumerStatefulWidget {
  const _ResultOverlay({required this.result, required this.onContinue});
  final FocusSessionResult result;
  final VoidCallback       onContinue;

  @override
  ConsumerState<_ResultOverlay> createState() => _ResultOverlayState();
}

class _ResultOverlayState extends ConsumerState<_ResultOverlay>
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
    _scale   = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
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
    final c = ref.watch(sieColorsProvider);
    final bgColor = c.background.withValues(alpha: 0.96);

    return FadeTransition(
      opacity: _opacity,
      child: Container(
        color: bgColor,
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Close (escape hatch) ──────────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: Semantics(
                      button: true,
                      label: 'Закрыть',
                      child: GestureDetector(
                        onTap: widget.onContinue,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Icon(Icons.close,
                              color: c.iconMuted, size: 22),
                        ),
                      ),
                    ),
                  ),
                  // ── Icon circle ───────────────────────────────
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.surface,
                      border: Border.all(color: c.accent, width: 1.5),
                      boxShadow: c.isLightMode
                          ? [
                              BoxShadow(
                                color: c.accent.withValues(alpha: 0.20),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: c.accent.withValues(alpha: 0.45),
                                blurRadius: 40,
                                spreadRadius: 4,
                              ),
                            ],
                    ),
                    child: Icon(
                      Icons.psychology_outlined,
                      size: 38,
                      color: c.accent,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Title ─────────────────────────────────────
                  Text(
                    'SESSION COMPLETE',
                    style:
                        Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: c.textPrimary,
                              shadows: c.isLightMode
                                  ? null
                                  : [
                                      Shadow(
                                        color:
                                            c.accent.withValues(alpha: 0.40),
                                        blurRadius: 12,
                                      ),
                                    ],
                            ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'FOCUS PROTOCOL EXECUTED',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  // ── Reward card ───────────────────────────────
                  SieGlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'XP GAINED',
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 11,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              '+${widget.result.xpGained} XP',
                              style: TextStyle(
                                color: c.accent,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                                shadows: c.isLightMode
                                    ? null
                                    : [
                                        Shadow(
                                          color: c.accent,
                                          blurRadius: 10,
                                        ),
                                      ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(height: 1, color: c.border),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.palette_outlined,
                                  size: 13,
                                  color: c.dp.withValues(alpha: 0.85),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'DP GAINED',
                                  style: TextStyle(
                                    color: c.textSecondary,
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '+${widget.result.dpGained} DP',
                              style: TextStyle(
                                color: c.dp,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                                shadows: c.isLightMode
                                    ? null
                                    : [
                                        Shadow(
                                          color:
                                              c.dp.withValues(alpha: 0.60),
                                          blurRadius: 10,
                                        ),
                                      ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Achievement unlock ─────────────────────────
                  if (widget.result.newAchievement != null) ...[
                    const SizedBox(height: 10),
                    SieGlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _kGold.withValues(alpha: 0.12),
                              border: Border.all(
                                color: _kGold.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Icon(
                              Icons.military_tech,
                              color: _kGold,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ACHIEVEMENT UNLOCKED',
                                  style: TextStyle(
                                    color: c.textSecondary,
                                    fontSize: 9,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.result.newAchievement!.name,
                                  style: const TextStyle(
                                    color: _kGold,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    shadows: [
                                      Shadow(color: _kGold, blurRadius: 8),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // ── Continue button ───────────────────────────
                  SieGlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 44,
                      vertical: 14,
                    ),
                    onTap: widget.onContinue,
                    child: Text(
                      'START BREAK',
                      style: TextStyle(
                        color: c.accentSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.5,
                        shadows: c.isLightMode
                            ? null
                            : [
                                Shadow(
                                  color: c.accentSecondary,
                                  blurRadius: 14,
                                ),
                              ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Focus Settings Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _FocusSettingsSheet extends ConsumerStatefulWidget {
  const _FocusSettingsSheet({
    required this.settings,
    required this.isTimerActive,
    required this.onChanged,
  });

  final FocusSettings           settings;
  final bool                    isTimerActive;
  final ValueChanged<FocusSettings> onChanged;

  @override
  ConsumerState<_FocusSettingsSheet> createState() =>
      _FocusSettingsSheetState();
}

class _FocusSettingsSheetState extends ConsumerState<_FocusSettingsSheet> {
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
    final c      = ref.watch(sieColorsProvider);
    final locked = widget.isTimerActive;

    final content = SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 3,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: c.isLightMode
                      ? c.border
                      : Colors.white.withValues(alpha: 0.20),
                ),
              ),
            ),
            Text(
              'PROTOCOL SETTINGS',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: c.textPrimary,
                  ),
            ),
            if (locked) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.lock_outline, size: 13, color: c.warning),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'НАСТРОЙКИ ЗАБЛОКИРОВАНЫ ВО ВРЕМЯ СЕССИИ',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: c.warning,
                      ),
                    ),
                  ),
                ],
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Divider(color: c.border, height: 1),
            ),
            _AmbientToggleRow(
              label: 'FOCUS MUSIC',
              icon: Icons.work_outline,
              value: _s.isWorkMusicEnabled,
              onChanged: (v) =>
                  _update(_s.copyWith(isWorkMusicEnabled: v)),
            ),
            _AmbientToggleRow(
              label: 'BREAK MUSIC',
              icon: Icons.coffee_outlined,
              value: _s.isBreakMusicEnabled,
              onChanged: (v) =>
                  _update(_s.copyWith(isBreakMusicEnabled: v)),
            ),
          ],
        ),
      ),
    );

    final lightDecoration = BoxDecoration(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      color: c.surface,
      border: Border(
        top: BorderSide(color: c.border, width: 1.0),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, -4),
        ),
      ],
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(decoration: lightDecoration, child: content),
    );
  }
}

class _FocusSettingRow extends ConsumerWidget {
  const _FocusSettingRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    this.enabled = true,
    required this.onChanged,
  });

  final String label;
  final int    value;
  final int    min;
  final int    max;
  final int    step;
  final bool   enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.35,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: c.textSecondary,
                    ),
              ),
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
                style: TextStyle(
                  color: c.textPrimary,
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

class _AmbientToggleRow extends ConsumerWidget {
  const _AmbientToggleRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String   label;
  final IconData icon;
  final bool     value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: value ? c.accent : c.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c.textSecondary,
                  ),
            ),
          ),
          _CockpitToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _CockpitToggle extends ConsumerStatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _CockpitToggle({required this.value, required this.onChanged});

  @override
  ConsumerState<_CockpitToggle> createState() => _CockpitToggleState();
}

class _CockpitToggleState extends ConsumerState<_CockpitToggle> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    return GestureDetector(
      onTap: () => widget.onChanged(!widget.value),
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: _pressed
            ? const Duration(milliseconds: 80)
            : const Duration(milliseconds: 220),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          width: 52,
          height: 26,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: widget.value
                ? c.accent.withValues(alpha: 0.18)
                : c.border,
            border: Border.all(
              color: widget.value
                  ? c.accent.withValues(alpha: 0.80)
                  : c.border,
              width: 1.2,
            ),
            boxShadow: widget.value
                ? [
                    BoxShadow(
                      color: c.accent.withValues(alpha: 0.30),
                      blurRadius: 10,
                    ),
                    BoxShadow(
                      color: c.accent.withValues(alpha: 0.12),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              // Cockpit track lines
              Positioned.fill(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: c.border.withValues(
                        alpha: widget.value ? 0.5 : 0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: c.border.withValues(
                        alpha: widget.value ? 0.3 : 0.15,
                      ),
                    ),
                  ],
                ),
              ),
              // Thumb — rectangular neon lever
              AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                alignment: widget.value
                    ? const Alignment(0.72, 0)
                    : const Alignment(-0.72, 0),
                child: Container(
                  width: 16,
                  height: 18,
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: widget.value ? c.accent : c.textSecondary,
                    boxShadow: widget.value
                        ? [
                            BoxShadow(
                              color: c.accent.withValues(alpha: 0.70),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepBtn extends ConsumerStatefulWidget {
  const _StepBtn({
    required this.icon,
    required this.active,
    this.onTap,
  });

  final IconData      icon;
  final bool          active;
  final VoidCallback? onTap;

  @override
  ConsumerState<_StepBtn> createState() => _StepBtnState();
}

class _StepBtnState extends ConsumerState<_StepBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: widget.onTap != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.onTap != null
          ? (_) => setState(() => _pressed = false)
          : null,
      onTapCancel: widget.onTap != null
          ? () => setState(() => _pressed = false)
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: _pressed
            ? const Duration(milliseconds: 80)
            : const Duration(milliseconds: 220),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.active
                  ? _pressed
                      ? c.accent
                      : c.accent.withValues(alpha: 0.65)
                  : c.border,
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(4),
            color: widget.active && _pressed
                ? c.accent.withValues(alpha: 0.12)
                : Colors.transparent,
            boxShadow: widget.active && !c.isLightMode
                ? [
                    BoxShadow(
                      color: c.accent.withValues(
                        alpha: _pressed ? 0.28 : 0.10,
                      ),
                      blurRadius: _pressed ? 10 : 6,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            widget.icon,
            size: 16,
            color: widget.active ? c.accent : c.textSecondary,
          ),
        ),
      ),
    );
  }
}
