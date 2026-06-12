import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'session_orb_painters.dart';

class MeditationSessionScreen extends ConsumerStatefulWidget {
  final MeditationPreset preset;
  const MeditationSessionScreen({super.key, required this.preset});

  @override
  ConsumerState<MeditationSessionScreen> createState() =>
      _MeditationSessionScreenState();
}

class _MeditationSessionScreenState
    extends ConsumerState<MeditationSessionScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _breathScaleCtrl;
  late AnimationController _meditationOpacityCtrl;
  late AnimationController _transitionCtrl;
  late Animation<double> _breathScale;
  late Animation<double> _meditationOpacity;

  late AnimationController _rimCtrl;
  late Animation<double> _rimAngle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _breathScaleCtrl = AnimationController(vsync: this);
    _breathScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _breathScaleCtrl, curve: Curves.easeInOut),
    );

    _meditationOpacityCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _meditationOpacity =
        Tween<double>(begin: 0.4, end: 0.9).animate(
      CurvedAnimation(
          parent: _meditationOpacityCtrl, curve: Curves.easeInOut),
    );

    _transitionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _rimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _rimAngle = Tween<double>(begin: 0, end: math.pi * 2).animate(
      CurvedAnimation(parent: _rimCtrl, curve: Curves.linear),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(meditationSessionProvider.notifier)
          .startSession(widget.preset);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _breathScaleCtrl.dispose();
    _meditationOpacityCtrl.dispose();
    _transitionCtrl.dispose();
    _rimCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(meditationSessionProvider.notifier);
    if (state == AppLifecycleState.paused) {
      notifier.pause();
    } else if (state == AppLifecycleState.resumed) {
      notifier.resume();
    }
  }

  void _syncAnimations(MeditationSessionState s) {
    switch (s.phase) {
      case MeditationPhase.breathing:
        _meditationOpacityCtrl.stop();
        final isInhale = s.breathingSubPhase == BreathingSubPhase.inhale;
        final isExhale = s.breathingSubPhase == BreathingSubPhase.exhale;
        if (isInhale && !_breathScaleCtrl.isAnimating) {
          _breathScaleCtrl.animateTo(
            1.0,
            duration: Duration(seconds: _subPhaseDuration(s)),
            curve: Curves.easeIn,
          );
        } else if (isExhale && !_breathScaleCtrl.isAnimating) {
          _breathScaleCtrl.animateBack(
            0.0,
            duration: Duration(seconds: _subPhaseDuration(s)),
            curve: Curves.easeOut,
          );
        }
      case MeditationPhase.meditating:
        _breathScaleCtrl.animateTo(0.5,
            duration: const Duration(seconds: 2), curve: Curves.easeOut);
        if (!_meditationOpacityCtrl.isAnimating) {
          _meditationOpacityCtrl.repeat(reverse: true);
        }
      case MeditationPhase.transition:
        if (!_transitionCtrl.isAnimating) {
          _transitionCtrl.forward(from: 0);
        }
      default:
        break;
    }
  }

  int _subPhaseDuration(MeditationSessionState s) {
    const patterns = {
      'box':      [4, 4, 4, 4],
      '4-7-8':   [4, 7, 8, 0],
      'coherence':[5, 5],
    };
    final list =
        patterns[s.preset?.breathingPatternId ?? 'box'] ?? [4, 4, 4, 4];
    final idx = BreathingSubPhase.values.indexOf(s.breathingSubPhase);
    if (idx < list.length) return list[idx].clamp(1, 10);
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);

    ref.listen<MeditationSessionState>(meditationSessionProvider,
        (prev, next) {
      _syncAnimations(next);
      if (next.phase == MeditationPhase.complete &&
          (prev?.phase != MeditationPhase.complete)) {
        _showCompletionSheet();
      }
    });

    final session = ref.watch(meditationSessionProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmAbandon();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Progress arc
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AnimatedBuilder(
                  animation: _rimAngle,
                  builder: (_, __) => CustomPaint(
                    painter: _ProgressArcPainter(
                      progress: session.overallProgress,
                      rimAngle: _rimAngle.value,
                      accentColor: c.accent,
                      borderColor: c.border,
                    ),
                  ),
                ),
              ),
            ),
            // Central orb
            Center(
              child: GestureDetector(
                onTap: () {
                  final n = ref.read(meditationSessionProvider.notifier);
                  final nowVisible = session.isMixerVisible;
                  n.setMixerVisible(!nowVisible);
                  if (!nowVisible) n.scheduleMixerHide();
                },
                child: AnimatedBuilder(
                  animation: Listenable.merge(
                      [_breathScaleCtrl, _meditationOpacityCtrl, _rimCtrl]),
                  builder: (_, __) => _MeditationOrb(
                    phase: session.phase,
                    breathT: _breathScale.value,
                    opacityT: _meditationOpacity.value,
                    rimAngle: _rimAngle.value,
                  ),
                ),
              ),
            ),
            // Breathing cue
            if (session.phase == MeditationPhase.breathing)
              Positioned(
                top: MediaQuery.of(context).size.height * 0.38,
                left: 0,
                right: 0,
                child: _BreathingCue(session: session, c: c),
              ),
            // Affirmation
            if (session.phase == MeditationPhase.meditating)
              Positioned(
                bottom: MediaQuery.of(context).size.height * 0.25,
                left: 32,
                right: 32,
                child: _AffirmationLayer(
                  affirmation: session.currentAffirmation,
                ),
              ),
            // Corner timer
            Positioned(
              bottom: 32,
              right: 20,
              child: _CornerTimer(
                  formatted: session.formattedRemaining, c: c),
            ),
            // Top HUD
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: _TopHud(
                session: session,
                onBack: _confirmAbandon,
                onTogglePause: () {
                  final n = ref.read(meditationSessionProvider.notifier);
                  if (session.isRunning) {
                    n.pause();
                  } else {
                    n.resume();
                  }
                },
                c: c,
              ),
            ),
            // Floating mixer
            Positioned(
              bottom: 60,
              left: 16,
              right: 16,
              child: _FloatingMixer(
                session: session,
                onVolumeChanged: (music, ambient, voice) {
                  ref
                      .read(meditationSessionProvider.notifier)
                      .updateVolume(
                        music: music,
                        ambient: ambient,
                        voice: voice,
                      );
                },
                onDarkMode: () => ref
                    .read(meditationSessionProvider.notifier)
                    .toggleDarkScreenMode(),
                c: c,
              ),
            ),
            // Dark screen overlay
            if (session.isDarkScreenMode)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => ref
                      .read(meditationSessionProvider.notifier)
                      .toggleDarkScreenMode(),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.92),
                    alignment: Alignment.bottomRight,
                    padding: const EdgeInsets.all(24),
                    child: _CornerTimer(
                        formatted: session.formattedRemaining, c: c),
                  ),
                ),
              ),
            // Reflection overlay
            if (session.phase == MeditationPhase.reflectionPause)
              _ReflectionOverlay(c: c),
          ],
        ),
      ),
    );
  }

  void _showCompletionSheet() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: ref.read(sieColorsProvider).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CompletionSheet(
        onComplete: (stateAfter) {
          Navigator.of(context).pop(); // close sheet
          ref
              .read(meditationSessionProvider.notifier)
              .completeSession(stateAfter);
          Navigator.of(context).pop(); // pop session screen
        },
      ),
    );
  }

  void _confirmAbandon() {
    final c = ref.read(sieColorsProvider);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Прервать сессию?',
            style: TextStyle(color: c.textPrimary)),
        content: Text(
          'Прогресс будет частично засчитан если прошло более 60 секунд.',
          style: TextStyle(color: c.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Продолжить',
                style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              ref
                  .read(meditationSessionProvider.notifier)
                  .abandonSession();
              Navigator.of(context).pop(); // pop session screen
            },
            child: const Text('Прервать',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

// ── Orb ─────────────────────────────────────────────────────────
class _MeditationOrb extends StatelessWidget {
  final MeditationPhase phase;
  final double breathT;
  final double opacityT;
  final double rimAngle;

  const _MeditationOrb({
    required this.phase,
    required this.breathT,
    required this.opacityT,
    required this.rimAngle,
  });

  @override
  Widget build(BuildContext context) {
    final isBreath = phase == MeditationPhase.breathing;
    final scale   = isBreath ? (0.85 + breathT * 0.30) : 1.0;
    final opacity = isBreath ? 1.0 : opacityT;

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          kRimTeal.withValues(alpha: 0.20 + breathT * 0.15),
                      blurRadius: 40 + breathT * 20,
                      spreadRadius: 8 + breathT * 8,
                    ),
                  ],
                ),
              ),
              // Core
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      kRimTealLight.withValues(alpha: 0.7),
                      kRimTeal.withValues(alpha: 0.5),
                      kRimTealDark.withValues(alpha: 0.3),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              // Rim
              CustomPaint(
                size: const Size(170, 170),
                painter: SphereRimPainter(
                  lightAngle: rimAngle,
                  intensity: 0.6 + breathT * 0.2,
                  isDark: true,
                  rimGold:   kRimTeal,
                  rimBronze: kRimTealDark,
                  rimLight:  kRimTealLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Breathing cue ────────────────────────────────────────────────
class _BreathingCue extends StatelessWidget {
  final MeditationSessionState session;
  final SieColors c;
  const _BreathingCue({required this.session, required this.c});

  @override
  Widget build(BuildContext context) {
    final label = switch (session.breathingSubPhase) {
      BreathingSubPhase.inhale  => 'ВДОХ',
      BreathingSubPhase.holdIn  => 'ЗАДЕРЖКА',
      BreathingSubPhase.exhale  => 'ВЫДОХ',
      BreathingSubPhase.holdOut => 'ПАУЗА',
    };
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: kRimTealLight,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${session.breathingSubPhaseRemaining}с',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: c.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w300),
        ),
      ],
    );
  }
}

