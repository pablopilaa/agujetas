import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('firestore rules gate trainer mode behind Pro entitlement', () {
    final rules = _readFirestoreRules();

    expect(rules, contains("userDoc(userId).data.plan == 'pro'"));
    expect(rules, contains("userDoc(userId).data.roles.hasAny(['trainer'])"));
    expect(rules, contains('allow create, update: if isOwner(trainerId)'));
    expect(rules, contains('&& canUseTrainerMode(trainerId);'));
    expect(
      rules,
      contains(
        'allow create: if signedIn()\n        && request.resource.data.trainerId == request.auth.uid\n        && request.resource.data.active == true\n        && canUseTrainerMode(request.auth.uid);',
      ),
    );
    expect(rules, contains('&& canUseTrainerMode(request.auth.uid);'));
  });

  test('firestore rules keep linked trainer access tied to active links', () {
    final rules = _readFirestoreRules();

    expect(
      rules,
      contains('&& canUseTrainerMode(trainerId)\n        && exists'),
    );
    expect(rules, contains(".data.status == 'active'"));
    expect(
      rules,
      contains("match /{document=**} {\n      allow read, write: if false;"),
    );
  });
}

String _readFirestoreRules() {
  final file = File('../../firebase/firestore.rules');
  expect(file.existsSync(), isTrue, reason: 'Missing firebase/firestore.rules');
  return file.readAsStringSync();
}
