import 'dart:convert' show jsonDecode;
import 'dart:ui' show Offset;
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart' show debugPrint;
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
  // Stage 1 (habits): flexible schedule descriptor — 'daily' | 'weekdays:…'
  // | 'weekly:N' | 'interval:N'. Defaults to legacy daily behaviour.
  TextColumn get schedule =>
      text().withDefault(const Constant('daily'))();
  // Stage 2 (habits): measurement type — 'binary' | 'count' | 'duration'.
  TextColumn get kind => text().withDefault(const Constant('binary'))();
  RealColumn get targetValue => real().nullable()();
  TextColumn get unit => text().nullable()();
  RealColumn get step => real().nullable()();
  // Stage 3 (habits): optional reminder time as 'HH:mm' string (null = off).
  TextColumn get reminderTime => text().nullable()();
  // Stage 6: life area ('health'|'mind'|'productivity'|'relationships'|'finance'|'spirit'|null)
  TextColumn get area => text().nullable()();
  // Stage 7: polarity — 'build' (default) | 'avoid' (break a bad habit).
  TextColumn get polarity =>
      text().withDefault(const Constant('build'))();
  // Stage 7: highest abstinence milestone (days) already rewarded; resets on lapse.
  IntColumn get lastAbstinenceMilestone =>
      integer().withDefault(const Constant(0))();
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
  // Stage 2: accumulated value for the day (1 for binary).
  RealColumn get value => real().withDefault(const Constant(1))();
  // Stage 5: 'done' (default) | 'rest' (explicit rest day, doesn't break streak).
  TextColumn get entryType => text().withDefault(const Constant('done'))();
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
  // Stage 7: optional link to a planning task / goal this session worked on.
  TextColumn get taskId => text().nullable()();
  TextColumn get goalId => text().nullable()();

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
  TextColumn get routineType => text()(); // 'morning' | 'evening' | 'stack'
  // Stage 8b: named stacks + anchor cue (null for legacy morning/evening).
  TextColumn get name        => text().nullable()();
  TextColumn get anchorCue   => text().nullable()();
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

