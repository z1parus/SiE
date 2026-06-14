import 'dart:convert' show jsonDecode;
import 'dart:ui' show Offset;
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_database.g.dart';

// ── Tables ─────────────────────────────────────────────────────────────────

@DataClassName('LocalHabit')
class LocalHabits extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get color => text().withDefault(const Constant('#00C8FF'))();
  TextColumn get icon => text().nullable()();
  BoolColumn get isPinned =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived =>
      boolean().withDefault(const Constant(false))();
  IntColumn get createdAtMs => integer()();
  BoolColumn get deletedLocally =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalHabitLog')
class LocalHabitLogs extends Table {
  TextColumn get habitId => text()();
  TextColumn get userId => text()();
  TextColumn get completedAt => text()();
  TextColumn get note => text().nullable()();
  TextColumn get emoji => text().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {habitId, userId, completedAt};
}

@DataClassName('LocalFocusSession')
class LocalFocusSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  IntColumn get durationSeconds => integer()();
  IntColumn get completedAtMs => integer()();
  IntColumn get xpAwarded => integer()();
  IntColumn get dpAwarded => integer()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalBreathingSession')
class LocalBreathingSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  IntColumn get durationSeconds => integer()();
  IntColumn get completedAtMs => integer()();
  IntColumn get xpAwarded => integer()();
  IntColumn get dpAwarded => integer()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// Stores the profile with pending offline deltas.
// cachedJson holds the full Supabase JSON snapshot for offline display.
@DataClassName('LocalProfileData')
class LocalProfiles extends Table {
  TextColumn get userId => text()();
  IntColumn get totalXp => integer().withDefault(const Constant(0))();
  IntColumn get designPoints =>
      integer().withDefault(const Constant(0))();
  IntColumn get pendingXp => integer().withDefault(const Constant(0))();
  IntColumn get pendingDp => integer().withDefault(const Constant(0))();
  TextColumn get cachedJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {userId};
}

