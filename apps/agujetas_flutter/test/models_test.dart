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
}
