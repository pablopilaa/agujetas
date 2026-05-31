import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

class ActiveWorkoutDraft {
  const ActiveWorkoutDraft({
    required this.userId,
    required this.sessionMode,
    required this.exercises,
    required this.updatedAt,
  });

  final String userId;
  final String sessionMode;
  final List<WorkoutExercise> exercises;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'userId': userId,
    'sessionMode': sessionMode,
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory ActiveWorkoutDraft.fromJson(Map<String, Object?> json) {
    final exercises = (json['exercises'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((raw) => WorkoutExercise.fromJson(raw.cast<String, Object?>()))
        .toList();
    return ActiveWorkoutDraft(
      userId: json['userId']?.toString() ?? '',
      sessionMode: json['sessionMode']?.toString() ?? 'Fuerza',
      exercises: exercises.isEmpty ? seedWorkout() : exercises,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

class LocalWorkoutSession {
  const LocalWorkoutSession({
    required this.id,
    required this.userId,
    required this.sessionMode,
    required this.exercises,
    required this.startedAt,
    required this.finishedAt,
    required this.durationSeconds,
  });

  final String id;
  final String userId;
  final String sessionMode;
  final List<WorkoutExercise> exercises;
  final DateTime startedAt;
  final DateTime finishedAt;
  final int durationSeconds;

  Map<String, Object?> toJson() => {
    'id': id,
    'userId': userId,
    'sessionMode': sessionMode,
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
    'startedAt': startedAt.toUtc().toIso8601String(),
    'finishedAt': finishedAt.toUtc().toIso8601String(),
    'durationSeconds': durationSeconds,
    'schemaVersion': 1,
  };

  factory LocalWorkoutSession.fromJson(Map<String, Object?> json) {
    final finishedAt =
        DateTime.tryParse(json['finishedAt']?.toString() ?? '') ??
        DateTime.now().toUtc();
    final durationSeconds = _readInt(json['durationSeconds']);
    final exercises = (json['exercises'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((raw) => WorkoutExercise.fromJson(raw.cast<String, Object?>()))
        .toList();
    return LocalWorkoutSession(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      sessionMode: json['sessionMode']?.toString() ?? 'Fuerza',
      exercises: exercises,
      startedAt:
          DateTime.tryParse(json['startedAt']?.toString() ?? '') ??
          finishedAt.subtract(Duration(seconds: durationSeconds)),
      finishedAt: finishedAt,
      durationSeconds: durationSeconds,
    );
  }

  LocalWorkoutSession copyWith({
    String? id,
    String? userId,
    String? sessionMode,
    List<WorkoutExercise>? exercises,
    DateTime? startedAt,
    DateTime? finishedAt,
    int? durationSeconds,
  }) {
    return LocalWorkoutSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sessionMode: sessionMode ?? this.sessionMode,
      exercises: exercises ?? this.exercises,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}

class LocalWorkoutStore {
  LocalWorkoutStore._();

  static final instance = LocalWorkoutStore._();
  static const _uuid = Uuid();

  Future<ActiveWorkoutDraft?> loadActiveDraft(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activeDraftKey(userId));
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final draft = ActiveWorkoutDraft.fromJson(decoded.cast<String, Object?>());
    return draft.userId == userId ? draft : null;
  }

  Future<void> saveActiveDraft({
    required String userId,
    required String sessionMode,
    required List<WorkoutExercise> exercises,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final draft = ActiveWorkoutDraft(
      userId: userId,
      sessionMode: sessionMode,
      exercises: exercises,
      updatedAt: DateTime.now().toUtc(),
    );
    await prefs.setString(_activeDraftKey(userId), jsonEncode(draft.toJson()));
  }

  Future<void> clearActiveDraft(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeDraftKey(userId));
  }

  Future<List<LocalWorkoutSession>> loadSessions(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionsKey(userId));
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map(
          (item) => LocalWorkoutSession.fromJson(item.cast<String, Object?>()),
        )
        .where((session) => session.userId == userId)
        .toList()
      ..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
  }

  Future<LocalWorkoutSession> saveSession({
    required String userId,
    required String sessionMode,
    required List<WorkoutExercise> exercises,
    required Duration duration,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = await loadSessions(userId);
    final finishedAt = DateTime.now().toUtc();
    final session = LocalWorkoutSession(
      id: _uuid.v4(),
      userId: userId,
      sessionMode: sessionMode,
      exercises: exercises,
      startedAt: finishedAt.subtract(duration),
      finishedAt: finishedAt,
      durationSeconds: duration.inSeconds,
    );
    final next = [session, ...previous].take(500).toList();
    await prefs.setString(
      _sessionsKey(userId),
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
    return session;
  }

  Future<List<BodyWeightEntry>> loadBodyWeights(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bodyWeightsKey(userId));
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => BodyWeightEntry.fromJson(item.cast<String, Object?>()))
        .where((entry) => entry.userId == userId)
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  Future<void> saveBodyWeightLocal({
    required String userId,
    required BodyWeightEntry entry,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = await loadBodyWeights(userId);
    final normalized = BodyWeightEntry(
      id: entry.id,
      userId: userId,
      weightKg: entry.weightKg,
      recordedAt: entry.recordedAt,
      note: entry.note,
    );
    final next = [
      normalized,
      ...previous.where((item) => item.id != normalized.id),
    ]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    await prefs.setString(
      _bodyWeightsKey(userId),
      jsonEncode(next.take(1000).map((item) => item.toJson()).toList()),
    );
  }

  Future<List<ExerciseCatalogEntry>> loadCustomExercises(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customExercisesKey(userId));
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map(
          (item) => ExerciseCatalogEntry.fromJson(item.cast<String, Object?>()),
        )
        .where((entry) => entry.isCustom)
        .toList()
      ..sort((a, b) {
        final lastUsed =
            (b.lastUsedDate ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
                  a.lastUsedDate ?? DateTime.fromMillisecondsSinceEpoch(0),
                );
        if (lastUsed != 0) return lastUsed;
        return a.name.compareTo(b.name);
      });
  }

  Future<void> saveCustomExerciseLocal({
    required String userId,
    required ExerciseCatalogEntry exercise,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = await loadCustomExercises(userId);
    final normalized = ExerciseCatalogEntry(
      id: exercise.id,
      name: exercise.name,
      muscleGroup: exercise.muscleGroup,
      imageUri: exercise.imageUri,
      usageCount: exercise.usageCount,
      lastUsedDate: exercise.lastUsedDate ?? DateTime.now().toUtc(),
      isCustom: true,
    );
    final next = [
      normalized,
      ...previous.where((item) => item.id != normalized.id),
    ];
    await prefs.setString(
      _customExercisesKey(userId),
      jsonEncode(next.take(1000).map((item) => item.toJson()).toList()),
    );
  }

  Future<List<RoutineTemplate>> loadRoutineTemplates(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_routinesKey(userId));
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => RoutineTemplate.fromJson(item.cast<String, Object?>()))
        .where((routine) => routine.ownerId == userId)
        .toList();
  }

  Future<void> saveRoutineTemplateLocal({
    required String userId,
    required RoutineTemplate routine,
  }) async {
    final routines = await loadRoutineTemplates(userId);
    final normalized = routine.copyWith(ownerId: userId);
    final index = routines.indexWhere((item) => item.id == normalized.id);
    final next = [...routines];
    if (index == -1) {
      next.insert(0, normalized);
    } else {
      next[index] = normalized;
    }
    await replaceRoutineTemplates(userId: userId, routines: next);
  }

  Future<void> deleteRoutineTemplate({
    required String userId,
    required String routineId,
  }) async {
    final routines = await loadRoutineTemplates(userId);
    await replaceRoutineTemplates(
      userId: userId,
      routines: routines.where((routine) => routine.id != routineId).toList(),
    );
  }

  Future<void> replaceRoutineTemplates({
    required String userId,
    required List<RoutineTemplate> routines,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = routines
        .where((routine) => routine.exercises.isNotEmpty)
        .map((routine) => routine.copyWith(ownerId: userId))
        .toList();
    await prefs.setString(
      _routinesKey(userId),
      jsonEncode(normalized.map((item) => item.toJson()).toList()),
    );
  }

  Future<int> saveImportedRoutineTemplates({
    required String userId,
    required List<RoutineTemplate> routines,
  }) async {
    if (routines.isEmpty) return 0;
    final prefs = await SharedPreferences.getInstance();
    final previous = await loadRoutineTemplates(userId);
    final existingIds = previous.map((routine) => routine.id).toSet();
    final imported = <RoutineTemplate>[];
    for (final routine in routines) {
      if (existingIds.contains(routine.id) || routine.exercises.isEmpty) {
        continue;
      }
      existingIds.add(routine.id);
      imported.add(
        RoutineTemplate(
          id: routine.id,
          ownerId: userId,
          title: routine.title,
          exercises: routine.exercises,
          assignedClientId: routine.assignedClientId,
        ),
      );
    }
    if (imported.isEmpty) return 0;
    await prefs.setString(
      _routinesKey(userId),
      jsonEncode(
        [...previous, ...imported].map((item) => item.toJson()).toList(),
      ),
    );
    return imported.length;
  }

  Future<int> saveImportedSessions({
    required String userId,
    required List<LocalWorkoutSession> sessions,
  }) async {
    if (sessions.isEmpty) return 0;
    final prefs = await SharedPreferences.getInstance();
    final previous = await loadSessions(userId);
    final existingIds = previous.map((session) => session.id).toSet();
    final imported = <LocalWorkoutSession>[];
    for (final session in sessions) {
      if (existingIds.contains(session.id)) continue;
      existingIds.add(session.id);
      imported.add(session.copyWith(userId: userId));
    }
    if (imported.isEmpty) return 0;
    final next = [...imported, ...previous]
      ..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
    await prefs.setString(
      _sessionsKey(userId),
      jsonEncode(next.take(2000).map((item) => item.toJson()).toList()),
    );
    return imported.length;
  }

  String _activeDraftKey(String userId) =>
      'agujetas.activeWorkoutDraft.v1.$userId';

  String _sessionsKey(String userId) => 'agujetas.localSessions.v1.$userId';

  String _routinesKey(String userId) => 'agujetas.localRoutines.v1.$userId';

  String _bodyWeightsKey(String userId) =>
      'agujetas.localBodyWeights.v1.$userId';

  String _customExercisesKey(String userId) =>
      'agujetas.localCustomExercises.v1.$userId';
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
