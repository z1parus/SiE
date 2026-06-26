import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../local/app_database.dart';
import '../models/goal_note.dart';
import 'connectivity_provider.dart';

const _uuid = Uuid();

/// Per-goal journal of quick notes. Offline-first: every mutation writes the
/// local Drift cache first, then pushes to Supabase when online (or enqueues a
/// sync op for later). Keyed by `goalId`.
final goalNotesProvider = AsyncNotifierProvider.autoDispose
    .family<GoalNotesNotifier, List<GoalNote>, String>(
  GoalNotesNotifier.new,
);

class GoalNotesNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<GoalNote>, String> {
  String get _goalId => arg;

  @override
  Future<List<GoalNote>> build(String goalId) async {
    ref.watch(connectivityProvider);
    final db = ref.read(appDatabaseProvider);
    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;

    if (isOnline) {
      try {
        final raw = await Supabase.instance.client
            .from('goal_notes')
            .select()
            .eq('goal_id', goalId)
            .order('updated_at', ascending: false);
        final notes = (raw as List)
            .map((r) => GoalNote.fromMap(r as Map<String, dynamic>))
            .toList();
        // Mirror to local cache so the journal is available offline.
        for (final n in notes) {
          await db.upsertGoalNote(_companion(n, synced: true));
        }
        return notes;
      } catch (_) {
        // fall through to local
      }
    }
    return _loadLocal(db, goalId);
  }

  Future<List<GoalNote>> _loadLocal(AppDatabase db, String goalId) async {
    final rows = await db.notesForGoal(goalId);
    return rows.map(_fromLocal).toList();
  }

  // ── Create ─────────────────────────────────────────────────────────────────

  Future<void> addNote({String? title, required String body}) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now();
    final cleanTitle = title?.trim();
    final note = GoalNote(
      id: _uuid.v4(),
      goalId: _goalId,
      userId: userId,
      title: (cleanTitle == null || cleanTitle.isEmpty) ? null : cleanTitle,
      body: body.trim(),
      createdAt: now,
      updatedAt: now,
    );

    // Optimistic insert at the top (notes are sorted newest-updated first).
    final current = state.valueOrNull ?? const [];
    state = AsyncData([note, ...current]);

    await db.upsertGoalNote(_companion(note, synced: false));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await client.from('goal_notes').insert(note.toUpsertJson());
        await db.markGoalNoteSynced(note.id);
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp('upsert_goal_note', jsonEncode(note.toUpsertJson()));
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  Future<void> updateNote(String id,
      {String? title, required String body}) async {
    final client = Supabase.instance.client;
    final db = ref.read(appDatabaseProvider);
    final current = state.valueOrNull;
    if (current == null) return;

    final existing = current.where((n) => n.id == id).firstOrNull;
    if (existing == null) return;

    final cleanTitle = title?.trim();
    final normalized = GoalNote(
      id: existing.id,
      goalId: existing.goalId,
      userId: existing.userId,
      title: (cleanTitle == null || cleanTitle.isEmpty) ? null : cleanTitle,
      body: body.trim(),
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );

    // Optimistic update + re-sort newest-first.
    final list = current.map((n) => n.id == id ? normalized : n).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = AsyncData(list);

    await db.upsertGoalNote(_companion(normalized, synced: false));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await client.from('goal_notes').update({
          'title': normalized.title,
          'body': normalized.body,
          'updated_at': normalized.updatedAt.toIso8601String(),
        }).eq('id', id);
        await db.markGoalNoteSynced(id);
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp(
        'upsert_goal_note', jsonEncode(normalized.toUpsertJson()));
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> deleteNote(String id) async {
    final client = Supabase.instance.client;
    final db = ref.read(appDatabaseProvider);
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncData(current.where((n) => n.id != id).toList());

    await db.deleteGoalNoteLocally(id);

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await client.from('goal_notes').delete().eq('id', id);
        await db.purgeGoalNote(id);
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp('delete_goal_note', jsonEncode({'id': id}));
  }

  // ── Mapping helpers ──────────────────────────────────────────────────────

  LocalGoalNotesCompanion _companion(GoalNote n, {required bool synced}) =>
      LocalGoalNotesCompanion(
        id: Value(n.id),
        goalId: Value(n.goalId),
        userId: Value(n.userId),
        title: Value(n.title),
        body: Value(n.body),
        createdAtMs: Value(n.createdAt.millisecondsSinceEpoch),
        updatedAtMs: Value(n.updatedAt.millisecondsSinceEpoch),
        synced: Value(synced),
        deletedLocally: const Value(false),
      );

  GoalNote _fromLocal(LocalGoalNote r) => GoalNote(
        id: r.id,
        goalId: r.goalId,
        userId: r.userId,
        title: (r.title?.trim().isEmpty ?? true) ? null : r.title!.trim(),
        body: r.body,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAtMs),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAtMs),
      );
}
