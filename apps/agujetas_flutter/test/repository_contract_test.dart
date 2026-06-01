import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account deletion covers known root ownership fields', () {
    final repository = _readRepositorySource();

    expect(
      repository,
      contains("'sessions': ['ownerId', 'clientId', 'assignedClientId']"),
    );
    expect(
      repository,
      contains(
        "'routineTemplates': ['ownerId', 'clientId', 'assignedClientId']",
      ),
    );
    expect(repository, contains("'bodyWeights': ['userId']"));
    expect(
      repository,
      contains(
        "'assignedRoutines': ['ownerId', 'clientId', 'assignedClientId']",
      ),
    );
    expect(
      repository,
      contains("'tasks': ['ownerId', 'clientId', 'assignedClientId']"),
    );
    expect(
      repository,
      contains("'schedules': ['ownerId', 'clientId', 'assignedClientId']"),
    );
    expect(
      repository,
      contains("'goals': ['ownerId', 'clientId', 'assignedClientId']"),
    );
  });

  test('account deletion clears known user subcollections before user doc', () {
    final repository = _readRepositorySource();

    for (final collection in [
      'sessions',
      'routines',
      'routineTemplates',
      'bodyWeights',
      'customExercises',
      'exerciseHistory',
      'activeDrafts',
      'exports',
      'consents',
      'devices',
      'preferences',
    ]) {
      expect(repository, contains("'$collection'"));
    }

    final subcollectionCleanup = repository.indexOf(
      '_deleteKnownUserSubcollections(userId);',
    );
    final userDocDelete = repository.indexOf(
      "_deleteDocIfExists(_firestore.collection('users').doc(userId));",
    );
    expect(subcollectionCleanup, isNonNegative);
    expect(userDocDelete, isNonNegative);
    expect(subcollectionCleanup, lessThan(userDocDelete));
    expect(repository, contains("userRef.collection(collection)"));
  });

  test('remote preferences stay scoped under the authenticated user', () {
    final repository = _readRepositorySource();
    final rules = _readFirestoreRules();

    expect(
      repository,
      contains("userRef.collection('preferences').doc('app')"),
    );
    expect(
      repository,
      contains("'preferredTheme': preferences.preferredTheme"),
    );
    expect(repository, contains('LocalUserPreferences.fromJson'));
    expect(rules, contains('request.resource.data.plan == resource.data.plan'));
    expect(rules, contains("'preferences'"));
  });

  test('body weight sync uses owner scoped Firestore records', () {
    final repository = _readRepositorySource();
    final rules = _readFirestoreRules();

    expect(repository, contains(".collection('bodyWeights')"));
    expect(repository, contains(".where('userId', isEqualTo: userId)"));
    expect(repository, contains("'userId': user.uid"));
    expect(repository, contains("'id': doc.id"));
    expect(
      rules,
      contains(
        'allow create: if signedIn()\n        && request.resource.data.userId == request.auth.uid;',
      ),
    );
  });

  test('session sync uses stable ids and owner scoped Firestore records', () {
    final repository = _readRepositorySource();
    final rules = _readFirestoreRules();

    expect(repository, contains(".collection('sessions').doc(normalized.id)"));
    expect(repository, contains(".where('ownerId', isEqualTo: userId)"));
    expect(repository, contains("'ownerId': user.uid"));
    expect(repository, contains('deleteSession'));
    expect(repository, contains('watchSessions'));
    expect(repository, contains("'id': doc.id"));
    expect(
      rules,
      contains(
        'allow create: if signedIn()\n        && (ownerId(request.resource.data) == request.auth.uid',
      ),
    );
  });

  test('custom exercise sync uses owner scoped Firestore records', () {
    final repository = _readRepositorySource();
    final rules = _readFirestoreRules();

    expect(repository, contains(".collection('customExercises')"));
    expect(repository, contains(".where('ownerId', isEqualTo: ownerId)"));
    expect(repository, contains("'ownerId': owner.uid"));
    expect(repository, contains('deleteCustomExercise'));
    expect(repository, contains("'id': doc.id"));
    expect(
      rules,
      contains(
        'allow create: if signedIn()\n        && ownerId(request.resource.data) == request.auth.uid;',
      ),
    );
  });

  test('routine template sync uses owner scoped Firestore records', () {
    final repository = _readRepositorySource();
    final rules = _readFirestoreRules();

    expect(repository, contains(".collection('routineTemplates')"));
    expect(repository, contains(".where('ownerId', isEqualTo: ownerId)"));
    expect(repository, contains("'ownerId': owner.uid"));
    expect(repository, contains('deleteRoutineTemplate'));
    expect(repository, contains('watchRoutineTemplates'));
    expect(repository, contains("'id': doc.id"));
    expect(
      rules,
      contains(
        'allow create: if signedIn()\n        && ownerId(request.resource.data) == request.auth.uid',
      ),
    );
  });

  test('trainer routine assignment uses linked client scoped records', () {
    final repository = _readRepositorySource();
    final rules = _readFirestoreRules();

    expect(repository, contains(".collection('assignedRoutines').doc(id)"));
    expect(repository, contains('trainerId: trainer.uid'));
    expect(repository, contains('assignedClientId: client.clientId'));
    expect(repository, contains("'ownerId': trainer.uid"));
    expect(repository, contains("'clientId': client.clientId"));
    expect(repository, contains('watchAssignedRoutinesForClient'));
    expect(
      rules,
      contains(
        'match /assignedRoutines/{docId} {\n      allow read, update, delete: if canAccessRecord(resource.data);',
      ),
    );
    expect(
      rules,
      contains(
        'allow create: if signedIn()\n        && (ownsRecord(request.resource.data)\n          || trainerCanAccessRecord(request.resource.data));',
      ),
    );
  });

  test('trainer task assignment uses linked client scoped records', () {
    final repository = _readRepositorySource();
    final rules = _readFirestoreRules();

    expect(repository, contains(".collection('tasks').doc(id)"));
    expect(repository, contains('assignTaskToClient'));
    expect(repository, contains('trainerId: trainer.uid'));
    expect(repository, contains('assignedClientId: client.clientId'));
    expect(repository, contains("'ownerId': trainer.uid"));
    expect(repository, contains("'clientId': client.clientId"));
    expect(repository, contains('watchAssignedTasksForClient'));
    expect(
      rules,
      contains(
        'match /tasks/{docId} {\n      allow read, update, delete: if canAccessRecord(resource.data);',
      ),
    );
  });

  test('trainer schedule assignment uses linked client scoped records', () {
    final repository = _readRepositorySource();
    final rules = _readFirestoreRules();

    expect(repository, contains(".collection('schedules').doc(id)"));
    expect(repository, contains('assignScheduleToClient'));
    expect(repository, contains('trainerId: trainer.uid'));
    expect(repository, contains('assignedClientId: client.clientId'));
    expect(repository, contains("'ownerId': trainer.uid"));
    expect(repository, contains("'clientId': client.clientId"));
    expect(repository, contains('watchAssignedSchedulesForClient'));
    expect(
      rules,
      contains(
        'match /schedules/{docId} {\n      allow read, update, delete: if canAccessRecord(resource.data);',
      ),
    );
  });

  test('trainer goal assignment uses linked client scoped records', () {
    final repository = _readRepositorySource();
    final rules = _readFirestoreRules();

    expect(repository, contains(".collection('goals').doc(id)"));
    expect(repository, contains('assignGoalToClient'));
    expect(repository, contains('trainerId: trainer.uid'));
    expect(repository, contains('assignedClientId: client.clientId'));
    expect(repository, contains("'ownerId': trainer.uid"));
    expect(repository, contains("'clientId': client.clientId"));
    expect(repository, contains('watchAssignedGoalsForClient'));
    expect(
      rules,
      contains(
        'match /goals/{docId} {\n      allow read, update, delete: if canAccessRecord(resource.data);',
      ),
    );
  });

  test('assigned client actions update task schedule and goal records', () {
    final repository = _readRepositorySource();
    final rules = _readFirestoreRules();

    expect(repository, contains('updateAssignedTaskStatus'));
    expect(repository, contains(".collection('tasks').doc(task.id).update"));
    expect(repository, contains('updateAssignedScheduleStatus'));
    expect(
      repository,
      contains(".collection('schedules').doc(schedule.id).update"),
    );
    expect(repository, contains('updateAssignedGoalProgress'));
    expect(repository, contains(".collection('goals').doc(goal.id).update"));
    expect(repository, contains("'currentValue': currentValue"));
    expect(
      rules,
      contains(
        'allow read, update, delete: if canAccessRecord(resource.data);',
      ),
    );
  });
}

String _readRepositorySource() {
  final file = File('lib/repositories.dart');
  expect(file.existsSync(), isTrue, reason: 'Missing lib/repositories.dart');
  return file.readAsStringSync();
}

String _readFirestoreRules() {
  final file = File('../../firebase/firestore.rules');
  expect(file.existsSync(), isTrue, reason: 'Missing firebase/firestore.rules');
  return file.readAsStringSync();
}
