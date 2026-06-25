import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

/// Native display name for a language (always shown in its own language).
String languageLabel(AppLocale locale) => switch (locale) {
      AppLocale.en => 'English',
      AppLocale.ru => 'Русский',
    };

/// Opens a bottom sheet to pick the app language. Persists + applies the choice
/// immediately (the whole tree rebuilds in the new language).
Future<void> showLanguagePicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LanguageSheet(),
  );
}

class _LanguageSheet extends ConsumerWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    final current = ref.watch(localeProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Icon(Icons.language, size: 18, color: c.textSecondary),
                const SizedBox(width: 10),
                Text(
                  t.common.language.toUpperCase(),
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          for (final locale in AppLocale.values)
            _LanguageRow(
              label: languageLabel(locale),
              selected: locale == current,
              c: c,
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(locale);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.label,
    required this.selected,
    required this.c,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final SieColors c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? c.accent.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? c.accent.withValues(alpha: 0.6) : c.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? c.accent : c.textPrimary,
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (selected) Icon(Icons.check, size: 18, color: c.accent),
          ],
        ),
      ),
    );
  }
}
