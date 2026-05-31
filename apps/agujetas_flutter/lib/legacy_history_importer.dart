import 'dart:convert';

import 'package:flutter/services.dart';

import 'local_workout_store.dart';
import 'models.dart';

class LegacyHistoryImportResult {
  const LegacyHistoryImportResult({
    required this.sessions,
    required this.skippedRows,
  });

  final List<LocalWorkoutSession> sessions;
  final int skippedRows;
}

class LegacyHistoryImporter {
  const LegacyHistoryImporter._();

  static const bundledHistoryAsset =
      'assets/user_data/historico_2025-12-31_a_2026-05-13.json';

  static Future<LegacyHistoryImportResult> loadBundled({
    required String userId,
    AssetBundle? bundle,
  }) async {
    final data = await (bundle ?? rootBundle).load(bundledHistoryAsset);
    final raw = utf8.decode(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    return parseJson(userId: userId, rawJson: raw);
  }

  static LegacyHistoryImportResult parseJson({
    required String userId,
    required String rawJson,
  }) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      return const LegacyHistoryImportResult(sessions: [], skippedRows: 0);
    }
    final rows = decoded['rows'];
    if (rows is! List) {
      return const LegacyHistoryImportResult(sessions: [], skippedRows: 0);
    }
    return parseRows(userId: userId, rows: rows);
  }

  static LegacyHistoryImportResult parseRows({
    required String userId,
    required List<dynamic> rows,
  }) {
    final sessionsByKey = <String, _MutableLegacySession>{};
    var skippedRows = 0;

    for (final rawRow in rows) {
      if (rawRow is! Map) {
        skippedRows++;
        continue;
      }
      final row = rawRow.cast<String, Object?>();
      final finishedAt = _parseDate(
        _readString(row['fecha_hora_iso']) ??
            _readString(row['fecha']) ??
            _readString(row['date']),
      );
      if (finishedAt == null) {
        skippedRows++;
        continue;
      }

      final routine = _readString(row['rutina']);
      final routineId = _readString(row['rutina_id']);
      final durationSeconds =
          _readInt(row['duracion_seg']) ??
          _parseDurationSeconds(_readString(row['duracion_hhmmss'])) ??
          0;
      final sessionMode = routine?.isNotEmpty == true
          ? routine!
          : _readString(row['tipo_sesion']) ?? 'Sesión importada';
      final sessionKey = [
        finishedAt.toUtc().toIso8601String(),
        sessionMode,
        routineId ?? '',
        durationSeconds,
      ].join('|');

      final session = sessionsByKey.putIfAbsent(
        sessionKey,
        () => _MutableLegacySession(
          key: sessionKey,
          userId: userId,
          sessionMode: sessionMode,
          durationSeconds: durationSeconds,
          finishedAt: finishedAt.toUtc(),
        ),
      );

      final exerciseName = _readString(row['ejercicio']);
      if (exerciseName == null || exerciseName.isEmpty) {
        skippedRows++;
        continue;
      }
      final exerciseOrder =
          _readInt(row['orden_ejercicio']) ?? session.exercisesByKey.length + 1;
      final exerciseKey =
          'order:$exerciseOrder:${_normalizeExerciseKey(exerciseName)}';
      final exercise = session.exercisesByKey.putIfAbsent(
        exerciseKey,
        () => _MutableLegacyExercise(
          id: _normalizeExerciseKey(exerciseName),
          name: exerciseName,
          muscleGroup: _readString(row['musculo']) ?? 'General',
          order: exerciseOrder,
          isUnilateral: (_readString(row['lado']) ?? '').isNotEmpty,
        ),
      );

      final setOrder =
          _readInt(row['numero_serie']) ?? exercise.setsByOrder.length + 1;
      final set = _parseSet(row, setOrder);
      if (set == null) {
        skippedRows++;
        continue;
      }
      exercise.setsByOrder[setOrder] = set;
    }

    final sessions =
        sessionsByKey.values
            .where((session) => session.exercisesByKey.isNotEmpty)
            .map((session) => session.toSession())
            .toList()
          ..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));

    return LegacyHistoryImportResult(
      sessions: sessions,
      skippedRows: skippedRows,
    );
  }

  static WorkoutSet? _parseSet(Map<String, Object?> row, int order) {
    final repsValue = _readString(row['repeticiones']);
    final weightValue = _readString(row['peso_kg']);
    final rir = _readInt(row['rir']);
    final hasAnyValue =
        (repsValue != null && repsValue.isNotEmpty) ||
        (weightValue != null && weightValue.isNotEmpty) ||
        rir != null;
    if (!hasAnyValue) return null;

    final weights = _parseDoubleList(weightValue);
    final reps = _parseIntList(repsValue);
    final segments = _buildSegments(weights: weights, reps: reps);
    return WorkoutSet(
      order: order,
      setType: SetTypeX.fromValue(_readString(row['tipo_serie'])),
      segments: segments.isEmpty
          ? const [WeightSegment(weightKg: 0, reps: 0)]
          : segments,
      rir: rir,
      done: true,
    );
  }

  static List<WeightSegment> _buildSegments({
    required List<double> weights,
    required List<int> reps,
  }) {
    if (weights.isEmpty && reps.isEmpty) return const [];
    final length = weights.length > reps.length ? weights.length : reps.length;
    return [
      for (var i = 0; i < length; i++)
        WeightSegment(
          weightKg: weights.isEmpty
              ? 0
              : i < weights.length
              ? weights[i]
              : weights.last,
          reps: reps.isEmpty
              ? 0
              : i < reps.length
              ? reps[i]
              : 0,
        ),
    ];
  }

  static List<double> _parseDoubleList(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return const [];
    return normalized
        .split(RegExp(r'\s*[-/+]\s*'))
        .map((item) => double.tryParse(item.replaceAll(',', '.').trim()))
        .whereType<double>()
        .toList();
  }

  static List<int> _parseIntList(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return const [];
    return normalized
        .split(RegExp(r'\s*[-/+]\s*'))
        .map((item) => int.tryParse(item.trim()))
        .whereType<int>()
        .toList();
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
    final parts = value.split('-').map(int.tryParse).toList();
    if (parts.length == 3 &&
        parts[0] != null &&
        parts[1] != null &&
        parts[2] != null) {
      return DateTime(parts[0]!, parts[1]!, parts[2]!);
    }
    return null;
  }

  static int? _parseDurationSeconds(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':').map((part) => int.tryParse(part)).toList();
    if (parts.length != 3 || parts.any((part) => part == null)) return null;
    return parts[0]! * 3600 + parts[1]! * 60 + parts[2]!;
  }

  static String? _readString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    final text = _readString(value);
    if (text == null) return null;
    return int.tryParse(text);
  }
}

