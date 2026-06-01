import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

const _webClientId =
    '727741646431-mhm923t7d9ha8jtr55u4j3efalkrdrff.apps.googleusercontent.com';

abstract class AgujetasRepository {
  Stream<AppUser?> authUser();
  Future<AppUser?> signInWithGoogle();
  Future<void> signOut();
  Future<void> setActiveRole(AppUser user, AppRole role);
  Future<void> ensureTrainerProfile(AppUser user);
  Future<TrainerInvite> createTrainerInvite(AppUser trainer);
  Future<TrainerClientLink> acceptTrainerInvite({
    required AppUser client,
    required String code,
  });
  Stream<List<TrainerClientLink>> watchTrainerClients(String trainerId);
  Future<void> saveSession({
    required AppUser user,
    required List<WorkoutExercise> exercises,
    String? trainerId,
  });
  Future<void> saveRoutineTemplate({
    required AppUser owner,
    required RoutineTemplate routine,
  });
  Future<void> saveCustomExercise({
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
  Future<void> setActiveRole(AppUser user, AppRole role) async {
    if (role == AppRole.trainer && !user.canUseTrainerMode) {
      throw StateError('Agujetas Pro es requerido para usar modo entrenador.');
    }
    final roles = {...user.roles, role};
    await _firestore.collection('users').doc(user.uid).set({
      'roles': roles.map((item) => item.value).toList(),
      'activeRole': role.value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (role == AppRole.trainer) {
      await ensureTrainerProfile(user.copyWith(roles: roles, activeRole: role));
    }
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
  Future<void> saveSession({
    required AppUser user,
    required List<WorkoutExercise> exercises,
    String? trainerId,
  }) async {
    await _firestore.collection('sessions').add({
      'ownerId': user.uid,
      'trainerId': trainerId,
      'createdAt': FieldValue.serverTimestamp(),
      'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
      'schemaVersion': 2,
    });
  }

  @override
  Future<void> saveRoutineTemplate({
    required AppUser owner,
    required RoutineTemplate routine,
  }) async {
    await _firestore
        .collection('routineTemplates')
        .doc(routine.id)
        .set(routine.toJson(), SetOptions(merge: true));
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
                  .map((doc) => BodyWeightEntry.fromJson(doc.data()))
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
}

class DemoAgujetasRepository implements AgujetasRepository {
  final _controller = StreamController<AppUser?>.broadcast();
  final _clients = StreamController<List<TrainerClientLink>>.broadcast();
  final _customExercises =
      StreamController<List<ExerciseCatalogEntry>>.broadcast();
  final _bodyWeights = StreamController<List<BodyWeightEntry>>.broadcast();
  final List<ExerciseCatalogEntry> _customExerciseItems = [];
  final List<BodyWeightEntry> _bodyWeightItems = [];

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
  Future<void> saveRoutineTemplate({
    required AppUser owner,
    required RoutineTemplate routine,
  }) async {}

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
    required List<WorkoutExercise> exercises,
    String? trainerId,
  }) async {}

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
