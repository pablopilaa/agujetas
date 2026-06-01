import 'exercise_image_resolver.dart';

enum AppRole { normal, trainer }

enum AppPlan { free, pro }

enum AppEntitlement { trainerMode, clientAssignments, routineSharing }

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

extension AppPlanX on AppPlan {
  String get value => switch (this) {
    AppPlan.free => 'free',
    AppPlan.pro => 'pro',
  };

  String get label => switch (this) {
    AppPlan.free => 'Free',
    AppPlan.pro => 'Pro',
  };

  static AppPlan fromValue(String? value) {
    return value == AppPlan.pro.value ? AppPlan.pro : AppPlan.free;
  }

  Set<AppEntitlement> get entitlements => switch (this) {
    AppPlan.free => const {},
    AppPlan.pro => const {
      AppEntitlement.trainerMode,
      AppEntitlement.clientAssignments,
      AppEntitlement.routineSharing,
    },
  };
}

extension AppEntitlementX on AppEntitlement {
  String get value => switch (this) {
    AppEntitlement.trainerMode => 'trainer_mode',
    AppEntitlement.clientAssignments => 'client_assignments',
    AppEntitlement.routineSharing => 'routine_sharing',
  };

  String get label => switch (this) {
    AppEntitlement.trainerMode => 'Modo entrenador',
    AppEntitlement.clientAssignments => 'Gestión de entrenados',
    AppEntitlement.routineSharing => 'Rutinas compartidas',
  };
}

class SubscriptionPlanDefinition {
  const SubscriptionPlanDefinition({
    required this.id,
    required this.plan,
    required this.title,
    required this.priceLabel,
    required this.subtitle,
    required this.features,
  });

  final String id;
  final AppPlan plan;
  final String title;
  final String priceLabel;
  final String subtitle;
  final List<String> features;

  Set<AppEntitlement> get entitlements => plan.entitlements;

  bool get isPro => plan == AppPlan.pro;

  static const free = SubscriptionPlanDefinition(
    id: 'free',
    plan: AppPlan.free,
    title: 'Agujetas Free',
    priceLabel: 'Gratis',
    subtitle: 'Entrenamiento personal local-first sin pagar cloud.',
    features: [
      'Sesión activa, rutinas e historial local',
      'Calendario mensual y progreso personal',
      'Ejercicios personalizados con imagen local',
    ],
  );

  static const pro = SubscriptionPlanDefinition(
    id: 'pro_monthly',
    plan: AppPlan.pro,
    title: 'Agujetas Pro',
    priceLabel: 'Precio pendiente',
    subtitle:
        'Herramientas comerciales para entrenadores y usuarios avanzados.',
    features: [
      'Modo entrenador y panel de entrenados',
      'Asignación de rutinas, tareas, schedules y metas',
      'Preparado para checkout con RevenueCat',
    ],
  );

  static const all = [free, pro];