@DataClassName('LocalRoutine')
class LocalRoutines extends Table {
  TextColumn get id          => text()();
  TextColumn get userId      => text()();
  TextColumn get routineType => text()(); // 'morning' | 'evening'
  IntColumn  get createdAtMs => integer()();
  BoolColumn get synced      => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalRoutineMember')
class LocalRoutineMembers extends Table {
  TextColumn get id        => text()();
  TextColumn get routineId => text()();
  TextColumn get habitId   => text()();
  IntColumn  get position  => integer().withDefault(const Constant(0))();
  BoolColumn get synced    => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PendingSyncOp')
class PendingSyncOps extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get operationType => text()();
  TextColumn get payload => text()();
  IntColumn get attempts =>
      integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  IntColumn get createdAtMs => integer()();
}

// ── Planning Tables ────────────────────────────────────────────────────────

@DataClassName('LocalGoal')
class LocalGoals extends Table {
  TextColumn get id             => text()();
  TextColumn get userId         => text()();
  TextColumn get name           => text()();
  TextColumn get description    => text().nullable()();
  IntColumn  get deadlineMs     => integer().nullable()();
  IntColumn  get priority       => integer().withDefault(const Constant(2))();
  TextColumn get status         => text().withDefault(const Constant('active'))();
  TextColumn get colorHex       => text().withDefault(const Constant('#5AADA0'))();
  RealColumn get progress       => real().withDefault(const Constant(0))();
  BoolColumn get synced         => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally => boolean().withDefault(const Constant(false))();
  IntColumn  get createdAtMs    => integer()();
  IntColumn  get updatedAtMs    => integer().nullable()();
  TextColumn get settingsJson      => text().nullable()();
  TextColumn get mapPositionsJson  => text().nullable()();
  BoolColumn get isPinned          => boolean().withDefault(const Constant(false))();
  BoolColumn get isShared          => boolean().withDefault(const Constant(false))();
  TextColumn get myRole            => text().nullable()();
  @override Set<Column> get primaryKey => {id};
}

@DataClassName('LocalSubGoal')
class LocalSubGoals extends Table {
  TextColumn get id               => text()();
  TextColumn get goalId           => text()();
  TextColumn get parentSubGoalId  => text().nullable()();
  TextColumn get name             => text()();
  BoolColumn get isCompleted      => boolean().withDefault(const Constant(false))();
  IntColumn  get orderIndex       => integer().withDefault(const Constant(0))();
  BoolColumn get synced           => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally   => boolean().withDefault(const Constant(false))();
  IntColumn  get createdAtMs      => integer()();
  @override Set<Column> get primaryKey => {id};
}

@DataClassName('LocalMilestone')
class LocalMilestones extends Table {
  TextColumn get id             => text()();
  TextColumn get goalId         => text()();
  TextColumn get name           => text()();
  IntColumn  get targetDateMs   => integer().nullable()();
  BoolColumn get isCompleted    => boolean().withDefault(const Constant(false))();
  BoolColumn get synced         => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally => boolean().withDefault(const Constant(false))();
  IntColumn  get createdAtMs    => integer()();
  // Stage 4: metric milestones
  TextColumn get kind           => text().withDefault(const Constant('binary'))();
  TextColumn get unit           => text().nullable()();
  RealColumn get startValue     => real().nullable()();
  RealColumn get targetValue    => real().nullable()();
  RealColumn get currentValue   => real().nullable()();
  TextColumn get direction      => text().withDefault(const Constant('up'))();
  @override Set<Column> get primaryKey => {id};
}

@DataClassName('LocalMilestoneLog')
class LocalMilestoneLogs extends Table {
  TextColumn get id           => text()();
  TextColumn get milestoneId  => text()();
  TextColumn get userId       => text()();
  RealColumn get value        => real()();
  IntColumn  get recordedAtMs => integer()();
  BoolColumn get synced       => boolean().withDefault(const Constant(false))();
  @override Set<Column> get primaryKey => {id};
}

@DataClassName('LocalGoalProgressSnapshot')
class LocalGoalProgressSnapshots extends Table {
  TextColumn get id             => text()();
  TextColumn get goalId         => text()();
  TextColumn get userId         => text()();
  RealColumn get progress       => real()();
  IntColumn  get completedTasks => integer().withDefault(const Constant(0))();
  IntColumn  get totalTasks     => integer().withDefault(const Constant(0))();
  IntColumn  get capturedAtMs   => integer()();
  // dayKey = capturedAt floored to local midnight (ms). Used to keep one
  // snapshot per goal per day (idempotent same-day re-capture).
  IntColumn  get dayKeyMs       => integer()();
  BoolColumn get synced         => boolean().withDefault(const Constant(false))();
  @override Set<Column> get primaryKey => {id};
}

@DataClassName('LocalMissionTemplate')
class LocalMissionTemplates extends Table {
  TextColumn get id             => text()();
  TextColumn get userId         => text().nullable()(); // null = system
  TextColumn get name           => text()();
  TextColumn get description    => text().nullable()();
  TextColumn get category       => text().nullable()();
  BoolColumn get isSystem       => boolean().withDefault(const Constant(false))();
  BoolColumn get isPublic       => boolean().withDefault(const Constant(false))();
  TextColumn get colorHex       => text().withDefault(const Constant('#5AADA0'))();
  TextColumn get structureJson  => text()();
  IntColumn  get createdAtMs    => integer()();
  BoolColumn get synced         => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally => boolean().withDefault(const Constant(false))();
  @override Set<Column> get primaryKey => {id};
}

@DataClassName('LocalPlanningTask')
class LocalPlanningTasks extends Table {
  TextColumn get id             => text()();
  TextColumn get subGoalId      => text()();
  TextColumn get userId         => text()();
  TextColumn get name           => text()();
  IntColumn  get weight         => integer().withDefault(const Constant(1))();
  BoolColumn get isCompleted    => boolean().withDefault(const Constant(false))();
  IntColumn  get completedAtMs  => integer().nullable()();
  IntColumn  get dueDateMs      => integer().nullable()();
  IntColumn  get orderIndex     => integer().withDefault(const Constant(0))();
  BoolColumn get synced         => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally => boolean().withDefault(const Constant(false))();
  IntColumn  get createdAtMs    => integer()();
  // Recurrence (stage 3): null = one-shot. Format: 'daily'|'weekly:1,3'|'monthly:15'|'every:N'.
  TextColumn get recurrenceRule     => text().nullable()();
  IntColumn  get recurrenceUntilMs  => integer().nullable()();
  TextColumn get recurrenceParentId => text().nullable()();
  @override Set<Column> get primaryKey => {id};
}

@DataClassName('LocalMissionMedal')
class LocalMissionMedals extends Table {
  TextColumn get id              => text()();
  TextColumn get userId          => text()();
  TextColumn get goalId          => text().withDefault(const Constant(''))();
  TextColumn get goalName        => text().withDefault(const Constant(''))();
  TextColumn get category        => text().withDefault(const Constant('none'))();
  IntColumn  get level           => integer()();
  TextColumn get name            => text()();
  IntColumn  get earnedAtMs      => integer()();
  IntColumn  get totalTaskWeight => integer().withDefault(const Constant(0))();
  IntColumn  get durationDays    => integer().withDefault(const Constant(0))();
  BoolColumn get synced          => boolean().withDefault(const Constant(false))();
  TextColumn get medalType       => text().withDefault(const Constant('goal'))();
  @override Set<Column> get primaryKey => {id};
}

@DataClassName('LocalGoalHabitLink')
class LocalGoalHabitLinks extends Table {
  TextColumn get id             => text()();
  TextColumn get goalId         => text()();
  TextColumn get habitId        => text()();
  RealColumn get boostValue     => real().withDefault(const Constant(0.5))();
  BoolColumn get synced         => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally => boolean().withDefault(const Constant(false))();
  IntColumn  get createdAtMs    => integer()();
  @override Set<Column> get primaryKey => {id};
}

// ── Meditation Tables ──────────────────────────────────────────────────────

@DataClassName('LocalMeditationSession')
class LocalMeditationSessions extends Table {
  TextColumn get id              => text()();
  TextColumn get userId          => text()();
  TextColumn get presetId        => text().nullable()();
  IntColumn  get durationSeconds => integer()();
  IntColumn  get completedAtMs   => integer()();
  IntColumn  get xpAwarded       => integer()();
  IntColumn  get dpAwarded       => integer()();
  IntColumn  get stateBefore     => integer().nullable()();
  IntColumn  get stateAfter      => integer().nullable()();
  BoolColumn get synced          => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalMeditationPreset')
class LocalMeditationPresets extends Table {
  TextColumn get id                      => text()();
  TextColumn get userId                  => text().nullable()();
  TextColumn get name                    => text()();
  TextColumn get description             => text().nullable()();
  BoolColumn get isSystem                => boolean().withDefault(const Constant(false))();
  BoolColumn get hasBreathing            => boolean().withDefault(const Constant(false))();
  TextColumn get breathingPatternId      => text().nullable()();
  IntColumn  get breathingDurationMin    => integer().withDefault(const Constant(5))();
  TextColumn get meditationType          => text().withDefault(const Constant('unguided'))();
  IntColumn  get meditationDurationMin   => integer().withDefault(const Constant(15))();
  TextColumn get baseMusicId             => text().nullable()();
  TextColumn get ambientFxId             => text().nullable()();
  RealColumn get baseVolume              => real().withDefault(const Constant(0.7))();
  RealColumn get ambientVolume           => real().withDefault(const Constant(0.5))();
  RealColumn get voiceVolume             => real().withDefault(const Constant(0.6))();
  TextColumn get affirmationPackId       => text().nullable()();
  IntColumn  get affirmationIntervalSecs => integer().withDefault(const Constant(30))();
  IntColumn  get createdAtMs             => integer()();
  BoolColumn get synced                  => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally          => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalMapPosition')
class LocalMapPositions extends Table {
  TextColumn get goalId => text()();
  TextColumn get nodeId => text()();
  RealColumn get x      => real()();
  RealColumn get y      => real()();

