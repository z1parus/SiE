import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'package:uuid/uuid.dart';
import 'breathing_exercise_screen.dart';
import 'meditation_session_screen.dart';

const _uuid = Uuid();

class MeditationPreflightScreen extends ConsumerStatefulWidget {
  final MeditationPreset preset;
  const MeditationPreflightScreen({super.key, required this.preset});

  @override
  ConsumerState<MeditationPreflightScreen> createState() =>
      _MeditationPreflightScreenState();
}

class _MeditationPreflightScreenState
    extends ConsumerState<MeditationPreflightScreen> {
  late MeditationPreset _current;

  @override
  void initState() {
    super.initState();
    _current = widget.preset;
  }

  bool get _dirty =>
      !mapEquals(_current.toMap(), widget.preset.toMap());

  Future<void> _handleBack() async {
    if (_dirty) {
      final leave = await confirmDestructive(
        context,
        ref,
        title: t.meditationPreflight.confirmLeave.title,
        message: t.meditationPreflight.confirmLeave.message,
        confirmLabel: t.meditationPreflight.confirmLeave.confirm,
      );
      if (!leave) return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c     = ref.watch(sieColorsProvider);
    final packs = ref
            .watch(meditationPresetsProvider)
            .valueOrNull
            ?.affirmationPacks ??
        [];

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.accent),
            onPressed: _handleBack,
          ),
          title: Text(
            t.meditationPreflight.appBar.title,
            style: TextStyle(
              color: c.accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
            ),
          ),
          centerTitle: true,
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: ElevatedButton(
              onPressed: _launch,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: c.background,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                t.meditationPreflight.launch,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2),
              ),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _current.name,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700),
              ),
              if (_current.description != null &&
                  _current.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(_current.description!,
                    style: TextStyle(
                        color: c.textSecondary, fontSize: 13)),
              ],
              const SizedBox(height: 24),

              _SectionLabel(t.meditationPreflight.sections.structure, c),
              const SizedBox(height: 10),
              _ChainSelector(
                hasBreathing: _current.hasBreathing,
                onChanged: (v) => setState(
                    () => _current = _current.copyWith(hasBreathing: v)),
                c: c,
              ),
              const SizedBox(height: 16),

              if (_current.hasBreathing) ...[
                _SectionLabel(t.meditationPreflight.sections.breathing, c),
                const SizedBox(height: 10),
                _BreathingConfigSection(
                  preset: _current,
                  sequences:
                      ref.watch(breathingSequencesProvider).valueOrNull ??
                          const [],
                  onChanged: (p) => setState(() => _current = p),
                  c: c,
                ),
                const SizedBox(height: 16),
              ],

              _SectionLabel(t.meditationPreflight.sections.meditation, c),
              const SizedBox(height: 10),
              _DurationPicker(
                label: t.meditationPreflight.duration.label,
                value: _current.meditationDurationMin,
                min: 1,
                max: 120,
                onChanged: (v) => setState(() =>
                    _current = _current.copyWith(meditationDurationMin: v)),
                c: c,
              ),
              const SizedBox(height: 16),

              _SectionLabel(t.meditationPreflight.sections.audio, c),
              const SizedBox(height: 10),
              _VolumeSlider(
                label: t.meditationPreflight.audio.music,
                value: _current.baseVolume,
                onChanged: (v) => setState(
                    () => _current = _current.copyWith(baseVolume: v)),
                c: c,
              ),
              const SizedBox(height: 6),
              _VolumeSlider(
                label: t.meditationPreflight.audio.ambient,
                value: _current.ambientVolume,
                onChanged: (v) => setState(
                    () => _current = _current.copyWith(ambientVolume: v)),
                c: c,
              ),
              const SizedBox(height: 6),
              _VolumeSlider(
                label: t.meditationPreflight.audio.voice,
                value: _current.voiceVolume,
                onChanged: (v) => setState(
                    () => _current = _current.copyWith(voiceVolume: v)),
                c: c,
              ),
              const SizedBox(height: 16),

              if (packs.isNotEmpty) ...[
                _SectionLabel(t.meditationPreflight.sections.affirmations, c),
                const SizedBox(height: 10),
                _AffirmationSection(
                  packs: packs,
                  selectedPackId: _current.affirmationPackId,
                  intervalSecs: _current.affirmationIntervalSecs,
                  onPackChanged: (id) => setState(
                      () => _current =
                          _current.copyWith(affirmationPackId: id)),
                  onIntervalChanged: (v) => setState(() => _current =
                      _current.copyWith(affirmationIntervalSecs: v)),
                  c: c,
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _launch() async {
    final preset = _current;
    final nav = Navigator.of(context);

    // One state survey, up front, for the whole flow (decision: single survey).
    final stateBefore = await _askStateBefore(context, ref);
    if (!mounted || stateBefore == null) return;

    // No breathing — straight into meditation.
    if (!preset.hasBreathing) {
      nav.push(MaterialPageRoute(
        builder: (_) =>
            MeditationSessionScreen(preset: preset, stateBefore: stateBefore),
      ));
      return;
    }

    // Chained: pre-generate ids so the breathing and meditation rows cross-link.
    final meditationId = _uuid.v4();
    final breathingId = _uuid.v4();

    // Resolve the breathing config: a saved sequence, or quick params.
    BreathingSequence? sequence;
    BreathingSettings? settings;
    if (preset.usesBreathingSequence) {
      final seqs =
          ref.read(breathingSequencesProvider).valueOrNull ?? const [];
      sequence = seqs.where((s) => s.id == preset.breathingSequenceId).isNotEmpty
          ? seqs.firstWhere((s) => s.id == preset.breathingSequenceId)
          : null;
    }
    if (sequence == null) {
      final cfg = preset.breathingQuickConfig;
      settings = BreathingSettings(
        rounds: cfg.rounds,
        cyclesPerRound: cfg.cyclesPerRound,
        inhaleSecs: cfg.inhaleSecs,
        exhaleSecs: cfg.exhaleSecs,
        exhaustRetentionSecs: cfg.exhaustRetentionSecs,
        recoveryHoldSecs: cfg.recoveryHoldSecs,
      );
    }

    nav.push(MaterialPageRoute(
      builder: (_) => BreathingExerciseScreen(
        sequence: sequence,
        initialSettings: settings,
        onChainComplete: (result) async {
          // Record the breathing session (metrics only, linked, no XP).
          try {
            await ref.read(sessionCompletionProvider.notifier).recordChainedBreathing(
                  breathingSessionId: breathingId,
                  meditationSessionId: meditationId,
                  durationSeconds: result.durationSeconds,
                  breaths: result.breaths,
                  rounds: result.rounds,
                  longestHoldSeconds: result.longestHoldSeconds,
                  totalHoldSeconds: result.totalHoldSeconds,
                );
          } catch (_) {
            // Best-effort — proceed to meditation regardless.
          }
          // Short auto-transition, then into the meditation (no extra taps).
          nav.pushReplacement(MaterialPageRoute(
            builder: (_) => _MeditationChainTransition(
              onDone: () => nav.pushReplacement(MaterialPageRoute(
                builder: (_) => MeditationSessionScreen(
                  preset: preset,
                  stateBefore: stateBefore,
                  forcedSessionId: meditationId,
                  breathingSessionId: breathingId,
                  extraBreathingSeconds: result.durationSeconds,
                ),
              )),
            ),
          ));
        },
      ),
    ));
  }
}

// ── Helpers ─────────────────────────────────────────────────────
Widget _SectionLabel(String text, SieColors c) => Text(
      text.toUpperCase(),
      style: TextStyle(
          color: c.accent,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2),
    );

// ── Chain selector ──────────────────────────────────────────────
class _ChainSelector extends StatelessWidget {
  final bool hasBreathing;
  final ValueChanged<bool> onChanged;
  final SieColors c;
  const _ChainSelector({
    required this.hasBreathing,
    required this.onChanged,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Option(
          label: t.meditationPreflight.chain.meditationOnly,
          icon: Icons.self_improvement_rounded,
          selected: !hasBreathing,
          onTap: () => onChanged(false),
          c: c,
        ),
        const SizedBox(width: 10),
        _Option(
          label: t.meditationPreflight.chain.breathingAndMeditation,
          icon: Icons.air_rounded,
          selected: hasBreathing,
          onTap: () => onChanged(true),
          c: c,
        ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final SieColors c;
  const _Option({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? c.accent.withValues(alpha: 0.18)
                : c.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? c.accent : c.border, width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? c.accent : c.textSecondary, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? c.accent : c.textSecondary,
                  fontSize: 11,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Duration picker ─────────────────────────────────────────────
class _DurationPicker extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final SieColors c;
  const _DurationPicker({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(color: c.textSecondary, fontSize: 13)),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.remove_rounded, color: c.accent, size: 18),
          onPressed:
              value > min ? () => onChanged(value - 1) : null,
          padding: EdgeInsets.zero,
          constraints:
              const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        SizedBox(
          width: 52,
          child: Text(
            t.meditationPreflight.duration.value(value: value),
            textAlign: TextAlign.center,
            style: TextStyle(
                color: c.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          icon: Icon(Icons.add_rounded, color: c.accent, size: 18),
          onPressed:
              value < max ? () => onChanged(value + 1) : null,
          padding: EdgeInsets.zero,
          constraints:
              const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}

// ── Breathing config (quick params / saved sequence) ───────────
class _BreathingConfigSection extends StatelessWidget {
  final MeditationPreset preset;
  final List<BreathingSequence> sequences;
  final ValueChanged<MeditationPreset> onChanged;
  final SieColors c;
  const _BreathingConfigSection({
    required this.preset,
    required this.sequences,
    required this.onChanged,
    required this.c,
  });

  void _setQuick(MeditationBreathingConfig cfg) => onChanged(preset.copyWith(
        breathingConfigJson: cfg.toJsonString(),
        breathingSequenceId: null,
      ));

  @override
  Widget build(BuildContext context) {
    final useSequence = preset.usesBreathingSequence;
    final cfg = preset.breathingQuickConfig;

    Widget modeTab(String label, bool selected, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: selected
                    ? c.accent.withValues(alpha: 0.18)
                    : c.surface.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: selected ? c.accent : c.border),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? c.accent : c.textSecondary,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            modeTab(t.meditationPreflight.breathingConfig.quick, !useSequence,
                () => _setQuick(cfg)),
            modeTab(
                t.meditationPreflight.breathingConfig.sequence,
                useSequence,
                () => onChanged(preset.copyWith(
                    breathingSequenceId:
                        sequences.isNotEmpty ? sequences.first.id : null))),
          ],
        ),
        const SizedBox(height: 12),
        if (!useSequence) ...[
          _StepperRow(
            label: t.meditationPreflight.breathingConfig.rounds,
            value: cfg.rounds,
            min: 1,
            max: 6,
            display: t.meditationPreflight.breathingConfig.roundsValue(n: cfg.rounds),
            onChanged: (v) => _setQuick(cfg.copyWith(rounds: v)),
            c: c,
          ),
          const SizedBox(height: 8),
          _StepperRow(
            label: t.meditationPreflight.breathingConfig.cycles,
            value: cfg.cyclesPerRound,
            min: 15,
            max: 40,
            display:
                t.meditationPreflight.breathingConfig.cyclesValue(n: cfg.cyclesPerRound),
            onChanged: (v) => _setQuick(cfg.copyWith(cyclesPerRound: v)),
            c: c,
          ),
        ] else if (sequences.isEmpty) ...[
          Text(
            t.meditationPreflight.breathingConfig.noSequences,
            style: TextStyle(color: c.textSecondary, fontSize: 11, height: 1.3),
          ),
        ] else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sequences.map((s) {
              final sel = s.id == preset.breathingSequenceId;
              return GestureDetector(
                onTap: () =>
                    onChanged(preset.copyWith(breathingSequenceId: s.id)),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel
                        ? c.accent.withValues(alpha: 0.18)
                        : c.surface.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sel ? c.accent : c.border),
                  ),
                  child: Text(
                    s.name,
                    style: TextStyle(
                      color: sel ? c.accent : c.textSecondary,
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

/// Compact −/N/+ stepper (a generalised [_DurationPicker] with a custom label).
class _StepperRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final String display;
  final ValueChanged<int> onChanged;
  final SieColors c;
  const _StepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 13)),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.remove_rounded, color: c.accent, size: 18),
          onPressed: value > min ? () => onChanged(value - 1) : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        SizedBox(
          width: 52,
          child: Text(
            display,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          icon: Icon(Icons.add_rounded, color: c.accent, size: 18),
          onPressed: value < max ? () => onChanged(value + 1) : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}

// ── State-before survey (one survey up front for the whole flow) ──
Future<int?> _askStateBefore(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _StateBeforeSheet(),
  );
}

class _StateBeforeSheet extends ConsumerStatefulWidget {
  const _StateBeforeSheet();
  @override
  ConsumerState<_StateBeforeSheet> createState() => _StateBeforeSheetState();
}

class _StateBeforeSheetState extends ConsumerState<_StateBeforeSheet> {
  int _state = 3;

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    final moodLabels = [
      t.meditationSession.completion.mood.veryBad,
      t.meditationSession.completion.mood.bad,
      t.meditationSession.completion.mood.neutral,
      t.meditationSession.completion.mood.good,
      t.meditationSession.completion.mood.great,
    ];
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: c.briefCard(radius: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.meditationPreflight.stateBefore.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final v = i + 1;
                final sel = v == _state;
                return Semantics(
                  button: true,
                  selected: sel,
                  label: moodLabels[i],
                  child: GestureDetector(
                    onTap: () {
                      SieHaptics.selection();
                      setState(() => _state = v);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sel
                            ? c.accent.withValues(alpha: 0.25)
                            : c.surface.withValues(alpha: 0.6),
                        border: Border.all(
                            color: sel ? c.accent : c.border, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(['😣', '😕', '😐', '🙂', '😊'][i],
                          style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                SieHaptics.light();
                Navigator.of(context).pop(_state);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  t.meditationPreflight.stateBefore.start,
                  style: TextStyle(
                    color: c.background,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chain transition (breathing → meditation, auto-advance) ──────
class _MeditationChainTransition extends ConsumerStatefulWidget {
  final VoidCallback onDone;
  const _MeditationChainTransition({required this.onDone});
  @override
  ConsumerState<_MeditationChainTransition> createState() =>
      _MeditationChainTransitionState();
}

class _MeditationChainTransitionState
    extends ConsumerState<_MeditationChainTransition> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.self_improvement_rounded, color: c.accent, size: 44),
              const SizedBox(height: 20),
              Text(
                t.meditationPreflight.chainTransition.title,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                t.meditationPreflight.chainTransition.subtitle,
                style: TextStyle(
                    color: c.textSecondary, fontSize: 13, letterSpacing: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Volume slider ───────────────────────────────────────────────
class _VolumeSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final SieColors c;
  const _VolumeSlider({
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
          width: 64,
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
        SizedBox(
          width: 36,
          child: Text(
            t.meditationPreflight.audio.volume(percent: (value * 100).round()),
            textAlign: TextAlign.end,
            style:
                TextStyle(color: c.textSecondary, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

// ── Affirmation section ─────────────────────────────────────────
class _AffirmationSection extends StatelessWidget {
  final List<AffirmationPack> packs;
  final String? selectedPackId;
  final int intervalSecs;
  final ValueChanged<String?> onPackChanged;
  final ValueChanged<int> onIntervalChanged;
  final SieColors c;
  const _AffirmationSection({
    required this.packs,
    required this.selectedPackId,
    required this.intervalSecs,
    required this.onPackChanged,
    required this.onIntervalChanged,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          value: selectedPackId,
          dropdownColor: c.surface,
          style: TextStyle(color: c.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            labelText: t.meditationPreflight.affirmations.packLabel,
            labelStyle:
                TextStyle(color: c.textSecondary, fontSize: 12),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: c.border),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: c.accent),
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(t.meditationPreflight.affirmations.noPack,
                  style: TextStyle(
                      color: c.textSecondary, fontSize: 13)),
            ),
            ...packs.map(
              (p) => DropdownMenuItem<String?>(
                  value: p.id, child: Text(p.name)),
            ),
          ],
          onChanged: onPackChanged,
        ),
        if (selectedPackId != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Text(t.meditationPreflight.affirmations.interval,
                  style: TextStyle(
                      color: c.textSecondary, fontSize: 13)),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.remove_rounded,
                    color: c.accent, size: 18),
                onPressed: intervalSecs > 10
                    ? () => onIntervalChanged(intervalSecs - 10)
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                    minWidth: 32, minHeight: 32),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  t.meditationPreflight.affirmations
                      .intervalValue(secs: intervalSecs),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: Icon(Icons.add_rounded,
                    color: c.accent, size: 18),
                onPressed: intervalSecs < 300
                    ? () => onIntervalChanged(intervalSecs + 10)
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                    minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
