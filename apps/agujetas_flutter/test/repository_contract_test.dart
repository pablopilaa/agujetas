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
}

String _readRepositorySource() {
  final file = File('lib/repositories.dart');
  expect(file.existsSync(), isTrue, reason: 'Missing lib/repositories.dart');
  return file.readAsStringSync();
}
