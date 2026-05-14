import 'package:agujetas_flutter/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      imageUri: 'app-image://00011101',
      isCustom: true,
    ).toWorkoutExercise();

    expect(exercise.sets, hasLength(3));
    expect(exercise.imageUri, 'app-image://00011101');
    expect(exercise.isCustom, isTrue);
  });
}
