import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'package:uuid/uuid.dart';

class MeditationPresetBuilderScreen extends ConsumerStatefulWidget {
  final MeditationPreset? editPreset;
  const MeditationPresetBuilderScreen({super.key, this.editPreset});

  @override
  ConsumerState<MeditationPresetBuilderScreen> createState() =>
      _MeditationPresetBuilderScreenState();
}

class _MeditationPresetBuilderScreenState
    extends ConsumerState<MeditationPresetBuilderScreen> {
  static const _totalPages = 4;

  late PageController _pageCtrl;
  int _page = 0;

  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late MeditationPreset _preset;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();

    final edit = widget.editPreset;
    _preset = edit ??
        MeditationPreset(
          id: const Uuid().v4(),
          userId: null,
          name: '',
          description: null,
          isSystem: false,
          hasBreathing: false,
          breathingPatternId: 'box',
          breathingDurationMin: 5,
          meditationType: 'unguided',
          meditationDurationMin: 15,
          baseMusicId: null,
          ambientFxId: null,
          baseVolume: 0.7,
          ambientVolume: 0.5,
          voiceVolume: 0.6,
          affirmationPackId: null,
          affirmationIntervalSecs: 30,
          createdAt: DateTime.now(),
        );

    _nameCtrl = TextEditingController(text: _preset.name);
    _descCtrl = TextEditingController(text: _preset.description ?? '');
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
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
            widget.editPreset != null ? 'РЕДАКТИРОВАНИЕ' : 'НОВЫЙ ПРЕСЕТ',
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
            child: Row(
              children: [
                if (_page > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _prevPage,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.textSecondary,
                        side: BorderSide(color: c.border),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('← Назад'),
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
                const SizedBox(width: 12),
                Text(
                  'Шаг ${_page + 1}/$_totalPages',
                  style:
                      TextStyle(color: c.textSecondary, fontSize: 12),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _page < _totalPages - 1 ? _nextPage : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: c.background,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(_page < _totalPages - 1
                        ? 'Далее →'
                        : 'СОХРАНИТЬ'),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: PageView(
          controller: _pageCtrl,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (p) => setState(() => _page = p),
          children: [
            _NamePage(nameCtrl: _nameCtrl, descCtrl: _descCtrl, c: c),
            _ChainPage(
              preset: _preset,
              onChanged: (p) => setState(() => _preset = p),
              c: c,
            ),
            _AudioPage(
              preset: _preset,
              onChanged: (p) => setState(() => _preset = p),
              c: c,
            ),
            _AffirmationsPage(
              preset: _preset,
              packs: packs,
              onChanged: (p) => setState(() => _preset = p),
              c: c,
            ),
          ],
        ),
      ),
    );
  }

  void _nextPage() {
    if (_page == 0 && _nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Введите название пресета')),
      );
      return;
    }
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _prevPage() {
    _pageCtrl.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Введите название пресета')),
      );
      return;
    }

    final finalPreset = _preset.copyWith(
      name:        name,
      description: _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
    );

    final notifier = ref.read(meditationPresetsProvider.notifier);
    if (widget.editPreset != null) {
      await notifier.updatePreset(finalPreset);
    } else {
      await notifier.createPreset(finalPreset);
    }

    if (mounted) Navigator.of(context).pop();
  }
}

// ── Page 1: Name ────────────────────────────────────────────────
class _NamePage extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final SieColors c;
  const _NamePage({
    required this.nameCtrl,
    required this.descCtrl,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label('Название пресета', c),
          const SizedBox(height: 12),
          _Field(
              controller: nameCtrl,
              hint: 'Например: Утренняя медитация',
              c: c),
          const SizedBox(height: 20),
          _Label('Описание (необязательно)', c),
          const SizedBox(height: 12),
          _Field(
              controller: descCtrl,
              hint: 'Краткое описание сессии',
              maxLines: 3,
              c: c),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final SieColors c;
  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: c.textPrimary, fontSize: 15),
      cursorColor: c.accent,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: c.textSecondary, fontSize: 14),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: c.border),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: c.accent, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: c.surface.withValues(alpha: 0.4),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ── Page 2: Chain ────────────────────────────────────────────────
