enum AppRole { normal, trainer }

enum SetType { normal, warmup, dropset }

extension AppRoleX on AppRole {
  String get value => switch (this) {
    AppRole.normal => 'normal',
    AppRole.trainer => 'trainer',
  };

  String get label => switch (this) {
    AppRole.normal => 'Usuario normal',
    AppRole.trainer => 'Entrenador',
  };

  static AppRole fromValue(String? value) {
    return value == AppRole.trainer.value ? AppRole.trainer : AppRole.normal;
  }
}

extension SetTypeX on SetType {
  String get value => switch (this) {
    SetType.normal => 'normal',
    SetType.warmup => 'warmup',
    SetType.dropset => 'dropset',
  };

  String get label => switch (this) {
    SetType.normal => 'Normal',
    SetType.warmup => 'Calentamiento',
    SetType.dropset => 'Dropset',
  };

  static SetType fromValue(String? value) {
    return switch ((value ?? '').trim().toLowerCase()) {
      'warmup' ||
      'calentamiento' ||
      'entrada' ||
      'entrada en calor' => SetType.warmup,
      'dropset' || 'drop' || 'drop set' || 'descendente' => SetType.dropset,
      _ => SetType.normal,
    };
  }
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.roles,
    required this.activeRole,
  });

  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final Set<AppRole> roles;
  final AppRole activeRole;

  bool get isTrainer => roles.contains(AppRole.trainer);

  Map<String, Object?> toJson() => {
    'uid': uid,
    'displayName': displayName,
    'email': email,
    'photoURL': photoUrl,
    'roles': roles.map((role) => role.value).toList(),
    'activeRole': activeRole.value,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
  };

  factory AppUser.fromJson(Map<String, Object?> json) {
    final roleValues = (json['roles'] as List<dynamic>? ?? const ['normal'])
        .map((value) => AppRoleX.fromValue(value?.toString()))
        .toSet();
    final roles = roleValues.isEmpty ? {AppRole.normal} : roleValues;
    final activeRole = AppRoleX.fromValue(json['activeRole']?.toString());
    return AppUser(
      uid: json['uid']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'Agujetas',
      email: json['email']?.toString() ?? '',
      photoUrl: json['photoURL']?.toString(),
      roles: roles,
      activeRole: roles.contains(activeRole) ? activeRole : roles.first,
    );
  }

  AppUser copyWith({Set<AppRole>? roles, AppRole? activeRole}) {
    return AppUser(
      uid: uid,
      displayName: displayName,
      email: email,
      photoUrl: photoUrl,
      roles: roles ?? this.roles,
      activeRole: activeRole ?? this.activeRole,
    );
  }
}

class WeightSegment {
  const WeightSegment({required this.weightKg, required this.reps});

  final double weightKg;
  final int reps;

  Map<String, Object?> toJson() => {'weightKg': weightKg, 'reps': reps};

  factory WeightSegment.fromJson(Map<String, Object?> json) {
    return WeightSegment(
      weightKg: _readDouble(json['weightKg']),
      reps: _readInt(json['reps']),
    );
  }
}

class WorkoutSet {
  const WorkoutSet({
    required this.order,
    required this.setType,
    required this.segments,
    this.rir,
    this.done = false,
  });

  final int order;
  final SetType setType;
  final List<WeightSegment> segments;
  final int? rir;
  final bool done;

  double get primaryWeightKg => segments.isEmpty ? 0 : segments.first.weightKg;
  int get totalReps =>
      segments.fold<int>(0, (sum, segment) => sum + segment.reps);
  bool get hasBackoffSegment => segments.length > 1;

  Map<String, Object?> toJson() => {
    'order': order,
    'setType': setType.value,
    'segments': segments.map((segment) => segment.toJson()).toList(),
    'rir': rir,
    'done': done,
  };

  factory WorkoutSet.fromJson(Map<String, Object?> json) {
    final rawSegments = json['segments'] as List<dynamic>?;
    return WorkoutSet(
      order: _readInt(json['order']),
      setType: SetTypeX.fromValue(json['setType']?.toString()),
      segments: rawSegments == null || rawSegments.isEmpty
          ? [
              WeightSegment(
                weightKg: _readDouble(json['weightKg']),
                reps: _readInt(json['reps']),
              ),
            ]
          : rawSegments
                .whereType<Map>()
                .map(
                  (raw) => WeightSegment.fromJson(raw.cast<String, Object?>()),
                )
                .toList(),
      rir: json['rir'] == null ? null : _readInt(json['rir']),
      done: json['done'] == true,
    );
  }

  WorkoutSet copyWith({
    SetType? setType,
    List<WeightSegment>? segments,
    int? rir,
    bool? done,
  }) {
    return WorkoutSet(
      order: order,
      setType: setType ?? this.setType,
      segments: segments ?? this.segments,
      rir: rir ?? this.rir,
      done: done ?? this.done,
    );
  }
}

