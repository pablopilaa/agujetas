import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'legal_contract.dart';
import 'models.dart';

class ActiveWorkoutDraft {
  const ActiveWorkoutDraft({
    required this.userId,
    required this.sessionMode,
    required this.exercises,
    required this.updatedAt,
    this.totalElapsed = Duration.zero,
    this.restRemaining = const Duration(minutes: 2),
    this.totalRunning = false,
    this.restRunning = false,
  });

  final String userId;
  final String sessionMode;
  final List<WorkoutExercise> exercises;
  final DateTime updatedAt;
  final Duration totalElapsed;
  final Duration restRemaining;
  final bool totalRunning;
  final bool restRunning;

  Map<String, Object?> toJson() => {
    'userId': userId,
    'sessionMode': sessionMode,
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'totalElapsedSeconds': totalElapsed.inSeconds,
    'restRemainingSeconds': restRemaining.inSeconds,
    'totalRunning': totalRunning,
    'restRunning': restRunning,
  };

  factory ActiveWorkoutDraft.fromJson(Map<String, Object?> json) {
    final exercises = (json['exercises'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((raw) => WorkoutExercise.fromJson(raw.cast<String, Object?>()))
        .toList();
    final updatedAt =
        DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
        DateTime.now().toUtc();
    final now = DateTime.now().toUtc();
    final elapsedSinceUpdate = now.isAfter(updatedAt)
        ? now.difference(updatedAt)
        : Duration.zero;
    final totalRunning = json['totalRunning'] == true;
    final restRunning = json['restRunning'] == true;
    final totalElapsed =
        Duration(seconds: _readInt(json['totalElapsedSeconds'])) +
        (totalRunning ? elapsedSinceUpdate : Duration.zero);
    final rawRestRemaining = Duration(
      seconds: _readIntWithDefault(json['restRemainingSeconds'], 120),
    );
    final adjustedRestRemaining = restRunning
        ? rawRestRemaining - elapsedSinceUpdate
        : rawRestRemaining;
    final restRemaining = adjustedRestRemaining <= Duration.zero
        ? Duration.zero
        : adjustedRestRemaining;
    return ActiveWorkoutDraft(
      userId: json['userId']?.toString() ?? '',
      sessionMode: json['sessionMode']?.toString() ?? 'Fuerza',
      exercises: exercises.isEmpty ? seedWorkout() : exercises,
      updatedAt: updatedAt,
      totalElapsed: totalElapsed,
      restRemaining: restRemaining,
      totalRunning: totalRunning,
      restRunning: restRunning && restRemaining > Duration.zero,
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
    this.title,
    this.note,
  });

  final String id;
  final String userId;
  final String sessionMode;
  final List<WorkoutExercise> exercises;
  final DateTime startedAt;
  final DateTime finishedAt;
  final int durationSeconds;
  final String? title;
  final String? note;

  Map<String, Object?> toJson() => {
    'id': id,
    'userId': userId,
    'sessionMode': sessionMode,
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
    'startedAt': startedAt.toUtc().toIso8601String(),
    'finishedAt': finishedAt.toUtc().toIso8601String(),
    'durationSeconds': durationSeconds,
    'title': title,
    'note': note,
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
      title: _optionalString(json['title']),
      note: _optionalString(json['note']),
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
    String? title,
    String? note,
    bool clearTitle = false,
    bool clearNote = false,
  }) {
    return LocalWorkoutSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sessionMode: sessionMode ?? this.sessionMode,
      exercises: exercises ?? this.exercises,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      title: clearTitle ? null : title ?? this.title,
      note: clearNote ? null : note ?? this.note,
    );
  }
}

class LocalBackupImportResult {
  const LocalBackupImportResult({
    required this.sessions,
    required this.routines,
    required this.bodyWeights,
    required this.customExercises,
  });

  final int sessions;
  final int routines;
  final int bodyWeights;
  final int customExercises;

  int get total => sessions + routines + bodyWeights + customExercises;