  @override
  Set<Column> get primaryKey => {goalId, nodeId};
}

// ── Database ───────────────────────────────────────────────────────────────

@DriftDatabase(tables: [
  LocalHabits,
  LocalHabitLogs,
  LocalFocusSessions,
  LocalBreathingSessions,
  LocalProfiles,
  LocalRoutines,
  LocalRoutineMembers,
  PendingSyncOps,
  LocalGoals,
  LocalSubGoals,
  LocalMilestones,
  LocalPlanningTasks,
  LocalGoalHabitLinks,
  LocalMissionMedals,
  LocalMeditationSessions,
  LocalMeditationPresets,
  LocalMapPositions,
  LocalMilestoneLogs,
  LocalGoalProgressSnapshots,
  LocalMissionTemplates,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 21;

  // Indexes for frequently-filtered foreign-key / user columns. Idempotent
  // (IF NOT EXISTS) so it can run on both fresh installs and upgrades.
  Future<void> _createIndexes(Migrator m) async {
    const stmts = [
      'CREATE INDEX IF NOT EXISTS idx_sub_goals_goal ON local_sub_goals(goal_id)',
      'CREATE INDEX IF NOT EXISTS idx_tasks_sub_goal ON local_planning_tasks(sub_goal_id)',
      'CREATE INDEX IF NOT EXISTS idx_tasks_user ON local_planning_tasks(user_id)',
      'CREATE INDEX IF NOT EXISTS idx_milestones_goal ON local_milestones(goal_id)',
      'CREATE INDEX IF NOT EXISTS idx_links_goal ON local_goal_habit_links(goal_id)',
      'CREATE INDEX IF NOT EXISTS idx_links_habit ON local_goal_habit_links(habit_id)',
      'CREATE INDEX IF NOT EXISTS idx_goals_user ON local_goals(user_id)',
      'CREATE INDEX IF NOT EXISTS idx_habit_logs_user ON local_habit_logs(user_id)',
      'CREATE INDEX IF NOT EXISTS idx_snapshots_goal ON local_goal_progress_snapshots(goal_id, captured_at_ms)',
    ];
    for (final s in stmts) {
      await m.issueCustomQuery(s, const []);
    }
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndexes(m);
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(localHabits, localHabits.isArchived);
      }
      if (from < 3) {
        await m.createTable(localRoutines);
        await m.createTable(localRoutineMembers);
      }
      if (from < 4) {
        await m.addColumn(localHabitLogs, localHabitLogs.note);
        await m.addColumn(localHabitLogs, localHabitLogs.emoji);
      }
      if (from < 5) {
        await m.addColumn(localHabits, localHabits.icon);
      }
      if (from < 6) {
        await m.createTable(localGoals);
        await m.createTable(localSubGoals);
        await m.createTable(localMilestones);
        await m.createTable(localPlanningTasks);
        await m.createTable(localGoalHabitLinks);
      }
      if (from < 7) {
        await m.issueCustomQuery(
            'ALTER TABLE local_goals ADD COLUMN updated_at_ms INTEGER', const []);
        await m.issueCustomQuery(
            'ALTER TABLE local_goal_habit_links ADD COLUMN boost_value REAL NOT NULL DEFAULT 0.5',
            const []);
      }
      if (from < 8) {
        await m.addColumn(localGoals, localGoals.settingsJson);
      }
      if (from < 9) {
        await m.createTable(localMissionMedals);
      }
      if (from < 10) {
        await m.addColumn(localGoals, localGoals.mapPositionsJson);
      }
      if (from < 11) {
        await m.addColumn(localPlanningTasks, localPlanningTasks.orderIndex);
      }
      if (from < 12) {
        await m.addColumn(localGoals, localGoals.isPinned);
      }
      if (from < 13) {
        await m.addColumn(localGoals, localGoals.isShared);
        await m.addColumn(localGoals, localGoals.myRole);
      }
      if (from < 14) {
        await m.addColumn(localMissionMedals, localMissionMedals.medalType);
      }
      if (from < 15) {
        await m.createTable(localMeditationSessions);
        await m.createTable(localMeditationPresets);
      }
      if (from < 16) {
        await _createIndexes(m);
      }
      if (from < 17) {
        await m.createTable(localMapPositions);
        // Lazy migration: populate from JSON blobs where present.
        // Each goal row's map_positions_json is read, parsed, and inserted into
        // the new table. The JSON column is then cleared to free space.
        final goals = await customSelect(
          'SELECT id, map_positions_json FROM local_goals '
          'WHERE map_positions_json IS NOT NULL AND map_positions_json != \'{}\'',
          readsFrom: {localGoals},
        ).get();
        for (final row in goals) {
          final id = row.read<String>('id');
          final raw = row.readNullable<String>('map_positions_json');
          if (raw == null || raw.isEmpty) continue;
          try {
            final map = jsonDecode(raw) as Map<String, dynamic>;
            await batch((b) {
              for (final entry in map.entries) {
                final pos = entry.value as Map<String, dynamic>;
                b.insert(
                  localMapPositions,
                  LocalMapPositionsCompanion(
                    goalId: Value(id),
                    nodeId: Value(entry.key),
                    x: Value((pos['x'] as num).toDouble()),
                    y: Value((pos['y'] as num).toDouble()),
                  ),
                  mode: InsertMode.insertOrReplace,
                );
              }
            });
          } catch (_) {}
        }
        await customUpdate(
          'UPDATE local_goals SET map_positions_json = NULL',
          updates: {localGoals},
        );
      }
      if (from < 18) {
        await m.addColumn(
            localPlanningTasks, localPlanningTasks.recurrenceRule);
        await m.addColumn(
            localPlanningTasks, localPlanningTasks.recurrenceUntilMs);
        await m.addColumn(
            localPlanningTasks, localPlanningTasks.recurrenceParentId);
      }
      if (from < 19) {
        await m.addColumn(localMilestones, localMilestones.kind);
        await m.addColumn(localMilestones, localMilestones.unit);
        await m.addColumn(localMilestones, localMilestones.startValue);
        await m.addColumn(localMilestones, localMilestones.targetValue);
        await m.addColumn(localMilestones, localMilestones.currentValue);
        await m.addColumn(localMilestones, localMilestones.direction);
        await m.createTable(localMilestoneLogs);
      }
      if (from < 20) {
        await m.createTable(localGoalProgressSnapshots);
        await m.issueCustomQuery(
            'CREATE INDEX IF NOT EXISTS idx_snapshots_goal '
            'ON local_goal_progress_snapshots(goal_id, captured_at_ms)',
            const []);
      }
      if (from < 21) {
        await m.createTable(localMissionTemplates);
      }
    },
  );

