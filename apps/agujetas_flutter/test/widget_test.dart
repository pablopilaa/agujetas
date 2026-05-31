import 'package:agujetas_flutter/app_theme.dart';
import 'package:agujetas_flutter/local_workout_store.dart';
import 'package:agujetas_flutter/main.dart';
import 'package:agujetas_flutter/models.dart';
import 'package:agujetas_flutter/repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('demo user can switch to trainer dashboard', (tester) async {
    await tester.pumpWidget(AgujetasApp(repository: DemoAgujetasRepository()));
    await tester.pump();

    expect(find.text('Inicio'), findsWidgets);
    expect(find.text('Modo de cuenta'), findsOneWidget);
    expect(find.text('Modo usuario'), findsOneWidget);
    expect(find.text('Modo entrenador'), findsOneWidget);

    await tester.tap(find.text('Modo entrenador').first);
    await tester.pumpAndSettle();

    expect(find.text('Modo entrenador es Pro'), findsOneWidget);
    expect(find.text('Activar Pro demo'), findsOneWidget);

    await tester.tap(find.text('Activar Pro demo'));
    await tester.pumpAndSettle();

    expect(find.text('Panel entrenador'), findsOneWidget);
    expect(find.text('Sumar entrenados'), findsOneWidget);
  });

  testWidgets(
    'training flow exposes unilateral, set type and second weight controls',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        AgujetasApp(repository: DemoAgujetasRepository()),
      );
      await tester.pump();

      await tester.tap(find.text('Entrenar'));
      await tester.pumpAndSettle();

      expect(find.text('Press banca'), findsWidgets);
      expect(find.text('Bi'), findsWidgets);
      expect(find.text('Uni'), findsWidgets);
      expect(find.text('Cal'), findsWidgets);
      expect(find.text('Drop'), findsWidgets);
      expect(find.text('RIR'), findsWidgets);

      final addSecondWeight = find.text('Agregar peso 2').first;
      await tester.ensureVisible(addSecondWeight);
      await tester.tap(addSecondWeight);
      await tester.pumpAndSettle();

      expect(find.text('Peso 2 / backoff'), findsWidgets);
    },
  );

  testWidgets('session mode chips open training with selected intent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(AgujetasApp(repository: DemoAgujetasRepository()));
    await tester.pump();

    await tester.tap(find.text('Hipertrofia').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Entrenar · Hipertrofia'), findsOneWidget);
    expect(find.text('Modo Hipertrofia'), findsOneWidget);
  });

  testWidgets('home exposes imported legacy routines and can start one', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(AgujetasApp(repository: DemoAgujetasRepository()));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Rutinas importadas'), findsOneWidget);

    final startButton = find.widgetWithText(FilledButton, 'Iniciar').first;
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('Entrenar · Fuerza'), findsOneWidget);
    expect(find.textContaining('Empuje A'), findsNothing);
  });

  testWidgets('library can load an imported routine into the local editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(AgujetasApp(repository: DemoAgujetasRepository()));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Biblioteca'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mis ejercicios'));
    await tester.pumpAndSettle();

    expect(find.text('Rutinas legacy importadas'), findsOneWidget);

    final editButton = find.widgetWithText(OutlinedButton, 'Editar').first;
    await tester.ensureVisible(editButton);
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    expect(find.text('En edición'), findsOneWidget);

    await tester.tap(find.text('Entrenar').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Empuje A'), findsOneWidget);
    expect(find.text('Press banca'), findsWidgets);
  });

  testWidgets('library removes an exercise from the routine order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var exercises = seedWorkout();
    const user = AppUser(
      uid: 'library-remove-user',
      displayName: 'Demo',
      email: 'demo@agujetas.app',
      photoUrl: null,
      roles: {AppRole.normal},
      activeRole: AppRole.normal,
      plan: AppPlan.free,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AgujetasTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => LibraryScreen(
              user: user,
              repository: DemoAgujetasRepository(),
              exercises: exercises,
              localSessions: const [],
              routines: const [],
              editingRoutineId: 'routine-edit',
              editingRoutineTitle: 'Rutina editable',
              customExercises: const [],
              onExercisesChanged: (next) => setState(() => exercises = next),
              onStartRoutine: (_) {},
              onEditRoutine: (_) {},
              onSaveRoutine: (_) async {},
              onSaveEditingRoutine: () async {},
              onSaveEditingRoutineAsCopy: () async {},
              onDeleteRoutine: (_) async {},
              onDuplicateRoutine: (_) async {},
              onMoveRoutine: (_, _) async {},
              onSaveCustomExercise: (_) async {},
              onDeleteCustomExercise: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Press banca'), findsOneWidget);

    await tester.tap(find.byTooltip('Quitar de rutina').first);
    await tester.pumpAndSettle();

    expect(find.text('Quitar ejercicio'), findsOneWidget);
    expect(
      find.textContaining('No borra tu historial ni el catálogo'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Quitar'));
    await tester.pumpAndSettle();

    expect(find.text('Press banca'), findsNothing);
  });

  testWidgets('routine defaults sheet edits template set defaults', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    WorkoutExercise? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: AgujetasTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  saved = await showRoutineExerciseDefaultsSheet(
                    context,
                    exercise: seedWorkout().first,
                  );
                },
                child: const Text('Abrir defaults'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir defaults'));
    await tester.pumpAndSettle();

    expect(find.text('Editar defaults'), findsOneWidget);
    expect(find.text('Series predeterminadas'), findsOneWidget);
    expect(find.text('RIR'), findsWidgets);

    final addSet = find.widgetWithText(OutlinedButton, 'Agregar serie');
    await tester.ensureVisible(addSet);
    await tester.tap(addSet);
    await tester.pumpAndSettle();

    expect(find.text('S4'), findsOneWidget);

    await tester.tap(find.text('Guardar defaults'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.sets, hasLength(4));
  });

  testWidgets('body weight card saves through local-first callback', (
    tester,
  ) async {
    BodyWeightEntry? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: AgujetasTheme.light(),
        home: Scaffold(
          body: BodyWeightCard(
            user: const AppUser(
              uid: 'weight-user',
              displayName: 'Demo',
              email: 'demo@agujetas.app',
              photoUrl: null,
              roles: {AppRole.normal},
              activeRole: AppRole.normal,
              plan: AppPlan.free,
            ),
            entries: const [],
            onSaved: (entry) async => saved = entry,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '81,7');
    await tester.tap(find.text('Guardar peso'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.userId, 'weight-user');
    expect(saved!.weightKg, 81.7);
  });

  testWidgets('custom exercise sheet creates a local exercise with 3 sets', (
    tester,
  ) async {
    ExerciseCatalogEntry? created;
    await tester.pumpWidget(
      MaterialApp(
        theme: AgujetasTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  created = await showModalBottomSheet<ExerciseCatalogEntry>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => CustomExerciseSheet(
                      catalogFuture: Future.value(const []),
                    ),
                  );
                },
                child: const Text('Abrir custom'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir custom'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Press raro');
    await tester.tap(find.text('Crear con 3 series'));
    await tester.pumpAndSettle();

    expect(created, isNotNull);
    expect(created!.name, 'Press raro');
    expect(created!.isCustom, isTrue);
    expect(created!.toWorkoutExercise().sets, hasLength(3));
  });

  testWidgets('custom exercise sheet edits an existing local exercise', (
    tester,
  ) async {
    ExerciseCatalogEntry? edited;
    const initial = ExerciseCatalogEntry(
      id: 'custom-edit',
      name: 'Press viejo',
      muscleGroup: 'Pectoral',
      imageUri: 'agujetas-image://ag_press',
      isCustom: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AgujetasTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  edited = await showModalBottomSheet<ExerciseCatalogEntry>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => CustomExerciseSheet(
                      catalogFuture: Future.value(const []),
                      initialExercise: initial,
                    ),
                  );
                },
                child: const Text('Editar custom'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Editar custom'));
    await tester.pumpAndSettle();

    expect(find.text('Editar ejercicio'), findsOneWidget);
    expect(find.text('Guardar cambios'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Press nuevo');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(edited, isNotNull);
    expect(edited!.id, 'custom-edit');
    expect(edited!.name, 'Press nuevo');
    expect(edited!.imageUri, 'agujetas-image://ag_press');
  });

  testWidgets('training flow edits a custom exercise already in session', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(AgujetasApp(repository: DemoAgujetasRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Biblioteca'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear ejercicio personalizado').first);
    await tester.pumpAndSettle();
    final nameField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Nombre',
    );
    await tester.enterText(nameField, 'Press custom');
    await tester.tap(find.text('Crear con 3 series'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entrenar').last);
    await tester.pumpAndSettle();

    final customExercise = find.text('Press custom');
    await tester.ensureVisible(customExercise);
    expect(customExercise, findsOneWidget);

    await tester.tap(find.byTooltip('Opciones del ejercicio').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar ejercicio'));
    await tester.pumpAndSettle();

    expect(find.text('Editar ejercicio'), findsOneWidget);
    await tester.enterText(nameField, 'Press custom editado');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(find.text('Press custom editado'), findsOneWidget);
    expect(find.text('Press custom'), findsNothing);
  });

  testWidgets('training flow removes an exercise from active session', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(AgujetasApp(repository: DemoAgujetasRepository()));
    await tester.pump();

    await tester.tap(find.text('Entrenar'));
    await tester.pumpAndSettle();

    expect(find.text('Press banca'), findsWidgets);

    await tester.tap(find.byTooltip('Opciones del ejercicio').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar de sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Quitar ejercicio'), findsOneWidget);
    expect(
      find.textContaining('No borra tu historial ni el catálogo'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Quitar'));
    await tester.pumpAndSettle();

    expect(find.text('Press banca'), findsNothing);
  });

  testWidgets('training timers expose start, pause and reset controls', (
    tester,
  ) async {
    await tester.pumpWidget(AgujetasApp(repository: DemoAgujetasRepository()));
    await tester.pump();

    await tester.tap(find.text('Entrenar'));
    await tester.pumpAndSettle();

    expect(find.text('Tiempo total'), findsOneWidget);
    expect(find.text('Descanso'), findsOneWidget);
    expect(find.text('Iniciar'), findsWidgets);

    await tester.tap(find.text('Iniciar').first);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Pausar'), findsWidgets);

    await tester.tap(find.byIcon(Icons.restart_alt).first);
    await tester.pumpAndSettle();

    expect(find.text('00:00'), findsOneWidget);
  });

  testWidgets('training mode dropdown confirms reset after session activity', (
    tester,
  ) async {
    await tester.pumpWidget(AgujetasApp(repository: DemoAgujetasRepository()));
    await tester.pump();

    await tester.tap(find.text('Entrenar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Modo Fuerza'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modo Técnica').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Entrenar · Técnica'), findsOneWidget);

    await tester.tap(find.text('Iniciar').first);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Modo Técnica'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modo Libre').last);
    await tester.pumpAndSettle();

    expect(find.text('Cambiar modo de sesión'), findsOneWidget);
    expect(find.text('Cambiar y reiniciar'), findsOneWidget);
  });

  testWidgets('weekly summary opens the monthly session calendar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(AgujetasApp(repository: DemoAgujetasRepository()));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ver mes'));
    await tester.pumpAndSettle();

    expect(find.text('Calendario mensual'), findsOneWidget);
    expect(
      find.text(
        'Tocá un día con marca para revisar entrenamientos guardados en este dispositivo.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Sesiones de'), findsOneWidget);
    expect(find.textContaining('Push-Pull-Piernas'), findsWidgets);
    expect(find.text('Sin entrenos locales todavía'), findsNothing);
  });

  testWidgets('finalized session appears in local monthly calendar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(AgujetasApp(repository: DemoAgujetasRepository()));
    await tester.pump();

    await tester.tap(find.text('Entrenar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Progreso'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Calendario'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sesiones de'), findsOneWidget);
    expect(find.textContaining('Fuerza · Press banca'), findsWidgets);
    expect(find.text('Sin entrenos locales todavía'), findsNothing);
  });

  testWidgets(
    'monthly calendar navigates months and opens full session detail',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final previousMonth = DateTime(now.year, now.month - 1, 15, 20);
      final session = LocalWorkoutSession(
        id: 'session-previous-month',
        userId: 'calendar-user',
        sessionMode: 'Fuerza',
        exercises: seedWorkout(),
        startedAt: previousMonth.subtract(const Duration(minutes: 58)).toUtc(),
        finishedAt: previousMonth.toUtc(),
        durationSeconds: 58 * 60,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AgujetasTheme.light(),
          home: Scaffold(
            body: MonthlySessionCalendarSheet(sessions: [session]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();

      expect(
        find.text('1 sesión en ${_monthNameForTest(previousMonth.month)}'),
        findsOneWidget,
      );
      expect(find.textContaining('Fuerza · Press banca'), findsWidgets);

      await tester.tap(find.textContaining('Fuerza · Press banca').first);
      await tester.pumpAndSettle();

      expect(find.text('Series registradas'), findsWidgets);
      expect(find.textContaining('RIR'), findsWidgets);
      expect(find.textContaining('kg x'), findsWidgets);
    },
  );

  testWidgets('session history can be repeated as active workout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(AgujetasApp(repository: DemoAgujetasRepository()));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ver mes'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Push-Pull-Piernas').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Repetir sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Finalizar'), findsOneWidget);
    expect(find.textContaining('Entrenar · Libre'), findsOneWidget);
    expect(find.textContaining('Repetir Push-Pull-Piernas'), findsOneWidget);
  });

  testWidgets('session history can be saved as a local routine', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(AgujetasApp(repository: DemoAgujetasRepository()));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ver mes'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Push-Pull-Piernas').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar rutina'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Biblioteca'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mis ejercicios'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Rutina desde'), findsOneWidget);
    expect(
      find.textContaining('rutinas y sesiones personalizadas'),
      findsOneWidget,
    );
  });

  testWidgets('exercise detail shows history and applies last defaults', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var exercise = seedWorkout().first.copyWith(
      sets: const [
        WorkoutSet(
          order: 1,
          setType: SetType.normal,
          segments: [WeightSegment(weightKg: 20, reps: 6)],
          rir: 3,
        ),
      ],
    );
    final historicalExercise = exercise.copyWith(
      sets: const [
        WorkoutSet(
          order: 1,
          setType: SetType.normal,
          segments: [WeightSegment(weightKg: 123, reps: 4)],
          rir: 1,
        ),
      ],
    );
    final session = LocalWorkoutSession(
      id: 'exercise-history-session',
      userId: 'exercise-history-user',
      sessionMode: 'Fuerza',
      exercises: [historicalExercise],
      startedAt: DateTime(2026, 5, 20, 10),
      finishedAt: DateTime(2026, 5, 20, 11),
      durationSeconds: 3600,
    );
    final historyRecords = ExerciseHistoryRecord.findAll([session], exercise);

    await tester.pumpWidget(
      MaterialApp(
        theme: AgujetasTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SizedBox(
              height: 900,
              child: ReorderableListView(
                buildDefaultDragHandles: false,
                onReorder: (_, _) {},
                children: [
                  ExerciseCard(
                    key: const ValueKey('history-card'),
                    index: 0,
                    exercise: exercise,
                    historyRecords: historyRecords,
                    latestRecord: historyRecords.first,
                    onChanged: (updated) => setState(() => exercise = updated),
                    onRemove: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Opciones del ejercicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Detalle'));
    await tester.pumpAndSettle();

    expect(find.text('Progreso del ejercicio'), findsOneWidget);
    expect(find.text('Mejor peso'), findsOneWidget);
    expect(find.text('Registros recientes'), findsOneWidget);
    expect(find.textContaining('123 kg x 4'), findsWidgets);

    await tester.tap(find.text('Usar último'));
    await tester.pumpAndSettle();

    expect(exercise.sets.first.primaryWeightKg, 123);
    expect(exercise.sets.first.totalReps, 4);
    expect(exercise.sets.first.rir, 1);
  });
}

String _monthNameForTest(int month) => const [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
][month - 1];