@DataClassName('LocalWeeklyReview')
class LocalWeeklyReviews extends Table {
  TextColumn get id             => text()();
  TextColumn get userId         => text()();
  IntColumn  get weekStartMs    => integer()();
  IntColumn  get completedTasks => integer().withDefault(const Constant(0))();
  TextColumn get notes          => text().nullable()();
  TextColumn get focusGoalIdsJson => text().withDefault(const Constant('[]'))();
  IntColumn  get createdAtMs    => integer()();
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

@DataClassName('LocalTaskDependency')
class LocalTaskDependencies extends Table {
  TextColumn get taskId          => text()();
  TextColumn get dependsOnTaskId => text()();
  TextColumn get goalId          => text()();
  BoolColumn get synced          => boolean().withDefault(const Constant(false))();
  IntColumn  get createdAtMs     => integer()();
  @override Set<Column> get primaryKey => {taskId, dependsOnTaskId};
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

/// Map-native elements (TacticalMapEvolution Stage 1): notes/labels now,
/// image cards/groups/connectors later. Polymorphic via [kind].
@DataClassName('LocalMapElement')
class LocalMapElements extends Table {
  TextColumn get id             => text()();
  TextColumn get goalId         => text()();
  TextColumn get kind           => text()();            // note|label|image|group|connector
  RealColumn get x              => real()();
  RealColumn get y              => real()();
  RealColumn get w              => real().nullable()();
  RealColumn get h              => real().nullable()();
  IntColumn  get zIndex         => integer().withDefault(const Constant(0))();
  TextColumn get content        => text().nullable()();
  TextColumn get colorHex       => text().nullable()();
  TextColumn get mediaUrl       => text().nullable()();
  TextColumn get fromRef        => text().nullable()();
  TextColumn get toRef          => text().nullable()();
  TextColumn get styleJsonText  => text().nullable()();   // Stage 4 connector style JSON
  TextColumn get createdBy      => text()();
  IntColumn  get createdAtMs    => integer()();
  IntColumn  get updatedAtMs    => integer().nullable()();
  BoolColumn get synced         => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally => boolean().withDefault(const Constant(false))();
  @override Set<Column> get primaryKey => {id};
}

// Stage 5: node assignees (task / sub-goal ↔ user).
@DataClassName('LocalTaskAssignee')
class LocalTaskAssignees extends Table {
  TextColumn get taskId      => text()();
  TextColumn get userId      => text()();
  TextColumn get goalId      => text()();
  TextColumn get assignedBy  => text().nullable()();
  IntColumn  get createdAtMs => integer()();
  BoolColumn get synced      => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally => boolean().withDefault(const Constant(false))();
  @override Set<Column> get primaryKey => {taskId, userId};
}

@DataClassName('LocalSubGoalAssignee')
class LocalSubGoalAssignees extends Table {
  TextColumn get subGoalId   => text()();
  TextColumn get userId      => text()();
  TextColumn get goalId      => text()();
  TextColumn get assignedBy  => text().nullable()();
  IntColumn  get createdAtMs => integer()();
  BoolColumn get synced      => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally => boolean().withDefault(const Constant(false))();
  @override Set<Column> get primaryKey => {subGoalId, userId};
}

// Stage 2: node attachments (images/files attached to plan nodes).
@DataClassName('LocalNodeAttachment')
class LocalNodeAttachments extends Table {
  TextColumn get id           => text()();
  TextColumn get goalId       => text()();
  TextColumn get nodeType     => text()();      // goal|subgoal|task|milestone
  TextColumn get nodeId       => text()();
  TextColumn get storagePath  => text()();      // path in goal-attachments bucket
  TextColumn get localPath    => text().nullable()(); // offline cache path
  TextColumn get fileName     => text()();
  TextColumn get mimeType     => text()();
  IntColumn  get sizeBytes    => integer().withDefault(const Constant(0))();
  TextColumn get uploadedBy   => text()();
  IntColumn  get createdAtMs  => integer()();
  BoolColumn get synced          => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally  => boolean().withDefault(const Constant(false))();
  @override Set<Column> get primaryKey => {id};
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
  LocalTaskDependencies,
  LocalWeeklyReviews,
  LocalMapElements,
  LocalNodeAttachments,
  LocalTaskAssignees,
  LocalSubGoalAssignees,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 35;

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
      'CREATE INDEX IF NOT EXISTS idx_map_elements_goal ON local_map_elements(goal_id)',
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
      try {
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
      if (from < 22) {
        await m.addColumn(localFocusSessions, localFocusSessions.taskId);
        await m.addColumn(localFocusSessions, localFocusSessions.goalId);
        await m.issueCustomQuery(
            'CREATE INDEX IF NOT EXISTS idx_focus_goal '
            'ON local_focus_sessions(goal_id)',
            const []);
      }
      if (from < 23) {
        await m.createTable(localTaskDependencies);
        await m.issueCustomQuery(
            'CREATE INDEX IF NOT EXISTS idx_task_deps_goal '
            'ON local_task_dependencies(goal_id)',
            const []);
      }
      if (from < 24) {
        await m.createTable(localWeeklyReviews);
      }
      if (from < 25) {
        await m.addColumn(localHabits, localHabits.schedule);
      }
      if (from < 26) {
        await m.addColumn(localHabits, localHabits.kind);
        await m.addColumn(localHabits, localHabits.targetValue);
        await m.addColumn(localHabits, localHabits.unit);
        await m.addColumn(localHabits, localHabits.step);
        // value column has a DEFAULT of 1, so existing rows backfill to 1.
        await m.addColumn(localHabitLogs, localHabitLogs.value);
      }
      if (from < 27) {
        await m.addColumn(localHabits, localHabits.reminderTime);
      }
      if (from < 28) {
        await m.addColumn(localHabitLogs, localHabitLogs.entryType);
      }
      if (from < 29) {
        await m.addColumn(localHabits, localHabits.area);
      }
      if (from < 30) {
        await m.addColumn(localHabits, localHabits.polarity);
        await m.addColumn(localHabits, localHabits.lastAbstinenceMilestone);
      }
      if (from < 31) {
        await m.addColumn(localRoutines, localRoutines.name);
        await m.addColumn(localRoutines, localRoutines.anchorCue);
      }
      if (from < 32) {
        await m.createTable(localMapElements);
      }
      if (from < 33) {
        await m.addColumn(localMapElements, localMapElements.styleJsonText);
      }
      if (from < 34) {
        await m.createTable(localNodeAttachments);
        await m.issueCustomQuery(
            'CREATE INDEX IF NOT EXISTS idx_attach_node_id '
            'ON local_node_attachments(node_id)',
            const []);
      }
      if (from < 35) {
        await m.createTable(localTaskAssignees);
        await m.createTable(localSubGoalAssignees);
        await m.issueCustomQuery(
            'CREATE INDEX IF NOT EXISTS idx_task_assignees_goal '
            'ON local_task_assignees(goal_id)',
            const []);
        await m.issueCustomQuery(
            'CREATE INDEX IF NOT EXISTS idx_sub_goal_assignees_goal '
            'ON local_sub_goal_assignees(goal_id)',
            const []);
      }
      } catch (e) {
        // Migration failed (e.g. table/column already exists from a dev build
        // that didn't bump schemaVersion). The local DB is a pure Supabase cache
        // — safe to recreate. Data re-syncs on next online load.
        debugPrint('SiE DB: migration $from→$to failed ($e) — recreating schema');
        await m.issueCustomQuery('PRAGMA foreign_keys = OFF');
        for (final table in allTables.toList()) {
          await m.drop(table);
        }
        await m.issueCustomQuery('PRAGMA foreign_keys = ON');
        await m.createAll();
        await _createIndexes(m);
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

  // Stage 7: persist the highest abstinence milestone already rewarded.
  Future<void> setAbstinenceMilestone(String habitId, int milestone) =>
      (update(localHabits)..where((t) => t.id.equals(habitId))).write(
        LocalHabitsCompanion(lastAbstinenceMilestone: Value(milestone)),
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

  /// Stage 2 — add [delta] to a day's accumulated value (clamp ≥ 0).
  /// Returns the new accumulated value.
  Future<double> incrementHabitLogValue({
    required String habitId,
    required String userId,
    required String completedAt,
    required double delta,
  }) async {
    // Read existing row (if any).
    final existing = await (select(localHabitLogs)
          ..where((t) =>
              t.habitId.equals(habitId) &
              t.userId.equals(userId) &
              t.completedAt.equals(completedAt)))
        .getSingleOrNull();
    final prev = existing?.value ?? 0;
    final next = (prev + delta).clamp(0.0, double.infinity);
    await into(localHabitLogs).insertOnConflictUpdate(LocalHabitLogsCompanion(
      habitId: Value(habitId),
      userId: Value(userId),
      completedAt: Value(completedAt),
      value: Value(next),
      note: Value(existing?.note),
      emoji: Value(existing?.emoji),
      synced: const Value(false),
    ));
    return next;
  }

  /// Stage 2 — reset a day's accumulated value to 0 (un-complete for
  /// count/duration habits).
  Future<void> resetHabitLogValue({
    required String habitId,
    required String userId,
    required String completedAt,
  }) async {
    final existing = await (select(localHabitLogs)
          ..where((t) =>
              t.habitId.equals(habitId) &
              t.userId.equals(userId) &
              t.completedAt.equals(completedAt)))
        .getSingleOrNull();
    if (existing == null) return;
    await into(localHabitLogs).insertOnConflictUpdate(LocalHabitLogsCompanion(
      habitId: Value(habitId),
      userId: Value(userId),
      completedAt: Value(completedAt),
      value: const Value(0),
      note: Value(existing.note),
      emoji: Value(existing.emoji),
      synced: const Value(false),
    ));
  }

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

  // ── Focus ↔ Planning aggregates (Stage 7) ──────────────────────────────────

  Future<int> focusSecondsForTask(String taskId) async {
    final rows = await (select(localFocusSessions)
          ..where((t) => t.taskId.equals(taskId)))
        .get();
    return rows.fold<int>(0, (s, r) => s + r.durationSeconds);
  }

  Future<int> focusSecondsForGoal(String goalId) async {
    final rows = await (select(localFocusSessions)
          ..where((t) => t.goalId.equals(goalId)))
        .get();
    return rows.fold<int>(0, (s, r) => s + r.durationSeconds);
  }

  /// Map of taskId → total focus seconds for one goal (orphan task_id rows
  /// after a task delete are skipped; their time still counts toward the goal).
  Future<Map<String, int>> focusSecondsByTaskForGoal(String goalId) async {
    final rows = await (select(localFocusSessions)
          ..where((t) => t.goalId.equals(goalId) & t.taskId.isNotNull()))
        .get();
    final result = <String, int>{};
    for (final r in rows) {
      final tid = r.taskId;
      if (tid == null) continue;
      result[tid] = (result[tid] ?? 0) + r.durationSeconds;
    }
    return result;
  }

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
            ..where((t) => t.attempts.isSmallerThanValue(10))
            ..orderBy([(t) => OrderingTerm(expression: t.id)]))
          .get();

  Future<void> deleteSyncOp(int id) =>
      (delete(pendingSyncOps)..where((t) => t.id.equals(id))).go();

  Future<void> purgeDeadSyncOps() =>
      (delete(pendingSyncOps)
            ..where((t) => t.attempts.isBiggerOrEqualValue(10)))
          .go();

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

  // ── Map elements (TacticalMapEvolution Stage 1) ────────────────────────────

  Future<void> upsertMapElement(LocalMapElementsCompanion row) =>
      into(localMapElements).insertOnConflictUpdate(row);

  Future<List<LocalMapElement>> mapElementsForGoals(List<String> goalIds) async {
    if (goalIds.isEmpty) return const [];
    return (select(localMapElements)
          ..where((t) => t.goalId.isIn(goalIds) & t.deletedLocally.equals(false)))
        .get();
  }

  Future<void> deleteMapElementLocally(String id) =>
      (update(localMapElements)..where((t) => t.id.equals(id))).write(
        const LocalMapElementsCompanion(
          deletedLocally: Value(true),
          synced: Value(false),
        ),
      );

  Future<void> purgeMapElement(String id) =>
      (delete(localMapElements)..where((t) => t.id.equals(id))).go();

  Future<List<LocalMapElement>> unsyncedMapElements() =>
      (select(localMapElements)..where((t) => t.synced.equals(false))).get();

  Future<void> markMapElementSynced(String id) =>
      (update(localMapElements)..where((t) => t.id.equals(id)))
          .write(const LocalMapElementsCompanion(synced: Value(true)));

  // ── Node attachments (Stage 2) ────────────────────────────────────────────

  Future<List<LocalNodeAttachment>> attachmentsForGoals(List<String> goalIds) =>
      (select(localNodeAttachments)
            ..where((t) =>
                t.goalId.isIn(goalIds) & t.deletedLocally.equals(false)))
          .get();

  Future<List<LocalNodeAttachment>> unsyncedAttachments() =>
      (select(localNodeAttachments)
            ..where((t) =>
                t.synced.equals(false) & t.deletedLocally.equals(false)))
          .get();

  Future<void> upsertNodeAttachment(LocalNodeAttachmentsCompanion row) =>
      into(localNodeAttachments).insertOnConflictUpdate(row);

  Future<void> deleteAttachmentLocally(String id) =>
      (update(localNodeAttachments)..where((t) => t.id.equals(id)))
          .write(const LocalNodeAttachmentsCompanion(
              deletedLocally: Value(true), synced: Value(false)));

  Future<void> purgeAttachment(String id) =>
      (delete(localNodeAttachments)..where((t) => t.id.equals(id))).go();

  Future<void> markAttachmentSynced(String id) =>
      (update(localNodeAttachments)..where((t) => t.id.equals(id)))
          .write(const LocalNodeAttachmentsCompanion(synced: Value(true)));

  Future<void> updateAttachmentStoragePath(String id, String path) =>
      (update(localNodeAttachments)..where((t) => t.id.equals(id)))
          .write(LocalNodeAttachmentsCompanion(
              storagePath: Value(path), synced: const Value(false)));

  // ── Node assignees (Stage 5) ──────────────────────────────────────────────

  Future<List<LocalTaskAssignee>> taskAssigneesForGoals(List<String> goalIds) =>
      goalIds.isEmpty
          ? Future.value(const [])
          : (select(localTaskAssignees)
                ..where((t) =>
                    t.goalId.isIn(goalIds) & t.deletedLocally.equals(false)))
              .get();

  Future<List<LocalSubGoalAssignee>> subGoalAssigneesForGoals(
          List<String> goalIds) =>
      goalIds.isEmpty
          ? Future.value(const [])
          : (select(localSubGoalAssignees)
                ..where((t) =>
                    t.goalId.isIn(goalIds) & t.deletedLocally.equals(false)))
              .get();

  Future<void> upsertTaskAssignee(LocalTaskAssigneesCompanion row) =>
      into(localTaskAssignees).insertOnConflictUpdate(row);

  Future<void> upsertSubGoalAssignee(LocalSubGoalAssigneesCompanion row) =>
      into(localSubGoalAssignees).insertOnConflictUpdate(row);

  Future<void> deleteTaskAssigneeLocally(String taskId, String userId) =>
      (update(localTaskAssignees)
            ..where((t) => t.taskId.equals(taskId) & t.userId.equals(userId)))
          .write(const LocalTaskAssigneesCompanion(
              deletedLocally: Value(true), synced: Value(false)));

  Future<void> deleteSubGoalAssigneeLocally(
          String subGoalId, String userId) =>
      (update(localSubGoalAssignees)
            ..where((t) =>
                t.subGoalId.equals(subGoalId) & t.userId.equals(userId)))
          .write(const LocalSubGoalAssigneesCompanion(
              deletedLocally: Value(true), synced: Value(false)));

  Future<void> purgeTaskAssignee(String taskId, String userId) =>
      (delete(localTaskAssignees)
            ..where(
                (t) => t.taskId.equals(taskId) & t.userId.equals(userId)))
          .go();

  Future<void> purgeSubGoalAssignee(String subGoalId, String userId) =>
      (delete(localSubGoalAssignees)
            ..where((t) =>
                t.subGoalId.equals(subGoalId) & t.userId.equals(userId)))
          .go();

  Future<List<LocalTaskAssignee>> unsyncedTaskAssignees() =>
      (select(localTaskAssignees)..where((t) => t.synced.equals(false)))
          .get();

  Future<List<LocalSubGoalAssignee>> unsyncedSubGoalAssignees() =>
      (select(localSubGoalAssignees)..where((t) => t.synced.equals(false)))
          .get();

  Future<void> markTaskAssigneeSynced(String taskId, String userId) =>
      (update(localTaskAssignees)
            ..where(
                (t) => t.taskId.equals(taskId) & t.userId.equals(userId)))
          .write(const LocalTaskAssigneesCompanion(synced: Value(true)));

  Future<void> markSubGoalAssigneeSynced(String subGoalId, String userId) =>
      (update(localSubGoalAssignees)
            ..where((t) =>
                t.subGoalId.equals(subGoalId) & t.userId.equals(userId)))
          .write(const LocalSubGoalAssigneesCompanion(synced: Value(true)));

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

  // ── Task Dependencies (Stage 8) ────────────────────────────────────────────

  Future<void> upsertTaskDependency(LocalTaskDependenciesCompanion row) =>
      into(localTaskDependencies).insertOnConflictUpdate(row);

  Future<void> deleteTaskDependency(
          String taskId, String dependsOnTaskId) =>
      (delete(localTaskDependencies)
            ..where((t) =>
                t.taskId.equals(taskId) &
                t.dependsOnTaskId.equals(dependsOnTaskId)))
          .go();

  Future<List<LocalTaskDependency>> dependenciesForGoals(
          List<String> goalIds) =>
      goalIds.isEmpty
          ? Future.value(const [])
          : (select(localTaskDependencies)
                ..where((t) => t.goalId.isIn(goalIds)))
              .get();

  Future<List<LocalTaskDependency>> unsyncedTaskDependencies() =>
      (select(localTaskDependencies)..where((t) => t.synced.equals(false)))
          .get();

  Future<void> markTaskDependencySynced(
          String taskId, String dependsOnTaskId) =>
      (update(localTaskDependencies)
            ..where((t) =>
                t.taskId.equals(taskId) &
                t.dependsOnTaskId.equals(dependsOnTaskId)))
          .write(const LocalTaskDependenciesCompanion(synced: Value(true)));

  Future<void> upsertGoalHabitLink(LocalGoalHabitLinksCompanion row) =>
      into(localGoalHabitLinks).insertOnConflictUpdate(row);

  // Partial UPDATE helpers — use these instead of upsert when only updating
  // a subset of fields (e.g. synced flag, isCompleted). upsert requires all
  // non-nullable fields for its INSERT portion and throws otherwise.
  Future<void> patchGoal(String id, LocalGoalsCompanion patch) =>
      (update(localGoals)..where((t) => t.id.equals(id))).write(patch);

  Future<void> patchSubGoal(String id, LocalSubGoalsCompanion patch) =>
      (update(localSubGoals)..where((t) => t.id.equals(id))).write(patch);

  Future<void> patchMilestone(String id, LocalMilestonesCompanion patch) =>
      (update(localMilestones)..where((t) => t.id.equals(id))).write(patch);

  Future<void> patchPlanningTask(String id, LocalPlanningTasksCompanion patch) =>
      (update(localPlanningTasks)..where((t) => t.id.equals(id))).write(patch);

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

  // ── Planning lookups (used by sync_service) ──────────────────────────────

  Future<LocalPlanningTask?> getPlanningTask(String id) =>
      (select(localPlanningTasks)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<LocalSubGoal?> getSubGoal(String id) =>
      (select(localSubGoals)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<LocalMilestone?> getMilestone(String id) =>
      (select(localMilestones)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  // ── Unsynced ID sets (used by _mirrorToLocal) ─────────────────────────────

  Future<Set<String>> unsyncedSubGoalIds() async =>
      (await (select(localSubGoals)..where((t) => t.synced.equals(false))).get())
          .map((e) => e.id)
          .toSet();

  Future<Set<String>> unsyncedTaskIds() async =>
      (await (select(localPlanningTasks)
            ..where((t) => t.synced.equals(false)))
          .get())
          .map((e) => e.id)
          .toSet();

  Future<Set<String>> unsyncedMilestoneIds() async =>
      (await (select(localMilestones)
            ..where((t) => t.synced.equals(false)))
          .get())
          .map((e) => e.id)
          .toSet();

  // ── Missing Methods Added Back ──────────────────────────────────────────────

  Future<void> upsertMedalLocally(LocalMissionMedalsCompanion row) =>
      into(localMissionMedals).insertOnConflictUpdate(row);

  Future<void> markMedalSynced(String id) =>
      (update(localMissionMedals)..where((t) => t.id.equals(id)))
          .write(const LocalMissionMedalsCompanion(synced: Value(true)));

  Future<void> insertMilestoneLog(LocalMilestoneLogsCompanion row) =>
      into(localMilestoneLogs).insert(row);

  Future<void> updateMilestoneCurrentValue(String id, double? val) =>
      (update(localMilestones)..where((t) => t.id.equals(id)))
          .write(LocalMilestonesCompanion(currentValue: Value(val)));

  Future<List<LocalMilestoneLog>> logsForMilestone(String milestoneId) =>
      (select(localMilestoneLogs)..where((t) => t.milestoneId.equals(milestoneId)))
          .get();

  Future<void> deleteMilestoneLogLocally(String id) =>
      (delete(localMilestoneLogs)..where((t) => t.id.equals(id))).go();

  Future<void> upsertMissionTemplate(LocalMissionTemplatesCompanion row) =>
      into(localMissionTemplates).insertOnConflictUpdate(row);

  Future<List<LocalMissionTemplate>> templatesForUser(String userId) =>
      (select(localMissionTemplates)..where((t) => t.userId.equals(userId) | t.isSystem.equals(true)))
          .get();

  Future<void> markMissionTemplateSynced(String id) =>
      (update(localMissionTemplates)..where((t) => t.id.equals(id)))
          .write(const LocalMissionTemplatesCompanion(synced: Value(true)));

  Future<void> deleteMissionTemplateLocally(String id) =>
      (delete(localMissionTemplates)..where((t) => t.id.equals(id))).go();

  Future<LocalWeeklyReview?> weeklyReviewForWeek(String userId, int weekStartMs) =>
      (select(localWeeklyReviews)..where((t) => t.userId.equals(userId) & t.weekStartMs.equals(weekStartMs)))
          .getSingleOrNull();

  Future<void> upsertWeeklyReview(LocalWeeklyReviewsCompanion row) =>
      into(localWeeklyReviews).insertOnConflictUpdate(row);

  Future<void> markWeeklyReviewSynced(String id) =>
      (update(localWeeklyReviews)..where((t) => t.id.equals(id)))
          .write(const LocalWeeklyReviewsCompanion(synced: Value(true)));

  Future<void> upsertMeditationPreset(LocalMeditationPresetsCompanion row) =>
      into(localMeditationPresets).insertOnConflictUpdate(row);

  Future<List<LocalMeditationPreset>> presetsForUser(String userId) =>
      (select(localMeditationPresets)..where((t) => t.userId.equals(userId) | t.isSystem.equals(true)))
          .get();

  Future<void> deletePresetLocally(String id) =>
      (delete(localMeditationPresets)..where((t) => t.id.equals(id))).go();

  Future<void> insertMeditationSession(LocalMeditationSessionsCompanion row) =>
      into(localMeditationSessions).insert(row);

  Future<void> markMeditationSessionSynced(String id) =>
      (update(localMeditationSessions)..where((t) => t.id.equals(id)))
          .write(const LocalMeditationSessionsCompanion(synced: Value(true)));

  Future<void> upsertGoalSnapshot(LocalGoalProgressSnapshotsCompanion row) =>
      into(localGoalProgressSnapshots).insertOnConflictUpdate(row);

  Future<List<LocalGoalProgressSnapshot>> snapshotsForGoal(String goalId) =>
      (select(localGoalProgressSnapshots)..where((t) => t.goalId.equals(goalId))).get();

  Future<List<LocalGoalProgressSnapshot>> unsyncedGoalSnapshots() =>
      (select(localGoalProgressSnapshots)..where((t) => t.synced.equals(false))).get();

  Future<LocalWeeklyReview?> latestWeeklyReview(String userId) =>
      (select(localWeeklyReviews)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm(expression: t.weekStartMs, mode: OrderingMode.desc)])
            ..limit(1))
          .getSingleOrNull();

  Future<List<LocalMissionMedal>> medalsForUser(String userId) =>
      (select(localMissionMedals)..where((t) => t.userId.equals(userId))).get();

  Future<int> meditationSecondsThisWeek(String userId, [int? startOfWeekMs]) async {
    final startMs = startOfWeekMs ??
        DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)).millisecondsSinceEpoch;
    final sessions = await (select(localMeditationSessions)
          ..where((t) => t.userId.equals(userId) & t.completedAtMs.isBiggerOrEqualValue(startMs)))
        .get();
    return sessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);
  }

  Future<bool> hasGoalSnapshotForDay(String goalId, int dayKeyMs) async {
    final countExp = localGoalProgressSnapshots.id.count();
    final query = selectOnly(localGoalProgressSnapshots)
      ..addColumns([countExp])
      ..where(localGoalProgressSnapshots.goalId.equals(goalId) &
          localGoalProgressSnapshots.dayKeyMs.equals(dayKeyMs));
    final count = await query.map((row) => row.read(countExp)).getSingle();
    return (count ?? 0) > 0;
  }

  Future<void> markGoalSnapshotSynced(String id) =>
      (update(localGoalProgressSnapshots)..where((t) => t.id.equals(id)))
          .write(const LocalGoalProgressSnapshotsCompanion(synced: Value(true)));
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