  // ── Habits ───────────────────────────────────────────────────────────────

  Future<List<LocalHabit>> habitsForUser(String userId) =>
      (select(localHabits)
            ..where((t) =>
                t.userId.equals(userId) &
                t.deletedLocally.equals(false) &
                t.isArchived.equals(false)))
          .get();

  Future<List<LocalHabit>> archivedHabitsForUser(String userId) =>
      (select(localHabits)
            ..where((t) =>
                t.userId.equals(userId) &
                t.deletedLocally.equals(false) &
                t.isArchived.equals(true)))
          .get();

  Future<void> upsertHabit(LocalHabitsCompanion row) =>
      into(localHabits).insertOnConflictUpdate(row);

  Future<void> markHabitDeleted(String habitId) =>
      (update(localHabits)..where((t) => t.id.equals(habitId))).write(
        const LocalHabitsCompanion(
            deletedLocally: Value(true), synced: Value(false)),
      );

  Future<List<LocalHabit>> unsyncedHabits(String userId) =>
      (select(localHabits)
            ..where((t) =>
                t.userId.equals(userId) & t.synced.equals(false)))
          .get();

  // ── Habit Logs ────────────────────────────────────────────────────────────

  Future<List<LocalHabitLog>> habitLogsForUser(
          String userId, String since) =>
      (select(localHabitLogs)
            ..where((t) =>
                t.userId.equals(userId) &
                t.completedAt.isBiggerOrEqualValue(since)))
          .get();

  Future<void> upsertHabitLog(LocalHabitLogsCompanion row) =>
      into(localHabitLogs).insertOnConflictUpdate(row);

  Future<void> deleteHabitLog(
          String habitId, String userId, String completedAt) =>
      (delete(localHabitLogs)
            ..where((t) =>
                t.habitId.equals(habitId) &
                t.userId.equals(userId) &
                t.completedAt.equals(completedAt)))
          .go();

  Future<List<LocalHabitLog>> unsyncedHabitLogs(String userId) =>
      (select(localHabitLogs)
            ..where((t) =>
                t.userId.equals(userId) & t.synced.equals(false)))
          .get();

  Future<void> markHabitLogSynced(
          String habitId, String userId, String completedAt) =>
      (update(localHabitLogs)
            ..where((t) =>
                t.habitId.equals(habitId) &
                t.userId.equals(userId) &
                t.completedAt.equals(completedAt)))
          .write(const LocalHabitLogsCompanion(synced: Value(true)));

  Future<void> updateHabitLogNote({
    required String habitId,
    required String userId,
    required String completedAt,
    String? note,
    String? emoji,
  }) =>
      (update(localHabitLogs)
            ..where((t) =>
                t.habitId.equals(habitId) &
                t.userId.equals(userId) &
                t.completedAt.equals(completedAt)))
          .write(LocalHabitLogsCompanion(
            note: Value(note),
            emoji: Value(emoji),
            synced: const Value(false),
          ));

