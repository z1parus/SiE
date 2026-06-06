import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_sqflite/drift_sqflite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

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
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
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

  Future<void> upsertRoutineMember(LocalRoutineMembersCompanion row) =>
      into(localRoutineMembers).insertOnConflictUpdate(row);

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
}

// ── Provider ──────────────────────────────────────────────────────────────────

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// ── Connection ─────────────────────────────────────────────────────────────────

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File('${dbFolder.path}/sie_local.db');
    return SqfliteQueryExecutor(path: file.path);
  });
}
