import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../local/app_database.dart';
import '../models/breathing_sequence.dart';
import 'connectivity_provider.dart';

const _uuid = Uuid();

/// All breathing round-sequences the current user has saved. Offline-first:
/// every mutation writes the local Drift cache first, then pushes to Supabase
/// when online (or enqueues a sync op for later).
final breathingSequencesProvider = AsyncNotifierProvider.autoDispose<
    BreathingSequencesNotifier, List<BreathingSequence>>(
  BreathingSequencesNotifier.new,
);

class BreathingSequencesNotifier
    extends AutoDisposeAsyncNotifier<List<BreathingSequence>> {
  @override
  Future<List<BreathingSequence>> build() async {
    ref.watch(connectivityProvider);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    final db = ref.read(appDatabaseProvider);
    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;

    if (isOnline) {
      try {
        final raw = await client
            .from('breathing_sequences')
            .select()
            .eq('user_id', userId)
            .order('updated_at', ascending: false);
        final seqs = (raw as List)
            .map((r) => BreathingSequence.fromMap(r as Map<String, dynamic>))
            .toList();
        for (final s in seqs) {
          await db.upsertBreathingSequence(_companion(s, synced: true));
        }
        return seqs;
      } catch (_) {
        // fall through to local cache
      }
    }
    return _loadLocal(db, userId);
  }

  Future<List<BreathingSequence>> _loadLocal(
      AppDatabase db, String userId) async {
    final rows = await db.breathingSequencesForUser(userId);
    return rows.map(_fromLocal).toList();
  }

  // ── Create ─────────────────────────────────────────────────────────────────

  Future<BreathingSequence?> createSequence({
    required String name,
    required List<BreathingRound> rounds,
  }) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;

    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now();
    final seq = BreathingSequence(
      id: _uuid.v4(),
      userId: userId,
      name: name.trim().isEmpty ? 'Без названия' : name.trim(),
      rounds: rounds,
      createdAt: now,
      updatedAt: now,
    );

    final current = state.valueOrNull ?? const [];
    state = AsyncData([seq, ...current]);

    await db.upsertBreathingSequence(_companion(seq, synced: false));
    await _push('upsert_breathing_sequence', seq);
    return seq;
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  Future<void> updateSequence(BreathingSequence seq) async {
    final db = ref.read(appDatabaseProvider);
    final updated = seq.copyWith(updatedAt: DateTime.now());

    final current = state.valueOrNull ?? const [];
    final list = current.map((s) => s.id == seq.id ? updated : s).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = AsyncData(list);

    await db.upsertBreathingSequence(_companion(updated, synced: false));
    await _push('upsert_breathing_sequence', updated);
  }

  // ── Duplicate ────────────────────────────────────────────────────────────

  Future<void> duplicateSequence(String id) async {
    final current = state.valueOrNull ?? const [];
    final src = current.where((s) => s.id == id).firstOrNull;
    if (src == null) return;
    await createSequence(name: '${src.name} (копия)', rounds: src.rounds);
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> deleteSequence(String id) async {
    final client = Supabase.instance.client;
    final db = ref.read(appDatabaseProvider);
    final current = state.valueOrNull ?? const [];
    state = AsyncData(current.where((s) => s.id != id).toList());

    await db.deleteBreathingSequenceLocally(id);

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await client.from('breathing_sequences').delete().eq('id', id);
        await db.purgeBreathingSequence(id);
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp('delete_breathing_sequence', jsonEncode({'id': id}));
  }

  // ── Shared push helper ─────────────────────────────────────────────────────

  Future<void> _push(String op, BreathingSequence seq) async {
    final client = Supabase.instance.client;
    final db = ref.read(appDatabaseProvider);
    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await client
            .from('breathing_sequences')
            .upsert(seq.toUpsertJson(), onConflict: 'id');
        await db.markBreathingSequenceSynced(seq.id);
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp(op, jsonEncode(seq.toUpsertJson()));
  }

  // ── Mapping helpers ──────────────────────────────────────────────────────

  LocalBreathingSequencesCompanion _companion(BreathingSequence s,
          {required bool synced}) =>
      LocalBreathingSequencesCompanion(
        id: Value(s.id),
        userId: Value(s.userId),
        name: Value(s.name),
        roundsJson: Value(s.roundsJsonString()),
        createdAtMs: Value(s.createdAt.millisecondsSinceEpoch),
        updatedAtMs: Value(s.updatedAt.millisecondsSinceEpoch),
        synced: Value(synced),
        deletedLocally: const Value(false),
      );

  BreathingSequence _fromLocal(LocalBreathingSequence r) => BreathingSequence(
        id: r.id,
        userId: r.userId,
        name: r.name,
        rounds: BreathingSequence.roundsFromRaw(r.roundsJson),
        createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAtMs),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAtMs),
      );
}