  Future<List<LocalHabitLog>> habitLogsForHabit(
          String habitId, String userId) =>
      (select(localHabitLogs)
            ..where((t) =>
                t.habitId.equals(habitId) & t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm(
                expression: t.completedAt, mode: OrderingMode.desc)]))
          .get();

  // ── Focus Sessions ─────────────────────────────────────────────────────────

  Future<void> insertFocusSession(LocalFocusSessionsCompanion row) =>
      into(localFocusSessions).insertOnConflictUpdate(row);

  Future<List<LocalFocusSession>> unsyncedFocusSessions(String userId) =>
      (select(localFocusSessions)
            ..where((t) =>
                t.userId.equals(userId) & t.synced.equals(false)))
          .get();

  Future<void> markFocusSessionSynced(String id) =>
      (update(localFocusSessions)..where((t) => t.id.equals(id)))
          .write(const LocalFocusSessionsCompanion(synced: Value(true)));

  // ── Breathing Sessions ──────────────────────────────────────────────────────

  Future<void> insertBreathingSession(
          LocalBreathingSessionsCompanion row) =>
      into(localBreathingSessions).insertOnConflictUpdate(row);

  Future<void> markBreathingSessionSynced(String id) =>
      (update(localBreathingSessions)..where((t) => t.id.equals(id)))
          .write(
              const LocalBreathingSessionsCompanion(synced: Value(true)));

  // ── Bootcamp Activity Queries ─────────────────────────────────────────────

  /// Number of breathing sessions completed by [userId] on [dateStr] (YYYY-MM-DD).
  Future<int> countBreathingSessionsOnDate(
      String userId, String dateStr) async {
    final start   = DateTime.parse(dateStr);
    final startMs = start.millisecondsSinceEpoch;
    final endMs   = start
        .add(const Duration(days: 1))
        .millisecondsSinceEpoch;
    final rows = await (select(localBreathingSessions)
          ..where((t) =>
              t.userId.equals(userId) &
              t.completedAtMs.isBiggerOrEqualValue(startMs) &
              t.completedAtMs.isSmallerThanValue(endMs)))
        .get();
    return rows.length;
  }

  /// Number of focus sessions completed by [userId] on [dateStr] (YYYY-MM-DD).
  Future<int> countFocusSessionsOnDate(
      String userId, String dateStr) async {
    final start   = DateTime.parse(dateStr);
    final startMs = start.millisecondsSinceEpoch;
    final endMs   = start
        .add(const Duration(days: 1))
        .millisecondsSinceEpoch;
    final rows = await (select(localFocusSessions)
          ..where((t) =>
              t.userId.equals(userId) &
              t.completedAtMs.isBiggerOrEqualValue(startMs) &
              t.completedAtMs.isSmallerThanValue(endMs)))
        .get();
    return rows.length;
  }

