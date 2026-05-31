import 'dart:convert';

import 'package:agujetas_flutter/exercise_image_resolver.dart';
import 'package:agujetas_flutter/legacy_history_importer.dart';
import 'package:agujetas_flutter/local_workout_store.dart';
import 'package:agujetas_flutter/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('set type parser normalizes warmup and dropset aliases', () {
    expect(SetTypeX.fromValue('entrada en calor'), SetType.warmup);
    expect(SetTypeX.fromValue('drop set'), SetType.dropset);
    expect(SetTypeX.fromValue('normal'), SetType.normal);
  });

  test('workout set supports two weight segments in one set', () {
    final set = WorkoutSet.fromJson({
      'order': 1,
      'setType': 'dropset',
      'segments': [
        {'weightKg': 20, 'reps': 8},
        {'weightKg': 10, 'reps': 6},
      ],
    });

    expect(set.setType, SetType.dropset);
    expect(set.hasBackoffSegment, isTrue);
    expect(set.primaryWeightKg, 20);
    expect(set.totalReps, 14);
  });

  test('roles allow a trainer to keep normal training mode available', () {
    final user = AppUser.fromJson({
      'uid': 'u1',
      'displayName': 'Pablo',
      'email': 'pablo@example.com',
      'roles': ['normal', 'trainer'],
      'activeRole': 'trainer',
    });

    expect(user.roles, containsAll([AppRole.normal, AppRole.trainer]));
    expect(user.activeRole, AppRole.trainer);
    expect(user.isTrainer, isTrue);
  });

  test('legacy single weight fields migrate into segments', () {
    final set = WorkoutSet.fromJson({
      'order': 2,
      'setType': 'warmup',
      'weightKg': '42,5',
      'reps': '12',
    });

    expect(set.setType, SetType.warmup);
    expect(set.segments.single.weightKg, 42.5);
    expect(set.segments.single.reps, 12);
  });

  test('new exercises start with three editable sets', () {
    final exercise = const ExerciseCatalogEntry(
      id: 'custom-1',
      name: 'Press propio',
      muscleGroup: 'Pectoral',
      imageUri: 'agujetas-image://ag_press_propio_test',
      isCustom: true,
    ).toWorkoutExercise();

    expect(exercise.sets, hasLength(3));
    expect(exercise.imageUri, 'agujetas-image://ag_press_propio_test');
    expect(exercise.isCustom, isTrue);
  });

  test('legacy app-image URIs are stripped from catalog data', () {
    final exercise = ExerciseCatalogEntry.fromJson({
      'id': 'legacy-1',
      'ejercicio': 'Press legado',
      'musculo': 'Pectoral',
      'imageUri': 'app-image://00011101',
    });

    expect(exercise.imageUri, isNull);
  });

  test('image resolver maps catalog exercises to Agujetas assets', () async {
    final resolved = await ExerciseImageResolver.instance.resolve(
      exerciseId: '1 a 2 cajas de salto',
      name: '1 a 2 cajas de salto',
      muscleGroup: 'General',
    );

    expect(resolved.imageId, isNotNull);
    expect(resolved.assetPath, startsWith('assets/exercise_images/thumbs/'));
    expect(resolved.assetPath, isNot(contains('lyfta')));
    expect(resolved.source, 'agujetas-generated');
  });

  test(
    'image resolver normalizes Spanish accents for catalog matching',
    () async {
      final resolved = await ExerciseImageResolver.instance.resolve(
        exerciseId: 'unknown-accented-id',
        name: 'Jalón lateral alternativo',
        muscleGroup: 'Espalda',
      );

      expect(resolved.isFallback, isFalse);
      expect(resolved.assetPath, contains('ag_jalon_lateral_alternativo'));
      expect(resolved.assetPath, isNot(contains('lyfta')));
    },
  );

  test(
    'legacy Lyfta URI is blocked and resolved through safe catalog art',
    () async {
      final resolved = await ExerciseImageResolver.instance.resolve(
        exerciseId: '1 a 2 cajas de salto',
        name: '1 a 2 cajas de salto',
        muscleGroup: 'General',
        imageUri: 'app-image://42091101',
      );

      expect(resolved.legacyUriBlocked, isTrue);
      expect(resolved.assetPath, startsWith('assets/exercise_images/thumbs/'));
      expect(resolved.assetPath, isNot(contains('lyfta')));
    },
  );

  test(
    'image resolver falls back to local placeholder for unknown exercises',
    () async {
      final resolved = await ExerciseImageResolver.instance.resolve(
        exerciseId: 'custom-no-match',
        name: 'Ejercicio inventado',
        muscleGroup: 'Pectoral',
      );

      expect(resolved.isFallback, isTrue);
      expect(
        resolved.assetPath,
        contains('assets/exercise_images/placeholders/'),
      );
    },
  );

  test('local workout store restores active workout drafts', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalWorkoutStore.instance;
    final exercises = seedWorkout();

    await store.saveActiveDraft(
      userId: 'local-user',
      sessionMode: 'Hipertrofia',
      exercises: exercises,
    );

    final draft = await store.loadActiveDraft('local-user');

    expect(draft, isNotNull);
    expect(draft!.sessionMode, 'Hipertrofia');
    expect(draft.exercises, hasLength(exercises.length));
    expect(draft.exercises.first.name, exercises.first.name);
  });

  test('active workout draft preserves timer state', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalWorkoutStore.instance;

    await store.saveActiveDraft(
      userId: 'timer-user',
      sessionMode: 'Técnica',
      exercises: seedWorkout(),
      totalElapsed: const Duration(minutes: 12, seconds: 4),
      restRemaining: const Duration(seconds: 45),
      totalRunning: true,
      restRunning: true,
    );

    final draft = await store.loadActiveDraft('timer-user');

    expect(draft, isNotNull);
    expect(draft!.sessionMode, 'Técnica');
    expect(draft.totalElapsed.inSeconds, greaterThanOrEqualTo(724));
    expect(draft.restRemaining.inSeconds, lessThanOrEqualTo(45));
    expect(draft.totalRunning, isTrue);
    expect(draft.restRunning, isTrue);
  });

  test('active workout draft stops expired rest timer on restore', () {
    final draft = ActiveWorkoutDraft.fromJson({
      'userId': 'timer-user',
      'sessionMode': 'Fuerza',
      'exercises': seedWorkout().map((exercise) => exercise.toJson()).toList(),
      'updatedAt': DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 3))
          .toIso8601String(),
      'totalElapsedSeconds': 60,
      'restRemainingSeconds': 45,
      'totalRunning': true,
      'restRunning': true,
    });

    expect(draft.totalElapsed.inSeconds, greaterThanOrEqualTo(240));
    expect(draft.restRemaining, Duration.zero);
    expect(draft.totalRunning, isTrue);
    expect(draft.restRunning, isFalse);
  });

  test(
    'local workout store saves history and clears draft separately',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = LocalWorkoutStore.instance;
      final exercises = seedWorkout();

      await store.saveActiveDraft(
        userId: 'history-user',
        sessionMode: 'Fuerza',
        exercises: exercises,
      );
      final session = await store.saveSession(
        userId: 'history-user',
        sessionMode: 'Fuerza',
        exercises: exercises,
        duration: const Duration(minutes: 42),
      );
      await store.clearActiveDraft('history-user');

      final sessions = await store.loadSessions('history-user');
      final draft = await store.loadActiveDraft('history-user');

      expect(session.durationSeconds, 2520);
      expect(sessions, hasLength(1));
      expect(sessions.single.exercises.first.sets, isNotEmpty);
      expect(draft, isNull);
    },
  );

  test('local workout store edits and deletes session metadata', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalWorkoutStore.instance;
    final session = await store.saveSession(
      userId: 'session-edit-user',
      sessionMode: 'Fuerza',
      exercises: seedWorkout(),
      duration: const Duration(minutes: 35),
    );

    await store.updateSessionLocal(
      userId: 'session-edit-user',
      session: session.copyWith(
        title: 'Piernas corregido',
        note: 'Subí RIR por molestia lumbar.',
      ),
    );

    var sessions = await store.loadSessions('session-edit-user');
    expect(sessions.single.title, 'Piernas corregido');
    expect(sessions.single.note, 'Subí RIR por molestia lumbar.');

    await store.deleteSessionLocal(
      userId: 'session-edit-user',
      sessionId: session.id,
    );

    sessions = await store.loadSessions('session-edit-user');
    expect(sessions, isEmpty);
  });

  test('local workout store persists body weight history by user', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalWorkoutStore.instance;
    final older = BodyWeightEntry(
      id: 'weight-old',
      userId: 'weight-user',
      weightKg: 82.4,
      recordedAt: DateTime.utc(2026, 5, 1),
    );
    final newer = BodyWeightEntry(
      id: 'weight-new',
      userId: 'weight-user',
      weightKg: 81.9,
      recordedAt: DateTime.utc(2026, 5, 3),
    );

    await store.saveBodyWeightLocal(userId: 'weight-user', entry: older);
    await store.saveBodyWeightLocal(userId: 'weight-user', entry: newer);
    await store.saveBodyWeightLocal(
      userId: 'other-user',
      entry: BodyWeightEntry(
        id: 'weight-other',
        userId: 'other-user',
        weightKg: 90,
        recordedAt: DateTime.utc(2026, 5, 4),
      ),
    );

    final entries = await store.loadBodyWeights('weight-user');

    expect(entries.map((entry) => entry.id), ['weight-new', 'weight-old']);
    expect(entries.map((entry) => entry.userId).toSet(), {'weight-user'});
    expect(entries.first.weightKg, 81.9);
  });

  test('local workout store persists custom exercises by user', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalWorkoutStore.instance;
    final older = ExerciseCatalogEntry(
      id: 'custom-a',
      name: 'Press propio',
      muscleGroup: 'Pectoral',
      imageUri: 'agujetas-image://ag_press',
      lastUsedDate: DateTime.utc(2026, 5, 1),
      isCustom: true,
    );
    final newer = ExerciseCatalogEntry(
      id: 'custom-b',
      name: 'Remo propio',
      muscleGroup: 'Espalda',
      imageUri: 'agujetas-image://ag_row',
      lastUsedDate: DateTime.utc(2026, 5, 3),
      isCustom: true,
    );

    await store.saveCustomExerciseLocal(userId: 'custom-user', exercise: older);
    await store.saveCustomExerciseLocal(userId: 'custom-user', exercise: newer);
    await store.saveCustomExerciseLocal(
      userId: 'other-user',
      exercise: const ExerciseCatalogEntry(
        id: 'custom-other',
        name: 'Otro',
        muscleGroup: 'General',
        isCustom: true,
      ),
    );

    final items = await store.loadCustomExercises('custom-user');

    expect(items.map((item) => item.id), ['custom-b', 'custom-a']);
    expect(items.every((item) => item.isCustom), isTrue);
    expect(items.first.imageUri, 'agujetas-image://ag_row');

    await store.saveCustomExerciseLocal(
      userId: 'custom-user',
      exercise: newer.copyWith(name: 'Remo propio editado'),
    );
    final edited = await store.loadCustomExercises('custom-user');
    expect(edited.first.name, 'Remo propio editado');
    expect(edited, hasLength(2));

    await store.deleteCustomExerciseLocal(
      userId: 'custom-user',
      exerciseId: 'custom-b',
    );
    final remaining = await store.loadCustomExercises('custom-user');
    expect(remaining.map((item) => item.id), ['custom-a']);
  });

  test(
    'legacy history importer groups exported rows into local sessions',
    () async {
      final result = await LegacyHistoryImporter.loadBundled(
        userId: 'import-user',
      );

      expect(result.sessions, hasLength(20));
      expect(result.skippedRows, lessThanOrEqualTo(3));
      expect(result.sessions.first.exercises, isNotEmpty);
      expect(result.sessions.first.finishedAt.year, 2026);
      expect(
        result.sessions.expand((session) => session.exercises),
        anyElement((exercise) => exercise.name == 'Curl bíceps predicador'),
      );
    },
  );

  test(
    'legacy history importer preserves hyphen weights as backoff segments',
    () {
      final result = LegacyHistoryImporter.parseRows(
        userId: 'import-user',
        rows: [
          {
            'fecha_hora_iso': '2026-02-19T00:00:00+01:00',
            'rutina': 'Push-Pull-Piernas',
            'duracion_seg': '3883',
            'orden_ejercicio': '1',
            'numero_serie': '5',
            'musculo': 'Espalda',
            'ejercicio': 'Jalón lateral alternativo',
            'repeticiones': '10',
            'peso_kg': '25-15',
            'rir': '0',
          },
        ],
      );

      final set = result.sessions.single.exercises.single.sets.single;

      expect(set.segments, hasLength(2));
      expect(set.segments.first.weightKg, 25);
      expect(set.segments.first.reps, 10);
      expect(set.segments.last.weightKg, 15);
      expect(set.segments.last.reps, 0);
      expect(set.hasBackoffSegment, isTrue);
    },
  );

  test(
    'local workout store imports legacy sessions only once by stable id',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = LocalWorkoutStore.instance;
      final result = LegacyHistoryImporter.parseRows(
        userId: 'dedupe-user',
        rows: [
          {
            'fecha_hora_iso': '2026-02-19T00:00:00+01:00',
            'rutina': 'Push-Pull-Piernas',
            'duracion_seg': '3883',
            'orden_ejercicio': '1',
            'numero_serie': '1',
            'musculo': 'Espalda',
            'ejercicio': 'Remo sentado con espalda recta y cable',
            'repeticiones': '15',
            'peso_kg': '26',
          },
        ],
      );

      final first = await store.saveImportedSessions(
        userId: 'dedupe-user',
        sessions: result.sessions,
      );
      final second = await store.saveImportedSessions(
        userId: 'dedupe-user',
        sessions: result.sessions,
      );
      final sessions = await store.loadSessions('dedupe-user');

      expect(first, 1);
      expect(second, 0);
      expect(sessions, hasLength(1));
    },
  );

  test(
    'legacy routine importer loads custom sessions as routine templates',
    () async {
      final result = await LegacyHistoryImporter.loadBundledRoutines(
        userId: 'routine-user',
      );

      expect(result.routines.length, greaterThanOrEqualTo(15));
      expect(
        result.routines,
        anyElement(
          isA<RoutineTemplate>()
              .having((routine) => routine.title, 'title', 'Push 2')
              .having((routine) => routine.exercises.length, 'exercises', 6),
        ),
      );
      final pushSmith = result.routines.firstWhere(
        (routine) => routine.title == 'Push Smith',
      );
      final backoffSet = pushSmith.exercises
          .expand((exercise) => exercise.sets)
          .firstWhere((set) => set.hasBackoffSegment);
      expect(
        backoffSet.segments.map((segment) => segment.weightKg),
        contains(20),
      );
    },
  );

  test(
    'local workout store imports legacy routines only once by stable id',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = LocalWorkoutStore.instance;
      final result = await LegacyHistoryImporter.loadBundledRoutines(
        userId: 'routine-dedupe-user',
      );

      final first = await store.saveImportedRoutineTemplates(
        userId: 'routine-dedupe-user',
        routines: result.routines,
      );
      final second = await store.saveImportedRoutineTemplates(
        userId: 'routine-dedupe-user',
        routines: result.routines,
      );
      final routines = await store.loadRoutineTemplates('routine-dedupe-user');

      expect(first, greaterThan(0));
      expect(second, 0);
      expect(routines.length, first);
      expect(routines, anyElement((routine) => routine.title == 'Push 2'));
    },
  );

  test('local workout store preserves routine CRUD order', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalWorkoutStore.instance;
    final exercises = seedWorkout();
    final first = RoutineTemplate(
      id: 'routine-a',
      ownerId: 'other-owner',
      title: 'Piernas',
      exercises: exercises.take(2).toList(),
    );
    final second = RoutineTemplate(
      id: 'routine-b',
      ownerId: 'other-owner',
      title: 'Espalda',
      exercises: exercises.skip(1).take(2).toList(),
    );

    await store.saveRoutineTemplateLocal(userId: 'crud-user', routine: first);
    await store.saveRoutineTemplateLocal(userId: 'crud-user', routine: second);

    final inserted = await store.loadRoutineTemplates('crud-user');
    expect(inserted.map((routine) => routine.id), ['routine-b', 'routine-a']);
    expect(inserted.every((routine) => routine.ownerId == 'crud-user'), true);

    await store.replaceRoutineTemplates(
      userId: 'crud-user',
      routines: [inserted.last, inserted.first],
    );
    final reordered = await store.loadRoutineTemplates('crud-user');
    expect(reordered.map((routine) => routine.id), ['routine-a', 'routine-b']);

    await store.saveRoutineTemplateLocal(
      userId: 'crud-user',
      routine: reordered.first.copyWith(title: 'Piernas pesado'),
    );
    final renamed = await store.loadRoutineTemplates('crud-user');
    expect(renamed.first.title, 'Piernas pesado');

    await store.deleteRoutineTemplate(
      userId: 'crud-user',
      routineId: 'routine-a',
    );
    final remaining = await store.loadRoutineTemplates('crud-user');
    expect(remaining.map((routine) => routine.id), ['routine-b']);
  });

  test('local backup exports and imports all local-first data', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalWorkoutStore.instance;
    final session = await store.saveSession(
      userId: 'backup-source',
      sessionMode: 'Fuerza',
      exercises: seedWorkout(),
      duration: const Duration(minutes: 45),
    );
    await store.updateSessionLocal(
      userId: 'backup-source',
      session: session.copyWith(title: 'Push pesado', note: 'Buen control.'),
    );
    await store.saveRoutineTemplateLocal(
      userId: 'backup-source',
      routine: RoutineTemplate(
        id: 'backup-routine',
        ownerId: 'other-owner',
        title: 'Rutina backup',
        exercises: seedWorkout(),
      ),
    );
    await store.saveBodyWeightLocal(
      userId: 'backup-source',
      entry: BodyWeightEntry(
        id: 'backup-weight',
        userId: 'other-owner',
        weightKg: 82.5,
        recordedAt: DateTime.utc(2026, 5, 31),
      ),
    );
    await store.saveCustomExerciseLocal(
      userId: 'backup-source',
      exercise: const ExerciseCatalogEntry(
        id: 'backup-custom',
        name: 'Remo propio backup',
        muscleGroup: 'Espalda',
        imageUri: 'agujetas-image://ag_backup_row',
        isCustom: true,
      ),
    );

    final rawJson = await store.exportBackupJson('backup-source');
    final decoded = jsonDecode(rawJson) as Map<String, Object?>;

    expect(decoded['schema'], 'agujetas.localBackup');
    expect(decoded['schemaVersion'], 1);
    expect(decoded['sessions'], isA<List<dynamic>>());

    SharedPreferences.setMockInitialValues({});
    final result = await store.importBackupJson(
      userId: 'backup-target',
      rawJson: rawJson,
    );

    expect(result.sessions, 1);
    expect(result.routines, 1);
    expect(result.bodyWeights, 1);
    expect(result.customExercises, 1);
    expect(result.total, 4);

    final sessions = await store.loadSessions('backup-target');
    final routines = await store.loadRoutineTemplates('backup-target');
    final bodyWeights = await store.loadBodyWeights('backup-target');
    final customExercises = await store.loadCustomExercises('backup-target');

    expect(sessions.single.userId, 'backup-target');
    expect(sessions.single.title, 'Push pesado');
    expect(routines.single.ownerId, 'backup-target');
    expect(bodyWeights.single.userId, 'backup-target');
    expect(customExercises.single.isCustom, isTrue);
    expect(customExercises.single.imageUri, 'agujetas-image://ag_backup_row');
  });

  test('local backup rejects non Agujetas JSON', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalWorkoutStore.instance;

    expect(
      () => store.importBackupJson(
        userId: 'backup-target',
        rawJson: '{"schema":"otra.app"}',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
