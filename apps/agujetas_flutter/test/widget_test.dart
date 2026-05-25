import 'package:agujetas_flutter/main.dart';
import 'package:agujetas_flutter/repositories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('demo user can switch to trainer dashboard', (tester) async {
    await tester.pumpWidget(AgujetasApp(repository: DemoAgujetasRepository()));
    await tester.pump();

    expect(find.text('Inicio'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Entrenamiento autogestionado'),
      300,
    );
    expect(find.text('Entrenamiento autogestionado'), findsOneWidget);

    await tester.tap(find.text('Entrenador').first);
    await tester.pumpAndSettle();

    expect(find.text('Panel entrenador'), findsOneWidget);
    expect(find.text('Sumar entrenados'), findsOneWidget);
  });

  testWidgets(
    'training flow exposes unilateral, set type and second weight controls',
    (tester) async {
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
    await tester.pumpWidget(AgujetasApp(repository: DemoAgujetasRepository()));
    await tester.pump();

    await tester.tap(find.text('Hipertrofia'));
    await tester.pumpAndSettle();

    expect(find.text('Entrenar · Hipertrofia'), findsOneWidget);
    expect(find.text('Modo Hipertrofia'), findsOneWidget);
  });
}