class _ChainPage extends StatelessWidget {
  final MeditationPreset preset;
  final ValueChanged<MeditationPreset> onChanged;
  final SieColors c;
  const _ChainPage({
    required this.preset,
    required this.onChanged,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label('СТРУКТУРА', c),
          const SizedBox(height: 10),
          Row(
            children: [
              _ToggleOpt(
                label: 'Только\nмедитация',
                icon: Icons.self_improvement_rounded,
                selected: !preset.hasBreathing,
                onTap: () =>
                    onChanged(preset.copyWith(hasBreathing: false)),
                c: c,
              ),
              const SizedBox(width: 10),
              _ToggleOpt(
                label: 'Дыхание +\nМедитация',
                icon: Icons.air_rounded,
                selected: preset.hasBreathing,
                onTap: () =>
                    onChanged(preset.copyWith(hasBreathing: true)),
                c: c,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (preset.hasBreathing) ...[
            _Label('ДЫХАНИЕ', c),
            const SizedBox(height: 10),
            _NumberRow(
              label: 'Длительность',
              value: preset.breathingDurationMin,
              unit: 'мин',
              min: 1,
              max: 30,
              onChanged: (v) =>
                  onChanged(preset.copyWith(breathingDurationMin: v)),
              c: c,
            ),
            const SizedBox(height: 12),
            _PatternRow(
              selected: preset.breathingPatternId ?? 'box',
              onSelected: (id) =>
                  onChanged(preset.copyWith(breathingPatternId: id)),
              c: c,
            ),
            const SizedBox(height: 20),
          ],
          _Label('МЕДИТАЦИЯ', c),
          const SizedBox(height: 10),
          _NumberRow(
            label: 'Длительность',
            value: preset.meditationDurationMin,
            unit: 'мин',
            min: 1,
            max: 120,
            onChanged: (v) =>
                onChanged(preset.copyWith(meditationDurationMin: v)),
            c: c,
          ),
        ],
      ),
    );
  }
}

// ── Page 3: Audio ────────────────────────────────────────────────
class _AudioPage extends StatelessWidget {
  final MeditationPreset preset;
  final ValueChanged<MeditationPreset> onChanged;
  final SieColors c;
  const _AudioPage({
    required this.preset,
    required this.onChanged,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label('ГРОМКОСТЬ', c),
          const SizedBox(height: 12),
          _SliderRow(
            label: 'МУЗЫКА',
            value: preset.baseVolume,
            onChanged: (v) =>
                onChanged(preset.copyWith(baseVolume: v)),
            c: c,
          ),
          const SizedBox(height: 8),
          _SliderRow(
            label: 'AMBIENT',
            value: preset.ambientVolume,
            onChanged: (v) =>
                onChanged(preset.copyWith(ambientVolume: v)),
            c: c,
          ),
          const SizedBox(height: 8),
          _SliderRow(
            label: 'ГОЛОС',
            value: preset.voiceVolume,
            onChanged: (v) =>
                onChanged(preset.copyWith(voiceVolume: v)),
            c: c,
          ),
        ],
      ),
    );
  }
}

// ── Page 4: Affirmations ─────────────────────────────────────────
class _AffirmationsPage extends StatelessWidget {
  final MeditationPreset preset;
  final List<AffirmationPack> packs;
  final ValueChanged<MeditationPreset> onChanged;
  final SieColors c;
  const _AffirmationsPage({
    required this.preset,
    required this.packs,
    required this.onChanged,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    if (packs.isEmpty) {
      return Center(
        child: Text('Паки аффирмаций недоступны',
            style: TextStyle(color: c.textSecondary, fontSize: 14)),
      );
    }

    final selectedPack =
        packs.where((p) => p.id == preset.affirmationPackId).firstOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label('ПАК АФФИРМАЦИЙ', c),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: preset.affirmationPackId,
            dropdownColor: c.surface,
            style: TextStyle(color: c.textPrimary, fontSize: 13),
            decoration: InputDecoration(
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
              filled: true,
              fillColor: c.surface.withValues(alpha: 0.4),
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text('Без аффирмаций',
                    style: TextStyle(
                        color: c.textSecondary, fontSize: 13)),
              ),
              ...packs.map((p) => DropdownMenuItem<String?>(
                  value: p.id, child: Text(p.name))),
            ],
            onChanged: (v) =>
                onChanged(preset.copyWith(affirmationPackId: v)),
          ),
          if (preset.affirmationPackId != null) ...[
            const SizedBox(height: 16),
            _Label('ИНТЕРВАЛ', c),
            const SizedBox(height: 8),
            _NumberRow(
              label: 'Каждые',
              value: preset.affirmationIntervalSecs,
              unit: 'сек',
              min: 10,
              max: 300,
              step: 10,
              onChanged: (v) => onChanged(
                  preset.copyWith(affirmationIntervalSecs: v)),
              c: c,
            ),
          ],
          if (selectedPack != null &&
              selectedPack.phrases.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Label('ПРЕДПРОСМОТР', c),
            const SizedBox(height: 8),
            ...selectedPack.phrases.take(3).map(
                  (ph) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: c.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: c.border.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        ph,
                        style: TextStyle(
                            color: c.textSecondary
                                .withValues(alpha: 0.9),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            height: 1.5),
                      ),
                    ),
                  ),
                ),
            if (selectedPack.phrases.length > 3)
              Text(
                'и ещё ${selectedPack.phrases.length - 3} фраз...',
                style:
                    TextStyle(color: c.textSecondary, fontSize: 11),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Shared builder widgets ───────────────────────────────────────
Widget _Label(String text, SieColors c) => Text(
      text,
      style: TextStyle(
          color: c.accent,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2),
    );

class _ToggleOpt extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final SieColors c;
  const _ToggleOpt({
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
          padding: const EdgeInsets.symmetric(
              vertical: 14, horizontal: 8),
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
                  color: selected ? c.accent : c.textSecondary,
                  size: 22),
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

class _NumberRow extends StatelessWidget {
  final String label;
  final int value;
  final String unit;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;
  final SieColors c;
  const _NumberRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    this.step = 1,
    required this.onChanged,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style:
                TextStyle(color: c.textSecondary, fontSize: 13)),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.remove_rounded, color: c.accent, size: 18),
          onPressed: value - step >= min
              ? () => onChanged(value - step)
              : null,
          padding: EdgeInsets.zero,
          constraints:
              const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        SizedBox(
          width: 60,
          child: Text(
            '$value $unit',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: c.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          icon: Icon(Icons.add_rounded, color: c.accent, size: 18),
          onPressed: value + step <= max
              ? () => onChanged(value + step)
              : null,
          padding: EdgeInsets.zero,
          constraints:
              const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}

class _PatternRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  final SieColors c;
  const _PatternRow({
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
                          color: isSelected
                              ? c.accent
                              : c.textSecondary,
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

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final SieColors c;
  const _SliderRow({
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