class _MutableLegacySession {
  _MutableLegacySession({
    required this.key,
    required this.userId,
    required this.sessionMode,
    required this.durationSeconds,
    required this.finishedAt,
  });

  final String key;
  final String userId;
  final String sessionMode;
  final int durationSeconds;
  final DateTime finishedAt;
  final exercisesByKey = <String, _MutableLegacyExercise>{};

  LocalWorkoutSession toSession() {
    final exercises = exercisesByKey.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return LocalWorkoutSession(
      id: 'legacy_${_stableHash(key).toRadixString(16)}',
      userId: userId,
      sessionMode: sessionMode,
      exercises: exercises
          .map((exercise) => exercise.toWorkoutExercise())
          .toList(),
      startedAt: finishedAt.subtract(Duration(seconds: durationSeconds)),
      finishedAt: finishedAt,
      durationSeconds: durationSeconds,
    );
  }
}

class _MutableLegacyExercise {
  _MutableLegacyExercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.order,
    required this.isUnilateral,
  });

  final String id;
  final String name;
  final String muscleGroup;
  final int order;
  final bool isUnilateral;
  final setsByOrder = <int, WorkoutSet>{};

  WorkoutExercise toWorkoutExercise() {
    final sets = setsByOrder.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return WorkoutExercise(
      id: id,
      name: name,
      muscleGroup: muscleGroup,
      isUnilateral: isUnilateral,
      sets: sets.map((entry) => entry.value).toList(),
    );
  }
}

String _normalizeExerciseKey(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

int _stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}