  static SubscriptionPlanDefinition forPlan(AppPlan plan) {
    return all.firstWhere((item) => item.plan == plan);
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
    required this.plan,
  });

  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final Set<AppRole> roles;
  final AppRole activeRole;
  final AppPlan plan;

  bool get isTrainer => roles.contains(AppRole.trainer);
  bool get isPro => plan == AppPlan.pro;
  Set<AppEntitlement> get entitlements => plan.entitlements;
  bool hasEntitlement(AppEntitlement entitlement) =>
      entitlements.contains(entitlement);
  bool get canUseTrainerMode => hasEntitlement(AppEntitlement.trainerMode);

  Map<String, Object?> toJson() => {
    'uid': uid,
    'displayName': displayName,
    'email': email,
    'photoURL': photoUrl,
    'roles': roles.map((role) => role.value).toList(),
    'activeRole': activeRole.value,
    'plan': plan.value,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
  };

  factory AppUser.fromJson(Map<String, Object?> json) {
    final roleValues = (json['roles'] as List<dynamic>? ?? const ['normal'])
        .map((value) => AppRoleX.fromValue(value?.toString()))
        .toSet();
    final roles = {AppRole.normal, ...roleValues};
    final activeRole = AppRoleX.fromValue(json['activeRole']?.toString());
    final plan = AppPlanX.fromValue(json['plan']?.toString());
    final activeRoleAllowed =
        activeRole == AppRole.normal ||
        (plan.entitlements.contains(AppEntitlement.trainerMode) &&
            roles.contains(AppRole.trainer));
    return AppUser(
      uid: json['uid']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'Agujetas',
      email: json['email']?.toString() ?? '',
      photoUrl: json['photoURL']?.toString(),
      roles: roles,
      activeRole: activeRoleAllowed ? activeRole : AppRole.normal,
      plan: plan,
    );
  }

  AppUser copyWith({Set<AppRole>? roles, AppRole? activeRole, AppPlan? plan}) {
    return AppUser(
      uid: uid,
      displayName: displayName,
      email: email,
      photoUrl: photoUrl,
      roles: roles ?? this.roles,
      activeRole: activeRole ?? this.activeRole,
      plan: plan ?? this.plan,
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
    this.imageUri,
    this.isCustom = false,
  });

  final String id;
  final String name;
  final String muscleGroup;
  final bool isUnilateral;
  final List<WorkoutSet> sets;
  final String? imageUri;
  final bool isCustom;

  Map<String, Object?> toJson() => {
    'exerciseId': id,
    'name': name,
    'muscleGroup': muscleGroup,
    'isUnilateral': isUnilateral,
    'sets': sets.map((set) => set.toJson()).toList(),
    'imageUri': imageUri,
    'isCustom': isCustom,
  };

  factory WorkoutExercise.fromJson(Map<String, Object?> json) {
    final sets = (json['sets'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((raw) => WorkoutSet.fromJson(raw.cast<String, Object?>()))
        .toList();
    return WorkoutExercise(
      id: json['exerciseId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      muscleGroup: json['muscleGroup']?.toString() ?? 'General',
      isUnilateral: json['isUnilateral'] == true,
      sets: sets.isEmpty ? defaultWorkoutSets() : sets,
      imageUri: sanitizeExerciseImageUri(json['imageUri']?.toString()),
      isCustom: json['isCustom'] == true,
    );
  }

  WorkoutExercise copyWith({
    String? name,
    String? muscleGroup,
    bool? isUnilateral,
    List<WorkoutSet>? sets,
    String? imageUri,
    bool? isCustom,
  }) {
    return WorkoutExercise(
      id: id,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      isUnilateral: isUnilateral ?? this.isUnilateral,
      sets: sets ?? this.sets,
      imageUri: imageUri ?? this.imageUri,
      isCustom: isCustom ?? this.isCustom,
    );
  }
}

class ExerciseCatalogEntry {
  const ExerciseCatalogEntry({
    required this.id,
    required this.name,
    required this.muscleGroup,
    this.imageUri,
    this.usageCount = 0,
    this.lastUsedDate,
    this.isCustom = false,
  });

  final String id;
  final String name;
  final String muscleGroup;
  final String? imageUri;
  final int usageCount;
  final DateTime? lastUsedDate;
  final bool isCustom;

  WorkoutExercise toWorkoutExercise() => WorkoutExercise(
    id: id,
    name: name,
    muscleGroup: muscleGroup,
    isUnilateral: false,
    sets: defaultWorkoutSets(),
    imageUri: imageUri,
    isCustom: isCustom,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'muscleGroup': muscleGroup,
    'imageUri': imageUri,
    'usageCount': usageCount,
    'lastUsedDate': lastUsedDate?.toUtc().toIso8601String(),
    'isCustom': isCustom,
  };

  factory ExerciseCatalogEntry.fromJson(Map<String, Object?> json) {
    final rawName = json['name'] ?? json['ejercicio'];
    final rawMuscle = json['muscleGroup'] ?? json['musculo'];
    final name = rawName?.toString().trim() ?? '';
    return ExerciseCatalogEntry(
      id: json['id']?.toString() ?? json['key']?.toString() ?? name,
      name: name,
      muscleGroup: rawMuscle?.toString().trim() ?? 'General',
      imageUri: sanitizeExerciseImageUri(json['imageUri']?.toString()),
      usageCount: _readInt(json['usageCount']),
      lastUsedDate: DateTime.tryParse(json['lastUsedDate']?.toString() ?? ''),
      isCustom: json['isCustom'] == true || json['inCustomSession'] == true,
    );
  }

  ExerciseCatalogEntry copyWith({
    String? name,
    String? muscleGroup,
    String? imageUri,
    int? usageCount,
    DateTime? lastUsedDate,
    bool? isCustom,
  }) {
    return ExerciseCatalogEntry(
      id: id,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      imageUri: imageUri ?? this.imageUri,
      usageCount: usageCount ?? this.usageCount,
      lastUsedDate: lastUsedDate ?? this.lastUsedDate,
      isCustom: isCustom ?? this.isCustom,
    );
  }
}

class BodyWeightEntry {
  const BodyWeightEntry({
    required this.id,
    required this.userId,
    required this.weightKg,
    required this.recordedAt,
    this.note,
  });

  final String id;
  final String userId;
  final double weightKg;
  final DateTime recordedAt;
  final String? note;

  Map<String, Object?> toJson() => {
    'id': id,
    'userId': userId,
    'weightKg': weightKg,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'note': note,
  };

  factory BodyWeightEntry.fromJson(Map<String, Object?> json) {
    return BodyWeightEntry(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      weightKg: _readDouble(json['weightKg']),
      recordedAt:
          DateTime.tryParse(json['recordedAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      note: json['note']?.toString(),
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

  RoutineTemplate copyWith({
    String? id,
    String? ownerId,
    String? title,
    List<WorkoutExercise>? exercises,
    String? assignedClientId,
  }) {
    return RoutineTemplate(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      exercises: exercises ?? this.exercises,
      assignedClientId: assignedClientId ?? this.assignedClientId,
    );
  }

  factory RoutineTemplate.fromJson(Map<String, Object?> json) {
    final exercises = (json['exercises'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((raw) => WorkoutExercise.fromJson(raw.cast<String, Object?>()))
        .toList();
    return RoutineTemplate(
      id: json['id']?.toString() ?? '',
      ownerId: json['ownerId']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Rutina importada',
      exercises: exercises,
      assignedClientId: json['assignedClientId']?.toString(),
    );
  }
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

class AssignedRoutine {
  const AssignedRoutine({
    required this.id,
    required this.trainerId,
    required this.assignedClientId,
    required this.routineTemplateId,
    required this.routineTitle,
    required this.exercises,
    required this.status,
    required this.assignedAt,
  });

  final String id;
  final String trainerId;
  final String assignedClientId;
  final String routineTemplateId;
  final String routineTitle;
  final List<WorkoutExercise> exercises;
  final String status;
  final DateTime assignedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'trainerId': trainerId,
    'assignedClientId': assignedClientId,
    'routineTemplateId': routineTemplateId,
    'routineTitle': routineTitle,
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
    'status': status,
    'assignedAt': assignedAt.toUtc().toIso8601String(),
    'schemaVersion': 1,
  };

  factory AssignedRoutine.fromJson(Map<String, Object?> json) {
    final exercises = (json['exercises'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((raw) => WorkoutExercise.fromJson(raw.cast<String, Object?>()))
        .toList();
    return AssignedRoutine(
      id: json['id']?.toString() ?? '',
      trainerId: json['trainerId']?.toString() ?? '',
      assignedClientId: json['assignedClientId']?.toString() ?? '',
      routineTemplateId: json['routineTemplateId']?.toString() ?? '',
      routineTitle: json['routineTitle']?.toString() ?? 'Rutina asignada',
      exercises: exercises,
      status: json['status']?.toString() ?? 'assigned',
      assignedAt:
          DateTime.tryParse(json['assignedAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

class AssignedTask {
  const AssignedTask({
    required this.id,
    required this.trainerId,
    required this.assignedClientId,
    required this.title,
    required this.description,
    required this.status,
    required this.assignedAt,
    this.dueAt,
  });

  final String id;
  final String trainerId;
  final String assignedClientId;
  final String title;
  final String description;
  final String status;
  final DateTime assignedAt;
  final DateTime? dueAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'trainerId': trainerId,
    'assignedClientId': assignedClientId,
    'title': title,
    'description': description,
    'status': status,
    'assignedAt': assignedAt.toUtc().toIso8601String(),
    'dueAt': dueAt?.toUtc().toIso8601String(),
    'schemaVersion': 1,
  };

  factory AssignedTask.fromJson(Map<String, Object?> json) {
    return AssignedTask(
      id: json['id']?.toString() ?? '',
      trainerId: json['trainerId']?.toString() ?? '',
      assignedClientId: json['assignedClientId']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Tarea asignada',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      assignedAt:
          DateTime.tryParse(json['assignedAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      dueAt: DateTime.tryParse(json['dueAt']?.toString() ?? ''),
    );
  }

  AssignedTask copyWith({String? status}) {
    return AssignedTask(
      id: id,
      trainerId: trainerId,
      assignedClientId: assignedClientId,
      title: title,
      description: description,
      status: status ?? this.status,
      assignedAt: assignedAt,
      dueAt: dueAt,
    );
  }
}

class AssignedSchedule {
  const AssignedSchedule({
    required this.id,
    required this.trainerId,
    required this.assignedClientId,
    required this.title,
    required this.scheduledFor,
    required this.status,
    required this.assignedAt,
    this.note,
    this.routineTemplateId,
    this.routineTitle,
  });

  final String id;
  final String trainerId;
  final String assignedClientId;
  final String title;
  final DateTime scheduledFor;
  final String status;
  final DateTime assignedAt;
  final String? note;
  final String? routineTemplateId;
  final String? routineTitle;

  Map<String, Object?> toJson() => {
    'id': id,
    'trainerId': trainerId,
    'assignedClientId': assignedClientId,
    'title': title,
    'scheduledFor': scheduledFor.toUtc().toIso8601String(),
    'status': status,
    'assignedAt': assignedAt.toUtc().toIso8601String(),
    'note': note,
    'routineTemplateId': routineTemplateId,
    'routineTitle': routineTitle,
    'schemaVersion': 1,
  };

  factory AssignedSchedule.fromJson(Map<String, Object?> json) {
    return AssignedSchedule(
      id: json['id']?.toString() ?? '',
      trainerId: json['trainerId']?.toString() ?? '',
      assignedClientId: json['assignedClientId']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Sesión planificada',
      scheduledFor:
          DateTime.tryParse(json['scheduledFor']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      status: json['status']?.toString() ?? 'scheduled',
      assignedAt:
          DateTime.tryParse(json['assignedAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      note: json['note']?.toString(),
      routineTemplateId: json['routineTemplateId']?.toString(),
      routineTitle: json['routineTitle']?.toString(),
    );
  }

  AssignedSchedule copyWith({String? status, DateTime? scheduledFor}) {
    return AssignedSchedule(
      id: id,
      trainerId: trainerId,
      assignedClientId: assignedClientId,
      title: title,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      status: status ?? this.status,
      assignedAt: assignedAt,
      note: note,
      routineTemplateId: routineTemplateId,
      routineTitle: routineTitle,
    );
  }
}

class AssignedGoal {
  const AssignedGoal({
    required this.id,
    required this.trainerId,
    required this.assignedClientId,
    required this.title,
    required this.metric,
    required this.targetValue,
    required this.currentValue,
    required this.unit,
    required this.status,
    required this.assignedAt,
    this.dueAt,
    this.note,
  });

  final String id;
  final String trainerId;
  final String assignedClientId;
  final String title;
  final String metric;
  final double targetValue;
  final double currentValue;
  final String unit;
  final String status;
  final DateTime assignedAt;
  final DateTime? dueAt;
  final String? note;

  double get progressRatio {
    if (targetValue <= 0) return 0;
    return (currentValue / targetValue).clamp(0, 1);
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'trainerId': trainerId,
    'assignedClientId': assignedClientId,
    'title': title,
    'metric': metric,
    'targetValue': targetValue,
    'currentValue': currentValue,
    'unit': unit,
    'status': status,
    'assignedAt': assignedAt.toUtc().toIso8601String(),
    'dueAt': dueAt?.toUtc().toIso8601String(),
    'note': note,
    'schemaVersion': 1,
  };

  factory AssignedGoal.fromJson(Map<String, Object?> json) {
    return AssignedGoal(
      id: json['id']?.toString() ?? '',
      trainerId: json['trainerId']?.toString() ?? '',
      assignedClientId: json['assignedClientId']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Meta asignada',
      metric: json['metric']?.toString() ?? 'custom',
      targetValue: _readDouble(json['targetValue']),
      currentValue: _readDouble(json['currentValue']),
      unit: json['unit']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      assignedAt:
          DateTime.tryParse(json['assignedAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      dueAt: DateTime.tryParse(json['dueAt']?.toString() ?? ''),
      note: json['note']?.toString(),
    );
  }

  AssignedGoal copyWith({double? currentValue, String? status}) {
    return AssignedGoal(
      id: id,
      trainerId: trainerId,
      assignedClientId: assignedClientId,
      title: title,
      metric: metric,
      targetValue: targetValue,
      currentValue: currentValue ?? this.currentValue,
      unit: unit,
      status: status ?? this.status,
      assignedAt: assignedAt,
      dueAt: dueAt,
      note: note,
    );
  }
}

List<WorkoutSet> defaultWorkoutSets() => const [
  WorkoutSet(
    order: 1,
    setType: SetType.normal,
    segments: [WeightSegment(weightKg: 0, reps: 0)],
  ),
  WorkoutSet(
    order: 2,
    setType: SetType.normal,
    segments: [WeightSegment(weightKg: 0, reps: 0)],
  ),
  WorkoutSet(
    order: 3,
    setType: SetType.normal,
    segments: [WeightSegment(weightKg: 0, reps: 0)],
  ),
];

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
      WorkoutSet(
        order: 3,
        setType: SetType.normal,
        segments: [WeightSegment(weightKg: 20, reps: 10)],
        rir: 2,
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
