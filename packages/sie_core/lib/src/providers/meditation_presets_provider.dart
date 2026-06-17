import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../local/app_database.dart';
import '../models/meditation_preset.dart';
import '../models/affirmation_pack.dart';
import 'auth_state_provider.dart';
import 'connectivity_provider.dart';

const _uuid = Uuid();

class MeditationPresetsState {
  final List<MeditationPreset> presets;
  final List<AffirmationPack> affirmationPacks;

  const MeditationPresetsState({
    this.presets = const [],
    this.affirmationPacks = const [],
  });

  MeditationPresetsState copyWith({
    List<MeditationPreset>? presets,
    List<AffirmationPack>? affirmationPacks,
  }) =>
      MeditationPresetsState(
        presets: presets ?? this.presets,
        affirmationPacks: affirmationPacks ?? this.affirmationPacks,
      );
}

class MeditationPresetsNotifier
    extends AutoDisposeAsyncNotifier<MeditationPresetsState> {
  AppDatabase get _db => ref.read(appDatabaseProvider);

  @override
  Future<MeditationPresetsState> build() async {
    ref.watch(authStateProvider);
    return _load();
  }

  Future<MeditationPresetsState> _load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const MeditationPresetsState();

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;

    if (isOnline) {
      try {
        final presetsRaw = await Supabase.instance.client
            .from('meditation_presets')
            .select()
            .or('user_id.eq.$userId,is_system.eq.true')
            .order('created_at');

        final packsRaw = await Supabase.instance.client
            .from('affirmation_packs')
            .select()
            .or('user_id.eq.$userId,is_custom.eq.false');

        final presets = (presetsRaw as List)
            .map((r) => MeditationPreset.fromMap(r as Map<String, dynamic>))
            .toList();
        final packs = (packsRaw as List)
            .map((r) => AffirmationPack.fromMap(r as Map<String, dynamic>))
            .toList();

        // Cache presets locally
        for (final p in presets) {
          await _db.upsertMeditationPreset(_presetToCompanion(p));
        }

        return MeditationPresetsState(presets: presets, affirmationPacks: packs);
      } catch (_) {}
    }

    // Offline fallback
    final local = await _db.presetsForUser(userId);
    final presets = local.map(_presetFromLocal).toList();
    return MeditationPresetsState(presets: presets);
  }

  Future<MeditationPreset> createPreset(MeditationPreset preset) async {
    final newPreset = preset.copyWith(
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      isSystem: false,
    );
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return newPreset;

    await _db.upsertMeditationPreset(_presetToCompanion(newPreset));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await Supabase.instance.client
            .from('meditation_presets')
            .insert(newPreset.toMap());
      } catch (_) {}
    }

    final cur = state.valueOrNull ?? const MeditationPresetsState();
    state = AsyncData(
        cur.copyWith(presets: [...cur.presets, newPreset]));
    return newPreset;
  }

  Future<void> updatePreset(MeditationPreset updated) async {
    if (updated.isSystem) return;

    await _db.upsertMeditationPreset(
        _presetToCompanion(updated).copyWith(synced: const Value(false)));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await Supabase.instance.client
            .from('meditation_presets')
            .update(updated.toMap())
            .eq('id', updated.id);
      } catch (_) {}
    }

    final cur = state.valueOrNull ?? const MeditationPresetsState();
    state = AsyncData(cur.copyWith(
      presets: cur.presets.map((p) => p.id == updated.id ? updated : p).toList(),
    ));
  }

  Future<void> deletePreset(String id) async {
    await _db.deletePresetLocally(id);

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await Supabase.instance.client
            .from('meditation_presets')
            .delete()
            .eq('id', id);
      } catch (_) {}
    }

    final cur = state.valueOrNull ?? const MeditationPresetsState();
    state = AsyncData(
        cur.copyWith(presets: cur.presets.where((p) => p.id != id).toList()));
  }

  Future<MeditationPreset> duplicatePreset(
      MeditationPreset source, String newName) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final dup = source.copyWith(
      id: _uuid.v4(),
      userId: userId,
      name: newName,
      isSystem: false,
      createdAt: DateTime.now(),
    );
    return createPreset(dup);
  }

  // ── Local ↔ Model converters ─────────────────────────────────────────────

  LocalMeditationPresetsCompanion _presetToCompanion(MeditationPreset p) =>
      LocalMeditationPresetsCompanion(
        id: Value(p.id),
        userId: Value(p.userId),
        name: Value(p.name),
        description: Value(p.description),
        isSystem: Value(p.isSystem),
        hasBreathing: Value(p.hasBreathing),
        breathingPatternId: Value(p.breathingPatternId),
        breathingDurationMin: Value(p.breathingDurationMin),
        meditationType: Value(p.meditationType),
        meditationDurationMin: Value(p.meditationDurationMin),
        baseMusicId: Value(p.baseMusicId),
        ambientFxId: Value(p.ambientFxId),
        baseVolume: Value(p.baseVolume),
        ambientVolume: Value(p.ambientVolume),
        voiceVolume: Value(p.voiceVolume),
        affirmationPackId: Value(p.affirmationPackId),
        affirmationIntervalSecs: Value(p.affirmationIntervalSecs),
        createdAtMs: Value(p.createdAt.millisecondsSinceEpoch),
        synced: const Value(true),
        deletedLocally: const Value(false),
      );

  MeditationPreset _presetFromLocal(LocalMeditationPreset r) =>
      MeditationPreset(
        id: r.id,
        userId: r.userId,
        name: r.name,
        description: r.description,
        isSystem: r.isSystem,
        hasBreathing: r.hasBreathing,
        breathingPatternId: r.breathingPatternId,
        breathingDurationMin: r.breathingDurationMin,
        meditationType: r.meditationType,
        meditationDurationMin: r.meditationDurationMin,
        baseMusicId: r.baseMusicId,
        ambientFxId: r.ambientFxId,
        baseVolume: r.baseVolume,
        ambientVolume: r.ambientVolume,
        voiceVolume: r.voiceVolume,
        affirmationPackId: r.affirmationPackId,
        affirmationIntervalSecs: r.affirmationIntervalSecs,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAtMs),
      );
}

final meditationPresetsProvider = AutoDisposeAsyncNotifierProvider<
    MeditationPresetsNotifier, MeditationPresetsState>(
  MeditationPresetsNotifier.new,
);
