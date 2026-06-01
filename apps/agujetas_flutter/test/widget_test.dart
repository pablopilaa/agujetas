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

  testWidgets(
    'library creates a named routine draft and adds catalog exercises',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        AgujetasApp(repository: DemoAgujetasRepository()),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Biblioteca'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mis ejercicios'));
      await tester.pumpAndSettle();

      final newRoutineButton = find.widgetWithText(
        OutlinedButton,
        'Nueva rutina',
      );
      await tester.ensureVisible(newRoutineButton.first);
      await tester.tap(newRoutineButton.first);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Empuje viernes');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
      await tester.pumpAndSettle();

      expect(find.text('Editando: Empuje viernes'), findsOneWidget);
      expect(find.textContaining('0 ejercicios'), findsWidgets);

      final saveButton = find.byKey(const ValueKey('routine-save-changes'));

      await tester.tap(find.byKey(const ValueKey('routine-add-from-catalog')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Más usados'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('catalog-add-bench_press')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mis ejercicios'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 ejercicios'), findsWidgets);
      expect(saveButton, findsOneWidget);
    },
  );

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
              onCreateRoutine: (_) {},
              onSaveRoutine: (_) async {},
              onSaveEditingRoutine: () async {},
              onSaveEditingRoutineAsCopy: () async {},
              onDeleteRoutine: (_) async {},
              onDuplicateRoutine: (_) async {},
              onMoveRoutine: (_, _) async {},
              onSaveCustomExercise: (_) async {},
              onDeleteCustomExercise: (_) async {},
              localGalleryEnabled: true,
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

  testWidgets('library filter chips filter custom exercises', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const user = AppUser(
      uid: 'library-filter-user',
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
          body: LibraryScreen(
            user: user,
            repository: DemoAgujetasRepository(),
            exercises: seedWorkout(),
            localSessions: const [],
            routines: const [],
            editingRoutineId: null,
            editingRoutineTitle: null,
            customExercises: const [
              ExerciseCatalogEntry(
                id: 'custom-press-barra',
                name: 'Press filtro barra',
                muscleGroup: 'Pectoral',
                usageCount: 2,
                isCustom: true,
              ),
              ExerciseCatalogEntry(
                id: 'custom-crunch-peso-corporal',
                name: 'Crunch filtro peso corporal',
                muscleGroup: 'Abdomen',
                isCustom: true,
              ),
              ExerciseCatalogEntry(
                id: 'custom-remo-cable',
                name: 'Remo filtro cable',
                muscleGroup: 'Espalda',
                usageCount: 1,
                isCustom: true,
              ),
            ],
            onExercisesChanged: (_) {},
            onStartRoutine: (_) {},
            onEditRoutine: (_) {},
            onCreateRoutine: (_) {},
            onSaveRoutine: (_) async {},
            onSaveEditingRoutine: () async {},
            onSaveEditingRoutineAsCopy: () async {},
            onDeleteRoutine: (_) async {},
            onDuplicateRoutine: (_) async {},
            onMoveRoutine: (_, _) async {},
            onSaveCustomExercise: (_) async {},
            onDeleteCustomExercise: (_) async {},
            localGalleryEnabled: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mis ejercicios'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Grupo muscular'));
    await tester.tap(find.text('Grupo muscular'));
    await tester.pumpAndSettle();
    expect(find.text('Todos'), findsOneWidget);
    await tester.tap(find.text('Abdomen').last);
    await tester.pumpAndSettle();

    expect(find.text('Crunch filtro peso corporal'), findsOneWidget);
    expect(find.text('Remo filtro cable'), findsNothing);
    expect(find.text('Press filtro barra'), findsNothing);

    await tester.tap(find.text('Limpiar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Equipamiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Peso corporal').last);
    await tester.pumpAndSettle();

    expect(find.text('Crunch filtro peso corporal'), findsOneWidget);
    expect(find.text('Press filtro barra'), findsNothing);
    expect(find.text('Remo filtro cable'), findsNothing);

    await tester.tap(find.text('Limpiar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usados'));
    await tester.pumpAndSettle();

    expect(find.text('Press filtro barra'), findsOneWidget);
    expect(find.text('Remo filtro cable'), findsOneWidget);
    expect(find.text('Crunch filtro peso corporal'), findsNothing);
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
            alertsEnabled: true,
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

  testWidgets('body weight reminders respect tracking preference', (
    tester,
  ) async {
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
            alertsEnabled: false,
            onSaved: (_) async {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Alertarme cada mañana'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Activá Seguimiento de peso desde Perfil para programar alertas.',
      ),
      findsOneWidget,
    );
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

  testWidgets('custom exercise sheet respects local gallery preference', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AgujetasTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  await showModalBottomSheet<ExerciseCatalogEntry>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => CustomExerciseSheet(
                      catalogFuture: Future.value(const []),
                      allowLocalGallery: false,
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
    await tester.tap(find.widgetWithText(OutlinedButton, 'Galería'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Activá Galería local desde Perfil para usar imágenes del dispositivo.',
      ),
      findsOneWidget,
    );
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

  testWidgets(
    'disabled rest alerts still start countdown without notification',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        AgujetasApp(repository: DemoAgujetasRepository()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();

      final restAlertsSetting = find.text('Alertas de descanso');
      await tester.ensureVisible(restAlertsSetting);
      final restAlertsSwitch = find.descendant(
        of: find.ancestor(
          of: restAlertsSetting,
          matching: find.byType(ListTile),
        ),
        matching: find.byType(Switch),
      );
      await tester.tap(restAlertsSwitch);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Entrenar').last);
      await tester.pumpAndSettle();

      final restButton = find.descendant(
        of: find.byType(CurrentSetLogger),
        matching: find.byIcon(Icons.timer_outlined),
      );
      await tester.tap(restButton);
      await tester.pumpAndSettle();

      expect(find.text('01:30'), findsOneWidget);
      expect(
        find.text('Descanso iniciado sin alerta: activala desde Perfil'),
        findsOneWidget,
      );
    },
  );

  testWidgets('active workout draft restores timer values in training', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await LocalWorkoutStore.instance.saveActiveDraft(
      userId: 'demo-user',
      sessionMode: 'Hipertrofia',
      exercises: seedWorkout(),
      totalElapsed: const Duration(minutes: 3, seconds: 5),
      restRemaining: const Duration(seconds: 30),
    );

    await tester.pumpWidget(AgujetasApp(repository: DemoAgujetasRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entrenar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Entrenar · Hipertrofia'), findsOneWidget);
    expect(find.text('03:05'), findsWidgets);
    expect(find.text('00:30'), findsOneWidget);
  });

  testWidgets(
    'progress screen derives volume and dropsets from local sessions',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now().toUtc();
      const user = AppUser(
        uid: 'progress-user',
        displayName: 'Demo',
        email: 'demo@agujetas.app',
        photoUrl: null,
        roles: {AppRole.normal},
        activeRole: AppRole.normal,
        plan: AppPlan.free,
      );
      final current = LocalWorkoutSession(
        id: 'current-week',
        userId: user.uid,
        sessionMode: 'Fuerza',
        startedAt: now.subtract(const Duration(days: 1, minutes: 50)),
        finishedAt: now.subtract(const Duration(days: 1)),
        durationSeconds: 3000,
        exercises: const [
          WorkoutExercise(
            id: 'bench',
            name: 'Press banca',
            muscleGroup: 'Pectoral',
            isUnilateral: false,
            sets: [
              WorkoutSet(
                order: 1,
                setType: SetType.normal,
                segments: [WeightSegment(weightKg: 100, reps: 5)],
              ),
              WorkoutSet(
                order: 2,
                setType: SetType.dropset,
                segments: [WeightSegment(weightKg: 80, reps: 5)],
              ),
            ],
          ),
        ],
      );
      final previous = LocalWorkoutSession(
        id: 'previous-week',
        userId: user.uid,
        sessionMode: 'Fuerza',
        startedAt: now.subtract(const Duration(days: 8, minutes: 40)),
        finishedAt: now.subtract(const Duration(days: 8)),
        durationSeconds: 2400,
        exercises: const [
          WorkoutExercise(
            id: 'bench',
            name: 'Press banca',
            muscleGroup: 'Pectoral',
            isUnilateral: false,
            sets: [
              WorkoutSet(
                order: 1,
                setType: SetType.normal,
                segments: [WeightSegment(weightKg: 50, reps: 5)],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AgujetasTheme.light(),
          home: Scaffold(
            body: ProgressScreen(
              user: user,
              repository: DemoAgujetasRepository(),
              exercises: seedWorkout(),
              localSessions: [current, previous],
              bodyWeights: const [],
              bodyWeightAlertsEnabled: false,
              onOpenCalendar: () {},
              onBodyWeightSaved: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('+260.0% vs semana previa, desde historial local.'),
        findsOneWidget,
      );
      expect(find.text('Historial local'), findsOneWidget);
      expect(find.text('Press banca'), findsWidgets);
      expect(
        find.text('900 kg-reps sin contar calentamientos'),
        findsOneWidget,
      );
      expect(find.text('1 de 2 series efectivas'), findsOneWidget);
    },
  );

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
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -900));
    await tester.pumpAndSettle();
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

    await tester.drag(find.byType(Scrollable).last, const Offset(0, -900));
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

    await tester.drag(find.byType(Scrollable).last, const Offset(0, -900));
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
    final olderHistoricalExercise = exercise.copyWith(
      sets: const [
        WorkoutSet(
          order: 1,
          setType: SetType.normal,
          segments: [WeightSegment(weightKg: 80, reps: 5)],
          rir: 2,
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
    final olderSession = LocalWorkoutSession(
      id: 'exercise-history-older-session',
      userId: 'exercise-history-user',
      sessionMode: 'Hipertrofia',
      exercises: [olderHistoricalExercise],
      startedAt: DateTime(2026, 5, 18, 10),
      finishedAt: DateTime(2026, 5, 18, 11),
      durationSeconds: 3600,
    );
    final historyRecords = ExerciseHistoryRecord.findAll([
      session,
      olderSession,
    ], exercise);

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

    await tester.tap(find.text('Ver progreso'));
    await tester.pumpAndSettle();

    expect(find.text('Progreso por ejercicio'), findsOneWidget);
    expect(find.text('Evolución de volumen'), findsOneWidget);
    expect(find.text('Historial completo'), findsOneWidget);
    expect(find.text('Cambio volumen'), findsOneWidget);
    expect(find.textContaining('+'), findsWidgets);

    Navigator.of(tester.element(find.text('Progreso por ejercicio'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Usar último'));
    await tester.pumpAndSettle();

    expect(exercise.sets.first.primaryWeightKg, 123);
    expect(exercise.sets.first.totalReps, 4);
    expect(exercise.sets.first.rir, 1);
  });

  testWidgets('monthly calendar edits and deletes local session metadata', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var savedSession = LocalWorkoutSession(
      id: 'editable-session',
      userId: 'calendar-edit-user',
      sessionMode: 'Fuerza',
      exercises: seedWorkout(),
      startedAt: DateTime(2026, 5, 20, 10),
      finishedAt: DateTime.now().toUtc(),
      durationSeconds: 3600,
    );
    var deleted = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AgujetasTheme.light(),
        home: Scaffold(
          body: MonthlySessionCalendarSheet(
            sessions: [savedSession],
            onUpdateSession: (session) async => savedSession = session,
            onDeleteSession: (session) async => deleted = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Fuerza · Press banca').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Editar nota'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre'),
      'Push corregido',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Nota'),
      'Bajé carga por técnica.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(savedSession.title, 'Push corregido');
    expect(savedSession.note, 'Bajé carga por técnica.');
    expect(find.text('Push corregido'), findsWidgets);

    await tester.tap(find.text('Push corregido').first);
    await tester.pumpAndSettle();
    expect(find.text('Bajé carga por técnica.'), findsOneWidget);

    await tester.tap(find.text('Borrar').first);
    await tester.pumpAndSettle();
    expect(find.text('Borrar sesión'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
    expect(find.text('Sin entrenos en este mes'), findsOneWidget);
    expect(find.text('Push corregido'), findsNothing);
  });

  testWidgets('profile exports and imports local backup JSON', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? importedRawJson;
    var exported = false;
    var legacyImported = false;
    var preferences = const LocalUserPreferences();
    const backupJson =
        '{"schema":"agujetas.localBackup","schemaVersion":1,"sessions":[]}';
    const user = AppUser(
      uid: 'profile-backup-user',
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
          body: ProfileScreen(
            user: user,
            repository: DemoAgujetasRepository(),
            themeMode: ThemeMode.light,
            preferences: preferences,
            onThemeModeChanged: (_) {},
            onPreferencesChanged: (next) => preferences = next,
            onExportLocalBackup: () async {
              exported = true;
              return backupJson;
            },
            onImportLocalBackup: (rawJson) async {
              importedRawJson = rawJson;
              return const LocalBackupImportResult(
                sessions: 1,
                routines: 2,
                bodyWeights: 3,
                customExercises: 4,
              );
            },
            onImportBundledLegacyData: () async {
              legacyImported = true;
              return const LegacyLocalImportResult(
                importedSessions: 5,
                availableSessions: 20,
                skippedHistoryRows: 1,
                importedRoutines: 6,
                availableRoutines: 16,
              );
            },
            onDeleteLocalAccount: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final exportAction = find.text('Exportar mis datos');
    await tester.ensureVisible(exportAction);
    await tester.tapAt(tester.getCenter(exportAction));
    await tester.pumpAndSettle();

    expect(exported, isTrue);
    expect(find.text('Respaldo local exportado'), findsOneWidget);
    expect(find.text(backupJson), findsOneWidget);

    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();

    final importAction = find.text('Importar respaldo');
    await tester.ensureVisible(importAction);
    await tester.tapAt(tester.getCenter(importAction));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'JSON de respaldo'),
      backupJson,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Importar'));
    await tester.pumpAndSettle();

    expect(importedRawJson, backupJson);
    expect(
      find.textContaining('1 sesiones, 2 rutinas, 3 pesos'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));

    final legacyAction = find.text('Importar datos legacy incluidos');
    await tester.ensureVisible(legacyAction);
    await tester.tapAt(tester.getCenter(legacyAction));
    await tester.pumpAndSettle();

    expect(find.text('Importar datos legacy'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Importar'));
    await tester.pumpAndSettle();

    expect(legacyImported, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.textContaining('5 sesiones y 6 rutinas nuevas'),
      findsOneWidget,
    );
  });

  testWidgets('profile permission toggles emit persistent preferences', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var preferences = const LocalUserPreferences();
    const user = AppUser(
      uid: 'profile-preferences-user',
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
            builder: (context, setState) => ProfileScreen(
              user: user,
              repository: DemoAgujetasRepository(),
              themeMode: ThemeMode.light,
              preferences: preferences,
              onThemeModeChanged: (_) {},
              onPreferencesChanged: (next) =>
                  setState(() => preferences = next),
              onExportLocalBackup: () async => '{}',
              onImportLocalBackup: (_) async => const LocalBackupImportResult(
                sessions: 0,
                routines: 0,
                bodyWeights: 0,
                customExercises: 0,
              ),
              onImportBundledLegacyData: () async =>
                  const LegacyLocalImportResult(
                    importedSessions: 0,
                    availableSessions: 0,
                    skippedHistoryRows: 0,
                    importedRoutines: 0,
                    availableRoutines: 0,
                  ),
              onDeleteLocalAccount: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gallerySetting = find.text('Galería local');
    await tester.ensureVisible(gallerySetting);
    expect(preferences.localGalleryEnabled, isFalse);

    final gallerySwitch = find.descendant(
      of: find.ancestor(of: gallerySetting, matching: find.byType(ListTile)),
      matching: find.byType(Switch),
    );
    await tester.tap(gallerySwitch);
    await tester.pumpAndSettle();

    expect(preferences.localGalleryEnabled, isTrue);
    expect(preferences.restAlertsEnabled, isTrue);
    expect(preferences.bodyWeightAlertsEnabled, isTrue);
  });

  testWidgets('profile delete account confirms local data wipe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var deleted = false;
    const user = AppUser(
      uid: 'profile-delete-user',
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
          body: ProfileScreen(
            user: user,
            repository: DemoAgujetasRepository(),
            themeMode: ThemeMode.light,
            preferences: const LocalUserPreferences(),
            onThemeModeChanged: (_) {},
            onPreferencesChanged: (_) {},
            onExportLocalBackup: () async => '{}',
            onImportLocalBackup: (_) async => const LocalBackupImportResult(
              sessions: 0,
              routines: 0,
              bodyWeights: 0,
              customExercises: 0,
            ),
            onImportBundledLegacyData: () async =>
                const LegacyLocalImportResult(
                  importedSessions: 0,
                  availableSessions: 0,
                  skippedHistoryRows: 0,
                  importedRoutines: 0,
                  availableRoutines: 0,
                ),
            onDeleteLocalAccount: () async => deleted = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final deleteAction = find.text('Eliminar cuenta');
    await tester.ensureVisible(deleteAction);
    await tester.tapAt(tester.getCenter(deleteAction));
    await tester.pumpAndSettle();

    expect(find.text('Eliminar cuenta local'), findsOneWidget);
    expect(
      find.textContaining('No elimina todavía documentos remotos de Firestore'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Borrar datos locales'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
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