// ── Affirmation layer ────────────────────────────────────────────
class _AffirmationLayer extends StatefulWidget {
  final String? affirmation;
  const _AffirmationLayer({required this.affirmation});

  @override
  State<_AffirmationLayer> createState() => _AffirmationLayerState();
}

class _AffirmationLayerState extends State<_AffirmationLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _opCtrl;
  late Animation<double> _opacity;
  String? _displayed;

  @override
  void initState() {
    super.initState();
    _opCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2));
    _opacity =
        CurvedAnimation(parent: _opCtrl, curve: Curves.easeInOut);
    _displayed = widget.affirmation;
    if (_displayed != null) _opCtrl.forward();
  }

  @override
  void didUpdateWidget(_AffirmationLayer old) {
    super.didUpdateWidget(old);
    if (widget.affirmation != old.affirmation) {
      _opCtrl.reverse().then((_) {
        if (mounted) {
          setState(() => _displayed = widget.affirmation);
          if (_displayed != null) _opCtrl.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _opCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_displayed == null) return const SizedBox.shrink();
    return FadeTransition(
      opacity: _opacity,
      child: Text(
        _displayed!,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w300,
          letterSpacing: 1.2,
          height: 1.6,
        ),
      ),
    );
  }
}

// ── Corner timer ────────────────────────────────────────────────
class _CornerTimer extends StatelessWidget {
  final String formatted;
  final SieColors c;
  const _CornerTimer({required this.formatted, required this.c});

  @override
  Widget build(BuildContext context) {
    return Text(
      formatted,
      style: TextStyle(
        color: c.textSecondary.withValues(alpha: 0.6),
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 1,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

// ── Top HUD ──────────────────────────────────────────────────────
class _TopHud extends StatelessWidget {
  final MeditationSessionState session;
  final VoidCallback onBack;
  final VoidCallback onTogglePause;
  final SieColors c;
  const _TopHud({
    required this.session,
    required this.onBack,
    required this.onTogglePause,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final phaseLabel = switch (session.phase) {
      MeditationPhase.breathing       => 'ДЫХАНИЕ',
      MeditationPhase.transition      => 'ПЕРЕХОД',
      MeditationPhase.meditating      => 'МЕДИТАЦИЯ',
      MeditationPhase.reflectionPause => 'РЕФЛЕКСИЯ',
      MeditationPhase.complete        => 'ЗАВЕРШЕНО',
      _                               => '',
    };
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.close_rounded,
              color: c.textSecondary, size: 20),
          onPressed: onBack,
          padding: EdgeInsets.zero,
        ),
        const Spacer(),
        Text(
          phaseLabel,
          style: TextStyle(
              color: c.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 3),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(
            session.isRunning
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            color: c.textSecondary,
            size: 20,
          ),
          onPressed: onTogglePause,
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

// ── Floating mixer ───────────────────────────────────────────────
class _FloatingMixer extends StatelessWidget {
  final MeditationSessionState session;
  final void Function(double? music, double? ambient, double? voice)
      onVolumeChanged;
  final VoidCallback onDarkMode;
  final SieColors c;
  const _FloatingMixer({
    required this.session,
    required this.onVolumeChanged,
    required this.onDarkMode,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: session.isMixerVisible
          ? Offset.zero
          : const Offset(0, 1.4),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MixerRow(
                label: 'МУЗЫКА',
                value: session.musicVolume,
                onChanged: (v) =>
                    onVolumeChanged(v, null, null),
                c: c),
            _MixerRow(
                label: 'AMBIENT',
                value: session.ambientVolume,
                onChanged: (v) =>
                    onVolumeChanged(null, v, null),
                c: c),
            _MixerRow(
                label: 'ГОЛОС',
                value: session.voiceVolume,
                onChanged: (v) =>
                    onVolumeChanged(null, null, v),
                c: c),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Экран затемнён',
                    style: TextStyle(
                        color: c.textSecondary, fontSize: 12)),
                const Spacer(),
                Switch(
                  value: session.isDarkScreenMode,
                  onChanged: (_) => onDarkMode(),
                  activeColor: c.accent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MixerRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final SieColors c;
  const _MixerRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label,
              style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: c.accent,
              inactiveTrackColor: c.border,
              thumbColor: c.accent,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(value: value, onChanged: onChanged),
          ),
        ),
      ],
    );
  }
}

// ── Progress arc ─────────────────────────────────────────────────
class _ProgressArcPainter extends CustomPainter {
  final double progress;
  final double rimAngle;
  final Color accentColor;
  final Color borderColor;

  const _ProgressArcPainter({
    required this.progress,
    required this.rimAngle,
    required this.accentColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center      = Offset(size.width / 2, size.height / 2);
    final radius      = math.min(size.width, size.height) / 2;
    const startAngle  = -math.pi / 2;
    const strokeWidth = 2.5;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color       = borderColor.withValues(alpha: 0.3),
    );

    if (progress <= 0) return;

    final sweepAngle = math.pi * 2 * progress.clamp(0.0, 1.0);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap   = StrokeCap.round
        ..color       = accentColor,
    );

    // Glowing dot at tip
    final tipAngle = startAngle + sweepAngle;
    final tip = Offset(
      center.dx + radius * math.cos(tipAngle),
      center.dy + radius * math.sin(tipAngle),
    );
    canvas.drawCircle(
      tip,
      4,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
        ..color      = accentColor,
    );
  }

  @override
  bool shouldRepaint(_ProgressArcPainter old) =>
      progress != old.progress || rimAngle != old.rimAngle;
}

// ── Reflection overlay ───────────────────────────────────────────
class _ReflectionOverlay extends StatelessWidget {
  final SieColors c;
  const _ReflectionOverlay({required this.c});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        alignment: Alignment.center,
        child: Text(
          'Подготовка\nк рефлексии…',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 18,
            fontWeight: FontWeight.w300,
            letterSpacing: 1.5,
            height: 1.8,
          ),
        ),
      ),
    );
  }
}

