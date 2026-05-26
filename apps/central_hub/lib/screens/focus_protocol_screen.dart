import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:sie_core/sie_core.dart';

// ── Design tokens ─────────────────────────────────────────────
const _kCyan   = Color(0xFF00E5FF);
const _kPurple = Color(0xFF7000FF);
const _kMuted  = Color(0xFF90A4AE);
const _kGold   = Color(0xFFFFD700);

// mirrors provider constant — used only for HUD display
const _kFocusXp = 100;

// ─────────────────────────────────────────────────────────────────────────────
// FocusProtocolScreen
// ─────────────────────────────────────────────────────────────────────────────
class FocusProtocolScreen extends ConsumerStatefulWidget {
  const FocusProtocolScreen({super.key});

  @override
  ConsumerState<FocusProtocolScreen> createState() =>
      _FocusProtocolScreenState();
}

class _FocusProtocolScreenState extends ConsumerState<FocusProtocolScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // SieSpaceBackground manages its own AnimationController internally —
  // no _skyCtrl needed here. Only the pulse animation remains.
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  bool _onboardingDismissed   = false;
  bool _showOnboardingManual  = false;

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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Background lifecycle handler (unchanged) ──────────────────
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

    // Drive pulse only when timer is running — unchanged logic
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

    final isBreak    = timerState.phase == FocusPhase.breakTime;
    final phaseColor = isBreak ? _kPurple : _kCyan;

    final onboardingProfile = ref.watch(userProfileProvider).valueOrNull;
    final showOnboarding = _showOnboardingManual ||
        (!_onboardingDismissed &&
            onboardingProfile != null &&
            !onboardingProfile.hasSeenOnboardingFocus);

    // Outer Stack so OnboardingOverlay can float above everything including
    // GlassPage without being clipped by it.
    return Stack(
      children: [
        // ── Main screen under glass backdrop ───────────────────
        GlassPage(
          background: const SieSpaceBackground(),
          statusBarStyle: GlassStatusBarStyle.light,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                // Column layout centres the ring between the two chrome bars
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
                      // Ring fills the vertical space between bars — truly centred
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
                // Result overlay — full-screen, above the column
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

        // ── Onboarding overlay (floats above GlassPage) ────────
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
// Chrono-Ring — the HD circular countdown display
// ─────────────────────────────────────────────────────────────────────────────
class _FocusRing extends StatelessWidget {
  const _FocusRing({
    required this.progress,
    required this.formattedTime,
    required this.phaseColor,
    required this.phase,
    required this.glowOpacity,
  });

  final double    progress;
  final String    formattedTime;
  final Color     phaseColor;
  final FocusPhase phase;
  final double    glowOpacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 284,
      height: 284,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Chrono-Ring painter — track + glass specular + neon arc + glow
          RepaintBoundary(
            child: CustomPaint(
              size: const Size(284, 284),
              painter: _FocusRingPainter(
                progress: progress,
                phaseColor: phaseColor,
                glowOpacity: glowOpacity,
              ),
            ),
          ),

          // Timer core — monospace bold countdown + phase label
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formattedTime,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 58,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  shadows: [
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
                    shadows: [
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
// Chrono-Ring Painter — thick liquid-glass ring profile + neon gradient arc
// ─────────────────────────────────────────────────────────────────────────────
class _FocusRingPainter extends CustomPainter {
  final double progress;
  final Color  phaseColor;
  final double glowOpacity;

  const _FocusRingPainter({
    required this.progress,
    required this.phaseColor,
    required this.glowOpacity,
  });

  // Ring geometry
  static const double _trackW = 10.0; // glass track width
  static const double _arcW   = 8.0;  // neon arc width

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20.0;
    const startAngle = -math.pi / 2; // 12 o'clock

    final trackRect = Rect.fromCircle(center: center, radius: radius);

    // ── Layer 1: Glass ring substrate ─────────────────────────
    // Outer ghost bloom — coloured faint corona around the track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = phaseColor.withValues(alpha: 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _trackW + 8,
    );
    // Main track ring — frosted white, low opacity
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _trackW,
    );
    // Thin inner edge — simulates the sharp inner rim of the glass ring
    canvas.drawCircle(
      center,
      radius - _trackW / 2 + 1,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.035)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // ── Layer 2: Glass specular highlight ─────────────────────
    // A short bright arc at ~135° (top-left) mimics the iOS light-source
    // catchlight on a curved glass surface — adds depth without a shader.
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

    if (progress <= 0) return;

    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);

    // ── Layer 3: Pulsed glow halo behind the arc ──────────────
    if (glowOpacity > 0.01) {
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

    // Constant ambient glow always present (not pulsed)
    canvas.drawArc(
      trackRect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = phaseColor.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _arcW + 10
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    // ── Layer 4: Neon arc — SweepGradient for glass-edge shimmer ─
    // Gradient starts slightly transparent and builds to full colour,
    // simulating how light grazes the curved glass edge.
    final arcGradient = SweepGradient(
      startAngle: startAngle,
      endAngle:   startAngle + sweepAngle,
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

    // ── Layer 5: Tip glow + tip dot ───────────────────────────
    final tipAngle = startAngle + sweepAngle;
    final tip = Offset(
      center.dx + radius * math.cos(tipAngle),
      center.dy + radius * math.sin(tipAngle),
    );

    // Outer bloom
    canvas.drawCircle(
      tip,
      11,
      Paint()
        ..color = phaseColor.withValues(alpha: 0.50)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    // Solid white tip dot
    canvas.drawCircle(tip, 5.5, Paint()..color = Colors.white);
    // Specular micro-dot inside the tip
    canvas.drawCircle(
      Offset(tip.dx - 1.4, tip.dy - 1.4),
      1.8,
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) =>
      old.progress != progress ||
      old.phaseColor != phaseColor ||
      old.glowOpacity != glowOpacity;
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar — glass circle buttons + session counter
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.completedSessions,
    required this.phaseColor,
    required this.onBack,
    required this.onInfo,
  });

  final int completedSessions;
  final Color phaseColor;
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

// Glass circle button — used in TopBar (not inside a ScrollView, so
// useOwnLayer:true is safe — no scroll-induced backdrop flicker risk).
class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        width: 38,
        height: 38,
        padding: EdgeInsets.zero,
        shape: LiquidRoundedSuperellipse(borderRadius: 19),
        useOwnLayer: true,
        quality: GlassQuality.standard,
        clipBehavior: Clip.antiAlias,
        settings: LiquidGlassSettings(
          blur: 2.0,
          thickness: 20,
          refractiveIndex: 1.45,
          glassColor: const Color(0x0A0A0E1A),
          lightAngle: GlassDefaults.lightAngle,
          lightIntensity: 0.72,
          glowIntensity: 0.85,
          saturation: 1.4,
          specularSharpness: GlassSpecularSharpness.sharp,
          ambientStrength: 0.08,
          chromaticAberration: 0.015,
        ),
        child: Center(
          child: Icon(icon, color: SieTheme.textSecondary, size: 17),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom HUD — telemetry glass card + controls
// ─────────────────────────────────────────────────────────────────────────────
class _BottomHUD extends StatelessWidget {
  const _BottomHUD({
    required this.timerState,
    required this.phaseColor,
    required this.onStart,
    required this.onPause,
    required this.onReset,
    required this.onSettings,
  });

  final FocusTimerState timerState;
  final Color phaseColor;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onReset;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final isIdle  = timerState.phase == FocusPhase.idle;
    final isBreak = timerState.phase == FocusPhase.breakTime;
    final s       = timerState.settings;

    final phaseLabel = isBreak
        ? 'BREAK  ·  ${s.breakMinutes} MIN'
        : 'FOCUS PROTOCOL  ·  ${s.workMinutes} MIN';
    final xpLabel = isBreak ? '+0 XP' : '+$_kFocusXp XP';

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
                        color: SieTheme.textSecondary,
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
                        shadows: [
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
                color: Colors.white.withValues(alpha: 0.10),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'XP AT STAKE',
                    style: TextStyle(
                      color: SieTheme.textSecondary,
                      fontSize: 9,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    xpLabel,
                    style: const TextStyle(
                      color: SieTheme.accent,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(color: SieTheme.accent, blurRadius: 10),
                      ],
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
                color: _kCyan.withValues(alpha: 0.38),
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
        // SieGlassCard(onTap:...) provides the 0.97-scale + specular-flash
        // press feedback automatically — no custom StatefulWidget needed.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SieGlassCard(
              padding: const EdgeInsets.symmetric(
                horizontal: 36,
                vertical: 14,
              ),
              onTap: timerState.isRunning ? onPause : onStart,
              child: Text(
                timerState.isRunning ? 'PAUSE' : 'START',
                style: TextStyle(
                  color: phaseColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3.0,
                  shadows: [
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
                onTap: onReset,
                child: const Text(
                  'RESET',
                  style: TextStyle(
                    color: _kMuted,
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
class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SieGlassCard(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tune, size: 15, color: _kMuted),
            const SizedBox(width: 8),
            Text(
              'PROTOCOL SETTINGS',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
// Session Result Overlay — full-screen glass reward display
// ─────────────────────────────────────────────────────────────────────────────
class _ResultOverlay extends StatefulWidget {
  const _ResultOverlay({required this.result, required this.onContinue});
  final FocusSessionResult result;
  final VoidCallback       onContinue;

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
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        color: const Color(0xFF0A0E1A).withValues(alpha: 0.92),
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Icon circle ───────────────────────────────
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: SieTheme.surface,
                      border: Border.all(color: _kCyan, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: _kCyan.withValues(alpha: 0.45),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.psychology_outlined,
                      size: 38,
                      color: _kCyan,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Title ─────────────────────────────────────
                  Text(
                    'SESSION COMPLETE',
                    style:
                        Theme.of(context).textTheme.headlineMedium?.copyWith(
                              shadows: [
                                Shadow(
                                  color: _kCyan.withValues(alpha: 0.40),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'FOCUS PROTOCOL EXECUTED',
                    style: TextStyle(
                      color: SieTheme.textSecondary,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  // ── Reward glass card ─────────────────────────
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
                            const Text(
                              'XP GAINED',
                              style: TextStyle(
                                color: SieTheme.textSecondary,
                                fontSize: 11,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              '+${widget.result.xpGained} XP',
                              style: const TextStyle(
                                color: _kCyan,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                                shadows: [
                                  Shadow(color: _kCyan, blurRadius: 10),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.palette_outlined,
                                  size: 13,
                                  color: SieTheme.dp.withValues(alpha: 0.85),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'DP GAINED',
                                  style: TextStyle(
                                    color: SieTheme.textSecondary,
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '+${widget.result.dpGained} DP',
                              style: TextStyle(
                                color: SieTheme.dp,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                                shadows: [
                                  Shadow(
                                    color: SieTheme.dp.withValues(alpha: 0.6),
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
                                    color: SieTheme.textSecondary,
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
                    child: const Text(
                      'START BREAK',
                      style: TextStyle(
                        color: _kPurple,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.5,
                        shadows: [
                          Shadow(color: _kPurple, blurRadius: 14),
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
// Focus Settings Sheet — logic + wiring unchanged; only visual chrome updated
// ─────────────────────────────────────────────────────────────────────────────
class _FocusSettingsSheet extends StatefulWidget {
  const _FocusSettingsSheet({
    required this.settings,
    required this.isTimerActive,
    required this.onChanged,
  });

  final FocusSettings          settings;
  final bool                   isTimerActive;
  final ValueChanged<FocusSettings> onChanged;

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

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
        child: Container(
          decoration: BoxDecoration(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _kCyan.withValues(alpha: 0.04),
                const Color(0xFF0A0E1A).withValues(alpha: 0.92),
              ],
            ),
            border: Border(
              top: BorderSide(
                color: _kCyan.withValues(alpha: 0.30),
                width: 1.0,
              ),
              left: BorderSide(
                color: _kCyan.withValues(alpha: 0.12),
                width: 1.0,
              ),
              right: BorderSide(
                color: _kCyan.withValues(alpha: 0.12),
                width: 1.0,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: _kCyan.withValues(alpha: 0.08),
                blurRadius: 60,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SafeArea(
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
                        color: Colors.white.withValues(alpha: 0.20),
                      ),
                    ),
                  ),
                  Text(
                    'PROTOCOL SETTINGS',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (locked) ...[
                    const SizedBox(height: 8),
                    Text(
                      'DURATION LOCKED DURING SESSION',
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 10,
                                letterSpacing: 1.5,
                                color: SieTheme.textSecondary
                                    .withValues(alpha: 0.5),
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
          ),
        ),
      ),
    );
  }
}

class _FocusSettingRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: value ? _kCyan : SieTheme.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          _CockpitToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _CockpitToggle extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _CockpitToggle({required this.value, required this.onChanged});

  @override
  State<_CockpitToggle> createState() => _CockpitToggleState();
}

class _CockpitToggleState extends State<_CockpitToggle> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
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
                ? _kCyan.withValues(alpha: 0.18)
                : const Color(0xFF0D1B2A),
            border: Border.all(
              color: widget.value
                  ? _kCyan.withValues(alpha: 0.80)
                  : SieTheme.borderDefault,
              width: 1.2,
            ),
            boxShadow: widget.value
                ? [
                    BoxShadow(
                      color: _kCyan.withValues(alpha: 0.30),
                      blurRadius: 10,
                    ),
                    BoxShadow(
                      color: _kCyan.withValues(alpha: 0.12),
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
                      color: Colors.white.withValues(
                        alpha: widget.value ? 0.18 : 0.08,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: Colors.white.withValues(
                        alpha: widget.value ? 0.12 : 0.05,
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
                    color: widget.value ? _kCyan : SieTheme.textSecondary,
                    boxShadow: widget.value
                        ? [
                            BoxShadow(
                              color: _kCyan.withValues(alpha: 0.70),
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

class _StepBtn extends StatefulWidget {
  const _StepBtn({
    required this.icon,
    required this.active,
    this.onTap,
  });

  final IconData      icon;
  final bool          active;
  final VoidCallback? onTap;

  @override
  State<_StepBtn> createState() => _StepBtnState();
}

class _StepBtnState extends State<_StepBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
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
                      ? _kCyan
                      : _kCyan.withValues(alpha: 0.65)
                  : SieTheme.borderDefault,
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(4),
            color: widget.active && _pressed
                ? _kCyan.withValues(alpha: 0.12)
                : Colors.transparent,
            boxShadow: widget.active
                ? [
                    BoxShadow(
                      color: _kCyan.withValues(
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
            color: widget.active ? _kCyan : SieTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
