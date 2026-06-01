import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';

import 'local_workout_store.dart';
import 'models.dart';

const _webClientId =
    '727741646431-mhm923t7d9ha8jtr55u4j3efalkrdrff.apps.googleusercontent.com';

const Map<String, List<String>> _accountDeletionRootFieldQueries = {
  'sessions': ['ownerId', 'clientId', 'assignedClientId'],
  'routineTemplates': ['ownerId', 'clientId', 'assignedClientId'],
  'customExercises': ['ownerId'],
  'bodyWeights': ['userId'],
  'assignedRoutines': ['ownerId', 'clientId', 'assignedClientId'],
  'tasks': ['ownerId', 'clientId', 'assignedClientId'],
  'schedules': ['ownerId', 'clientId', 'assignedClientId'],
  'goals': ['ownerId', 'clientId', 'assignedClientId'],
};

const List<String> _accountDeletionUserSubcollections = [
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
];

abstract class AgujetasRepository {
  Stream<AppUser?> authUser();
  Future<AppUser?> signInWithGoogle();
  Future<void> signOut();
  Future<void> deleteAccount(AppUser user);
  Future<void> setActiveRole(AppUser user, AppRole role);
  Future<LocalUserPreferences?> loadUserPreferences(AppUser user);
  Future<void> saveUserPreferences({
    required AppUser user,
    required LocalUserPreferences preferences,
  });
  Future<void> ensureTrainerProfile(AppUser user);
  Future<TrainerInvite> createTrainerInvite(AppUser trainer);
  Future<TrainerClientLink> acceptTrainerInvite({
    required AppUser client,
    required String code,
  });
  Stream<List<TrainerClientLink>> watchTrainerClients(String trainerId);
  Future<AssignedRoutine> assignRoutineToClient({
    required AppUser trainer,
    required TrainerClientLink client,
    required RoutineTemplate routine,
  });
  Stream<List<AssignedRoutine>> watchAssignedRoutinesForClient(String clientId);
  Future<AssignedTask> assignTaskToClient({
    required AppUser trainer,
    required TrainerClientLink client,
    required String title,
    required String description,
    DateTime? dueAt,
  });
  Stream<List<AssignedTask>> watchAssignedTasksForClient(String clientId);
  Future<void> updateAssignedTaskStatus({
    required AppUser user,
    required AssignedTask task,
    required String status,
  });
  Future<AssignedSchedule> assignScheduleToClient({
    required AppUser trainer,
    required TrainerClientLink client,
    required String title,
    required DateTime scheduledFor,
    String? note,
    RoutineTemplate? routine,
  });
  Stream<List<AssignedSchedule>> watchAssignedSchedulesForClient(
    String clientId,
  );
  Future<void> updateAssignedScheduleStatus({
    required AppUser user,
    required AssignedSchedule schedule,
    required String status,
  });
  Future<AssignedGoal> assignGoalToClient({
    required AppUser trainer,
    required TrainerClientLink client,
    required String title,
    required String metric,
    required double targetValue,
    required String unit,
    double currentValue,
    DateTime? dueAt,
    String? note,
  });
  Stream<List<AssignedGoal>> watchAssignedGoalsForClient(String clientId);
  Future<void> updateAssignedGoalProgress({
    required AppUser user,
    required AssignedGoal goal,
    required double currentValue,
    required String status,
  });
  Future<void> saveSession({
    required AppUser user,
    required LocalWorkoutSession session,
    String? trainerId,
  });
  Future<void> deleteSession({
    required AppUser user,
    required LocalWorkoutSession session,
  });
  Stream<List<LocalWorkoutSession>> watchSessions(String userId);
  Future<void> saveRoutineTemplate({
    required AppUser owner,
    required RoutineTemplate routine,
  });
  Future<void> deleteRoutineTemplate({
    required AppUser owner,
    required RoutineTemplate routine,
  });
  Stream<List<RoutineTemplate>> watchRoutineTemplates(String ownerId);
  Future<void> saveCustomExercise({
    required AppUser owner,
    required ExerciseCatalogEntry exercise,
  });
  Future<void> deleteCustomExercise({
    required AppUser owner,
    required ExerciseCatalogEntry exercise,
  });
  Stream<List<ExerciseCatalogEntry>> watchCustomExercises(String ownerId);
  Future<void> saveBodyWeight({
    required AppUser user,
    required BodyWeightEntry entry,
  });
  Stream<List<BodyWeightEntry>> watchBodyWeights(String userId);
}

