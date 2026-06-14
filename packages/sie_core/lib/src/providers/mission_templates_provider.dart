import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../local/app_database.dart';
import '../models/mission_template.dart';
import '../models/planning.dart';
import 'auth_state_provider.dart';
import 'connectivity_provider.dart';

const _uuid = Uuid();

/// System + user mission templates ("blueprints"). Mirrors the
/// meditation_presets pattern: online-first load with local Drift fallback.
class MissionTemplatesNotifier
    extends AutoDisposeAsyncNotifier<List<MissionTemplate>> {
  AppDatabase get _db => ref.read(appDatabaseProvider);

  @override
  Future<List<MissionTemplate>> build() async {
    ref.watch(authStateProvider);
    return _load();
  }

  Future<List<MissionTemplate>> _load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const [];

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        final raw = await Supabase.instance.client
            .from('mission_templates')
            .select()
            .or('user_id.eq.$userId,is_system.eq.true')
            .order('created_at');
        final templates = (raw as List)
            .map((r) => MissionTemplate.fromJson(r as Map<String, dynamic>))
            .toList();
        for (final t in templates) {
          await _db.upsertMissionTemplate(_toCompanion(t, synced: true));
        }
        return templates;
      } catch (_) {}
    }

    final local = await _db.templatesForUser(userId);
    return local.map(_fromLocal).toList();
  }

  /// Persists a brand-new user template (used by "save as template" and by the
  /// AI→template shortcut).
  Future<MissionTemplate> createTemplate({
    required String name,
    String? description,
    GoalCategory? category,
    String colorHex = '#5AADA0',
    required TemplateStructure structure,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final template = MissionTemplate(
      id: _uuid.v4(),
      userId: userId,
      name: name,
      description: description,
      category: category,
      isSystem: false,
      colorHex: colorHex,
      structure: structure,
      createdAt: DateTime.now(),
    );
    if (userId == null) return template;

    await _db.upsertMissionTemplate(_toCompanion(template, synced: false));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await Supabase.instance.client
            .from('mission_templates')
            .insert(template.toInsertJson());
        await _db.markMissionTemplateSynced(template.id);
      } catch (_) {
        await _db.enqueueSyncOp(
            'insert_mission_template', jsonEncode(template.toInsertJson()));
      }
    } else {
      await _db.enqueueSyncOp(
          'insert_mission_template', jsonEncode(template.toInsertJson()));
    }

    final cur = state.valueOrNull ?? const <MissionTemplate>[];
    state = AsyncData([...cur, template]);
    return template;
  }

  Future<void> deleteTemplate(String id) async {
    await _db.deleteMissionTemplateLocally(id);

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await Supabase.instance.client
            .from('mission_templates')
            .delete()
            .eq('id', id);
      } catch (_) {}
    }

    final cur = state.valueOrNull ?? const <MissionTemplate>[];
    state = AsyncData(cur.where((t) => t.id != id).toList());
  }

  // ── Converters ────────────────────────────────────────────────────────────

  LocalMissionTemplatesCompanion _toCompanion(MissionTemplate t,
          {required bool synced}) =>
      LocalMissionTemplatesCompanion(
        id: Value(t.id),
        userId: Value(t.userId),
        name: Value(t.name),
        description: Value(t.description),
        category: Value(t.category?.name),
        isSystem: Value(t.isSystem),
        isPublic: Value(t.isPublic),
        colorHex: Value(t.colorHex),
        structureJson: Value(t.structureJsonString),
        createdAtMs: Value(t.createdAt.millisecondsSinceEpoch),
        synced: Value(synced),
        deletedLocally: const Value(false),
      );

  MissionTemplate _fromLocal(LocalMissionTemplate r) =>
      MissionTemplate.fromJson({
        'id': r.id,
        'user_id': r.userId,
        'name': r.name,
        'description': r.description,
        'category': r.category,
        'is_system': r.isSystem,
        'is_public': r.isPublic,
        'color_hex': r.colorHex,
        'structure_json': r.structureJson,
        'created_at':
            DateTime.fromMillisecondsSinceEpoch(r.createdAtMs).toIso8601String(),
      });
}

final missionTemplatesProvider = AutoDisposeAsyncNotifierProvider<
    MissionTemplatesNotifier, List<MissionTemplate>>(
  MissionTemplatesNotifier.new,
);