class WorkoutExercise {
  const WorkoutExercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.isUnilateral,
    required this.sets,
  });

  final String id;
  final String name;
  final String muscleGroup;
  final bool isUnilateral;
  final List<WorkoutSet> sets;

  Map<String, Object?> toJson() => {
    'exerciseId': id,
    'name': name,
    'muscleGroup': muscleGroup,
    'isUnilateral': isUnilateral,
    'sets': sets.map((set) => set.toJson()).toList(),
  };

  factory WorkoutExercise.fromJson(Map<String, Object?> json) {
    return WorkoutExercise(
      id: json['exerciseId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      muscleGroup: json['muscleGroup']?.toString() ?? 'General',
      isUnilateral: json['isUnilateral'] == true,
      sets: (json['sets'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((raw) => WorkoutSet.fromJson(raw.cast<String, Object?>()))
          .toList(),
    );
  }

  WorkoutExercise copyWith({bool? isUnilateral, List<WorkoutSet>? sets}) {
    return WorkoutExercise(
      id: id,
      name: name,
      muscleGroup: muscleGroup,
      isUnilateral: isUnilateral ?? this.isUnilateral,
      sets: sets ?? this.sets,
    );
  }
}

class RoutineTemplate {
  const RoutineTemplate({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.exercises,
    this.assignedClientId,
  });

  final String id;
  final String ownerId;
  final String title;
  final List<WorkoutExercise> exercises;
  final String? assignedClientId;

  Map<String, Object?> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'title': title,
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
    'assignedClientId': assignedClientId,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
  };
}

class TrainerInvite {
  const TrainerInvite({
    required this.code,
    required this.trainerId,
    required this.trainerName,
    required this.createdAt,
    this.active = true,
  });

  final String code;
  final String trainerId;
  final String trainerName;
  final DateTime createdAt;
  final bool active;

  Map<String, Object?> toJson() => {
    'code': code,
    'trainerId': trainerId,
    'trainerName': trainerName,
    'active': active,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory TrainerInvite.fromJson(Map<String, Object?> json) {
    return TrainerInvite(
      code: json['code']?.toString() ?? '',
      trainerId: json['trainerId']?.toString() ?? '',
      trainerName: json['trainerName']?.toString() ?? 'Entrenador',
      active: json['active'] != false,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

class TrainerClientLink {
  const TrainerClientLink({
    required this.id,
    required this.trainerId,
    required this.clientId,
    required this.clientName,
    required this.status,
  });

  final String id;
  final String trainerId;
  final String clientId;
  final String clientName;
  final String status;

  Map<String, Object?> toJson() => {
    'id': id,
    'trainerId': trainerId,
    'clientId': clientId,
    'clientName': clientName,
    'status': status,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
  };

  factory TrainerClientLink.fromJson(Map<String, Object?> json) {
    return TrainerClientLink(
      id: json['id']?.toString() ?? '',
      trainerId: json['trainerId']?.toString() ?? '',
      clientId: json['clientId']?.toString() ?? '',
      clientName: json['clientName']?.toString() ?? 'Entrenado',
      status: json['status']?.toString() ?? 'active',
    );
  }
}

List<WorkoutExercise> seedWorkout() => [
  WorkoutExercise(
    id: 'bench_press',
    name: 'Press banca',
    muscleGroup: 'Pectoral',
    isUnilateral: false,
    sets: const [
      WorkoutSet(
        order: 1,
        setType: SetType.warmup,
        segments: [WeightSegment(weightKg: 40, reps: 12)],
        rir: 4,
      ),
      WorkoutSet(
        order: 2,
        setType: SetType.normal,
        segments: [WeightSegment(weightKg: 70, reps: 8)],
        rir: 2,
      ),
      WorkoutSet(
        order: 3,
        setType: SetType.dropset,
        segments: [
          WeightSegment(weightKg: 70, reps: 6),
          WeightSegment(weightKg: 50, reps: 8),
        ],
        rir: 1,
      ),
    ],
  ),
  WorkoutExercise(
    id: 'db_row',
    name: 'Remo mancuerna',
    muscleGroup: 'Espalda',
    isUnilateral: true,
    sets: const [
      WorkoutSet(
        order: 1,
        setType: SetType.normal,
        segments: [WeightSegment(weightKg: 24, reps: 10)],
        rir: 2,
      ),
      WorkoutSet(
        order: 2,
        setType: SetType.dropset,
        segments: [
          WeightSegment(weightKg: 24, reps: 8),
          WeightSegment(weightKg: 16, reps: 6),
        ],
        rir: 1,
      ),
    ],
  ),
];

double _readDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
}

int _readInt(Object? value) {
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