class AccountDeletionRequiresRecentLoginException implements Exception {
  const AccountDeletionRequiresRecentLoginException();

  @override
  String toString() {
    return 'Google requiere que vuelvas a ingresar antes de eliminar la cuenta.';
  }
}

class FirebaseAgujetasRepository implements AgujetasRepository {
  FirebaseAgujetasRepository({
    fb.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? fb.FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  @override
  Stream<AppUser?> authUser() {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      return _upsertUser(firebaseUser);
    });
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = fb.GoogleAuthProvider();
      final credential = await _auth.signInWithPopup(provider);
      final user = credential.user;
      return user == null ? null : _upsertUser(user);
    }

    await GoogleSignIn.instance.initialize(serverClientId: _webClientId);
    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;
    final credential = fb.GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    final user = result.user;
    return user == null ? null : _upsertUser(user);
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      await GoogleSignIn.instance.disconnect();
    }
  }

  @override
  Future<void> deleteAccount(AppUser user) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid != user.uid) {
      throw StateError('No hay una sesión activa para eliminar esta cuenta.');
    }

    await _reauthenticateForAccountDeletion(currentUser);
    await _deleteKnownFirestoreData(user.uid);
    try {
      await currentUser.delete();
    } on fb.FirebaseAuthException catch (error) {
      if (error.code == 'requires-recent-login') {
        throw const AccountDeletionRequiresRecentLoginException();
      }
      rethrow;
    }

    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.disconnect();
      } catch (_) {}
    }
  }

  Future<void> _reauthenticateForAccountDeletion(fb.User currentUser) async {
    try {
      if (kIsWeb) {
        final provider = fb.GoogleAuthProvider();
        final result = await currentUser.reauthenticateWithPopup(provider);
        if (result.user?.uid != currentUser.uid) {
          throw StateError('La cuenta Google elegida no coincide.');
        }
        return;
      }

      await GoogleSignIn.instance.initialize(serverClientId: _webClientId);
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final result = await currentUser.reauthenticateWithCredential(credential);
      if (result.user?.uid != currentUser.uid) {
        throw StateError('La cuenta Google elegida no coincide.');
      }
    } on fb.FirebaseAuthException catch (error) {
      if (error.code == 'requires-recent-login') {
        throw const AccountDeletionRequiresRecentLoginException();
      }
      rethrow;
    } catch (_) {
      throw const AccountDeletionRequiresRecentLoginException();
    }
  }

  @override
  Future<void> setActiveRole(AppUser user, AppRole role) async {
    if (role == AppRole.trainer && !user.canUseTrainerMode) {
      throw StateError('Agujetas Pro es requerido para usar modo entrenador.');
    }
    await _firestore.collection('users').doc(user.uid).set({
      'activeRole': role.value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (role == AppRole.trainer) {
      await ensureTrainerProfile(user.copyWith(activeRole: role));
    }
  }

  @override
  Future<LocalUserPreferences?> loadUserPreferences(AppUser user) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final preferencesRef = userRef.collection('preferences').doc('app');
    final preferencesSnapshot = await preferencesRef.get();
    final preferencesData = preferencesSnapshot.data();
    if (preferencesData != null) {
      return LocalUserPreferences.fromJson(
        preferencesData.cast<String, Object?>(),
      );
    }

    final userSnapshot = await userRef.get();
    final userData = userSnapshot.data();
    if (userData == null || !userData.containsKey('preferredTheme')) {
      return null;
    }
    return LocalUserPreferences.fromJson(userData.cast<String, Object?>());
  }

  @override
  Future<void> saveUserPreferences({
    required AppUser user,
    required LocalUserPreferences preferences,
  }) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();
    batch.set(userRef, {
      'preferredTheme': preferences.preferredTheme,
      'updatedAt': now,
    }, SetOptions(merge: true));
    batch.set(userRef.collection('preferences').doc('app'), {
      ...preferences.toJson(),
      'updatedAt': now,
    }, SetOptions(merge: true));
    await batch.commit();
  }

  @override
  Future<void> ensureTrainerProfile(AppUser user) async {
    await _firestore.collection('trainerProfiles').doc(user.uid).set({
      'uid': user.uid,
      'displayName': user.displayName,
      'email': user.email,
      'photoURL': user.photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<TrainerInvite> createTrainerInvite(AppUser trainer) async {
    await ensureTrainerProfile(trainer);
    final code = _uuid.v4().replaceAll('-', '').substring(0, 8).toUpperCase();
    final invite = TrainerInvite(
      code: code,
      trainerId: trainer.uid,
      trainerName: trainer.displayName,
      createdAt: DateTime.now().toUtc(),
    );
    await _firestore
        .collection('trainerInvites')
        .doc(code)
        .set(invite.toJson());
    return invite;
  }

  @override
  Future<TrainerClientLink> acceptTrainerInvite({
    required AppUser client,
    required String code,
  }) async {
    final normalizedCode = code.trim().toUpperCase();
    final inviteSnap = await _firestore
        .collection('trainerInvites')
        .doc(normalizedCode)
        .get();
    final inviteData = inviteSnap.data();
    if (inviteData == null) {
      throw StateError('No existe una invitación con ese código.');
    }
    final invite = TrainerInvite.fromJson(inviteData.cast<String, Object?>());
    if (!invite.active) {
      throw StateError('La invitación ya no está activa.');
    }
    final linkId = '${invite.trainerId}_${client.uid}';
    final link = TrainerClientLink(
      id: linkId,
      trainerId: invite.trainerId,
      clientId: client.uid,
      clientName: client.displayName,
      status: 'active',
    );
    await _firestore.collection('trainerClientLinks').doc(linkId).set({
      ...link.toJson(),
      'inviteCode': normalizedCode,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return link;
  }

  @override
  Stream<List<TrainerClientLink>> watchTrainerClients(String trainerId) {
    return _firestore
        .collection('trainerClientLinks')
        .where('trainerId', isEqualTo: trainerId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TrainerClientLink.fromJson(doc.data()))
              .toList(),
        );
  }

  @override
  Future<AssignedRoutine> assignRoutineToClient({
    required AppUser trainer,
    required TrainerClientLink client,
    required RoutineTemplate routine,
  }) async {
    final id = _uuid.v4();
    final assigned = AssignedRoutine(
      id: id,
      trainerId: trainer.uid,
      assignedClientId: client.clientId,
      routineTemplateId: routine.id,
      routineTitle: routine.title,
      exercises: routine.exercises,
      status: 'assigned',
      assignedAt: DateTime.now().toUtc(),
    );
    await _firestore.collection('assignedRoutines').doc(id).set({
      ...assigned.toJson(),
      'ownerId': trainer.uid,
      'clientId': client.clientId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return assigned;
  }

  @override
  Stream<List<AssignedRoutine>> watchAssignedRoutinesForClient(
    String clientId,
  ) {
    return _firestore
        .collection('assignedRoutines')
        .where('assignedClientId', isEqualTo: clientId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    AssignedRoutine.fromJson({...doc.data(), 'id': doc.id}),
              )
              .where(
                (routine) =>
                    routine.id.isNotEmpty &&
                    routine.assignedClientId == clientId &&
                    routine.exercises.isNotEmpty,
              )
              .toList(),
        );
  }

  @override
  Future<AssignedTask> assignTaskToClient({
    required AppUser trainer,
    required TrainerClientLink client,
    required String title,
    required String description,
    DateTime? dueAt,
  }) async {
    final id = _uuid.v4();
    final assigned = AssignedTask(
      id: id,
      trainerId: trainer.uid,
      assignedClientId: client.clientId,
      title: title,
      description: description,
      status: 'pending',
      assignedAt: DateTime.now().toUtc(),
      dueAt: dueAt,
    );
    await _firestore.collection('tasks').doc(id).set({
      ...assigned.toJson(),
      'ownerId': trainer.uid,
      'clientId': client.clientId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return assigned;
  }

  @override
  Stream<List<AssignedTask>> watchAssignedTasksForClient(String clientId) {
    return _firestore
        .collection('tasks')
        .where('assignedClientId', isEqualTo: clientId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => AssignedTask.fromJson({...doc.data(), 'id': doc.id}),
              )
              .where(
                (task) =>
                    task.id.isNotEmpty &&
                    task.assignedClientId == clientId &&
                    task.title.isNotEmpty,
              )
              .toList(),
        );
  }

  @override
  Future<void> updateAssignedTaskStatus({
    required AppUser user,
    required AssignedTask task,
    required String status,
  }) async {
    if (task.assignedClientId != user.uid) {
      throw StateError('Esta tarea no pertenece al usuario actual.');
    }
    await _firestore.collection('tasks').doc(task.id).update({
      'status': status,
      'completedAt': status == 'completed'
          ? FieldValue.serverTimestamp()
          : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<AssignedSchedule> assignScheduleToClient({
    required AppUser trainer,
    required TrainerClientLink client,
    required String title,
    required DateTime scheduledFor,
    String? note,
    RoutineTemplate? routine,
  }) async {
    final id = _uuid.v4();
    final assigned = AssignedSchedule(
      id: id,
      trainerId: trainer.uid,
      assignedClientId: client.clientId,
      title: title,
      scheduledFor: scheduledFor.toUtc(),
      status: 'scheduled',
      assignedAt: DateTime.now().toUtc(),
      note: note,
      routineTemplateId: routine?.id,
      routineTitle: routine?.title,
    );
    await _firestore.collection('schedules').doc(id).set({
      ...assigned.toJson(),
      'ownerId': trainer.uid,
      'clientId': client.clientId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return assigned;
  }

  @override
  Stream<List<AssignedSchedule>> watchAssignedSchedulesForClient(
    String clientId,
  ) {
    return _firestore
        .collection('schedules')
        .where('assignedClientId', isEqualTo: clientId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => AssignedSchedule.fromJson({
                      ...doc.data(),
                      'id': doc.id,
                    }),
                  )
                  .where(
                    (schedule) =>
                        schedule.id.isNotEmpty &&
                        schedule.assignedClientId == clientId &&
                        schedule.title.isNotEmpty,
                  )
                  .toList()
                ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor)),
        );
  }

  @override
  Future<void> updateAssignedScheduleStatus({
    required AppUser user,
    required AssignedSchedule schedule,
    required String status,
  }) async {
    if (schedule.assignedClientId != user.uid) {
      throw StateError('Este schedule no pertenece al usuario actual.');
    }
    await _firestore.collection('schedules').doc(schedule.id).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<AssignedGoal> assignGoalToClient({
    required AppUser trainer,
    required TrainerClientLink client,
    required String title,
    required String metric,
    required double targetValue,
    required String unit,
    double currentValue = 0,
    DateTime? dueAt,
    String? note,
  }) async {
    final id = _uuid.v4();
    final assigned = AssignedGoal(
      id: id,
      trainerId: trainer.uid,
      assignedClientId: client.clientId,
      title: title,
      metric: metric,
      targetValue: targetValue,
      currentValue: currentValue,
      unit: unit,
      status: 'active',
      assignedAt: DateTime.now().toUtc(),
      dueAt: dueAt,
      note: note,
    );
    await _firestore.collection('goals').doc(id).set({
      ...assigned.toJson(),
      'ownerId': trainer.uid,
      'clientId': client.clientId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return assigned;
  }

  @override
  Stream<List<AssignedGoal>> watchAssignedGoalsForClient(String clientId) {
    return _firestore
        .collection('goals')
        .where('assignedClientId', isEqualTo: clientId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) =>
                        AssignedGoal.fromJson({...doc.data(), 'id': doc.id}),
                  )
                  .where(
                    (goal) =>
                        goal.id.isNotEmpty &&
                        goal.assignedClientId == clientId &&
                        goal.title.isNotEmpty,
                  )
                  .toList()
                ..sort((a, b) => a.assignedAt.compareTo(b.assignedAt)),
        );
  }

  @override
  Future<void> updateAssignedGoalProgress({
    required AppUser user,
    required AssignedGoal goal,
    required double currentValue,
    required String status,
  }) async {
    if (goal.assignedClientId != user.uid) {
      throw StateError('Esta meta no pertenece al usuario actual.');
    }
    await _firestore.collection('goals').doc(goal.id).update({
      'currentValue': currentValue,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> saveSession({
    required AppUser user,
    required LocalWorkoutSession session,
    String? trainerId,
  }) async {
    final normalized = session.copyWith(userId: user.uid);
    await _firestore.collection('sessions').doc(normalized.id).set({
      ...normalized.toJson(),
      'ownerId': user.uid,
      'trainerId': trainerId,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'schemaVersion': 2,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteSession({
    required AppUser user,
    required LocalWorkoutSession session,
  }) async {
    await _firestore.collection('sessions').doc(session.id).delete();
  }

  @override
  Stream<List<LocalWorkoutSession>> watchSessions(String userId) {
    return _firestore
        .collection('sessions')
        .where('ownerId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => LocalWorkoutSession.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                  'userId': doc.data()['userId'] ?? doc.data()['ownerId'],
                }),
              )
              .where(
                (session) =>
                    session.id.isNotEmpty &&
                    session.userId == userId &&
                    session.exercises.isNotEmpty,
              )
              .toList(),
        );
  }

  @override
  Future<void> saveRoutineTemplate({
    required AppUser owner,
    required RoutineTemplate routine,
  }) async {
    final normalized = routine.copyWith(ownerId: owner.uid);
    await _firestore.collection('routineTemplates').doc(normalized.id).set({
      ...normalized.toJson(),
      'ownerId': owner.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteRoutineTemplate({
    required AppUser owner,
    required RoutineTemplate routine,
  }) async {
    await _firestore.collection('routineTemplates').doc(routine.id).delete();
  }

  @override
  Stream<List<RoutineTemplate>> watchRoutineTemplates(String ownerId) {
    return _firestore
        .collection('routineTemplates')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    RoutineTemplate.fromJson({...doc.data(), 'id': doc.id}),
              )
              .where(
                (routine) =>
                    routine.id.isNotEmpty &&
                    routine.ownerId == ownerId &&
                    routine.exercises.isNotEmpty,
              )
              .toList(),
        );
  }

  @override
  Future<void> saveCustomExercise({
    required AppUser owner,
    required ExerciseCatalogEntry exercise,
  }) async {
    await _firestore.collection('customExercises').doc(exercise.id).set({
      ...exercise.toJson(),
      'ownerId': owner.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteCustomExercise({
    required AppUser owner,
    required ExerciseCatalogEntry exercise,
  }) async {
    await _firestore.collection('customExercises').doc(exercise.id).delete();
  }

  @override
  Stream<List<ExerciseCatalogEntry>> watchCustomExercises(String ownerId) {
    return _firestore
        .collection('customExercises')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ExerciseCatalogEntry.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                }),
              )
              .where((entry) => entry.id.isNotEmpty && entry.isCustom)
              .toList(),
        );
  }

  @override
  Future<void> saveBodyWeight({
    required AppUser user,
    required BodyWeightEntry entry,
  }) async {
    await _firestore.collection('bodyWeights').doc(entry.id).set({
      ...entry.toJson(),
      'userId': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Stream<List<BodyWeightEntry>> watchBodyWeights(String userId) {
    return _firestore
        .collection('bodyWeights')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) =>
                        BodyWeightEntry.fromJson({...doc.data(), 'id': doc.id}),
                  )
                  .where((entry) => entry.id.isNotEmpty)
                  .toList()
                ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt)),
        );
  }

  Future<AppUser> _upsertUser(fb.User firebaseUser) async {
    final userRef = _firestore.collection('users').doc(firebaseUser.uid);
    final snapshot = await userRef.get();
    final now = FieldValue.serverTimestamp();
    if (!snapshot.exists) {
      final user = AppUser(
        uid: firebaseUser.uid,
        displayName: firebaseUser.displayName ?? 'Agujetas',
        email: firebaseUser.email ?? '',
        photoUrl: firebaseUser.photoURL,
        roles: const {AppRole.normal},
        activeRole: AppRole.normal,
        plan: AppPlan.free,
      );
      await userRef.set({
        ...user.toJson(),
        'createdAt': now,
        'updatedAt': now,
        'onboardingCompleted': false,
        'preferredTheme': 'system',
        'plan': 'free',
      });
      return user;
    }
    await userRef.set({'updatedAt': now}, SetOptions(merge: true));
    return AppUser.fromJson(snapshot.data()!.cast<String, Object?>());
  }

  Future<void> _deleteKnownFirestoreData(String userId) async {
    for (final entry in _accountDeletionRootFieldQueries.entries) {
      for (final field in entry.value) {
        await _deleteQuery(
          _firestore.collection(entry.key).where(field, isEqualTo: userId),
        );
      }
    }
    await _deleteDocIfExists(
      _firestore.collection('trainerProfiles').doc(userId),
    );
    await _deleteQuery(
      _firestore
          .collection('trainerInvites')
          .where('trainerId', isEqualTo: userId),
    );
    await _deleteQuery(
      _firestore
          .collection('trainerClientLinks')
          .where('trainerId', isEqualTo: userId),
    );
    await _deleteQuery(
      _firestore
          .collection('trainerClientLinks')
          .where('clientId', isEqualTo: userId),
    );
    await _deleteKnownUserSubcollections(userId);
    await _deleteDocIfExists(_firestore.collection('users').doc(userId));
  }

  Future<void> _deleteKnownUserSubcollections(String userId) async {
    final userRef = _firestore.collection('users').doc(userId);
    for (final collection in _accountDeletionUserSubcollections) {
      await _deleteQuery(userRef.collection(collection));
    }
  }

  Future<void> _deleteQuery(Query<Map<String, dynamic>> query) async {
    while (true) {
      final snapshot = await query.limit(300).get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteDocIfExists(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    final snapshot = await ref.get();
    if (snapshot.exists) {
      await ref.delete();
    }
  }
}

class DemoAgujetasRepository implements AgujetasRepository {
  final _controller = StreamController<AppUser?>.broadcast();
  final _clients = StreamController<List<TrainerClientLink>>.broadcast();
  final _assignedRoutines = StreamController<List<AssignedRoutine>>.broadcast();
  final _assignedTasks = StreamController<List<AssignedTask>>.broadcast();
  final _assignedSchedules =
      StreamController<List<AssignedSchedule>>.broadcast();
  final _assignedGoals = StreamController<List<AssignedGoal>>.broadcast();
  final _customExercises =
      StreamController<List<ExerciseCatalogEntry>>.broadcast();
  final _bodyWeights = StreamController<List<BodyWeightEntry>>.broadcast();
  final List<ExerciseCatalogEntry> _customExerciseItems = [];
  final List<BodyWeightEntry> _bodyWeightItems = [];
  final List<AssignedRoutine> _assignedRoutineItems = [];
  final List<AssignedTask> _assignedTaskItems = [];
  final List<AssignedSchedule> _assignedScheduleItems = [];
  final List<AssignedGoal> _assignedGoalItems = [];
  LocalUserPreferences _preferences = const LocalUserPreferences();

  AppUser? _user = const AppUser(
    uid: 'demo-user',
    displayName: 'Demo Agujetas',
    email: 'demo@agujetas.app',
    photoUrl: null,
    roles: {AppRole.normal},
    activeRole: AppRole.normal,
    plan: AppPlan.free,
  );

  @override
  Stream<AppUser?> authUser() {
    scheduleMicrotask(() => _controller.add(_user));
    return _controller.stream;
  }

  @override
  Future<TrainerClientLink> acceptTrainerInvite({
    required AppUser client,
    required String code,
  }) async {
    final link = TrainerClientLink(
      id: 'demo-trainer_${client.uid}',
      trainerId: 'demo-trainer',
      clientId: client.uid,
      clientName: client.displayName,
      status: 'active',
    );
    _clients.add([link]);
    return link;
  }

  @override
  Future<TrainerInvite> createTrainerInvite(AppUser trainer) async {
    return TrainerInvite(
      code: 'AGUJETAS',
      trainerId: trainer.uid,
      trainerName: trainer.displayName,
      createdAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> ensureTrainerProfile(AppUser user) async {}

  @override
  Future<LocalUserPreferences?> loadUserPreferences(AppUser user) async {
    return _preferences;
  }

  @override
  Future<void> saveUserPreferences({
    required AppUser user,
    required LocalUserPreferences preferences,
  }) async {
    _preferences = preferences;
  }

  @override
  Future<void> deleteAccount(AppUser user) async {
    _user = null;
    _customExerciseItems.clear();
    _bodyWeightItems.clear();
    _assignedRoutineItems.clear();
    _assignedTaskItems.clear();
    _assignedScheduleItems.clear();
    _assignedGoalItems.clear();
    _customExercises.add(const []);
    _bodyWeights.add(const []);
    _clients.add(const []);
    _assignedRoutines.add(const []);
    _assignedTasks.add(const []);
    _assignedSchedules.add(const []);
    _assignedGoals.add(const []);
    _controller.add(null);
  }

  @override
  Future<void> saveRoutineTemplate({
    required AppUser owner,
    required RoutineTemplate routine,
  }) async {}

  @override
  Future<void> deleteRoutineTemplate({
    required AppUser owner,
    required RoutineTemplate routine,
  }) async {}

  @override
  Stream<List<RoutineTemplate>> watchRoutineTemplates(String ownerId) {
    return const Stream.empty();
  }

  @override
  Future<AssignedRoutine> assignRoutineToClient({
    required AppUser trainer,
    required TrainerClientLink client,
    required RoutineTemplate routine,
  }) async {
    final assigned = AssignedRoutine(
      id: 'demo-assigned-${_assignedRoutineItems.length + 1}',
      trainerId: trainer.uid,
      assignedClientId: client.clientId,
      routineTemplateId: routine.id,
      routineTitle: routine.title,
      exercises: routine.exercises,
      status: 'assigned',
      assignedAt: DateTime.now().toUtc(),
    );
    _assignedRoutineItems.insert(0, assigned);
    _assignedRoutines.add(List.unmodifiable(_assignedRoutineItems));
    return assigned;
  }

  @override
  Stream<List<AssignedRoutine>> watchAssignedRoutinesForClient(
    String clientId,
  ) {
    scheduleMicrotask(
      () => _assignedRoutines.add(
        _assignedRoutineItems
            .where((routine) => routine.assignedClientId == clientId)
            .toList(),
      ),
    );
    return _assignedRoutines.stream.map(
      (items) => items
          .where((routine) => routine.assignedClientId == clientId)
          .toList(),
    );
  }

  @override
  Future<AssignedTask> assignTaskToClient({
    required AppUser trainer,
    required TrainerClientLink client,
    required String title,
    required String description,
    DateTime? dueAt,
  }) async {
    final assigned = AssignedTask(
      id: 'demo-task-${_assignedTaskItems.length + 1}',
      trainerId: trainer.uid,
      assignedClientId: client.clientId,
      title: title,
      description: description,
      status: 'pending',
      assignedAt: DateTime.now().toUtc(),
      dueAt: dueAt,
    );
    _assignedTaskItems.insert(0, assigned);
    _assignedTasks.add(List.unmodifiable(_assignedTaskItems));
    return assigned;
  }

  @override
  Stream<List<AssignedTask>> watchAssignedTasksForClient(String clientId) {
    scheduleMicrotask(
      () => _assignedTasks.add(
        _assignedTaskItems
            .where((task) => task.assignedClientId == clientId)
            .toList(),
      ),
    );
    return _assignedTasks.stream.map(
      (items) =>
          items.where((task) => task.assignedClientId == clientId).toList(),
    );
  }

  @override
  Future<void> updateAssignedTaskStatus({
    required AppUser user,
    required AssignedTask task,
    required String status,
  }) async {
    _assignedTaskItems.removeWhere((item) => item.id == task.id);
    _assignedTaskItems.insert(0, task.copyWith(status: status));
    _assignedTasks.add(List.unmodifiable(_assignedTaskItems));
  }

  @override
  Future<AssignedSchedule> assignScheduleToClient({
    required AppUser trainer,
    required TrainerClientLink client,
    required String title,
    required DateTime scheduledFor,
    String? note,
    RoutineTemplate? routine,
  }) async {
    final assigned = AssignedSchedule(
      id: 'demo-schedule-${_assignedScheduleItems.length + 1}',
      trainerId: trainer.uid,
      assignedClientId: client.clientId,
      title: title,
      scheduledFor: scheduledFor.toUtc(),
      status: 'scheduled',
      assignedAt: DateTime.now().toUtc(),
      note: note,
      routineTemplateId: routine?.id,
      routineTitle: routine?.title,
    );
    _assignedScheduleItems.insert(0, assigned);
    _assignedSchedules.add(List.unmodifiable(_assignedScheduleItems));
    return assigned;
  }

  @override
  Stream<List<AssignedSchedule>> watchAssignedSchedulesForClient(
    String clientId,
  ) {
    scheduleMicrotask(
      () => _assignedSchedules.add(
        _assignedScheduleItems
            .where((schedule) => schedule.assignedClientId == clientId)
            .toList(),
      ),
    );
    return _assignedSchedules.stream.map(
      (items) =>
          items
              .where((schedule) => schedule.assignedClientId == clientId)
              .toList()
            ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor)),
    );
  }

  @override
  Future<void> updateAssignedScheduleStatus({
    required AppUser user,
    required AssignedSchedule schedule,
    required String status,
  }) async {
    _assignedScheduleItems.removeWhere((item) => item.id == schedule.id);
    _assignedScheduleItems.insert(0, schedule.copyWith(status: status));
    _assignedSchedules.add(List.unmodifiable(_assignedScheduleItems));
  }

  @override
  Future<AssignedGoal> assignGoalToClient({
    required AppUser trainer,
    required TrainerClientLink client,
    required String title,
    required String metric,
    required double targetValue,
    required String unit,
    double currentValue = 0,
    DateTime? dueAt,
    String? note,
  }) async {
    final assigned = AssignedGoal(
      id: 'demo-goal-${_assignedGoalItems.length + 1}',
      trainerId: trainer.uid,
      assignedClientId: client.clientId,
      title: title,
      metric: metric,
      targetValue: targetValue,
      currentValue: currentValue,
      unit: unit,
      status: 'active',
      assignedAt: DateTime.now().toUtc(),
      dueAt: dueAt,
      note: note,
    );
    _assignedGoalItems.insert(0, assigned);
    _assignedGoals.add(List.unmodifiable(_assignedGoalItems));
    return assigned;
  }

  @override
  Stream<List<AssignedGoal>> watchAssignedGoalsForClient(String clientId) {
    scheduleMicrotask(
      () => _assignedGoals.add(
        _assignedGoalItems
            .where((goal) => goal.assignedClientId == clientId)
            .toList(),
      ),
    );
    return _assignedGoals.stream.map(
      (items) =>
          items.where((goal) => goal.assignedClientId == clientId).toList(),
    );
  }

  @override
  Future<void> updateAssignedGoalProgress({
    required AppUser user,
    required AssignedGoal goal,
    required double currentValue,
    required String status,
  }) async {
    _assignedGoalItems.removeWhere((item) => item.id == goal.id);
    _assignedGoalItems.insert(
      0,
      goal.copyWith(currentValue: currentValue, status: status),
    );
    _assignedGoals.add(List.unmodifiable(_assignedGoalItems));
  }

  @override
  Future<void> saveCustomExercise({
    required AppUser owner,
    required ExerciseCatalogEntry exercise,
  }) async {
    _customExerciseItems.removeWhere((item) => item.id == exercise.id);
    _customExerciseItems.insert(0, exercise);
    _customExercises.add(List.unmodifiable(_customExerciseItems));
  }

  @override
  Future<void> deleteCustomExercise({
    required AppUser owner,
    required ExerciseCatalogEntry exercise,
  }) async {
    _customExerciseItems.removeWhere((item) => item.id == exercise.id);
    _customExercises.add(List.unmodifiable(_customExerciseItems));
  }

  @override
  Stream<List<ExerciseCatalogEntry>> watchCustomExercises(String ownerId) {
    scheduleMicrotask(() => _customExercises.add(_customExerciseItems));
    return _customExercises.stream;
  }

  @override
  Future<void> saveBodyWeight({
    required AppUser user,
    required BodyWeightEntry entry,
  }) async {
    _bodyWeightItems.removeWhere((item) => item.id == entry.id);
    _bodyWeightItems.insert(0, entry);
    _bodyWeights.add(List.unmodifiable(_bodyWeightItems));
  }

  @override
  Stream<List<BodyWeightEntry>> watchBodyWeights(String userId) {
    scheduleMicrotask(
      () => _bodyWeights.add([
        ..._bodyWeightItems,
        BodyWeightEntry(
          id: 'demo-weight',
          userId: userId,
          weightKg: 82.4,
          recordedAt: DateTime.now().subtract(const Duration(days: 2)),
          note: 'Referencia demo',
        ),
      ]),
    );
    return _bodyWeights.stream;
  }

  @override
  Future<void> saveSession({
    required AppUser user,
    required LocalWorkoutSession session,
    String? trainerId,
  }) async {}

  @override
  Future<void> deleteSession({
    required AppUser user,
    required LocalWorkoutSession session,
  }) async {}

  @override
  Stream<List<LocalWorkoutSession>> watchSessions(String userId) {
    return const Stream.empty();
  }

  @override
  Future<void> setActiveRole(AppUser user, AppRole role) async {
    if (role == AppRole.trainer && !user.canUseTrainerMode) {
      throw StateError('Agujetas Pro es requerido para usar modo entrenador.');
    }
    _user = user.copyWith(roles: {...user.roles, role}, activeRole: role);
    _controller.add(_user);
  }

  @override
  Future<AppUser?> signInWithGoogle() async => _user;

  @override
  Future<void> signOut() async {
    _controller.add(null);
  }

  @override
  Stream<List<TrainerClientLink>> watchTrainerClients(String trainerId) {
    scheduleMicrotask(() {
      _clients.add([
        const TrainerClientLink(
          id: 'demo-trainer_demo-client',
          trainerId: 'demo-trainer',
          clientId: 'demo-client',
          clientName: 'Sofia Demo',
          status: 'active',
        ),
      ]);
    });
    return _clients.stream;
  }
}