  String get summary =>
      '$sessions sesiones, $routines rutinas, $bodyWeights pesos y '
      '$customExercises ejercicios propios';
}

class LocalUserPreferences {
  const LocalUserPreferences({
    this.preferredTheme = 'system',
    this.restAlertsEnabled = true,
    this.bodyWeightAlertsEnabled = true,
    this.localGalleryEnabled = false,
  });

  final String preferredTheme;
  final bool restAlertsEnabled;
  final bool bodyWeightAlertsEnabled;
  final bool localGalleryEnabled;

  Map<String, Object?> toJson() => {
    'preferredTheme': preferredTheme,
    'restAlertsEnabled': restAlertsEnabled,
    'bodyWeightAlertsEnabled': bodyWeightAlertsEnabled,
    'localGalleryEnabled': localGalleryEnabled,
    'schemaVersion': 1,
  };

  factory LocalUserPreferences.fromJson(Map<String, Object?> json) {
    return LocalUserPreferences(
      preferredTheme: _readPreferredTheme(json['preferredTheme']),
      restAlertsEnabled: _readBoolWithDefault(json['restAlertsEnabled'], true),
      bodyWeightAlertsEnabled: _readBoolWithDefault(
        json['bodyWeightAlertsEnabled'],
        true,
      ),
      localGalleryEnabled: _readBoolWithDefault(
        json['localGalleryEnabled'],
        false,
      ),
    );
  }

  LocalUserPreferences copyWith({
    String? preferredTheme,
    bool? restAlertsEnabled,
    bool? bodyWeightAlertsEnabled,
    bool? localGalleryEnabled,
  }) {
    return LocalUserPreferences(
      preferredTheme: preferredTheme ?? this.preferredTheme,
      restAlertsEnabled: restAlertsEnabled ?? this.restAlertsEnabled,
      bodyWeightAlertsEnabled:
          bodyWeightAlertsEnabled ?? this.bodyWeightAlertsEnabled,
      localGalleryEnabled: localGalleryEnabled ?? this.localGalleryEnabled,
    );
  }
}

String _readPreferredTheme(Object? value) {
  final raw = value?.toString();
  return raw == 'light' || raw == 'dark' || raw == 'system' ? raw! : 'system';
}

class LocalPrivacyConsent {
  const LocalPrivacyConsent({
    required this.acceptedAt,
    this.schemaVersion = currentSchemaVersion,
    this.termsVersion = AgujetasLegalContract.termsVersion,
    this.privacyVersion = AgujetasLegalContract.privacyVersion,
    this.dataPolicyVersion = AgujetasLegalContract.dataPolicyVersion,
    this.notificationsVersion = AgujetasLegalContract.notificationsVersion,
    this.termsAccepted = true,
    this.firebaseSyncAccepted = true,
    this.localMediaAcknowledged = true,
    this.notificationsAcknowledged = true,
  });

  static const currentSchemaVersion = AgujetasLegalContract.schemaVersion;

  final DateTime acceptedAt;
  final int schemaVersion;
  final String termsVersion;
  final String privacyVersion;
  final String dataPolicyVersion;
  final String notificationsVersion;
  final bool termsAccepted;
  final bool firebaseSyncAccepted;
  final bool localMediaAcknowledged;
  final bool notificationsAcknowledged;

  bool get isCurrent =>
      schemaVersion >= currentSchemaVersion &&
      termsVersion == AgujetasLegalContract.termsVersion &&
      privacyVersion == AgujetasLegalContract.privacyVersion &&
      dataPolicyVersion == AgujetasLegalContract.dataPolicyVersion &&
      notificationsVersion == AgujetasLegalContract.notificationsVersion &&
      termsAccepted &&
      firebaseSyncAccepted &&
      localMediaAcknowledged &&
      notificationsAcknowledged;

