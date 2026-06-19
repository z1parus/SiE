import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WidgetStudioScreen
//
// Live preview + customisation panel for a single home-screen widget.
// Opens when the user taps "Configure" on a widget card in settings.
// ─────────────────────────────────────────────────────────────────────────────

class WidgetStudioScreen extends ConsumerStatefulWidget {
  final WidgetConfig initialConfig;
  final int appWidgetId;

  const WidgetStudioScreen({
    super.key,
    required this.initialConfig,
    required this.appWidgetId,
  });

  @override
  ConsumerState<WidgetStudioScreen> createState() => _WidgetStudioScreenState();
}

class _WidgetStudioScreenState extends ConsumerState<WidgetStudioScreen> {
  late WidgetConfig _cfg;
  bool _saving = false;

  ModuleWidgetProvider? get _provider =>
      WidgetRegistry.instance.get(_cfg.moduleId);

  @override
  void initState() {
    super.initState();
    _cfg = widget.initialConfig;
  }

  void _update(WidgetConfig cfg) => setState(() => _cfg = cfg);

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await WidgetConfigStore.save(_cfg);
      final db = ref.read(appDatabaseProvider);
      await WidgetRenderService.refresh(_cfg.appWidgetId, db);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Виджет сохранён')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    final provider = _provider;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: Text(
          provider?.displayName ?? 'Виджет',
          style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  child: Text('Сохранить',
                      style: TextStyle(color: c.accent, fontWeight: FontWeight.w600)),
                ),
        ],
      ),
      body: provider == null
          ? Center(
              child: Text('Модуль не найден', style: TextStyle(color: c.textSecondary)),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Live preview ──────────────────────────────────────────────
                _PreviewSection(cfg: _cfg, provider: provider, c: c),
                const SizedBox(height: 24),

                // ── Size picker ───────────────────────────────────────────────
                _SectionHeader(label: 'Размер', c: c),
                const SizedBox(height: 8),
                _SizePicker(
                  current: _cfg.sizeBucket,
                  supported: provider.supportedSizes,
                  c: c,
                  onChanged: (size) => _update(_cfg.copyWith(sizeBucket: size)),
                ),
                const SizedBox(height: 20),

                // ── Theme picker ──────────────────────────────────────────────
                _SectionHeader(label: 'Тема', c: c),
                const SizedBox(height: 8),
                _ThemePicker(
                  current: _cfg.themeOverride,
                  c: c,
                  onChanged: (t) => _update(_cfg.copyWith(themeOverride: t)),
                ),
                const SizedBox(height: 20),

                // ── Background style ──────────────────────────────────────────
                _SectionHeader(label: 'Фон', c: c),
                const SizedBox(height: 8),
                _BgStylePicker(
                  current: _cfg.bgStyle,
                  c: c,
                  onChanged: (s) => _update(_cfg.copyWith(bgStyle: s)),
                ),
                const SizedBox(height: 20),

                // ── Content options ───────────────────────────────────────────
                ..._buildContentOptions(provider, c),
              ],
            ),
    );
  }

  List<Widget> _buildContentOptions(
      ModuleWidgetProvider provider, SieColors c) {
    final specs = provider.optionSchema(_cfg.sizeBucket);
    if (specs.isEmpty) return const [];

    return [
      _SectionHeader(label: 'Содержимое', c: c),
      const SizedBox(height: 8),
      ...specs.map((spec) {
        final value = _cfg.contentOptions[spec.id] ?? spec.defaultValue;
        if (spec.isToggle) {
          return _ToggleOption(
            spec: spec,
            value: value as bool? ?? false,
            c: c,
            onChanged: (v) {
              final opts = Map<String, dynamic>.from(_cfg.contentOptions);
              opts[spec.id] = v;
              _update(_cfg.copyWith(contentOptions: opts));
            },
          );
        }
        if (spec.isEnumChoice) {
          return _EnumOption(
            spec: spec,
            value: value as String?,
            c: c,
            onChanged: (v) {
              final opts = Map<String, dynamic>.from(_cfg.contentOptions);
              opts[spec.id] = v;
              _update(_cfg.copyWith(contentOptions: opts));
            },
          );
        }
        if (spec.isNumber) {
          return _NumberOption(
            spec: spec,
            value: (value as num?)?.toInt() ?? spec.defaultValue?.toInt() ?? 4,
            c: c,
            onChanged: (v) {
              final opts = Map<String, dynamic>.from(_cfg.contentOptions);
              opts[spec.id] = v;
              _update(_cfg.copyWith(contentOptions: opts));
            },
          );
        }
        return const SizedBox.shrink();
      }),
      const SizedBox(height: 8),
    ];
  }
}

// ── Preview ───────────────────────────────────────────────────────────────────

class _PreviewSection extends StatelessWidget {
  final WidgetConfig cfg;
  final ModuleWidgetProvider provider;
  final SieColors c;

  const _PreviewSection({
    required this.cfg,
    required this.provider,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final ctx = WidgetRenderContext(
      colors: _colorsForConfig(cfg),
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
      config: cfg,
    );
    final data = provider.sampleData(cfg.sizeBucket);
    final preview = provider.render(ctx, cfg, data);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Предпросмотр',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: preview,
            ),
          ),
        ],
      ),
    );
  }

  SieColors _colorsForConfig(WidgetConfig cfg) {
    final appMode = SieThemeMode.classicDark; // fallback; bridge reads prefs async
    final mode = switch (cfg.themeOverride) {
      WidgetThemeMode.forceDark  => SieThemeMode.classicDark,
      WidgetThemeMode.forceLight => SieThemeMode.classicLight,
      WidgetThemeMode.followApp  => appMode,
    };
    return SieColors.forMode(mode);
  }
}