// ── Completion sheet ─────────────────────────────────────────────
class _CompletionSheet extends ConsumerStatefulWidget {
  final void Function(int stateAfter) onComplete;
  const _CompletionSheet({required this.onComplete});

  @override
  ConsumerState<_CompletionSheet> createState() =>
      _CompletionSheetState();
}

class _CompletionSheetState extends ConsumerState<_CompletionSheet> {
  int _stateAfter = 3;

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    final s = ref.watch(meditationSessionProvider);
    final durationMins =
        (s.meditationElapsedSecs + s.breathingElapsedSecs) ~/ 60;
    final result = s.completionResult;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'СЕССИЯ ЗАВЕРШЕНА',
              style: TextStyle(
                  color: c.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ResultChip(
                    label: '$durationMins мин',
                    icon: Icons.access_time_rounded,
                    c: c),
                const SizedBox(width: 16),
                _ResultChip(
                    label: '+${result?.xpGained ?? 0} XP',
                    icon: Icons.bolt_rounded,
                    c: c),
                const SizedBox(width: 16),
                _ResultChip(
                    label: '+${result?.dpGained ?? 0} DP',
                    icon: Icons.diamond_outlined,
                    c: c),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Как вы себя чувствуете?',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final v   = i + 1;
                final sel = v == _stateAfter;
                return GestureDetector(
                  onTap: () => setState(() => _stateAfter = v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sel
                          ? c.accent.withValues(alpha: 0.25)
                          : c.surface.withValues(alpha: 0.6),
                      border: Border.all(
                          color: sel ? c.accent : c.border, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      ['😣', '😕', '😐', '🙂', '😊'][i],
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => widget.onComplete(_stateAfter),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: c.background,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'ГОТОВО',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final SieColors c;
  const _ResultChip(
      {required this.label, required this.icon, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: c.accent, size: 14),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
