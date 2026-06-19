import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:sie_core/sie_core.dart';

import 'widget_studio_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MyWidgetsScreen
//
// Lists every SiE widget the user has placed on the home screen and lets them
// open the Studio to customise each instance. Reachable from the profile.
// ─────────────────────────────────────────────────────────────────────────────

class MyWidgetsScreen extends ConsumerStatefulWidget {
  const MyWidgetsScreen({super.key});

  @override
  ConsumerState<MyWidgetsScreen> createState() => _MyWidgetsScreenState();
}

class _WidgetEntry {
  final int appWidgetId;
  final ModuleWidgetProvider provider;
  final WidgetConfig config;
  const _WidgetEntry(this.appWidgetId, this.provider, this.config);
}

class _MyWidgetsScreenState extends ConsumerState<MyWidgetsScreen> {
  bool _loading = true;
  List<_WidgetEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = <_WidgetEntry>[];
    try {
      final installed = await HomeWidget.getInstalledWidgets();
      for (final info in installed) {
        final id = info.androidWidgetId;
        if (id == null) continue;
        final provider = _providerForClass(info.androidClassName);
        if (provider == null) continue;
        final cfg = await WidgetConfigStore.load(id) ??
            WidgetConfig(
              appWidgetId: id,
              moduleId: provider.moduleId,
              sizeBucket: provider.supportedSizes.contains(WidgetSizeBucket.medium)
                  ? WidgetSizeBucket.medium
                  : provider.supportedSizes.first,
            );
        entries.add(_WidgetEntry(id, provider, cfg));
      }
    } catch (_) {
      // Leave the list empty on failure; the empty state explains next steps.
    }
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  ModuleWidgetProvider? _providerForClass(String? className) {
    if (className == null) return null;
    for (final p in WidgetRegistry.instance.all) {
      if (className.endsWith(p.androidProviderClass)) return p;
    }
    return null;
  }

  Future<void> _openStudio(_WidgetEntry e) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WidgetStudioScreen(
        initialConfig: e.config,
        appWidgetId: e.appWidgetId,
      ),
    ));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: Text('Мои виджеты',
            style: TextStyle(
                color: c.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? _EmptyState(c: c)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _WidgetRow(
                      entry: _entries[i],
                      c: c,
                      onTap: () => _openStudio(_entries[i]),
                    ),
                  ),
                ),
    );
  }
}

class _WidgetRow extends StatelessWidget {
  final _WidgetEntry entry;
  final SieColors c;
  final VoidCallback onTap;

  const _WidgetRow({required this.entry, required this.c, required this.onTap});

  String get _sizeLabel => switch (entry.config.sizeBucket) {
        WidgetSizeBucket.small => 'Малый',
        WidgetSizeBucket.medium => 'Средний',
        WidgetSizeBucket.large => 'Большой',
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: c.flatCard(radius: 16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(entry.provider.glyph, color: c.accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.provider.displayName,
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text('$_sizeLabel · #${entry.appWidgetId}',
                      style:
                          TextStyle(color: c.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.tune, color: c.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final SieColors c;
  const _EmptyState({required this.c});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.widgets_outlined, color: c.iconMuted, size: 48),
            const SizedBox(height: 16),
            Text(
              'Виджетов пока нет',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Добавь виджет SiE на домашний экран '
              '(долгое нажатие на экране → Виджеты), затем вернись сюда, '
              'чтобы настроить его.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
