import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'meditation_session_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final c     = ref.watch(sieColorsProvider);
    final packs = ref
            .watch(meditationPresetsProvider)
            .valueOrNull
            ?.affirmationPacks ??
        [];

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.accent),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'НАСТРОЙКА СЕССИИ',
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
              child: const Text(
                'ЗАПУСТИТЬ СЕССИЮ',
                style: TextStyle(
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

              _SectionLabel('Структура сессии', c),
              const SizedBox(height: 10),
              _ChainSelector(
                hasBreathing: _current.hasBreathing,
                onChanged: (v) => setState(
                    () => _current = _current.copyWith(hasBreathing: v)),
                c: c,
              ),
              const SizedBox(height: 16),

              if (_current.hasBreathing) ...[
                _SectionLabel('Дыхание', c),
                const SizedBox(height: 10),
                _DurationPicker(
                  label: 'Длительность',
                  value: _current.breathingDurationMin,
                  min: 1,
                  max: 30,
                  onChanged: (v) => setState(() =>
                      _current = _current.copyWith(breathingDurationMin: v)),
                  c: c,
                ),
                const SizedBox(height: 10),
                _PatternChips(
                  selected: _current.breathingPatternId ?? 'box',
                  onSelected: (id) => setState(() =>
                      _current = _current.copyWith(breathingPatternId: id)),
                  c: c,
                ),
                const SizedBox(height: 16),
              ],

              _SectionLabel('Медитация', c),
              const SizedBox(height: 10),
              _DurationPicker(
                label: 'Длительность',
                value: _current.meditationDurationMin,
                min: 1,
                max: 120,
                onChanged: (v) => setState(() =>
                    _current = _current.copyWith(meditationDurationMin: v)),
                c: c,
              ),
              const SizedBox(height: 16),

              _SectionLabel('Аудио', c),
              const SizedBox(height: 10),
              _VolumeSlider(
                label: 'МУЗЫКА',
                value: _current.baseVolume,
                onChanged: (v) => setState(
                    () => _current = _current.copyWith(baseVolume: v)),
                c: c,
              ),
              const SizedBox(height: 6),
              _VolumeSlider(
                label: 'AMBIENT',
                value: _current.ambientVolume,
                onChanged: (v) => setState(
                    () => _current = _current.copyWith(ambientVolume: v)),
                c: c,
              ),
              const SizedBox(height: 6),
              _VolumeSlider(
                label: 'ГОЛОС',
                value: _current.voiceVolume,
                onChanged: (v) => setState(
                    () => _current = _current.copyWith(voiceVolume: v)),
                c: c,
              ),
              const SizedBox(height: 16),

              if (packs.isNotEmpty) ...[
                _SectionLabel('Аффирмации', c),
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
    );
  }

  void _launch() {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => MeditationSessionScreen(preset: _current)),
    );
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
          label: 'Только медитация',
          icon: Icons.self_improvement_rounded,
          selected: !hasBreathing,
          onTap: () => onChanged(false),
          c: c,
        ),
        const SizedBox(width: 10),
        _Option(
          label: 'Дыхание + Медитация',
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
            '$value мин',
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

// ── Breathing pattern chips ────────────────────────────────────
class _PatternChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  final SieColors c;
  const _PatternChips({
    required this.selected,
    required this.onSelected,
    required this.c,
  });

  static const _patterns = [
    ('box', 'Box 4×4', '4-4-4-4'),
    ('4-7-8', '4-7-8', '4-7-8'),
    ('coherence', 'Coherence', '5-5'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _patterns.map((rec) {
        final (id, name, timing) = rec;
        final isSelected = selected == id;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? c.accent.withValues(alpha: 0.18)
                    : c.surface.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isSelected ? c.accent : c.border),
              ),
              child: Column(
                children: [
                  Text(name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: isSelected ? c.accent : c.textSecondary,
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400)),
                  Text(timing,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: c.textSecondary, fontSize: 9)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
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
            '${(value * 100).round()}%',
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
            labelText: 'Пак аффирмаций',
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
              child: Text('Без аффирмаций',
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
              Text('Интервал:',
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
                  '${intervalSecs}с',
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