// ── Size picker ───────────────────────────────────────────────────────────────

class _SizePicker extends StatelessWidget {
  final WidgetSizeBucket current;
  final List<WidgetSizeBucket> supported;
  final SieColors c;
  final ValueChanged<WidgetSizeBucket> onChanged;

  const _SizePicker({
    required this.current,
    required this.supported,
    required this.c,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: WidgetSizeBucket.values
          .where((s) => supported.contains(s))
          .map((s) {
        final selected = s == current;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(s),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected ? c.accent.withValues(alpha: 0.15) : c.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? c.accent : c.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    s == WidgetSizeBucket.small
                        ? Icons.crop_square
                        : s == WidgetSizeBucket.medium
                            ? Icons.crop_landscape
                            : Icons.crop_din,
                    color: selected ? c.accent : c.textSecondary,
                    size: 18,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s == WidgetSizeBucket.small
                        ? 'Малый'
                        : s == WidgetSizeBucket.medium
                            ? 'Средний'
                            : 'Большой',
                    style: TextStyle(
                      color: selected ? c.accent : c.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Theme picker ──────────────────────────────────────────────────────────────

class _ThemePicker extends StatelessWidget {
  final WidgetThemeMode current;
  final SieColors c;
  final ValueChanged<WidgetThemeMode> onChanged;

  const _ThemePicker({
    required this.current,
    required this.c,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const options = [
      (WidgetThemeMode.followApp, 'Как в приложении', Icons.sync),
      (WidgetThemeMode.forceDark, 'Тёмная', Icons.dark_mode),
      (WidgetThemeMode.forceLight, 'Светлая', Icons.light_mode),
    ];
    return Row(
      children: options.map((opt) {
        final (mode, label, icon) = opt;
        final selected = mode == current;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(mode),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected ? c.accent.withValues(alpha: 0.15) : c.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? c.accent : c.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(icon,
                      color: selected ? c.accent : c.textSecondary,
                      size: 18),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                        color: selected ? c.accent : c.textSecondary,
                        fontSize: 10),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Background style picker ───────────────────────────────────────────────────

class _BgStylePicker extends StatelessWidget {
  final WidgetBackgroundStyle current;
  final SieColors c;
  final ValueChanged<WidgetBackgroundStyle> onChanged;

  const _BgStylePicker({
    required this.current,
    required this.c,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const options = [
      (WidgetBackgroundStyle.flat, 'Плоский'),
      (WidgetBackgroundStyle.glass, 'Стекло'),
      (WidgetBackgroundStyle.gradient, 'Градиент'),
      (WidgetBackgroundStyle.transparent, 'Прозрачный'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final (style, label) = opt;
        final selected = style == current;
        return GestureDetector(
          onTap: () => onChanged(style),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? c.accent.withValues(alpha: 0.15) : c.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? c.accent : c.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? c.accent : c.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final SieColors c;
  const _SectionHeader({required this.label, required this.c});

  @override
  Widget build(BuildContext context) => Text(
        label.toUpperCase(),
        style: TextStyle(
          color: c.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      );
}

// ── Toggle option ─────────────────────────────────────────────────────────────

class _ToggleOption extends StatelessWidget {
  final WidgetOptionSpec spec;
  final bool value;
  final SieColors c;
  final ValueChanged<bool> onChanged;

  const _ToggleOption({
    required this.spec,
    required this.value,
    required this.c,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(spec.label,
                style: TextStyle(color: c.textPrimary, fontSize: 14)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: c.accent,
          ),
        ],
      ),
    );
  }
}

// ── Enum choice option ────────────────────────────────────────────────────────

class _EnumOption extends StatelessWidget {
  final WidgetOptionSpec spec;
  final String? value;
  final SieColors c;
  final ValueChanged<String> onChanged;

  const _EnumOption({
    required this.spec,
    required this.value,
    required this.c,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final choices = spec.choices ?? {};
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(spec.label,
                style: TextStyle(color: c.textPrimary, fontSize: 14)),
          ),
          DropdownButton<String>(
            value: value ?? spec.defaultValue as String?,
            dropdownColor: c.surface,
            style: TextStyle(color: c.textPrimary, fontSize: 13),
            underline: const SizedBox.shrink(),
            items: choices.entries
                .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value)))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

// ── Number option ─────────────────────────────────────────────────────────────

class _NumberOption extends StatelessWidget {
  final WidgetOptionSpec spec;
  final int value;
  final SieColors c;
  final ValueChanged<int> onChanged;

  const _NumberOption({
    required this.spec,
    required this.value,
    required this.c,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final min = spec.min?.toInt() ?? 1;
    final max = spec.max?.toInt() ?? 10;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(spec.label,
                  style: TextStyle(color: c.textPrimary, fontSize: 14)),
              Text(
                '$value',
                style: TextStyle(
                    color: c.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Slider(
            value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            activeColor: c.accent,
            inactiveColor: c.border,
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }
}
