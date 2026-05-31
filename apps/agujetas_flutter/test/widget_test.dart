import 'package:agujetas_flutter/app_theme.dart';
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
    expect(find.text('Entrenos recientes'), findsOneWidget);
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

    expect(find.text('Entrenos recientes'), findsOneWidget);
    expect(find.textContaining('Fuerza · Press banca'), findsWidgets);
    expect(find.text('Sin entrenos locales todavía'), findsNothing);
  });
}