  Map<String, Object?> toJson() => {
    'acceptedAt': acceptedAt.toUtc().toIso8601String(),
    'schemaVersion': schemaVersion,
    'termsVersion': termsVersion,
    'privacyVersion': privacyVersion,
    'dataPolicyVersion': dataPolicyVersion,
    'notificationsVersion': notificationsVersion,
    'termsAccepted': termsAccepted,
    'firebaseSyncAccepted': firebaseSyncAccepted,
    'localMediaAcknowledged': localMediaAcknowledged,
    'notificationsAcknowledged': notificationsAcknowledged,
  };

  factory LocalPrivacyConsent.fromJson(Map<String, Object?> json) {
    return LocalPrivacyConsent(
      acceptedAt:
          DateTime.tryParse(json['acceptedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      schemaVersion: _readIntWithDefault(json['schemaVersion'], 0),
      termsVersion: json['termsVersion']?.toString() ?? '',
      privacyVersion: json['privacyVersion']?.toString() ?? '',
      dataPolicyVersion: json['dataPolicyVersion']?.toString() ?? '',
      notificationsVersion: json['notificationsVersion']?.toString() ?? '',
      termsAccepted: _readBoolWithDefault(json['termsAccepted'], false),
      firebaseSyncAccepted: _readBoolWithDefault(
        json['firebaseSyncAccepted'],
        false,
      ),
      localMediaAcknowledged: _readBoolWithDefault(
        json['localMediaAcknowledged'],
        false,
      ),
      notificationsAcknowledged: _readBoolWithDefault(
        json['notificationsAcknowledged'],
        false,
      ),
    );
  }
}

String? _optionalString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
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
    Duration totalElapsed = Duration.zero,
    Duration restRemaining = const Duration(minutes: 2),
    bool totalRunning = false,
    bool restRunning = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final draft = ActiveWorkoutDraft(
      userId: userId,
      sessionMode: sessionMode,
      exercises: exercises,
      updatedAt: DateTime.now().toUtc(),
      totalElapsed: totalElapsed,
      restRemaining: restRemaining,
      totalRunning: totalRunning,
      restRunning: restRunning,
    );
    await prefs.setString(_activeDraftKey(userId), jsonEncode(draft.toJson()));
  }

