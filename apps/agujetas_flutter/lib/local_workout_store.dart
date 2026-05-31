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
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
