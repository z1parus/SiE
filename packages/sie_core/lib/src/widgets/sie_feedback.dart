import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/sie_colors.dart';
import '../theme/sie_haptics.dart';

/// Shared feedback helpers for destructive actions (Stage 0 — design system).
///
/// Centralises the two guard-rails the UX audit flagged as missing across the
/// app: an explicit confirmation dialog for heavy/irreversible actions, and an
/// optimistic "undo" snackbar for light deletions.

/// Shows a themed confirmation dialog with a danger-styled confirm button.
///
/// Returns `true` only if the user explicitly confirms. Use for ca. heavy or
/// cascading deletions (a goal with sub-goals, archiving a habit) where an
/// undo snackbar is not enough.
Future<bool> confirmDestructive(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String message,
  String confirmLabel = 'Удалить',
  String cancelLabel = 'Отмена',
}) async {
  final c = ref.read(sieColorsProvider);
  SieHaptics.warning();
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.border),
      ),
      title: Text(title, style: TextStyle(color: c.textPrimary)),
      content: Text(message, style: TextStyle(color: c.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(cancelLabel, style: TextStyle(color: c.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(
            confirmLabel,
            style: TextStyle(color: c.danger, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Shows a snackbar with an UNDO action for an optimistic deletion.
///
/// The caller removes the item from the UI immediately, then calls this. If the
/// user taps UNDO before the snackbar dismisses, [onUndo] runs (restore);
/// otherwise [onCommit] runs once the snackbar closes (finalise the delete).
void showUndoSnackbar(
  BuildContext context,
  WidgetRef ref, {
  required String message,
  required VoidCallback onUndo,
  VoidCallback? onCommit,
  Duration duration = const Duration(seconds: 5),
}) {
  final c = ref.read(sieColorsProvider);
  var undone = false;
  final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
  messenger
      .showSnackBar(
        SnackBar(
          duration: duration,
          behavior: SnackBarBehavior.floating,
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: c.border),
          ),
          content: Text(message, style: TextStyle(color: c.textPrimary)),
          action: SnackBarAction(
            label: 'ОТМЕНИТЬ',
            textColor: c.accent,
            onPressed: () {
              undone = true;
              SieHaptics.light();
              onUndo();
            },
          ),
        ),
      )
      .closed
      .then((_) {
    if (!undone) onCommit?.call();
  });
}
