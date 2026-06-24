import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import '../local/app_database.dart';
import 'widget_render_service.dart';

/// Parses and executes quick-actions fired from a home-screen widget.
///
/// Action URIs look like:
///   `sie://action/habits/toggle?widget=12&habit=<id>`
///
/// All work is offline-first: mutations are written to Drift and queued in the
/// pending-sync table (same mechanism the in-app offline edits use). The app's
/// existing sync layer flushes them to Supabase on the next online session.
class WidgetActionRouter {
  /// Runs the action described by [uri] against [db], then re-renders the
  /// originating widget so the change is reflected immediately.
  static Future<void> run(Uri? uri, AppDatabase db) async {
    if (uri == null) return;
    if (uri.scheme != 'sie' || uri.host != 'action') return;

    // path segments: [moduleId, actionId]
    final segments = uri.pathSegments;
    if (segments.length < 2) return;
    final moduleId = segments[0];
    final actionId = segments[1];
    final widgetId = int.tryParse(uri.queryParameters['widget'] ?? '');

    try {
      switch ('$moduleId/$actionId') {
        case 'habits/toggle':
          await _toggleHabit(uri.queryParameters['id'], db);
          break;
        default:
          debugPrint('WidgetActionRouter: unknown action $moduleId/$actionId');
      }
    } catch (e) {
      debugPrint('WidgetActionRouter: action failed — $e');
    }

    if (widgetId != null) {
      await WidgetRenderService.refresh(widgetId, db);
    }
  }

  static Future<void> _toggleHabit(String? habitId, AppDatabase db) async {
    if (habitId == null) return;

    final habits = await db.habitsForWidget();
    LocalHabit? habit;
    for (final h in habits) {
      if (h.id == habitId) {
        habit = h;
        break;
      }
    }
    if (habit == null) return;
    final userId = habit.userId;

    final today = _fmt(DateTime.now());
    final logs = await db.habitLogsForDate(today);
    final isDone = logs.any((l) => l.habitId == habitId);

    if (isDone) {
      await db.deleteHabitLog(habitId, userId, today);
      await db.enqueueSyncOp('delete_habit_log', jsonEncode({
        'habit_id': habitId,
        'user_id': userId,
        'completed_at': today,
      }));
    } else {
      await db.upsertHabitLog(LocalHabitLogsCompanion(
        habitId: Value(habitId),
        userId: Value(userId),
        completedAt: Value(today),
        note: const Value(null),
        emoji: const Value(null),
        synced: const Value(false),
      ));
      await db.enqueueSyncOp('insert_habit_log', jsonEncode({
        'habit_id': habitId,
        'user_id': userId,
        'completed_at': today,
      }));
    }
  }

  static String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