  Future<void> clearActiveDraft(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeDraftKey(userId));
  }

  Future<LocalUserPreferences> loadUserPreferences(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_preferencesKey(userId));
    if (raw == null || raw.isEmpty) return const LocalUserPreferences();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const LocalUserPreferences();
    return LocalUserPreferences.fromJson(decoded.cast<String, Object?>());
  }

  Future<void> saveUserPreferences({
    required String userId,
    required LocalUserPreferences preferences,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _preferencesKey(userId),
      jsonEncode(preferences.toJson()),
    );
  }

  Future<LocalPrivacyConsent?> loadPrivacyConsent(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_privacyConsentKey(userId));
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return LocalPrivacyConsent.fromJson(decoded.cast<String, Object?>());
  }

  Future<void> savePrivacyConsent({
    required String userId,
    required LocalPrivacyConsent consent,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _privacyConsentKey(userId),
      jsonEncode(consent.toJson()),
    );
  }

  Future<void> clearAllLocalData(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_activeDraftKey(userId)),
      prefs.remove(_sessionsKey(userId)),
      prefs.remove(_routinesKey(userId)),
      prefs.remove(_bodyWeightsKey(userId)),
      prefs.remove(_customExercisesKey(userId)),
      prefs.remove(_preferencesKey(userId)),
      prefs.remove(_privacyConsentKey(userId)),
    ]);
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

  Future<void> updateSessionLocal({
    required String userId,
    required LocalWorkoutSession session,
  }) async {
    final previous = await loadSessions(userId);
    final normalized = session.copyWith(userId: userId);
    final next = [
      for (final item in previous)
        if (item.id == normalized.id) normalized else item,
    ]..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
    await _replaceSessions(userId: userId, sessions: next);
  }

  Future<void> deleteSessionLocal({
    required String userId,
    required String sessionId,
  }) async {
    final previous = await loadSessions(userId);
    final next = previous.where((item) => item.id != sessionId).toList();
    await _replaceSessions(userId: userId, sessions: next);
  }

  Future<void> _replaceSessions({
    required String userId,
    required List<LocalWorkoutSession> sessions,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = sessions
        .where((session) => session.userId == userId)
        .take(500)
        .toList();
    await prefs.setString(
      _sessionsKey(userId),
      jsonEncode(normalized.map((item) => item.toJson()).toList()),
    );
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
    await replaceBodyWeightsLocal(userId: userId, entries: next);
  }

  Future<int> mergeBodyWeightsLocal({
    required String userId,
    required List<BodyWeightEntry> entries,
  }) async {
    if (entries.isEmpty) return 0;
    final previous = await loadBodyWeights(userId);
    final byId = <String, BodyWeightEntry>{
      for (final entry in previous) entry.id: entry,
    };
    var changed = 0;
    for (final entry in entries) {
      if (entry.id.isEmpty) continue;
      final normalized = BodyWeightEntry(
        id: entry.id,
        userId: userId,
        weightKg: entry.weightKg,
        recordedAt: entry.recordedAt,
        note: entry.note,
      );
      final previousEntry = byId[normalized.id];
      byId[normalized.id] = normalized;
      if (previousEntry == null ||
          previousEntry.userId != normalized.userId ||
          previousEntry.weightKg != normalized.weightKg ||
          previousEntry.recordedAt != normalized.recordedAt ||
          previousEntry.note != normalized.note) {
        changed++;
      }
    }
    await replaceBodyWeightsLocal(userId: userId, entries: byId.values);
    return changed;
  }

  Future<void> replaceBodyWeightsLocal({
    required String userId,
    required Iterable<BodyWeightEntry> entries,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized =
        entries
            .where((entry) => entry.id.isNotEmpty)
            .map(
              (entry) => BodyWeightEntry(
                id: entry.id,
                userId: userId,
                weightKg: entry.weightKg,
                recordedAt: entry.recordedAt,
                note: entry.note,
              ),
            )
            .toList()
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    await prefs.setString(
      _bodyWeightsKey(userId),
      jsonEncode(normalized.take(1000).map((item) => item.toJson()).toList()),
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

  Future<void> deleteCustomExerciseLocal({
    required String userId,
    required String exerciseId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = await loadCustomExercises(userId);
    final next = previous.where((item) => item.id != exerciseId).toList();
    await prefs.setString(
      _customExercisesKey(userId),
      jsonEncode(next.map((item) => item.toJson()).toList()),
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

  Future<String> exportBackupJson(String userId) async {
    final snapshot = {
      'schema': 'agujetas.localBackup',
      'schemaVersion': 1,
      'userId': userId,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'sessions': (await loadSessions(
        userId,
      )).map((session) => session.toJson()).toList(),
      'routines': (await loadRoutineTemplates(
        userId,
      )).map((routine) => routine.toJson()).toList(),
      'bodyWeights': (await loadBodyWeights(
        userId,
      )).map((entry) => entry.toJson()).toList(),
      'customExercises': (await loadCustomExercises(
        userId,
      )).map((entry) => entry.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(snapshot);
  }

  Future<LocalBackupImportResult> importBackupJson({
    required String userId,
    required String rawJson,
  }) async {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      throw const FormatException('El respaldo debe ser un objeto JSON.');
    }
    final json = decoded.cast<String, Object?>();
    if (json['schema'] != 'agujetas.localBackup') {
      throw const FormatException('El respaldo no pertenece a Agujetas.');
    }

    final importedSessions = (json['sessions'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((raw) => LocalWorkoutSession.fromJson(raw.cast<String, Object?>()))
        .where((session) => session.id.isNotEmpty)
        .map((session) => session.copyWith(userId: userId))
        .toList();
    final importedRoutines = (json['routines'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((raw) => RoutineTemplate.fromJson(raw.cast<String, Object?>()))
        .where(
          (routine) => routine.id.isNotEmpty && routine.exercises.isNotEmpty,
        )
        .map((routine) => routine.copyWith(ownerId: userId))
        .toList();
    final importedBodyWeights =
        (json['bodyWeights'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((raw) => BodyWeightEntry.fromJson(raw.cast<String, Object?>()))
            .where((entry) => entry.id.isNotEmpty)
            .map(
              (entry) => BodyWeightEntry(
                id: entry.id,
                userId: userId,
                weightKg: entry.weightKg,
                recordedAt: entry.recordedAt,
                note: entry.note,
              ),
            )
            .toList();
    final importedCustomExercises =
        (json['customExercises'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map(
              (raw) =>
                  ExerciseCatalogEntry.fromJson(raw.cast<String, Object?>()),
            )
            .where((entry) => entry.id.isNotEmpty)
            .map((entry) => entry.copyWith(isCustom: true))
            .toList();

    final previousSessions = await loadSessions(userId);
    final previousRoutines = await loadRoutineTemplates(userId);
    final previousBodyWeights = await loadBodyWeights(userId);
    final previousCustomExercises = await loadCustomExercises(userId);

    await _replaceSessions(
      userId: userId,
      sessions: _upsertById(
        previousSessions,
        importedSessions,
        (item) => item.id,
      )..sort((a, b) => b.finishedAt.compareTo(a.finishedAt)),
    );
    await replaceRoutineTemplates(
      userId: userId,
      routines: _upsertById(
        previousRoutines,
        importedRoutines,
        (item) => item.id,
      ),
    );
    await replaceBodyWeightsLocal(
      userId: userId,
      entries: _upsertById(
        previousBodyWeights,
        importedBodyWeights,
        (item) => item.id,
      )..sort((a, b) => b.recordedAt.compareTo(a.recordedAt)),
    );
    await _replaceCustomExercises(
      userId: userId,
      exercises: _upsertById(
        previousCustomExercises,
        importedCustomExercises,
        (item) => item.id,
      ),
    );

    return LocalBackupImportResult(
      sessions: importedSessions.length,
      routines: importedRoutines.length,
      bodyWeights: importedBodyWeights.length,
      customExercises: importedCustomExercises.length,
    );
  }

  Future<void> _replaceCustomExercises({
    required String userId,
    required List<ExerciseCatalogEntry> exercises,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = exercises
        .map((exercise) => exercise.copyWith(isCustom: true))
        .take(1000)
        .toList();
    await prefs.setString(
      _customExercisesKey(userId),
      jsonEncode(normalized.map((item) => item.toJson()).toList()),
    );
  }

  String _activeDraftKey(String userId) =>
      'agujetas.activeWorkoutDraft.v1.$userId';

  String _sessionsKey(String userId) => 'agujetas.localSessions.v1.$userId';

  String _routinesKey(String userId) => 'agujetas.localRoutines.v1.$userId';

  String _bodyWeightsKey(String userId) =>
      'agujetas.localBodyWeights.v1.$userId';

  String _customExercisesKey(String userId) =>
      'agujetas.localCustomExercises.v1.$userId';

  String _preferencesKey(String userId) =>
      'agujetas.localUserPreferences.v1.$userId';

  String _privacyConsentKey(String userId) =>
      'agujetas.localPrivacyConsent.v1.$userId';
}

List<T> _upsertById<T>(
  List<T> previous,
  List<T> imported,
  String Function(T item) idOf,
) {
  final byId = <String, T>{};
  for (final item in previous) {
    byId[idOf(item)] = item;
  }
  for (final item in imported) {
    byId[idOf(item)] = item;
  }
  return byId.values.toList();
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int _readIntWithDefault(Object? value, int fallback) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString()) ?? fallback;
}

bool _readBoolWithDefault(Object? value, bool fallback) {
  if (value == null) return fallback;
  if (value is bool) return value;
  final normalized = value.toString().trim().toLowerCase();
  return switch (normalized) {
    'true' || '1' || 'yes' || 'si' || 'sí' => true,
    'false' || '0' || 'no' => false,
    _ => fallback,
  };
}
