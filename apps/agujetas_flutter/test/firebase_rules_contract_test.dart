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

  test('firestore rules prevent client-side plan or role escalation', () {
    final rules = _readFirestoreRules();

    expect(rules, contains("request.resource.data.plan == 'free'"));
    expect(rules, contains("request.resource.data.roles.hasOnly(['normal'])"));
    expect(rules, contains('request.resource.data.plan == resource.data.plan'));
    expect(
      rules,
      contains('request.resource.data.roles == resource.data.roles'),
    );
    expect(rules, contains("request.resource.data.activeRole == 'normal'"));
    expect(
      rules,
      contains('allow update: if validSelfUserUpdate(userId) || isAdmin();'),
    );
  });

  test(
    'firestore rules allow privacy cleanup without active Pro entitlement',
    () {
      final rules = _readFirestoreRules();

      expect(
        rules,
        contains('allow delete: if isOwner(trainerId) || isAdmin();'),
      );
      expect(
        rules,
        contains(
          'allow delete: if signedIn()\n        && resource.data.trainerId == request.auth.uid;',
        ),
      );
    },
  );

  test('firestore rules do not use request.resource on link deletes', () {
    final rules = _readFirestoreRules();
    final linkRules = _rulesBlock(rules, 'trainerClientLinks');

    expect(
      linkRules,
      contains(
        'allow update: if signedIn()\n        && (resource.data.trainerId == request.auth.uid\n          || resource.data.clientId == request.auth.uid)\n        && request.resource.data.trainerId == resource.data.trainerId\n        && request.resource.data.clientId == resource.data.clientId;',
      ),
    );
    expect(
      linkRules,
      contains(
        'allow delete: if signedIn()\n        && (resource.data.trainerId == request.auth.uid\n          || resource.data.clientId == request.auth.uid);',
      ),
    );
    expect(linkRules, isNot(contains('allow update, delete: if signedIn()')));
  });

  test(
    'firestore rules do not use request.resource on routine template deletes',
    () {
      final rules = _readFirestoreRules();
      final routineRules = _rulesBlock(rules, 'routineTemplates');

      expect(
        routineRules,
        contains(
          'allow update: if signedIn()\n        && canAccessRecord(resource.data)\n        && validOptionalAssignment(request.resource.data);',
        ),
      );
      expect(
        routineRules,
        contains(
          'allow delete: if signedIn()\n        && canAccessRecord(resource.data);',
        ),
      );
      expect(
        routineRules,
        isNot(contains('allow update, delete: if signedIn()')),
      );
    },
  );

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

String _rulesBlock(String rules, String collectionName) {
  final start = rules.indexOf('match /$collectionName/');
  expect(start, isNonNegative, reason: 'Missing $collectionName rules block');

  final nextMatch = rules.indexOf('\n    match /', start + 1);
  return rules.substring(start, nextMatch == -1 ? rules.length : nextMatch);
}