  /// Whether [userId] has at least one habit log on [dateStr] (YYYY-MM-DD).
  Future<bool> hasHabitLogOnDate(String userId, String dateStr) async {
    final rows = await habitLogsForUser(userId, dateStr);
    return rows.any((r) => r.completedAt == dateStr);
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  Future<LocalProfileData?> getProfile(String userId) =>
      (select(localProfiles)..where((t) => t.userId.equals(userId)))
          .getSingleOrNull();

  Future<void> upsertProfile(LocalProfilesCompanion row) =>
      into(localProfiles).insertOnConflictUpdate(row);

  Future<void> applyXpDelta(String userId, int xp, int dp) async {
    final profile = await getProfile(userId);
    if (profile == null) return;
    await (update(localProfiles)
          ..where((t) => t.userId.equals(userId)))
        .write(LocalProfilesCompanion(
      totalXp: Value(profile.totalXp + xp),
      designPoints: Value(profile.designPoints + dp),
      pendingXp: Value(profile.pendingXp + xp),
      pendingDp: Value(profile.pendingDp + dp),
    ));
  }

  Future<void> clearPending(String userId) =>
      (update(localProfiles)..where((t) => t.userId.equals(userId)))
          .write(const LocalProfilesCompanion(
        pendingXp: Value(0),
        pendingDp: Value(0),
      ));

  // ── Routines ──────────────────────────────────────────────────────────────

  Future<List<LocalRoutine>> routinesForUser(String userId) =>
      (select(localRoutines)..where((t) => t.userId.equals(userId))).get();

  Future<List<LocalRoutineMember>> routineMembersForRoutine(String routineId) =>
      (select(localRoutineMembers)
            ..where((t) => t.routineId.equals(routineId))
            ..orderBy([(t) => OrderingTerm(expression: t.position)]))
          .get();

  Future<void> upsertRoutine(LocalRoutinesCompanion row) =>
      into(localRoutines).insertOnConflictUpdate(row);

  Future<void> updateRoutine(String id, LocalRoutinesCompanion changes) =>
      (update(localRoutines)..where((r) => r.id.equals(id))).write(changes);

  Future<void> upsertRoutineMember(LocalRoutineMembersCompanion row) =>
      into(localRoutineMembers).insertOnConflictUpdate(row);

  Future<void> updateRoutineMember(String id, LocalRoutineMembersCompanion changes) =>
      (update(localRoutineMembers)..where((m) => m.id.equals(id))).write(changes);

  Future<void> deleteRoutineMembers(String routineId) =>
      (delete(localRoutineMembers)
            ..where((t) => t.routineId.equals(routineId)))
          .go();

  Future<void> deleteRoutine(String routineId) =>
      (delete(localRoutines)..where((t) => t.id.equals(routineId))).go();

  // ── Sync Ops ──────────────────────────────────────────────────────────────

  Future<void> enqueueSyncOp(String operationType, String payload) =>
      into(pendingSyncOps).insert(PendingSyncOpsCompanion(
        operationType: Value(operationType),
        payload: Value(payload),
        createdAtMs: Value(DateTime.now().millisecondsSinceEpoch),
      ));

  Future<List<PendingSyncOp>> getPendingSyncOps() =>
      (select(pendingSyncOps)
            ..orderBy(
                [(t) => OrderingTerm(expression: t.id)]))
          .get();

  Future<void> deleteSyncOp(int id) =>
      (delete(pendingSyncOps)..where((t) => t.id.equals(id))).go();

  Future<void> incrementSyncAttempts(int id, String error) async {
    final op = await (select(pendingSyncOps)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (op == null) return;
    await (update(pendingSyncOps)..where((t) => t.id.equals(id))).write(
      PendingSyncOpsCompanion(
        attempts: Value(op.attempts + 1),
        lastError: Value(error),
      ),
    );
  }

  // ── Planning ──────────────────────────────────────────────────────────────

  Future<void> upsertGoal(LocalGoalsCompanion row) =>
      into(localGoals).insertOnConflictUpdate(row);

  Future<void> upsertSubGoal(LocalSubGoalsCompanion row) =>
      into(localSubGoals).insertOnConflictUpdate(row);

  Future<void> upsertMilestone(LocalMilestonesCompanion row) =>
      into(localMilestones).insertOnConflictUpdate(row);

  Future<void> upsertPlanningTask(LocalPlanningTasksCompanion row) =>
      into(localPlanningTasks).insertOnConflictUpdate(row);

  Future<void> updatePlanningTask(String id, LocalPlanningTasksCompanion changes) =>
      (update(localPlanningTasks)..where((t) => t.id.equals(id))).write(changes);

  Future<void> updateSubGoal(String id, LocalSubGoalsCompanion changes) =>
      (update(localSubGoals)..where((s) => s.id.equals(id))).write(changes);

  Future<void> updateGoal(String id, LocalGoalsCompanion changes) =>
      (update(localGoals)..where((g) => g.id.equals(id))).write(changes);

  Future<void> updateGoalSettings(String id, String? settingsJson) =>
      updateGoal(id, LocalGoalsCompanion(
        settingsJson: Value(settingsJson),
        synced: const Value(false),
      ));

  Future<void> updateGoalMapPositions(String id, String? json) =>
      updateGoal(id, LocalGoalsCompanion(
        mapPositionsJson: Value(json),
        synced: const Value(false),
      ));

  Future<void> upsertMapPositionsBatch(
      String goalId, Map<String, Offset> positions) =>
      batch((b) {
        for (final e in positions.entries) {
          b.insert(
            localMapPositions,
            LocalMapPositionsCompanion(
              goalId: Value(goalId),
              nodeId: Value(e.key),
              x: Value(e.value.dx),
              y: Value(e.value.dy),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });

  Future<Map<String, Offset>> mapPositionsForGoal(String goalId) async {
    final rows = await (select(localMapPositions)
          ..where((t) => t.goalId.equals(goalId)))
        .get();
    return {for (final r in rows) r.nodeId: Offset(r.x, r.y)};
  }

  Future<Map<String, Map<String, Offset>>> mapPositionsForGoals(
      List<String> goalIds) async {
    if (goalIds.isEmpty) return {};
    final rows = await (select(localMapPositions)
          ..where((t) => t.goalId.isIn(goalIds)))
        .get();
    final result = <String, Map<String, Offset>>{};
    for (final r in rows) {
      (result[r.goalId] ??= {})[r.nodeId] = Offset(r.x, r.y);
    }
    return result;
  }

  Future<void> deleteMapPositionsForGoal(String goalId) =>
      (delete(localMapPositions)..where((t) => t.goalId.equals(goalId))).go();

  Future<void> updateSubGoalOrderIndex(String id, int idx) =>
      (update(localSubGoals)..where((t) => t.id.equals(id)))
          .write(LocalSubGoalsCompanion(
              orderIndex: Value(idx), synced: const Value(false)));

  Future<void> updateTaskOrderIndex(String id, int idx) =>
      (update(localPlanningTasks)..where((t) => t.id.equals(id)))
          .write(LocalPlanningTasksCompanion(
              orderIndex: Value(idx), synced: const Value(false)));

  /// Writes new order indices for [idsInOrder] in a single transaction
  /// (one batch instead of N individual UPDATEs).
  Future<void> batchUpdateSubGoalOrder(List<String> idsInOrder) =>
      batch((b) {
        for (int i = 0; i < idsInOrder.length; i++) {
          b.update(
            localSubGoals,
            LocalSubGoalsCompanion(
                orderIndex: Value(i), synced: const Value(false)),
            where: (t) => t.id.equals(idsInOrder[i]),
          );
        }
      });

  Future<void> batchUpdateTaskOrder(List<String> idsInOrder) =>
      batch((b) {
        for (int i = 0; i < idsInOrder.length; i++) {
          b.update(
            localPlanningTasks,
            LocalPlanningTasksCompanion(
                orderIndex: Value(i), synced: const Value(false)),
            where: (t) => t.id.equals(idsInOrder[i]),
          );
        }
      });

  Future<void> upsertGoalHabitLink(LocalGoalHabitLinksCompanion row) =>
      into(localGoalHabitLinks).insertOnConflictUpdate(row);

  Future<List<LocalGoal>> goalsForUser(String uid) =>
      (select(localGoals)
            ..where((t) =>
                (t.userId.equals(uid) | t.isShared.equals(true)) &
                t.deletedLocally.equals(false))
            ..orderBy([
              (t) => OrderingTerm(expression: t.isPinned, mode: OrderingMode.desc),
              (t) => OrderingTerm(expression: t.createdAtMs),
            ]))
          .get();

  Future<void> cleanupRemovedSharedGoals(Set<String> currentServerIds) async {
    final shared = await (select(localGoals)
          ..where((t) => t.isShared.equals(true)))
        .get();
    for (final g in shared) {
      if (!currentServerIds.contains(g.id)) {
        await deleteGoalLocally(g.id);
      }
    }
  }

  Future<List<LocalSubGoal>> subGoalsForGoal(String goalId) =>
      (select(localSubGoals)
            ..where((t) =>
                t.goalId.equals(goalId) & t.deletedLocally.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
          .get();

  Future<List<LocalPlanningTask>> tasksForSubGoal(String subGoalId) =>
      (select(localPlanningTasks)
            ..where((t) =>
                t.subGoalId.equals(subGoalId) &
                t.deletedLocally.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
          .get();

  Future<List<LocalMilestone>> milestonesForGoal(String goalId) =>
      (select(localMilestones)
            ..where((t) =>
                t.goalId.equals(goalId) & t.deletedLocally.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAtMs)]))
          .get();

  Future<List<LocalGoalHabitLink>> habitLinksForGoal(String goalId) =>
      (select(localGoalHabitLinks)
            ..where((t) =>
                t.goalId.equals(goalId) & t.deletedLocally.equals(false)))
          .get();

  Future<List<LocalGoalHabitLink>> habitLinksForHabit(String habitId) =>
      (select(localGoalHabitLinks)
            ..where((t) =>
                t.habitId.equals(habitId) & t.deletedLocally.equals(false)))
          .get();

  // ── Batch planning loaders (avoid N+1 on offline load) ────────────────────

  Future<List<LocalSubGoal>> subGoalsForGoals(List<String> goalIds) =>
      (select(localSubGoals)
            ..where((t) =>
                t.goalId.isIn(goalIds) & t.deletedLocally.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
          .get();

  Future<List<LocalPlanningTask>> tasksForSubGoals(List<String> subGoalIds) =>
      (select(localPlanningTasks)
            ..where((t) =>
                t.subGoalId.isIn(subGoalIds) & t.deletedLocally.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
          .get();

  Future<List<LocalMilestone>> milestonesForGoals(List<String> goalIds) =>
      (select(localMilestones)
            ..where((t) =>
                t.goalId.isIn(goalIds) & t.deletedLocally.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAtMs)]))
          .get();

  Future<List<LocalGoalHabitLink>> habitLinksForGoals(List<String> goalIds) =>
      (select(localGoalHabitLinks)
            ..where((t) =>
                t.goalId.isIn(goalIds) & t.deletedLocally.equals(false)))
          .get();

  Future<void> deleteGoalLocally(String id) =>
      (update(localGoals)..where((t) => t.id.equals(id)))
          .write(const LocalGoalsCompanion(deletedLocally: Value(true)));

  Future<void> deleteSubGoalLocally(String id) =>
      (update(localSubGoals)..where((t) => t.id.equals(id)))
          .write(const LocalSubGoalsCompanion(deletedLocally: Value(true)));

  Future<void> deletePlanningTaskLocally(String id) =>
      (update(localPlanningTasks)..where((t) => t.id.equals(id)))
          .write(const LocalPlanningTasksCompanion(deletedLocally: Value(true)));

  Future<void> deleteMilestoneLocally(String id) =>
      (update(localMilestones)..where((t) => t.id.equals(id)))
          .write(const LocalMilestonesCompanion(deletedLocally: Value(true)));

  Future<void> deleteGoalHabitLinkLocally(String id) =>
      (update(localGoalHabitLinks)..where((t) => t.id.equals(id)))
          .write(const LocalGoalHabitLinksCompanion(deletedLocally: Value(true)));

  Future<LocalPlanningTask?> getPlanningTask(String id) =>
      (select(localPlanningTasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<LocalSubGoal?> getSubGoal(String id) =>
      (select(localSubGoals)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<LocalMilestone?> getMilestone(String id) =>
      (select(localMilestones)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> updateMilestoneCurrentValue(String milestoneId, double? value) =>
      (update(localMilestones)..where((t) => t.id.equals(milestoneId)))
          .write(LocalMilestonesCompanion(
            currentValue: Value(value),
            synced: const Value(false),
          ));

  // ── Milestone Logs ────────────────────────────────────────────────────────

  Future<void> insertMilestoneLog(LocalMilestoneLogsCompanion row) =>
      into(localMilestoneLogs).insertOnConflictUpdate(row);

  Future<List<LocalMilestoneLog>> logsForMilestone(String milestoneId) =>
      (select(localMilestoneLogs)
            ..where((t) => t.milestoneId.equals(milestoneId))
            ..orderBy([(t) => OrderingTerm(expression: t.recordedAtMs)]))
          .get();

  Future<void> deleteMilestoneLogLocally(String id) =>
      (delete(localMilestoneLogs)..where((t) => t.id.equals(id))).go();

  // ── Goal Progress Snapshots ───────────────────────────────────────────────

  Future<void> upsertGoalSnapshot(LocalGoalProgressSnapshotsCompanion row) =>
      into(localGoalProgressSnapshots).insertOnConflictUpdate(row);

  /// Whether a snapshot already exists for [goalId] on the local day [dayKeyMs].
  Future<bool> hasGoalSnapshotForDay(String goalId, int dayKeyMs) async {
    final row = await (select(localGoalProgressSnapshots)
          ..where((t) =>
              t.goalId.equals(goalId) & t.dayKeyMs.equals(dayKeyMs))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  Future<List<LocalGoalProgressSnapshot>> snapshotsForGoal(String goalId) =>
      (select(localGoalProgressSnapshots)
            ..where((t) => t.goalId.equals(goalId))
            ..orderBy([(t) => OrderingTerm(expression: t.capturedAtMs)]))
          .get();

  Future<List<LocalGoalProgressSnapshot>> unsyncedGoalSnapshots(
          String userId) =>
      (select(localGoalProgressSnapshots)
            ..where((t) =>
                t.userId.equals(userId) & t.synced.equals(false)))
          .get();

  Future<void> markGoalSnapshotSynced(String id) =>
      (update(localGoalProgressSnapshots)..where((t) => t.id.equals(id)))
          .write(const LocalGoalProgressSnapshotsCompanion(
              synced: Value(true)));

  // ── Mission Templates ─────────────────────────────────────────────────────

  Future<void> upsertMissionTemplate(LocalMissionTemplatesCompanion row) =>
      into(localMissionTemplates).insertOnConflictUpdate(row);

  Future<List<LocalMissionTemplate>> templatesForUser(String userId) =>
      (select(localMissionTemplates)
            ..where((t) =>
                (t.userId.equals(userId) | t.isSystem.equals(true)) &
                t.deletedLocally.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAtMs)]))
          .get();

  Future<void> deleteMissionTemplateLocally(String id) =>
      (update(localMissionTemplates)..where((t) => t.id.equals(id)))
          .write(const LocalMissionTemplatesCompanion(
              deletedLocally: Value(true)));

  Future<void> markMissionTemplateSynced(String id) =>
      (update(localMissionTemplates)..where((t) => t.id.equals(id)))
          .write(const LocalMissionTemplatesCompanion(synced: Value(true)));

  // ── Mission Medals ────────────────────────────────────────────────────────

  Future<void> upsertMedalLocally(LocalMissionMedalsCompanion row) =>
      into(localMissionMedals).insertOnConflictUpdate(row);

  Future<List<LocalMissionMedal>> medalsForUser(String userId) =>
      (select(localMissionMedals)
            ..where((t) => t.userId.equals(userId))
            ..orderBy(
                [(t) => OrderingTerm(expression: t.earnedAtMs, mode: OrderingMode.desc)]))
          .get();

  Future<void> markMedalSynced(String id) =>
      (update(localMissionMedals)..where((t) => t.id.equals(id)))
          .write(const LocalMissionMedalsCompanion(synced: Value(true)));

  // ── Meditation Sessions ───────────────────────────────────────────────────

  Future<void> insertMeditationSession(LocalMeditationSessionsCompanion row) =>
      into(localMeditationSessions).insertOnConflictUpdate(row);

  Future<List<LocalMeditationSession>> unsyncedMeditationSessions(
          String userId) =>
      (select(localMeditationSessions)
            ..where((t) =>
                t.userId.equals(userId) & t.synced.equals(false)))
          .get();

  Future<void> markMeditationSessionSynced(String id) =>
      (update(localMeditationSessions)..where((t) => t.id.equals(id)))
          .write(
              const LocalMeditationSessionsCompanion(synced: Value(true)));

  Future<int> meditationSecondsThisWeek(String userId) async {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final startMs = startOfWeek.millisecondsSinceEpoch;
    final rows = await (select(localMeditationSessions)
          ..where((t) =>
              t.userId.equals(userId) &
              t.completedAtMs.isBiggerOrEqualValue(startMs)))
        .get();
    return rows.fold<int>(0, (sum, r) => sum + r.durationSeconds);
  }

  // ── Meditation Presets ────────────────────────────────────────────────────

  Future<void> upsertMeditationPreset(LocalMeditationPresetsCompanion row) =>
      into(localMeditationPresets).insertOnConflictUpdate(row);

  Future<List<LocalMeditationPreset>> presetsForUser(String userId) =>
      (select(localMeditationPresets)
            ..where((t) =>
                (t.userId.equals(userId) | t.isSystem.equals(true)) &
                t.deletedLocally.equals(false)))
          .get();

  Future<void> deletePresetLocally(String id) =>
      (update(localMeditationPresets)..where((t) => t.id.equals(id)))
          .write(const LocalMeditationPresetsCompanion(
              deletedLocally: Value(true)));

  Future<Set<String>> unsyncedPlanningIds() async {
    final goals = await (select(localGoals)..where((t) => t.synced.equals(false))).get();
    final subs = await (select(localSubGoals)..where((t) => t.synced.equals(false))).get();
    final tasks = await (select(localPlanningTasks)..where((t) => t.synced.equals(false))).get();
    final ms = await (select(localMilestones)..where((t) => t.synced.equals(false))).get();
    final links = await (select(localGoalHabitLinks)..where((t) => t.synced.equals(false))).get();
    return {
      for (final g in goals) g.id,
      for (final s in subs) s.id,
      for (final t in tasks) t.id,
      for (final m in ms) m.id,
      for (final l in links) l.id,
    };
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// ── Connection ─────────────────────────────────────────────────────────────────

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'sie_local',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
