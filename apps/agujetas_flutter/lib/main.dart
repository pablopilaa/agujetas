import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'app_theme.dart';
import 'exercise_image_resolver.dart';
import 'firebase_options.dart';
import 'legacy_history_importer.dart';
import 'legal_contract.dart';
import 'local_workout_store.dart';
import 'models.dart';
import 'notification_service.dart';
import 'repositories.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    await NotificationService.initialize();
  }
  runApp(AgujetasApp(repository: FirebaseAgujetasRepository()));
}

class AgujetasApp extends StatefulWidget {
  const AgujetasApp({super.key, required this.repository});

  final AgujetasRepository repository;

  @override
  State<AgujetasApp> createState() => _AgujetasAppState();
}

class _AgujetasAppState extends State<AgujetasApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agujetas',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: AgujetasTheme.light(),
      darkTheme: AgujetasTheme.dark(),
      home: AuthGate(
        repository: widget.repository,
        themeMode: _themeMode,
        onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.repository,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final AgujetasRepository repository;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: repository.authUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        final user = snapshot.data;
        if (user == null) {
          return LoginScreen(repository: repository);
        }
        if (user.uid == 'demo-user') {
          return HomeShell(
            repository: repository,
            user: user,
            themeMode: themeMode,
            onThemeModeChanged: onThemeModeChanged,
          );
        }
        return PrivacyConsentGate(
          repository: repository,
          user: user,
          themeMode: themeMode,
          onThemeModeChanged: onThemeModeChanged,
        );
      },
    );
  }
}

class PrivacyConsentGate extends StatefulWidget {
  PrivacyConsentGate({
    super.key,
    required this.repository,
    required this.user,
    required this.themeMode,
    required this.onThemeModeChanged,
    LocalWorkoutStore? localStore,
  }) : localStore = localStore ?? LocalWorkoutStore.instance;

  final AgujetasRepository repository;
  final AppUser user;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final LocalWorkoutStore localStore;

  @override
  State<PrivacyConsentGate> createState() => _PrivacyConsentGateState();
}

class _PrivacyConsentGateState extends State<PrivacyConsentGate> {
  late Future<LocalPrivacyConsent?> _consentFuture;

  @override
  void initState() {
    super.initState();
    _consentFuture = widget.localStore.loadPrivacyConsent(widget.user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LocalPrivacyConsent?>(
      future: _consentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        final consent = snapshot.data;
        if (consent?.isCurrent != true) {
          return PrivacyConsentScreen(
            user: widget.user,
            onAccept: _acceptConsent,
            onSignOut: widget.repository.signOut,
          );
        }
        return HomeShell(
          repository: widget.repository,
          user: widget.user,
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
        );
      },
    );
  }

  Future<void> _acceptConsent() async {
    await widget.localStore.savePrivacyConsent(
      userId: widget.user.uid,
      consent: LocalPrivacyConsent(acceptedAt: DateTime.now().toUtc()),
    );
    if (mounted) {
      setState(() {
        _consentFuture = widget.localStore.loadPrivacyConsent(widget.user.uid);
      });
    }
  }
}

extension AppUserUiX on AppUser {
  String get firstName {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return 'Atleta';
    return trimmed.split(RegExp(r'\s+')).first;
  }
}

ThemeMode _themeModeFromPreference(String value) {
  return switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

String _themeModeToPreference(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: BrandMark(
          size: 96,
          dark: Theme.of(context).brightness == Brightness.dark,
        ),
      ),
    );
  }
}

class PrivacyConsentScreen extends StatefulWidget {
  const PrivacyConsentScreen({
    super.key,
    required this.user,
    required this.onAccept,
    required this.onSignOut,
  });

  final AppUser user;
  final Future<void> Function() onAccept;
  final Future<void> Function() onSignOut;

  @override
  State<PrivacyConsentScreen> createState() => _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends State<PrivacyConsentScreen> {
  bool _termsAccepted = false;
  bool _syncAccepted = false;
  bool _mediaAcknowledged = false;
  bool _notificationsAcknowledged = false;
  bool _saving = false;
  String? _error;

  bool get _canContinue =>
      _termsAccepted &&
      _syncAccepted &&
      _mediaAcknowledged &&
      _notificationsAcknowledged &&
      !_saving;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: BrandMark(size: 72, dark: dark)),
                  const SizedBox(height: 18),
                  Text(
                    'Privacidad y datos',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colors.primaryStrong,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Antes de empezar, confirmá cómo Agujetas maneja tus datos de entrenamiento.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Versión ${AgujetasLegalContract.effectiveDateLabel}. ${AgujetasLegalContract.legalReviewNotice}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  _ConsentTile(
                    value: _termsAccepted,
                    onChanged: (value) =>
                        setState(() => _termsAccepted = value),
                    requirement: AgujetasLegalContract.requirements[0],
                  ),
                  _ConsentTile(
                    value: _syncAccepted,
                    onChanged: (value) => setState(() => _syncAccepted = value),
                    requirement: AgujetasLegalContract.requirements[1],
                  ),
                  _ConsentTile(
                    value: _mediaAcknowledged,
                    onChanged: (value) =>
                        setState(() => _mediaAcknowledged = value),
                    requirement: AgujetasLegalContract.requirements[2],
                  ),
                  _ConsentTile(
                    value: _notificationsAcknowledged,
                    onChanged: (value) =>
                        setState(() => _notificationsAcknowledged = value),
                    requirement: AgujetasLegalContract.requirements[3],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    InfoBanner(text: _error!),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _canContinue ? _accept : null,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('Aceptar y continuar'),
                  ),
                  TextButton(
                    onPressed: _saving ? null : widget.onSignOut,
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _accept() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onAccept();
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar el consentimiento: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.value,
    required this.onChanged,
    required this.requirement,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final ConsentRequirement requirement;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: (next) => onChanged(next ?? false),
      title: Text(requirement.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(requirement.subtitle),
          const SizedBox(height: 4),
          Text(
            'Versión: ${requirement.version}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.repository});

  final AgujetasRepository repository;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String? _error;

  static const _heroImage =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDPYJaE2jY_n7IJ28b4ElAWQ7WgQwT5T7rd3tipiVr2aIfMeZH0CyppXnqqB-dffQUnxSuP1wu38M1CmGJ3VRgovNSqHmmSnfja_nhjBav-B1xdM-33IRC705z_l02B-g8jZjRCzdNqJV2KIJoOpQG-Yo5vwXrCJ7hxMgf7AlgXEtHhTh2Hq7CSHrN8oUf5_GAJ4nCnowCdQqkSit1h5ZqGqTfMRnh6eWPyk2NeafVA8q_ggswg30i5xnZ28Kz_txM4y2zQPdpuOzA';

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: BrandMark(size: 96, dark: dark)),
                  const SizedBox(height: 14),
                  Text(
                    'Agujetas',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: colors.primaryStrong,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _heroImage,
                      height: 256,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        height: 256,
                        color: colors.raised,
                        child: Icon(
                          Icons.fitness_center,
                          size: 72,
                          color: colors.primaryStrong,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Entrena con precisión.',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Registra tu progreso con elegancia y mantén el foco en lo que importa.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  if (_error != null) ...[
                    InfoBanner(text: _error!),
                    const SizedBox(height: 8),
                  ],
                  FilledButton.icon(
                    onPressed: _loading ? null : _signIn,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const GoogleGlyph(),
                    label: const Text('Continuar con Google'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              AgujetasApp(repository: DemoAgujetasRepository()),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Ver demo sin guardar'),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Al continuar, aceptas la sincronización segura de tus entrenamientos vía Firebase Auth y Firestore. No usamos Storage en el plan gratuito.',
                    style: Theme.of(context).textTheme.labelMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  const _LoginFeatureRow(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.signInWithGoogle();
    } catch (error) {
      setState(() => _error = 'No se pudo iniciar sesión: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}

class _LoginFeatureRow extends StatelessWidget {
  const _LoginFeatureRow();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    const items = [
      (Icons.sync, 'Sincronizar'),
      (Icons.insights, 'Progreso'),
      (Icons.library_books_outlined, 'Catálogo'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: items
          .map(
            (item) => Column(
              children: [
                Icon(item.$1, color: colors.textSecondary, size: 20),
                const SizedBox(height: 4),
                Text(item.$2, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          )
          .toList(),
    );
  }
}

class GoogleGlyph extends StatelessWidget {
  const GoogleGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Text(
        'G',
        style: TextStyle(
          color: context.appColors.primaryStrong,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.repository,
    required this.user,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final AgujetasRepository repository;
  final AppUser user;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _localStore = LocalWorkoutStore.instance;
  int _tab = 0;
  late List<WorkoutExercise> _workout;
  List<WorkoutExercise> _routineEditorExercises = const [];
  List<LocalWorkoutSession> _localSessions = const [];
  List<RoutineTemplate> _localRoutines = const [];
  List<BodyWeightEntry> _localBodyWeights = const [];
  List<ExerciseCatalogEntry> _localCustomExercises = const [];
  List<AssignedSchedule> _assignedSchedules = const [];
  List<AssignedGoal> _assignedGoals = const [];
  StreamSubscription<List<LocalWorkoutSession>>? _sessionsSubscription;
  StreamSubscription<List<RoutineTemplate>>? _routineTemplatesSubscription;
  StreamSubscription<List<BodyWeightEntry>>? _bodyWeightsSubscription;
  StreamSubscription<List<ExerciseCatalogEntry>>? _customExercisesSubscription;
  StreamSubscription<List<AssignedSchedule>>? _assignedSchedulesSubscription;
  StreamSubscription<List<AssignedGoal>>? _assignedGoalsSubscription;
  String _sessionMode = 'Fuerza';
  String _activeRoutineTitle = 'Empuje A';
  String? _editingRoutineId;
  String? _editingRoutineTitle;
  bool _workoutDirty = false;
  int _sessionResetToken = 0;
  Duration _totalElapsed = Duration.zero;
  Duration _restRemaining = const Duration(minutes: 2);
  bool _totalRunning = false;
  bool _restRunning = false;
  LocalUserPreferences _preferences = const LocalUserPreferences();
  String? _lastInviteCode;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _workout = seedWorkout();
    unawaited(_loadLocalSessions());
    unawaited(_loadLocalRoutines());
    unawaited(_loadLocalBodyWeights());
    unawaited(_loadLocalCustomExercises());
    _watchAssignedSchedules();
    _watchAssignedGoals();
    unawaited(_loadUserPreferences());
    unawaited(_restoreActiveDraft());
  }

  @override
  void dispose() {
    unawaited(_sessionsSubscription?.cancel());
    unawaited(_routineTemplatesSubscription?.cancel());
    unawaited(_bodyWeightsSubscription?.cancel());
    unawaited(_customExercisesSubscription?.cancel());
    unawaited(_assignedSchedulesSubscription?.cancel());
    unawaited(_assignedGoalsSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editingRoutine = _editingRoutineId != null;
    final libraryExercises = editingRoutine
        ? _routineEditorExercises
        : _workout;
    final ValueChanged<List<WorkoutExercise>> onLibraryExercisesChanged =
        editingRoutine ? _updateRoutineEditor : _updateWorkout;
    final pages = [
      HomeDashboard(
        user: widget.user,
        repository: widget.repository,
        inviteCode: _lastInviteCode,
        notice: _notice,
        onInviteCreated: (code) => setState(() => _lastInviteCode = code),
        onNotice: (notice) => setState(() => _notice = notice),
        selectedSessionMode: _sessionMode,
        routines: _localRoutines,
        assignedSchedules: _assignedSchedules,
        assignedGoals: _assignedGoals,
        onSessionModeSelected: _selectSessionMode,
        onStartWorkout: () => _startWorkout(_sessionMode),
        onStartRoutine: _startRoutine,
        onOpenCalendar: () => _openCalendar(context),
      ),
      TrainScreen(
        user: widget.user,
        repository: widget.repository,
        sessionMode: _sessionMode,
        routineTitle: _activeRoutineTitle,
        sessionResetToken: _sessionResetToken,
        exercises: _workout,
        localSessions: _localSessions,
        hasEditedWorkout: _workoutDirty,
        initialTotalElapsed: _totalElapsed,
        initialRestRemaining: _restRemaining,
        initialTotalRunning: _totalRunning,
        initialRestRunning: _restRunning,
        restAlertsEnabled: _preferences.restAlertsEnabled,
        localGalleryEnabled: _preferences.localGalleryEnabled,
        onExercisesChanged: _updateWorkout,
        onSaveCustomExercise: _saveCustomExerciseLocally,
        onTimerStateChanged: _updateTimerDraft,
        onSessionModeChanged: _changeTrainingMode,
        onSessionSavedLocally: _saveSessionLocally,
        onOpenLibrary: () => setState(() => _tab = 3),
      ),
      ProgressScreen(
        user: widget.user,
        repository: widget.repository,
        exercises: _workout,
        localSessions: _localSessions,
        bodyWeights: _localBodyWeights,
        bodyWeightAlertsEnabled: _preferences.bodyWeightAlertsEnabled,
        onOpenCalendar: () => _openCalendar(context),
        onBodyWeightSaved: _saveBodyWeightLocally,
      ),
      LibraryScreen(
        user: widget.user,
        repository: widget.repository,
        exercises: libraryExercises,
        localSessions: _localSessions,
        routines: _localRoutines,
        editingRoutineId: _editingRoutineId,
        editingRoutineTitle: _editingRoutineTitle,
        customExercises: _localCustomExercises,
        onExercisesChanged: onLibraryExercisesChanged,
        onStartRoutine: _startRoutine,
        onEditRoutine: _editRoutine,
        onCreateRoutine: _createRoutine,
        onSaveRoutine: _saveRoutine,
        onSaveEditingRoutine: _saveEditingRoutine,
        onSaveEditingRoutineAsCopy: _saveEditingRoutineAsCopy,
        onDeleteRoutine: _deleteRoutine,
        onDuplicateRoutine: _duplicateRoutine,
        onMoveRoutine: _moveRoutine,
        onSaveCustomExercise: _saveCustomExerciseLocally,
        onDeleteCustomExercise: _deleteCustomExerciseLocally,
        localGalleryEnabled: _preferences.localGalleryEnabled,
      ),
      ProfileScreen(
        user: widget.user,
        repository: widget.repository,
        themeMode: widget.themeMode,
        preferences: _preferences,
        onThemeModeChanged: _updateThemeMode,
        onPreferencesChanged: _updateUserPreferences,
        onExportLocalBackup: _exportLocalBackup,
        onImportLocalBackup: _importLocalBackup,
        onImportBundledLegacyData: _importBundledLegacyData,
        onDeleteLocalAccount: _deleteLocalAccount,
      ),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: StitchBottomNav(
        selectedIndex: _tab,
        onSelected: (index) => setState(() => _tab = index),
      ),
    );
  }

  void _openCalendar(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => MonthlySessionCalendarSheet(
        sessions: _localSessions,
        schedules: _assignedSchedules,
        onRepeatSession: _repeatHistoricalSession,
        onSaveSessionAsRoutine: _saveHistoricalSessionAsRoutine,
        onUpdateSession: _updateHistoricalSession,
        onDeleteSession: _deleteHistoricalSession,
      ),
    );
  }

  void _selectSessionMode(String mode) {
    _startWorkout(mode);
  }

  void _watchAssignedSchedules() {
    _assignedSchedulesSubscription = widget.repository
        .watchAssignedSchedulesForClient(widget.user.uid)
        .listen((schedules) {
          if (!mounted) return;
          setState(() => _assignedSchedules = schedules);
        });
  }

  void _watchAssignedGoals() {
    _assignedGoalsSubscription = widget.repository
        .watchAssignedGoalsForClient(widget.user.uid)
        .listen((goals) {
          if (!mounted) return;
          setState(() => _assignedGoals = goals);
        });
  }

  void _startWorkout(String mode) {
    setState(() {
      _sessionMode = mode;
      _activeRoutineTitle = 'Empuje A';
      _editingRoutineId = null;
      _editingRoutineTitle = null;
      _tab = 1;
      _totalElapsed = Duration.zero;
      _restRemaining = const Duration(minutes: 2);
      _totalRunning = false;
      _restRunning = false;
      _sessionResetToken++;
    });
    unawaited(_persistActiveDraft());
  }

  void _startRoutine(RoutineTemplate routine) {
    setState(() {
      _workout = _cloneWorkoutExercises(routine.exercises);
      _activeRoutineTitle = routine.title;
      _workoutDirty = true;
      _tab = 1;
      _totalElapsed = Duration.zero;
      _restRemaining = const Duration(minutes: 2);
      _totalRunning = false;
      _restRunning = false;
      _sessionResetToken++;
    });
    unawaited(_persistActiveDraft());
  }

  void _repeatHistoricalSession(LocalWorkoutSession session) {
    setState(() {
      _sessionMode = _sessionModeForHistoricalRepeat(session.sessionMode);
      _workout = _cloneWorkoutExercises(session.exercises);
      _activeRoutineTitle = 'Repetir ${_sessionTitle(session)}';
      _workoutDirty = true;
      _editingRoutineId = null;
      _editingRoutineTitle = null;
      _routineEditorExercises = const [];
      _tab = 1;
      _notice = 'Sesión histórica cargada como entrenamiento activo.';
      _totalElapsed = Duration.zero;
      _restRemaining = const Duration(minutes: 2);
      _totalRunning = false;
      _restRunning = false;
      _sessionResetToken++;
    });
    unawaited(_persistActiveDraft());
  }

  String _sessionModeForHistoricalRepeat(String rawMode) {
    const supportedModes = {'Fuerza', 'Hipertrofia', 'Técnica', 'Libre'};
    return supportedModes.contains(rawMode) ? rawMode : 'Libre';
  }

  Future<void> _saveHistoricalSessionAsRoutine(
    LocalWorkoutSession session,
  ) async {
    final routine = RoutineTemplate(
      id: const Uuid().v4(),
      ownerId: widget.user.uid,
      title: 'Rutina desde ${_shortDate(session.finishedAt.toLocal())}',
      exercises: _cloneWorkoutExercises(session.exercises),
    );
    await _saveRoutine(routine);
  }

  Future<void> _updateHistoricalSession(LocalWorkoutSession session) async {
    await _localStore.updateSessionLocal(
      userId: widget.user.uid,
      session: session,
    );
    final sessions = await _localStore.loadSessions(widget.user.uid);
    if (!mounted) return;
    setState(() {
      _localSessions = sessions;
      _notice = 'Sesión histórica actualizada localmente.';
    });
    if (_canSyncRemoteUserData) {
      unawaited(_syncSessionBestEffort(session));
    }
  }

  Future<void> _deleteHistoricalSession(LocalWorkoutSession session) async {
    await _localStore.deleteSessionLocal(
      userId: widget.user.uid,
      sessionId: session.id,
    );
    final sessions = await _localStore.loadSessions(widget.user.uid);
    if (!mounted) return;
    setState(() {
      _localSessions = sessions;
      _notice = 'Sesión histórica eliminada de este dispositivo.';
    });
    if (_canSyncRemoteUserData) {
      unawaited(_deleteSessionBestEffort(session));
    }
  }

  void _editRoutine(RoutineTemplate routine) {
    setState(() {
      _routineEditorExercises = _cloneWorkoutExercises(routine.exercises);
      _editingRoutineId = routine.id;
      _editingRoutineTitle = routine.title;
      _tab = 3;
      _notice = 'Editando rutina "${routine.title}" localmente.';
    });
  }

  void _createRoutine(String title) {
    final normalizedTitle = title.trim().isEmpty
        ? 'Rutina nueva'
        : title.trim();
    setState(() {
      _routineEditorExercises = const [];
      _editingRoutineId = const Uuid().v4();
      _editingRoutineTitle = normalizedTitle;
      _tab = 3;
      _notice =
          'Rutina "$normalizedTitle" creada como borrador local. Agregá ejercicios y guardala.';
    });
  }

  Future<void> _saveRoutine(RoutineTemplate routine) async {
    await _localStore.saveRoutineTemplateLocal(
      userId: widget.user.uid,
      routine: routine,
    );
    final routines = await _localStore.loadRoutineTemplates(widget.user.uid);
    if (!mounted) return;
    setState(() {
      _localRoutines = routines;
      _notice = 'Rutina "${routine.title}" guardada localmente.';
      if (_editingRoutineId == routine.id) {
        _editingRoutineTitle = routine.title;
        _activeRoutineTitle = routine.title;
      }
    });
    if (_canSyncRemoteUserData) {
      unawaited(_syncRoutineTemplateBestEffort(routine));
    }
  }

  Future<void> _saveEditingRoutine() async {
    final id = _editingRoutineId;
    final title = _editingRoutineTitle;
    if (id == null || title == null) return;
    if (_routineEditorExercises.isEmpty) {
      if (!mounted) return;
      setState(() {
        _notice = 'Agregá al menos un ejercicio antes de guardar la rutina.';
      });
      return;
    }
    await _saveRoutine(
      RoutineTemplate(
        id: id,
        ownerId: widget.user.uid,
        title: title,
        exercises: _cloneWorkoutExercises(_routineEditorExercises),
      ),
    );
  }

  Future<void> _saveEditingRoutineAsCopy() async {
    final title = _editingRoutineTitle ?? _activeRoutineTitle;
    final copy = RoutineTemplate(
      id: const Uuid().v4(),
      ownerId: widget.user.uid,
      title: '$title copia',
      exercises: _cloneWorkoutExercises(_routineEditorExercises),
    );
    await _saveRoutine(copy);
  }

  Future<void> _deleteRoutine(RoutineTemplate routine) async {
    await _localStore.deleteRoutineTemplate(
      userId: widget.user.uid,
      routineId: routine.id,
    );
    final routines = await _localStore.loadRoutineTemplates(widget.user.uid);
    if (!mounted) return;
    setState(() {
      _localRoutines = routines;
      _notice = 'Rutina "${routine.title}" eliminada.';
      if (_editingRoutineId == routine.id) {
        _editingRoutineId = null;
        _editingRoutineTitle = null;
        _routineEditorExercises = const [];
      }
    });
    if (_canSyncRemoteUserData) {
      unawaited(_deleteRoutineTemplateBestEffort(routine));
    }
  }

  Future<void> _duplicateRoutine(RoutineTemplate routine) async {
    final copy = routine.copyWith(
      id: const Uuid().v4(),
      ownerId: widget.user.uid,
      title: '${routine.title} copia',
      exercises: routine.exercises
          .map((exercise) => WorkoutExercise.fromJson(exercise.toJson()))
          .toList(),
    );
    await _saveRoutine(copy);
  }

  Future<void> _moveRoutine(int oldIndex, int newIndex) async {
    if (oldIndex < 0 ||
        oldIndex >= _localRoutines.length ||
        newIndex < 0 ||
        newIndex >= _localRoutines.length ||
        oldIndex == newIndex) {
      return;
    }
    final next = [..._localRoutines];
    final routine = next.removeAt(oldIndex);
    next.insert(newIndex, routine);
    await _localStore.replaceRoutineTemplates(
      userId: widget.user.uid,
      routines: next,
    );
    if (!mounted) return;
    setState(() {
      _localRoutines = next;
      _notice = 'Orden de rutinas actualizado.';
    });
    if (_canSyncRemoteUserData) {
      unawaited(_pushLocalRoutineTemplatesBestEffort(next));
    }
  }

  void _changeTrainingMode(String mode) {
    setState(() {
      _sessionMode = mode;
      _workout = seedWorkout();
      _activeRoutineTitle = 'Empuje A';
      _editingRoutineId = null;
      _editingRoutineTitle = null;
      _routineEditorExercises = const [];
      _workoutDirty = false;
      _sessionResetToken++;
      _tab = 1;
      _totalElapsed = Duration.zero;
      _restRemaining = const Duration(minutes: 2);
      _totalRunning = false;
      _restRunning = false;
    });
    unawaited(_persistActiveDraft());
  }

  void _updateWorkout(List<WorkoutExercise> items) {
    setState(() {
      _workout = items;
      _workoutDirty = true;
    });
    unawaited(_persistActiveDraft());
  }

  void _updateRoutineEditor(List<WorkoutExercise> items) {
    setState(() {
      _routineEditorExercises = items;
    });
  }

  Future<void> _restoreActiveDraft() async {
    final draft = await _localStore.loadActiveDraft(widget.user.uid);
    if (!mounted || draft == null) return;
    setState(() {
      _workout = draft.exercises;
      _sessionMode = draft.sessionMode;
      _workoutDirty = true;
      _editingRoutineId = null;
      _editingRoutineTitle = null;
      _routineEditorExercises = const [];
      _totalElapsed = draft.totalElapsed;
      _restRemaining = draft.restRemaining;
      _totalRunning = draft.totalRunning;
      _restRunning = draft.restRunning;
      _sessionResetToken++;
      _notice = 'Restauré tu sesión activa guardada en este dispositivo.';
    });
  }

  Future<void> _loadLocalSessions() async {
    var sessions = await _localStore.loadSessions(widget.user.uid);
    if (sessions.isEmpty) {
      try {
        final result = await LegacyHistoryImporter.loadBundled(
          userId: widget.user.uid,
        );
        final imported = await _localStore.saveImportedSessions(
          userId: widget.user.uid,
          sessions: result.sessions,
        );
        if (imported > 0) {
          sessions = await _localStore.loadSessions(widget.user.uid);
          if (mounted) {
            setState(
              () => _notice =
                  'Importé $imported sesiones históricas locales desde tu backup.',
            );
          }
        }
      } catch (_) {
        // La app debe seguir usable aunque el asset histórico no exista.
      }
    }
    if (!mounted) return;
    setState(() => _localSessions = sessions);
    if (_canSyncRemoteUserData) {
      unawaited(_pushLocalSessionsBestEffort(sessions));
      _startSessionSync();
    }
  }

  Future<void> _loadLocalRoutines() async {
    var routines = await _localStore.loadRoutineTemplates(widget.user.uid);
    if (routines.isEmpty) {
      try {
        final result = await LegacyHistoryImporter.loadBundledRoutines(
          userId: widget.user.uid,
        );
        final imported = await _localStore.saveImportedRoutineTemplates(
          userId: widget.user.uid,
          routines: result.routines,
        );
        if (imported > 0) {
          routines = await _localStore.loadRoutineTemplates(widget.user.uid);
          if (mounted) {
            setState(
              () => _notice =
                  'Importé $imported rutinas y sesiones personalizadas locales.',
            );
          }
        }
      } catch (_) {
        // La app debe seguir usable aunque el asset de catálogo no exista.
      }
    }
    if (!mounted) return;
    setState(() => _localRoutines = routines);
    if (_canSyncRemoteUserData) {
      unawaited(_pushLocalRoutineTemplatesBestEffort(routines));
      _startRoutineTemplateSync();
    }
  }

  Future<void> _loadLocalBodyWeights() async {
    final entries = await _localStore.loadBodyWeights(widget.user.uid);
    if (!mounted) return;
    setState(() => _localBodyWeights = entries);
    if (_canSyncRemoteUserData) {
      unawaited(_pushLocalBodyWeightsBestEffort(entries));
      _startBodyWeightSync();
    }
  }

  Future<void> _loadLocalCustomExercises() async {
    final exercises = await _localStore.loadCustomExercises(widget.user.uid);
    if (!mounted) return;
    setState(() => _localCustomExercises = exercises);
    if (_canSyncRemoteUserData) {
      unawaited(_pushLocalCustomExercisesBestEffort(exercises));
      _startCustomExerciseSync();
    }
  }

  Future<void> _loadUserPreferences() async {
    final preferences = await _localStore.loadUserPreferences(widget.user.uid);
    if (!mounted) return;
    setState(() => _preferences = preferences);
    _applyPreferredTheme(preferences);

    try {
      final remotePreferences = await widget.repository.loadUserPreferences(
        widget.user,
      );
      if (remotePreferences == null) return;
      await _localStore.saveUserPreferences(
        userId: widget.user.uid,
        preferences: remotePreferences,
      );
      if (!mounted) return;
      setState(() => _preferences = remotePreferences);
      _applyPreferredTheme(remotePreferences);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notice =
            'No pude sincronizar preferencias remotas; sigo con datos locales.';
      });
    }
  }

  bool get _canSyncRemoteUserData => widget.user.uid != 'demo-user';

  void _startSessionSync() {
    _sessionsSubscription ??= widget.repository
        .watchSessions(widget.user.uid)
        .listen(
          (sessions) => unawaited(_mergeRemoteSessions(sessions)),
          onError: (_) {
            if (!mounted) return;
            setState(() {
              _notice =
                  'No pude leer sesiones remotas; sigo con historial local.';
            });
          },
        );
  }

  Future<void> _mergeRemoteSessions(List<LocalWorkoutSession> sessions) async {
    final changed = await _localStore.mergeSessionsLocal(
      userId: widget.user.uid,
      sessions: sessions,
    );
    final merged = await _localStore.loadSessions(widget.user.uid);
    if (!mounted) return;
    setState(() {
      _localSessions = merged;
      if (changed > 0) {
        _notice = 'Sincronicé $changed sesiones históricas.';
      }
    });
  }

  Future<void> _pushLocalSessionsBestEffort(
    List<LocalWorkoutSession> sessions,
  ) async {
    try {
      for (final session in sessions.take(250)) {
        await widget.repository.saveSession(
          user: widget.user,
          session: session,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notice =
            'Historial local conservado; la sincronización remota quedó pendiente.';
      });
    }
  }

  Future<void> _syncSessionBestEffort(LocalWorkoutSession session) async {
    try {
      await widget.repository.saveSession(user: widget.user, session: session);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notice =
            'Sesión guardada localmente; la sincronización remota quedó pendiente.';
      });
    }
  }

  Future<void> _deleteSessionBestEffort(LocalWorkoutSession session) async {
    try {
      await widget.repository.deleteSession(
        user: widget.user,
        session: session,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notice =
            'Sesión eliminada localmente; la eliminación remota quedó pendiente.';
      });
    }
  }

  void _startRoutineTemplateSync() {
    _routineTemplatesSubscription ??= widget.repository
        .watchRoutineTemplates(widget.user.uid)
        .listen(
          (routines) => unawaited(_mergeRemoteRoutineTemplates(routines)),
          onError: (_) {
            if (!mounted) return;
            setState(() {
              _notice =
                  'No pude leer rutinas remotas; sigo con rutinas locales.';
            });
          },
        );
  }

  Future<void> _mergeRemoteRoutineTemplates(
    List<RoutineTemplate> routines,
  ) async {
    final changed = await _localStore.mergeRoutineTemplatesLocal(
      userId: widget.user.uid,
      routines: routines,
    );
    final merged = await _localStore.loadRoutineTemplates(widget.user.uid);
    if (!mounted) return;
    setState(() {
      _localRoutines = merged;
      if (changed > 0) {
        _notice = 'Sincronicé $changed rutinas.';
      }
    });
  }

  Future<void> _pushLocalRoutineTemplatesBestEffort(
    List<RoutineTemplate> routines,
  ) async {
    try {
      for (final routine in routines.take(100)) {
        await widget.repository.saveRoutineTemplate(
          owner: widget.user,
          routine: routine,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notice =
            'Rutinas locales conservadas; la sincronización remota quedó pendiente.';
      });
    }
  }

  Future<void> _syncRoutineTemplateBestEffort(RoutineTemplate routine) async {
    try {
      await widget.repository.saveRoutineTemplate(
        owner: widget.user,
        routine: routine,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notice =
            'Rutina guardada localmente; la sincronización remota quedó pendiente.';
      });
    }
  }

  Future<void> _deleteRoutineTemplateBestEffort(RoutineTemplate routine) async {
    try {
      await widget.repository.deleteRoutineTemplate(
        owner: widget.user,
        routine: routine,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notice =
            'Rutina eliminada localmente; la eliminación remota quedó pendiente.';
      });
    }
  }

  void _updateUserPreferences(LocalUserPreferences preferences) {
    setState(() => _preferences = preferences);
    unawaited(_persistUserPreferences(preferences));
  }

  Future<void> _persistUserPreferences(LocalUserPreferences preferences) async {
    await _localStore.saveUserPreferences(
      userId: widget.user.uid,
      preferences: preferences,
    );
    try {
      await widget.repository.saveUserPreferences(
        user: widget.user,
        preferences: preferences,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notice =
            'Preferencias guardadas localmente; la sincronización remota quedó pendiente.';
      });
    }
  }

  void _updateThemeMode(ThemeMode mode) {
    widget.onThemeModeChanged(mode);
    _updateUserPreferences(
      _preferences.copyWith(preferredTheme: _themeModeToPreference(mode)),
    );
  }

  void _applyPreferredTheme(LocalUserPreferences preferences) {
    final mode = _themeModeFromPreference(preferences.preferredTheme);
    if (mode != widget.themeMode) {
      widget.onThemeModeChanged(mode);
    }
  }

  Future<void> _deleteLocalAccount() async {
    await widget.repository.deleteAccount(widget.user);
    await _localStore.clearAllLocalData(widget.user.uid);
  }

  Future<void> _persistActiveDraft() {
    return _localStore.saveActiveDraft(
      userId: widget.user.uid,
      sessionMode: _sessionMode,
      exercises: _workout,
      totalElapsed: _totalElapsed,
      restRemaining: _restRemaining,
      totalRunning: _totalRunning,
      restRunning: _restRunning,
    );
  }

  void _updateTimerDraft(
    Duration totalElapsed,
    Duration restRemaining,
    bool totalRunning,
    bool restRunning,
  ) {
    _totalElapsed = totalElapsed;
    _restRemaining = restRemaining;
    _totalRunning = totalRunning;
    _restRunning = restRunning;
    unawaited(_persistActiveDraft());
  }

  Future<LocalWorkoutSession> _saveSessionLocally(
    Duration totalElapsed,
    List<WorkoutExercise> exercises,
  ) async {
    final savedSession = await _localStore.saveSession(
      userId: widget.user.uid,
      sessionMode: _sessionMode,
      exercises: exercises,
      duration: totalElapsed,
    );
    await _localStore.clearActiveDraft(widget.user.uid);
    if (!mounted) return savedSession;
    setState(() {
      _workout = seedWorkout();
      _activeRoutineTitle = 'Empuje A';
      _localSessions = [
        savedSession,
        ..._localSessions.where((session) => session.id != savedSession.id),
      ].take(500).toList();
      _workoutDirty = false;
      _editingRoutineId = null;
      _editingRoutineTitle = null;
      _routineEditorExercises = const [];
      _sessionResetToken++;
      _totalElapsed = Duration.zero;
      _restRemaining = const Duration(minutes: 2);
      _totalRunning = false;
      _restRunning = false;
      _notice = 'Sesión guardada en el historial local.';
    });
    return savedSession;
  }

  Future<void> _saveBodyWeightLocally(BodyWeightEntry entry) async {
    await _localStore.saveBodyWeightLocal(
      userId: widget.user.uid,
      entry: entry,
    );
    final entries = await _localStore.loadBodyWeights(widget.user.uid);
    if (!mounted) return;
    setState(() {
      _localBodyWeights = entries;
      _notice =
          'Peso corporal ${entry.weightKg.toStringAsFixed(1)} kg guardado localmente.';
    });
    if (_canSyncRemoteUserData) {
      unawaited(_syncBodyWeightBestEffort(entry));
    }
  }

  void _startBodyWeightSync() {
    _bodyWeightsSubscription ??= widget.repository
        .watchBodyWeights(widget.user.uid)
        .listen(
          (entries) => unawaited(_mergeRemoteBodyWeights(entries)),
          onError: (_) {
            if (!mounted) return;
            setState(() {
              _notice =
                  'No pude leer peso corporal remoto; sigo con historial local.';
            });
          },
        );
  }

  Future<void> _mergeRemoteBodyWeights(List<BodyWeightEntry> entries) async {
    final changed = await _localStore.mergeBodyWeightsLocal(
      userId: widget.user.uid,
      entries: entries,
    );
    final merged = await _localStore.loadBodyWeights(widget.user.uid);
    if (!mounted) return;
    setState(() {
      _localBodyWeights = merged;
      if (changed > 0) {
        _notice = 'Sincronicé $changed registros de peso corporal.';
      }
    });
  }

  Future<void> _pushLocalBodyWeightsBestEffort(
    List<BodyWeightEntry> entries,
  ) async {
    try {
      for (final entry in entries.take(100)) {
        await widget.repository.saveBodyWeight(user: widget.user, entry: entry);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notice =
            'Peso corporal local conservado; la sincronización remota quedó pendiente.';
      });
    }
  }

  Future<void> _syncBodyWeightBestEffort(BodyWeightEntry entry) async {
    try {
      await widget.repository.saveBodyWeight(user: widget.user, entry: entry);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notice =
            'Peso corporal guardado localmente; la sincronización remota quedó pendiente.';
      });
    }
  }

  Future<void> _saveCustomExerciseLocally(ExerciseCatalogEntry exercise) async {
    await _localStore.saveCustomExerciseLocal(
      userId: widget.user.uid,
      exercise: exercise,
    );
    final exercises = await _localStore.loadCustomExercises(widget.user.uid);
    if (!mounted) return;
    setState(() {
      _localCustomExercises = exercises;
      _notice =
          'Ejercicio personalizado "${exercise.name}" guardado localmente.';
    });
    if (_canSyncRemoteUserData) {
      unawaited(_syncCustomExerciseBestEffort(exercise));
    }
  }

  Future<void> _deleteCustomExerciseLocally(
    ExerciseCatalogEntry exercise,
  ) async {
    await _localStore.deleteCustomExerciseLocal(
      userId: widget.user.uid,
      exerciseId: exercise.id,
    );
    final exercises = await _localStore.loadCustomExercises(widget.user.uid);
    if (!mounted) return;
    setState(() {
      _localCustomExercises = exercises;
      _notice = 'Ejercicio personalizado "${exercise.name}" eliminado.';
    });
    if (_canSyncRemoteUserData) {
      unawaited(_deleteCustomExerciseBestEffort(exercise));
    }
  }

  void _startCustomExerciseSync() {
    _customExercisesSubscription ??= widget.repository
        .watchCustomExercises(widget.user.uid)
        .listen(
          (exercises) => unawaited(_mergeRemoteCustomExercises(exercises)),
          onError: (_) {
            if (!mounted) return;
            setState(() {
              _notice =
                  'No pude leer ejercicios propios remotos; sigo con catálogo local.';
            });
          },
        );
  }

  Future<void> _mergeRemoteCustomExercises(
    List<ExerciseCatalogEntry> exercises,
  ) async {
    final changed = await _localStore.mergeCustomExercisesLocal(
      userId: widget.user.uid,
      exercises: exercises,
    );
    final merged = await _localStore.loadCustomExercises(widget.user.uid);
    if (!mounted) return;
    setState(() {
      _localCustomExercises = merged;
      if (changed > 0) {
        _notice = 'Sincronicé $changed ejercicios personalizados.';
      }
    });
  }

  Future<void> _pushLocalCustomExercisesBestEffort(
    List<ExerciseCatalogEntry> exercises,
  ) async {
    try {
      for (final exercise in exercises.take(250)) {
        await widget.repository.saveCustomExercise(
          owner: widget.user,
          exercise: exercise,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notice =
            'Ejercicios propios locales conservados; la sincronización remota quedó pendiente.';
      });
    }
  }

  Future<void> _syncCustomExerciseBestEffort(
    ExerciseCatalogEntry exercise,
  ) async {
    try {
      await widget.repository.saveCustomExercise(
        owner: widget.user,
        exercise: exercise,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notice =
            'Ejercicio propio guardado localmente; la sincronización remota quedó pendiente.';
      });
    }
  }

  Future<void> _deleteCustomExerciseBestEffort(
    ExerciseCatalogEntry exercise,
  ) async {
    try {
      await widget.repository.deleteCustomExercise(
        owner: widget.user,
        exercise: exercise,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notice =
            'Ejercicio propio eliminado localmente; la eliminación remota quedó pendiente.';
      });
    }
  }

  Future<String> _exportLocalBackup() {
    return _localStore.exportBackupJson(widget.user.uid);
  }

  Future<LocalBackupImportResult> _importLocalBackup(String rawJson) async {
    final result = await _localStore.importBackupJson(
      userId: widget.user.uid,
      rawJson: rawJson,
    );
    final sessions = await _localStore.loadSessions(widget.user.uid);
    final routines = await _localStore.loadRoutineTemplates(widget.user.uid);
    final bodyWeights = await _localStore.loadBodyWeights(widget.user.uid);
    final customExercises = await _localStore.loadCustomExercises(
      widget.user.uid,
    );
    if (!mounted) return result;
    setState(() {
      _localSessions = sessions;
      _localRoutines = routines;
      _localBodyWeights = bodyWeights;
      _localCustomExercises = customExercises;
      _notice = 'Respaldo local importado: ${result.summary}.';
    });
    if (_canSyncRemoteUserData) {
      unawaited(_pushLocalSessionsBestEffort(sessions));
    }
    return result;
  }

  Future<LegacyLocalImportResult> _importBundledLegacyData() async {
    final history = await LegacyHistoryImporter.loadBundled(
      userId: widget.user.uid,
    );
    final importedSessions = await _localStore.saveImportedSessions(
      userId: widget.user.uid,
      sessions: history.sessions,
    );
    final routines = await LegacyHistoryImporter.loadBundledRoutines(
      userId: widget.user.uid,
    );
    final importedRoutines = await _localStore.saveImportedRoutineTemplates(
      userId: widget.user.uid,
      routines: routines.routines,
    );
    final sessions = await _localStore.loadSessions(widget.user.uid);
    final localRoutines = await _localStore.loadRoutineTemplates(
      widget.user.uid,
    );
    final result = LegacyLocalImportResult(
      importedSessions: importedSessions,
      availableSessions: history.sessions.length,
      skippedHistoryRows: history.skippedRows,
      importedRoutines: importedRoutines,
      availableRoutines: routines.routines.length,
    );
    if (!mounted) return result;
    setState(() {
      _localSessions = sessions;
      _localRoutines = localRoutines;
      _notice = result.summary;
    });
    if (_canSyncRemoteUserData) {
      unawaited(_pushLocalSessionsBestEffort(sessions));
    }
    return result;
  }
}

class LegacyLocalImportResult {
  const LegacyLocalImportResult({
    required this.importedSessions,
    required this.availableSessions,
    required this.skippedHistoryRows,
    required this.importedRoutines,
    required this.availableRoutines,
  });

  final int importedSessions;
  final int availableSessions;
  final int skippedHistoryRows;
  final int importedRoutines;
  final int availableRoutines;

  int get totalImported => importedSessions + importedRoutines;

  String get summary {
    final skippedText = skippedHistoryRows > 0
        ? ' $skippedHistoryRows filas históricas quedaron fuera por formato.'
        : '';
    return totalImported == 0
        ? 'Datos legacy revisados: no había sesiones ni rutinas nuevas.$skippedText'
        : 'Datos legacy importados: $importedSessions sesiones y '
              '$importedRoutines rutinas nuevas.$skippedText';
  }
}

List<WorkoutExercise> _cloneWorkoutExercises(List<WorkoutExercise> exercises) {
  return exercises
      .map((exercise) => WorkoutExercise.fromJson(exercise.toJson()))
      .toList();
}

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({
    super.key,
    required this.user,
    required this.repository,
    required this.inviteCode,
    required this.notice,
    required this.onInviteCreated,
    required this.onNotice,
    required this.selectedSessionMode,
    required this.routines,
    required this.assignedSchedules,
    required this.assignedGoals,
    required this.onSessionModeSelected,
    required this.onStartWorkout,
    required this.onStartRoutine,
    required this.onOpenCalendar,
  });

  final AppUser user;
  final AgujetasRepository repository;
  final String? inviteCode;
  final String? notice;
  final ValueChanged<String> onInviteCreated;
  final ValueChanged<String> onNotice;
  final String selectedSessionMode;
  final List<RoutineTemplate> routines;
  final List<AssignedSchedule> assignedSchedules;
  final List<AssignedGoal> assignedGoals;
  final ValueChanged<String> onSessionModeSelected;
  final VoidCallback onStartWorkout;
  final ValueChanged<RoutineTemplate> onStartRoutine;
  final VoidCallback onOpenCalendar;

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final _inviteController = TextEditingController();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final isTrainerMode =
        widget.user.canUseTrainerMode &&
        widget.user.activeRole == AppRole.trainer;
    return AppScaffold(
      title: isTrainerMode
          ? 'Panel entrenador'
          : 'Hola,\n${widget.user.firstName}',
      user: widget.user,
      bottomAction: isTrainerMode
          ? null
          : SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.onStartWorkout,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar entrenamiento'),
              ),
            ),
      menuActions: [
        AppMenuAction(
          icon: Icons.home_outlined,
          label: isTrainerMode ? 'Panel entrenador' : 'Resumen',
          selected: true,
          onSelected: () {},
        ),
        AppMenuAction(
          icon: Icons.calendar_month_outlined,
          label: 'Calendario de sesiones',
          onSelected: widget.onOpenCalendar,
        ),
      ],
      children: [
        if (widget.notice != null) InfoBanner(text: widget.notice!),
        RoleSwitcher(user: widget.user, repository: widget.repository),
        if (!isTrainerMode) ...[
          WeeklySummaryCard(onOpenCalendar: widget.onOpenCalendar),
          SessionModeSelector(
            selectedMode: widget.selectedSessionMode,
            onSelected: widget.onSessionModeSelected,
          ),
          const _CompactSectionTitle('Próximo Entrenamiento'),
          RecommendedWorkoutCard(
            routine: widget.routines.isEmpty ? null : widget.routines.first,
            onStart: widget.routines.isEmpty
                ? widget.onStartWorkout
                : () => widget.onStartRoutine(widget.routines.first),
          ),
          if (widget.routines.isNotEmpty)
            ImportedRoutinesCard(
              routines: widget.routines,
              onStartRoutine: widget.onStartRoutine,
            ),
          DashboardCard(
            icon: Icons.calendar_month_outlined,
            title: 'Calendario de sesiones',
            subtitle: 'Ver sesiones, schedules, tareas y metas de la semana.',
            onTap: widget.onOpenCalendar,
            action: Icon(
              Icons.chevron_right,
              color: context.appColors.primaryStrong,
            ),
          ),
        ],
        if (isTrainerMode)
          _TrainerPanel(
            user: widget.user,
            repository: widget.repository,
            routines: widget.routines,
            busy: _busy,
            inviteCode: widget.inviteCode,
            onCreateInvite: _createInvite,
            onNotice: widget.onNotice,
          )
        else
          _AthletePanel(
            user: widget.user,
            repository: widget.repository,
            schedules: widget.assignedSchedules,
            goals: widget.assignedGoals,
            controller: _inviteController,
            busy: _busy,
            onAcceptInvite: _acceptInvite,
            onNotice: widget.onNotice,
          ),
      ],
    );
  }

  Future<void> _createInvite() async {
    setState(() => _busy = true);
    try {
      final invite = await widget.repository.createTrainerInvite(widget.user);
      widget.onInviteCreated(invite.code);
      widget.onNotice('Código de invitación creado: ${invite.code}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptInvite() async {
    final code = _inviteController.text.trim();
    if (code.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.repository.acceptTrainerInvite(
        client: widget.user,
        code: code,
      );
      widget.onNotice(
        'Entrenador vinculado. Ya puede asignarte rutinas y metas.',
      );
      _inviteController.clear();
    } catch (error) {
      widget.onNotice('No se pudo aceptar el código: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _TrainerPanel extends StatelessWidget {
  const _TrainerPanel({
    required this.user,
    required this.repository,
    required this.routines,
    required this.busy,
    required this.inviteCode,
    required this.onCreateInvite,
    required this.onNotice,
  });

  final AppUser user;
  final AgujetasRepository repository;
  final List<RoutineTemplate> routines;
  final bool busy;
  final String? inviteCode;
  final VoidCallback onCreateInvite;
  final ValueChanged<String> onNotice;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DashboardCard(
          icon: Icons.group_add_outlined,
          title: 'Sumar entrenados',
          subtitle: inviteCode == null
              ? 'Genera un código para vincular usuarios.'
              : 'Código activo: $inviteCode',
          action: FilledButton(
            onPressed: busy ? null : onCreateInvite,
            child: Text(inviteCode == null ? 'Crear código' : 'Crear otro'),
          ),
        ),
        StreamBuilder<List<TrainerClientLink>>(
          stream: repository.watchTrainerClients(user.uid),
          builder: (context, snapshot) {
            final clients = snapshot.data ?? const <TrainerClientLink>[];
            return DashboardCard(
              icon: Icons.assignment_ind_outlined,
              title: 'Entrenados activos',
              subtitle: clients.isEmpty
                  ? 'Aún no hay vinculaciones.'
                  : '${clients.length} usuarios vinculados',
              child: Column(
                children: clients
                    .map(
                      (client) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: Text(client.clientName),
                              subtitle: const Text(
                                'Rutinas, tareas, schedules y metas',
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.tonal(
                                  onPressed: routines.isEmpty
                                      ? null
                                      : () => _assignFirstRoutine(client),
                                  child: const Text('Asignar rutina'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _assignDefaultTask(client),
                                  child: const Text('Enviar tarea'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _assignDefaultSchedule(client),
                                  icon: const Icon(Icons.event_available),
                                  label: const Text('Agendar'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _assignDefaultGoal(client),
                                  icon: const Icon(Icons.flag_outlined),
                                  label: const Text('Meta'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          },
        ),
        const DashboardCard(
          icon: Icons.flag_outlined,
          title: 'Metas y tareas',
          subtitle:
              'Asigna volumen semanal, hábitos, sesiones y objetivos medibles.',
        ),
      ],
    );
  }

  Future<void> _assignFirstRoutine(TrainerClientLink client) async {
    if (routines.isEmpty) {
      onNotice('Creá una rutina antes de asignarla a un entrenado.');
      return;
    }
    final routine = routines.first;
    try {
      final assigned = await repository.assignRoutineToClient(
        trainer: user,
        client: client,
        routine: routine,
      );
      onNotice(
        'Rutina "${assigned.routineTitle}" asignada a ${client.clientName}.',
      );
    } catch (error) {
      onNotice('No pude asignar la rutina: $error');
    }
  }

  Future<void> _assignDefaultTask(TrainerClientLink client) async {
    try {
      final task = await repository.assignTaskToClient(
        trainer: user,
        client: client,
        title: 'Registrar peso corporal',
        description:
            'Cargá tu peso esta semana y avisame si hubo cambios fuertes.',
        dueAt: DateTime.now().toUtc().add(const Duration(days: 7)),
      );
      onNotice('Tarea "${task.title}" enviada a ${client.clientName}.');
    } catch (error) {
      onNotice('No pude enviar la tarea: $error');
    }
  }

  Future<void> _assignDefaultSchedule(TrainerClientLink client) async {
    final scheduledFor = DateTime.now()
        .toLocal()
        .add(const Duration(days: 2))
        .copyWith(hour: 18, minute: 0, second: 0, millisecond: 0);
    try {
      final schedule = await repository.assignScheduleToClient(
        trainer: user,
        client: client,
        title: 'Sesión planificada',
        scheduledFor: scheduledFor,
        note: 'Revisar técnica y completar RIR en todas las series.',
        routine: routines.isEmpty ? null : routines.first,
      );
      onNotice(
        'Schedule "${schedule.title}" agendado para ${client.clientName}.',
      );
    } catch (error) {
      onNotice('No pude agendar la sesión: $error');
    }
  }

  Future<void> _assignDefaultGoal(TrainerClientLink client) async {
    try {
      final goal = await repository.assignGoalToClient(
        trainer: user,
        client: client,
        title: 'Volumen semanal',
        metric: 'weekly_volume',
        targetValue: 18000,
        unit: 'kg-reps',
        currentValue: 0,
        dueAt: DateTime.now().toUtc().add(const Duration(days: 14)),
        note: 'Objetivo inicial de volumen acumulado para medir tolerancia.',
      );
      onNotice('Meta "${goal.title}" asignada a ${client.clientName}.');
    } catch (error) {
      onNotice('No pude asignar la meta: $error');
    }
  }
}

class _AthletePanel extends StatelessWidget {
  const _AthletePanel({
    required this.user,
    required this.repository,
    required this.schedules,
    required this.goals,
    required this.controller,
    required this.busy,
    required this.onAcceptInvite,
    required this.onNotice,
  });

  final AppUser user;
  final AgujetasRepository repository;
  final List<AssignedSchedule> schedules;
  final List<AssignedGoal> goals;
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onAcceptInvite;
  final ValueChanged<String> onNotice;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DashboardCard(
          icon: Icons.link_outlined,
          title: 'Vincular entrenador',
          subtitle:
              'Ingresa un código si un entrenador te comparte rutina o schedule.',
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Código'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: busy ? null : onAcceptInvite,
                child: const Text('Aceptar'),
              ),
            ],
          ),
        ),
        StreamBuilder<List<AssignedRoutine>>(
          stream: repository.watchAssignedRoutinesForClient(user.uid),
          builder: (context, snapshot) {
            final assigned = snapshot.data ?? const <AssignedRoutine>[];
            return DashboardCard(
              icon: Icons.assignment_turned_in_outlined,
              title: 'Rutinas asignadas',
              subtitle: assigned.isEmpty
                  ? 'Cuando un entrenador te asigne una rutina, aparecerá acá.'
                  : '${assigned.length} rutina${assigned.length == 1 ? '' : 's'} pendiente${assigned.length == 1 ? '' : 's'}',
              child: assigned.isEmpty
                  ? null
                  : Column(
                      children: [
                        for (final routine in assigned.take(3))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              child: Icon(Icons.fitness_center),
                            ),
                            title: Text(routine.routineTitle),
                            subtitle: Text(
                              '${routine.exercises.length} ejercicios asignados',
                            ),
                          ),
                      ],
                    ),
            );
          },
        ),
        StreamBuilder<List<AssignedTask>>(
          stream: repository.watchAssignedTasksForClient(user.uid),
          builder: (context, snapshot) {
            final tasks = snapshot.data ?? const <AssignedTask>[];
            return DashboardCard(
              icon: Icons.task_alt_outlined,
              title: 'Tareas del entrenador',
              subtitle: tasks.isEmpty
                  ? 'Si tu entrenador te manda tareas o controles, aparecen acá.'
                  : '${tasks.length} tarea${tasks.length == 1 ? '' : 's'} pendiente${tasks.length == 1 ? '' : 's'}',
              child: tasks.isEmpty
                  ? null
                  : Column(
                      children: [
                        for (final task in tasks.take(3))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              child: Icon(Icons.checklist_outlined),
                            ),
                            title: Text(task.title),
                            subtitle: Text(task.description),
                            trailing: task.status == 'completed'
                                ? const Icon(Icons.check_circle)
                                : TextButton(
                                    onPressed: () => _completeTask(task),
                                    child: const Text('Completar'),
                                  ),
                          ),
                      ],
                    ),
            );
          },
        ),
        DashboardCard(
          icon: Icons.event_available_outlined,
          title: 'Schedules asignados',
          subtitle: schedules.isEmpty
              ? 'Las sesiones planificadas por tu entrenador aparecen acá y en el calendario.'
              : '${schedules.length} sesión${schedules.length == 1 ? '' : 'es'} planificada${schedules.length == 1 ? '' : 's'}',
          child: schedules.isEmpty
              ? null
              : Column(
                  children: [
                    for (final schedule in schedules.take(3))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          child: Icon(Icons.calendar_today_outlined),
                        ),
                        title: Text(schedule.title),
                        subtitle: Text(
                          '${_scheduleSubtitle(schedule)}'
                          '${schedule.status == 'cancelled' ? ' · cancelado' : ''}',
                        ),
                        trailing: schedule.status == 'cancelled'
                            ? const Icon(Icons.event_busy)
                            : TextButton(
                                onPressed: () => _cancelSchedule(schedule),
                                child: const Text('Cancelar'),
                              ),
                      ),
                  ],
                ),
        ),
        DashboardCard(
          icon: Icons.flag_outlined,
          title: 'Metas del entrenador',
          subtitle: goals.isEmpty
              ? 'Las metas medibles asignadas por tu entrenador aparecen acá.'
              : '${goals.length} meta${goals.length == 1 ? '' : 's'} activa${goals.length == 1 ? '' : 's'}',
          child: goals.isEmpty
              ? null
              : Column(
                  children: [
                    for (final goal in goals.take(3))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text('${(goal.progressRatio * 100).round()}%'),
                        ),
                        title: Text(goal.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_goalSubtitle(goal)),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(value: goal.progressRatio),
                          ],
                        ),
                        trailing: TextButton(
                          onPressed: goal.status == 'completed'
                              ? null
                              : () => _advanceGoal(goal),
                          child: const Text('+25%'),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _completeTask(AssignedTask task) async {
    try {
      await repository.updateAssignedTaskStatus(
        user: user,
        task: task,
        status: 'completed',
      );
      onNotice('Tarea "${task.title}" completada.');
    } catch (error) {
      onNotice('No pude completar la tarea: $error');
    }
  }

  Future<void> _cancelSchedule(AssignedSchedule schedule) async {
    try {
      await repository.updateAssignedScheduleStatus(
        user: user,
        schedule: schedule,
        status: 'cancelled',
      );
      onNotice('Schedule "${schedule.title}" cancelado.');
    } catch (error) {
      onNotice('No pude cancelar el schedule: $error');
    }
  }

  Future<void> _advanceGoal(AssignedGoal goal) async {
    final increment = goal.targetValue * 0.25;
    final nextValue = (goal.currentValue + increment).clamp(
      0,
      goal.targetValue,
    );
    final nextStatus = nextValue >= goal.targetValue ? 'completed' : 'active';
    try {
      await repository.updateAssignedGoalProgress(
        user: user,
        goal: goal,
        currentValue: nextValue.toDouble(),
        status: nextStatus,
      );
      onNotice('Meta "${goal.title}" actualizada.');
    } catch (error) {
      onNotice('No pude actualizar la meta: $error');
    }
  }
}

class WeeklySummaryCard extends StatelessWidget {
  const WeeklySummaryCard({super.key, required this.onOpenCalendar});

  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    const days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return DashboardCard(
      icon: Icons.calendar_month_outlined,
      title: 'Resumen Semanal',
      subtitle:
          'Atajo rápido: 2 entrenos completados, 1 planificado y acceso al mes completo.',
      action: _SoftChip(
        label: 'Ver mes',
        color: colors.amber,
        background: colors.amberContainer.withValues(alpha: 0.45),
      ),
      onTap: onOpenCalendar,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < days.length; i++)
            _DayPill(label: days[i], selected: i < 2, highlighted: i == 2),
        ],
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.label,
    required this.selected,
    required this.highlighted,
  });

  final String label;
  final bool selected;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final background = selected
        ? colors.primaryContainer
        : highlighted
        ? colors.amberContainer
        : colors.raised;
    final foreground = selected
        ? Colors.white
        : highlighted
        ? colors.amber
        : colors.textSecondary;
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Text(
        label,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class SessionModeSelector extends StatelessWidget {
  const SessionModeSelector({
    super.key,
    required this.selectedMode,
    required this.onSelected,
  });

  final String selectedMode;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    const modes = ['Fuerza', 'Hipertrofia', 'Técnica', 'Libre'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < modes.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == modes.length - 1 ? 0 : 2),
                child: Material(
                  color: modes[i] == selectedMode
                      ? colors.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onSelected(modes[i]),
                    child: Container(
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: modes[i] == selectedMode
                            ? Border.all(color: colors.divider)
                            : null,
                      ),
                      child: Text(
                        modes[i],
                        style: TextStyle(
                          color: modes[i] == selectedMode
                              ? colors.text
                              : colors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompactSectionTitle extends StatelessWidget {
  const _CompactSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15),
      ),
    );
  }
}

class RecommendedWorkoutCard extends StatelessWidget {
  const RecommendedWorkoutCard({
    super.key,
    required this.onStart,
    this.routine,
  });

  final VoidCallback onStart;
  final RoutineTemplate? routine;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final activeRoutine = routine;
    return DashboardCard(
      icon: Icons.fitness_center,
      title: activeRoutine?.title ?? 'Empuje A',
      subtitle: activeRoutine == null
          ? 'Pecho, hombro y tríceps'
          : activeRoutine.exercises
                .take(3)
                .map((exercise) => exercise.muscleGroup)
                .toSet()
                .join(', '),
      onTap: onStart,
      action: _SoftChip(
        label: 'Recomendado hoy',
        color: colors.primaryStrong,
        background: colors.raised,
      ),
      child: Column(
        children: [
          Divider(color: colors.divider),
          Row(
            children: [
              Expanded(
                child: _InlineMeta(
                  icon: Icons.view_list_outlined,
                  label: '${activeRoutine?.exercises.length ?? 6} ejercicios',
                ),
              ),
              Expanded(
                child: _InlineMeta(icon: Icons.schedule, label: '~55 min'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ImportedRoutinesCard extends StatelessWidget {
  const ImportedRoutinesCard({
    super.key,
    required this.routines,
    required this.onStartRoutine,
  });

  final List<RoutineTemplate> routines;
  final ValueChanged<RoutineTemplate> onStartRoutine;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      icon: Icons.bookmarks_outlined,
      title: 'Rutinas importadas',
      subtitle:
          '${routines.length} plantillas recuperadas desde tu app anterior.',
      child: Column(
        children: [
          for (final routine in routines.take(4))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.fitness_center),
              title: Text(routine.title),
              subtitle: Text('${routine.exercises.length} ejercicios'),
              trailing: FilledButton(
                onPressed: () => onStartRoutine(routine),
                child: const Text('Iniciar'),
              ),
            ),
        ],
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.appColors.textSecondary),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class TrainScreen extends StatefulWidget {
  const TrainScreen({
    super.key,
    required this.user,
    required this.repository,
    required this.sessionMode,
    required this.routineTitle,
    required this.sessionResetToken,
    required this.exercises,
    required this.localSessions,
    required this.hasEditedWorkout,
    required this.initialTotalElapsed,
    required this.initialRestRemaining,
    required this.initialTotalRunning,
    required this.initialRestRunning,
    required this.restAlertsEnabled,
    required this.localGalleryEnabled,
    required this.onExercisesChanged,
    required this.onSaveCustomExercise,
    required this.onTimerStateChanged,
    required this.onSessionModeChanged,
    required this.onSessionSavedLocally,
    required this.onOpenLibrary,
  });

  final AppUser user;
  final AgujetasRepository repository;
  final String sessionMode;
  final String routineTitle;
  final int sessionResetToken;
  final List<WorkoutExercise> exercises;
  final List<LocalWorkoutSession> localSessions;
  final bool hasEditedWorkout;
  final Duration initialTotalElapsed;
  final Duration initialRestRemaining;
  final bool initialTotalRunning;
  final bool initialRestRunning;
  final bool restAlertsEnabled;
  final bool localGalleryEnabled;
  final ValueChanged<List<WorkoutExercise>> onExercisesChanged;
  final Future<void> Function(ExerciseCatalogEntry exercise)
  onSaveCustomExercise;
  final void Function(
    Duration totalElapsed,
    Duration restRemaining,
    bool totalRunning,
    bool restRunning,
  )
  onTimerStateChanged;
  final ValueChanged<String> onSessionModeChanged;
  final Future<LocalWorkoutSession> Function(
    Duration totalElapsed,
    List<WorkoutExercise> exercises,
  )
  onSessionSavedLocally;
  final VoidCallback onOpenLibrary;

  @override
  State<TrainScreen> createState() => _TrainScreenState();
}

class _TrainScreenState extends State<TrainScreen> {
  late final Future<List<ExerciseCatalogEntry>> _catalogFuture =
      _loadCatalogSnapshot();
  Timer? _ticker;
  Duration _totalElapsed = Duration.zero;
  Duration _restRemaining = const Duration(minutes: 2);
  bool _totalRunning = false;
  bool _restRunning = false;

  bool get _hasTimerActivity =>
      _totalElapsed > Duration.zero ||
      _restRemaining != const Duration(minutes: 2) ||
      _totalRunning ||
      _restRunning;

  @override
  void initState() {
    super.initState();
    _applyInitialTimerState();
    if (_totalRunning || _restRunning) {
      _ensureTicker();
    }
  }

  @override
  void didUpdateWidget(covariant TrainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionResetToken != widget.sessionResetToken) {
      _applyInitialTimerState();
      if (_totalRunning || _restRunning) {
        _ensureTicker();
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title:
          'Entrenar · ${widget.sessionMode}\n${widget.routineTitle} • ${_formatSessionDuration(_totalElapsed)}',
      user: widget.user,
      menuActions: [
        AppMenuAction(
          icon: Icons.play_circle_outline,
          label: 'Sesión actual',
          selected: true,
          onSelected: () {},
        ),
        AppMenuAction(
          icon: Icons.bookmarks_outlined,
          label: 'Biblioteca de rutinas',
          onSelected: widget.onOpenLibrary,
        ),
      ],
      trailing: IconButton.filledTonal(
        tooltip: 'Guardar sesión',
        onPressed: _saveSession,
        icon: const Icon(Icons.cloud_done_outlined),
      ),
      bottomAction: Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: _saveSession,
              child: const Text('Finalizar'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: _toggleTotalTimer,
              child: Text(_totalRunning ? 'Pausar' : 'Iniciar'),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: widget.onOpenLibrary,
            icon: const Icon(Icons.add),
            label: const Text('Agregar'),
          ),
        ],
      ),
      children: [
        _SessionIntentCard(
          mode: widget.sessionMode,
          onModeChanged: _requestModeChange,
        ),
        CompactTimers(
          totalElapsed: _totalElapsed,
          restRemaining: _restRemaining,
          totalRunning: _totalRunning,
          restRunning: _restRunning,
          onToggleTotal: _toggleTotalTimer,
          onResetTotal: _resetTotalTimer,
          onToggleRest: _toggleRestTimer,
          onResetRest: _resetRestTimer,
        ),
        CurrentSetLogger(
          exercise: widget.exercises.isEmpty ? null : widget.exercises.first,
          onRestTimer: () async {
            _startRestTimer(const Duration(seconds: 90));
            final shouldScheduleNotification =
                widget.restAlertsEnabled && !kIsWeb;
            AgujetasNotificationResult? notificationResult;
            if (shouldScheduleNotification) {
              notificationResult =
                  await NotificationService.scheduleRestFinished(
                    const Duration(seconds: 90),
                  );
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _restTimerMessage(
                      restAlertsEnabled: widget.restAlertsEnabled,
                      notificationResult: notificationResult,
                    ),
                  ),
                ),
              );
            }
          },
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          proxyDecorator: stitchReorderProxy,
          onReorderStart: (_) => HapticFeedback.mediumImpact(),
          onReorderEnd: (_) => HapticFeedback.selectionClick(),
          itemCount: widget.exercises.length,
          onReorder: (oldIndex, newIndex) {
            final next = [...widget.exercises];
            final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
            final item = next.removeAt(oldIndex);
            next.insert(target, item);
            widget.onExercisesChanged(next);
          },
          itemBuilder: (context, index) {
            final exercise = widget.exercises[index];
            final historyRecords = ExerciseHistoryRecord.findAll(
              widget.localSessions,
              exercise,
            );
            final latestRecord = historyRecords.isEmpty
                ? null
                : historyRecords.first;
            return ExerciseCard(
              key: ValueKey(exercise.id),
              index: index,
              exercise: exercise,
              historyRecords: historyRecords,
              latestRecord: latestRecord,
              onChanged: (updated) {
                final next = [...widget.exercises];
                next[index] = updated;
                widget.onExercisesChanged(next);
              },
              onEditCustomExercise: exercise.isCustom
                  ? () => _editCustomExercise(index, exercise)
                  : null,
              onRemove: () => _confirmRemoveExercise(index, exercise),
              onMoveUp: index == 0
                  ? null
                  : () {
                      final next = [...widget.exercises];
                      final item = next.removeAt(index);
                      next.insert(index - 1, item);
                      widget.onExercisesChanged(next);
                      HapticFeedback.selectionClick();
                    },
              onMoveDown: index == widget.exercises.length - 1
                  ? null
                  : () {
                      final next = [...widget.exercises];
                      final item = next.removeAt(index);
                      next.insert(index + 1, item);
                      widget.onExercisesChanged(next);
                      HapticFeedback.selectionClick();
                    },
            );
          },
        ),
      ],
    );
  }

  String _restTimerMessage({
    required bool restAlertsEnabled,
    required AgujetasNotificationResult? notificationResult,
  }) {
    if (!restAlertsEnabled) {
      return 'Descanso iniciado sin alerta: activala desde Perfil';
    }
    return switch (notificationResult) {
      AgujetasNotificationResult.scheduledExact =>
        'Alerta de descanso exacta programada en 01:30',
      AgujetasNotificationResult.scheduledInexact =>
        'Alerta de descanso programada en 01:30',
      AgujetasNotificationResult.permissionDenied =>
        'Descanso iniciado, pero Android no permitió notificaciones',
      AgujetasNotificationResult.disabled ||
      null => 'Descanso iniciado sin alerta disponible en este dispositivo',
      AgujetasNotificationResult.shown =>
        'Alerta de descanso programada en 01:30',
    };
  }

  void _ensureTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_totalRunning) {
          _totalElapsed += const Duration(seconds: 1);
        }
        if (_restRunning) {
          final next = _restRemaining - const Duration(seconds: 1);
          _restRemaining = next <= Duration.zero ? Duration.zero : next;
          if (_restRemaining == Duration.zero) {
            _restRunning = false;
          }
        }
      });
      _notifyTimerStateChanged();
    });
  }

  void _applyInitialTimerState() {
    _totalElapsed = widget.initialTotalElapsed;
    _restRemaining = widget.initialRestRemaining;
    _totalRunning = widget.initialTotalRunning;
    _restRunning =
        widget.initialRestRunning &&
        widget.initialRestRemaining > Duration.zero;
  }

  void _notifyTimerStateChanged() {
    widget.onTimerStateChanged(
      _totalElapsed,
      _restRemaining,
      _totalRunning,
      _restRunning,
    );
  }

  Future<void> _editCustomExercise(int index, WorkoutExercise exercise) async {
    final updated = await showModalBottomSheet<ExerciseCatalogEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CustomExerciseSheet(
        catalogFuture: _catalogFuture,
        initialExercise: ExerciseCatalogEntry(
          id: exercise.id,
          name: exercise.name,
          muscleGroup: exercise.muscleGroup,
          imageUri: exercise.imageUri,
          isCustom: true,
        ),
        allowLocalGallery: widget.localGalleryEnabled,
      ),
    );
    if (updated == null) return;
    await widget.onSaveCustomExercise(updated);
    if (!mounted) return;
    final next = [...widget.exercises];
    if (index < 0 || index >= next.length) return;
    next[index] = exercise.copyWith(
      name: updated.name,
      muscleGroup: updated.muscleGroup,
      imageUri: updated.imageUri,
      isCustom: true,
    );
    widget.onExercisesChanged(next);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${updated.name} actualizado en la sesión')),
    );
  }

  Future<void> _confirmRemoveExercise(
    int index,
    WorkoutExercise exercise,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitar ejercicio'),
        content: Text(
          'Esto quita "${exercise.name}" de la sesión actual. '
          'No borra tu historial ni el catálogo de ejercicios.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final next = [...widget.exercises];
    if (index < 0 || index >= next.length) return;
    next.removeAt(index);
    widget.onExercisesChanged(next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${exercise.name} quitado de la sesión')),
    );
  }

  void _toggleTotalTimer() {
    setState(() {
      _totalRunning = !_totalRunning;
      if (_totalRunning) {
        _ensureTicker();
      }
    });
    _notifyTimerStateChanged();
  }

  void _resetTotalTimer() {
    setState(() {
      _totalRunning = false;
      _totalElapsed = Duration.zero;
    });
    _notifyTimerStateChanged();
  }

  void _toggleRestTimer() {
    if (_restRemaining == Duration.zero) {
      _restRemaining = const Duration(minutes: 2);
    }
    setState(() {
      _restRunning = !_restRunning;
      if (_restRunning) {
        _ensureTicker();
      }
    });
    _notifyTimerStateChanged();
  }

  void _startRestTimer(Duration duration) {
    setState(() {
      _restRemaining = duration;
      _restRunning = true;
      _ensureTicker();
    });
    _notifyTimerStateChanged();
  }

  void _resetRestTimer() {
    setState(() {
      _restRunning = false;
      _restRemaining = const Duration(minutes: 2);
    });
    _notifyTimerStateChanged();
  }

  Future<void> _requestModeChange(String mode) async {
    if (mode == widget.sessionMode) return;
    final shouldConfirm = _hasTimerActivity || widget.hasEditedWorkout;
    if (shouldConfirm) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cambiar modo de sesión'),
          content: const Text(
            'Cambiar el modo reiniciará los relojes y los valores cargados en los ejercicios.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cambiar y reiniciar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    widget.onSessionModeChanged(mode);
  }

  Future<void> _saveSession() async {
    final exercisesSnapshot = List<WorkoutExercise>.unmodifiable(
      widget.exercises,
    );
    final savedSession = await widget.onSessionSavedLocally(
      _totalElapsed,
      exercisesSnapshot,
    );
    var synced = true;
    try {
      await widget.repository.saveSession(
        user: widget.user,
        session: savedSession,
      );
    } catch (_) {
      synced = false;
    }
    if (!kIsWeb) {
      await NotificationService.showSessionSaved();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            synced
                ? 'Sesión guardada localmente y sincronizada'
                : 'Sesión guardada localmente; sincronización pendiente',
          ),
        ),
      );
    }
  }

  String _formatSessionDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

class _SessionIntentCard extends StatelessWidget {
  const _SessionIntentCard({required this.mode, required this.onModeChanged});

  final String mode;
  final ValueChanged<String> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    const modes = ['Fuerza', 'Hipertrofia', 'Técnica', 'Libre'];
    final icon = switch (mode) {
      'Hipertrofia' => Icons.trending_up,
      'Técnica' => Icons.tune,
      'Libre' => Icons.edit_note,
      _ => Icons.bolt,
    };
    final copy = switch (mode) {
      'Hipertrofia' => 'Volumen, control y proximidad al fallo.',
      'Técnica' => 'Calidad de movimiento, tempo y ejecución prolija.',
      'Libre' => 'Sesión flexible para registrar lo que hagas hoy.',
      _ => 'Carga alta, descansos más largos y foco en progresión.',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primaryStrong),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: mode,
                    isDense: true,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    items: [
                      for (final item in modes)
                        DropdownMenuItem(
                          value: item,
                          child: Text('Modo $item'),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) onModeChanged(value);
                    },
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 2),
                Text(copy, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.index,
    required this.exercise,
    required this.historyRecords,
    this.latestRecord,
    required this.onChanged,
    this.onEditCustomExercise,
    required this.onRemove,
    this.onMoveUp,
    this.onMoveDown,
  });

  final int index;
  final WorkoutExercise exercise;
  final List<ExerciseHistoryRecord> historyRecords;
  final ExerciseHistoryRecord? latestRecord;
  final ValueChanged<WorkoutExercise> onChanged;
  final VoidCallback? onEditCustomExercise;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ReorderGrip(index: index, label: 'Reordenar ${exercise.name}'),
                const SizedBox(width: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => showExerciseDetailSheet(
                    context,
                    exercise: exercise,
                    historyRecords: historyRecords,
                    latestRecord: latestRecord,
                    onApplyLatestRecord: latestRecord == null
                        ? null
                        : _applyLatestRecordDefaults,
                  ),
                  child: ExerciseImageBadge(
                    exerciseId: exercise.id,
                    name: exercise.name,
                    muscleGroup: exercise.muscleGroup,
                    imageUri: exercise.imageUri,
                    size: 50,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        exercise.muscleGroup,
                        style: TextStyle(color: colors.textSecondary),
                      ),
                      if (latestRecord != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          latestRecord!.compactLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: colors.primaryStrong),
                        ),
                      ],
                    ],
                  ),
                ),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('Bi')),
                    ButtonSegment(value: true, label: Text('Uni')),
                  ],
                  selected: {exercise.isUnilateral},
                  onSelectionChanged: (value) =>
                      onChanged(exercise.copyWith(isUnilateral: value.first)),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Opciones del ejercicio',
                  onSelected: (value) {
                    switch (value) {
                      case 'detail':
                        showExerciseDetailSheet(
                          context,
                          exercise: exercise,
                          historyRecords: historyRecords,
                          latestRecord: latestRecord,
                          onApplyLatestRecord: latestRecord == null
                              ? null
                              : _applyLatestRecordDefaults,
                        );
                        break;
                      case 'editCustom':
                        onEditCustomExercise?.call();
                        break;
                      case 'remove':
                        onRemove();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'detail',
                      child: Text('Detalle'),
                    ),
                    if (onEditCustomExercise != null)
                      const PopupMenuItem(
                        value: 'editCustom',
                        child: Text('Editar ejercicio'),
                      ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Quitar de sesión'),
                    ),
                  ],
                ),
                ReorderAccessibilityMenu(
                  onMoveUp: onMoveUp,
                  onMoveDown: onMoveDown,
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < exercise.sets.length; i++)
              SetEditor(
                set: exercise.sets[i],
                onChanged: (updated) {
                  final nextSets = [...exercise.sets];
                  nextSets[i] = updated;
                  onChanged(exercise.copyWith(sets: nextSets));
                },
              ),
          ],
        ),
      ),
    );
  }

  void _applyLatestRecordDefaults(ExerciseHistoryRecord record) {
    onChanged(
      exercise.copyWith(
        isUnilateral: record.exercise.isUnilateral,
        sets: record.exercise.sets
            .map((set) => WorkoutSet.fromJson(set.toJson()))
            .toList(),
      ),
    );
  }
}

Future<void> showExerciseDetailSheet(
  BuildContext context, {
  required WorkoutExercise exercise,
  List<ExerciseHistoryRecord> historyRecords = const [],
  ExerciseHistoryRecord? latestRecord,
  ValueChanged<ExerciseHistoryRecord>? onApplyLatestRecord,
  VoidCallback? onAdd,
}) {
  final effectiveRecords = historyRecords.isEmpty && latestRecord != null
      ? [latestRecord]
      : historyRecords;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ExerciseDetailSheet(
      exercise: exercise,
      historyRecords: effectiveRecords,
      latestRecord:
          latestRecord ??
          (effectiveRecords.isEmpty ? null : effectiveRecords.first),
      onApplyLatestRecord: onApplyLatestRecord,
      onAdd: onAdd,
    ),
  );
}

Future<WorkoutExercise?> showRoutineExerciseDefaultsSheet(
  BuildContext context, {
  required WorkoutExercise exercise,
}) {
  return showModalBottomSheet<WorkoutExercise>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => RoutineExerciseDefaultsSheet(exercise: exercise),
  );
}

class RoutineExerciseDefaultsSheet extends StatefulWidget {
  const RoutineExerciseDefaultsSheet({super.key, required this.exercise});

  final WorkoutExercise exercise;

  @override
  State<RoutineExerciseDefaultsSheet> createState() =>
      _RoutineExerciseDefaultsSheetState();
}

class _RoutineExerciseDefaultsSheetState
    extends State<RoutineExerciseDefaultsSheet> {
  late WorkoutExercise _exercise = WorkoutExercise.fromJson(
    widget.exercise.toJson(),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExerciseImageBadge(
                  exerciseId: _exercise.id,
                  name: _exercise.name,
                  muscleGroup: _exercise.muscleGroup,
                  imageUri: _exercise.imageUri,
                  size: 58,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Editar defaults',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.primaryStrong,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _exercise.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        _exercise.muscleGroup,
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.raised,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ejecución',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: false, label: Text('Bilateral')),
                      ButtonSegment(value: true, label: Text('Unilateral')),
                    ],
                    selected: {_exercise.isUnilateral},
                    onSelectionChanged: (value) => setState(
                      () => _exercise = _exercise.copyWith(
                        isUnilateral: value.first,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Series predeterminadas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _exercise.sets.length; i++)
              SetEditor(
                set: _exercise.sets[i],
                showDoneCheckbox: false,
                onChanged: (updated) => _updateSet(i, updated),
              ),
            OutlinedButton.icon(
              onPressed: _addSet,
              icon: const Icon(Icons.add),
              label: const Text('Agregar serie'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(_exercise),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar defaults'),
            ),
          ],
        ),
      ),
    );
  }

  void _updateSet(int index, WorkoutSet updated) {
    final nextSets = [..._exercise.sets];
    if (index < 0 || index >= nextSets.length) return;
    nextSets[index] = updated.copyWith(done: false);
    setState(() => _exercise = _exercise.copyWith(sets: nextSets));
  }

  void _addSet() {
    final nextOrder = _exercise.sets.length + 1;
    final nextSets = [
      ..._exercise.sets,
      WorkoutSet(
        order: nextOrder,
        setType: SetType.normal,
        segments: const [WeightSegment(weightKg: 0, reps: 0)],
      ),
    ];
    setState(() => _exercise = _exercise.copyWith(sets: nextSets));
  }
}

class _ExerciseDetailSheet extends StatelessWidget {
  const _ExerciseDetailSheet({
    required this.exercise,
    required this.historyRecords,
    this.latestRecord,
    this.onApplyLatestRecord,
    this.onAdd,
  });

  final WorkoutExercise exercise;
  final List<ExerciseHistoryRecord> historyRecords;
  final ExerciseHistoryRecord? latestRecord;
  final ValueChanged<ExerciseHistoryRecord>? onApplyLatestRecord;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final bestWeight = ExerciseHistoryRecord.bestWeight(historyRecords);
    final bestVolume = ExerciseHistoryRecord.bestVolume(historyRecords);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 178,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.raised,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.divider),
              ),
              child: ExerciseImageBadge(
                exerciseId: exercise.id,
                name: exercise.name,
                muscleGroup: exercise.muscleGroup,
                imageUri: exercise.imageUri,
                size: 132,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              exercise.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              latestRecord == null
                  ? 'Ficha técnica, historial y acciones rápidas.'
                  : latestRecord!.detailLabel,
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.7,
              children: [
                _DetailMetaTile(
                  icon: Icons.accessibility_new,
                  label: 'Músculo',
                  value: exercise.muscleGroup,
                ),
                _DetailMetaTile(
                  icon: Icons.fitness_center,
                  label: 'Equipo',
                  value: 'Libre / máquina',
                ),
                _DetailMetaTile(
                  icon: Icons.flag_outlined,
                  label: 'Nivel',
                  value: 'Intermedio',
                ),
                _DetailMetaTile(
                  icon: Icons.compare_arrows,
                  label: 'Tipo',
                  value: exercise.isUnilateral ? 'Unilateral' : 'Bilateral',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      onAdd?.call();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.add),
                    label: Text(onAdd == null ? 'Ya en rutina' : 'Agregar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        latestRecord == null || onApplyLatestRecord == null
                        ? null
                        : () {
                            onApplyLatestRecord!(latestRecord!);
                            Navigator.of(context).pop();
                          },
                    icon: const Icon(Icons.show_chart),
                    label: const Text('Usar último'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: historyRecords.isEmpty
                  ? null
                  : () => _showExerciseProgressSheet(context),
              icon: const Icon(Icons.query_stats),
              label: const Text('Ver progreso'),
            ),
            const SizedBox(height: 14),
            DashboardCard(
              icon: Icons.query_stats,
              title: 'Progreso del ejercicio',
              subtitle: historyRecords.isEmpty
                  ? 'Sin registros locales todavía.'
                  : '${historyRecords.length} registro${historyRecords.length == 1 ? '' : 's'} guardado${historyRecords.length == 1 ? '' : 's'}',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ExercisePrTile(
                          label: 'Mejor peso',
                          value: bestWeight?.setSummary ?? '-',
                          caption: bestWeight?.dateLabel ?? 'Sin marca',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ExercisePrTile(
                          label: 'Mejor volumen',
                          value: bestVolume?.volumeSummary ?? '-',
                          caption: bestVolume?.dateLabel ?? 'Sin marca',
                        ),
                      ),
                    ],
                  ),
                  if (historyRecords.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Registros recientes',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final record in historyRecords.take(5))
                      _ExerciseHistoryTile(record: record),
                  ],
                ],
              ),
            ),
            _DetailSection(
              title: 'Instrucciones',
              icon: Icons.format_list_numbered,
              children: const [
                'Prepará la posición y estabilizá el torso antes de iniciar.',
                'Mové la carga con control, sin rebotes ni compensaciones.',
                'Registrá kg, reps y RIR al terminar cada serie.',
              ],
            ),
            _DetailSection(
              title: 'Seguridad',
              icon: Icons.health_and_safety_outlined,
              children: const [
                'Usá calentamiento si la primera serie efectiva es pesada.',
                'Marcá dropset cuando reduzcas peso para extender reps.',
                'Si duele una articulación, bajá carga o cambiá variante.',
              ],
            ),
            DashboardCard(
              icon: Icons.history,
              title: 'Historial reciente',
              subtitle: latestRecord == null
                  ? 'Todavía no hay registros locales para este ejercicio.'
                  : '${latestRecord!.setSummary} · ${latestRecord!.sessionTitle}',
              child: _ProgressBar(
                value: latestRecord == null
                    ? 0
                    : (latestRecord!.setVolume / 2500)
                          .clamp(0.08, 1)
                          .toDouble(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExerciseProgressSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ExerciseProgressDetailSheet(
        exercise: exercise,
        records: historyRecords,
      ),
    );
  }
}

class _ExerciseProgressDetailSheet extends StatelessWidget {
  const _ExerciseProgressDetailSheet({
    required this.exercise,
    required this.records,
  });

  final WorkoutExercise exercise;
  final List<ExerciseHistoryRecord> records;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final bestWeight = ExerciseHistoryRecord.bestWeight(records);
    final bestVolume = ExerciseHistoryRecord.bestVolume(records);
    final latest = records.isEmpty ? null : records.first;
    final previous = records.length < 2 ? null : records[1];
    final latestVolume = latest?.setVolume ?? 0;
    final deltaVolume = previous == null
        ? null
        : latestVolume - previous.setVolume;
    final recentCount = records.length < 4 ? records.length : 4;
    final recentAverage = recentCount == 0
        ? 0.0
        : records
                  .take(4)
                  .fold<double>(0, (sum, record) => sum + record.setVolume) /
              recentCount;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExerciseImageBadge(
                  exerciseId: exercise.id,
                  name: exercise.name,
                  muscleGroup: exercise.muscleGroup,
                  imageUri: exercise.imageUri,
                  size: 58,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progreso por ejercicio',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.primaryStrong,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        exercise.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${records.length} registro${records.length == 1 ? '' : 's'} locales',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.25,
              children: [
                _ExerciseProgressMetricTile(
                  label: 'Última serie',
                  value: latest?.setSummary ?? '-',
                  caption: latest?.dateLabel ?? 'Sin registro',
                ),
                _ExerciseProgressMetricTile(
                  label: 'Cambio volumen',
                  value: deltaVolume == null
                      ? '-'
                      : '${deltaVolume >= 0 ? '+' : ''}${_formatCompactVolume(deltaVolume)}',
                  caption: previous == null
                      ? 'Necesita 2 registros'
                      : 'vs. registro anterior',
                ),
                _ExerciseProgressMetricTile(
                  label: 'Promedio reciente',
                  value: _formatCompactVolume(recentAverage),
                  caption: 'últimos $recentCount',
                ),
                _ExerciseProgressMetricTile(
                  label: 'Mejor peso',
                  value: bestWeight?.setSummary ?? '-',
                  caption: bestWeight?.dateLabel ?? 'Sin marca',
                ),
              ],
            ),
            const SizedBox(height: 12),
            DashboardCard(
              icon: Icons.bar_chart,
              title: 'Evolución de volumen',
              subtitle: bestVolume == null
                  ? 'Sin volumen suficiente para graficar.'
                  : 'Mejor volumen: ${bestVolume.volumeSummary} el ${bestVolume.dateLabel}.',
              child: _ExerciseProgressTrend(records: records),
            ),
            DashboardCard(
              icon: Icons.history,
              title: 'Historial completo',
              subtitle: 'Ordenado del registro más reciente al más antiguo.',
              child: Column(
                children: [
                  for (final record in records.take(12))
                    _ExerciseProgressHistoryTile(record: record),
                  if (records.length > 12)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+${records.length - 12} registros más',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseProgressMetricTile extends StatelessWidget {
  const _ExerciseProgressMetricTile({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ExerciseProgressTrend extends StatelessWidget {
  const _ExerciseProgressTrend({required this.records});

  final List<ExerciseHistoryRecord> records;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final points = records.take(8).toList().reversed.toList();
    final maxVolume = points.fold<double>(
      0,
      (max, record) => record.setVolume > max ? record.setVolume : max,
    );
    if (points.isEmpty || maxVolume <= 0) {
      return Container(
        height: 112,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.raised,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Sin datos suficientes',
          style: TextStyle(color: colors.textSecondary),
        ),
      );
    }
    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final record in points)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: (record.setVolume / maxVolume)
                              .clamp(0.08, 1)
                              .toDouble(),
                          child: Container(
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      record.dateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExerciseProgressHistoryTile extends StatelessWidget {
  const _ExerciseProgressHistoryTile({required this.record});

  final ExerciseHistoryRecord record;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          Icon(Icons.query_stats, size: 18, color: colors.primaryStrong),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.setSummary),
                const SizedBox(height: 2),
                Text(
                  '${record.volumeSummary} · ${record.sessionTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          _MiniValuePill(record.dateLabel),
        ],
      ),
    );
  }
}

class _ExercisePrTile extends StatelessWidget {
  const _ExercisePrTile({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(caption, style: TextStyle(color: colors.textSecondary)),
        ],
      ),
    );
  }
}

class _ExerciseHistoryTile extends StatelessWidget {
  const _ExerciseHistoryTile({required this.record});

  final ExerciseHistoryRecord record;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          Icon(Icons.history, size: 18, color: colors.primaryStrong),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.setSummary),
                Text(
                  record.sessionTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          _MiniValuePill(record.dateLabel),
        ],
      ),
    );
  }
}

class _DetailMetaTile extends StatelessWidget {
  const _DetailMetaTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.primaryStrong),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<String> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DashboardCard(
      icon: icon,
      title: title,
      subtitle: 'Guía operativa para registrar mejor el ejercicio.',
      child: Column(
        children: [
          for (final item in children)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: colors.primaryStrong,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class CurrentSetLogger extends StatelessWidget {
  const CurrentSetLogger({
    super.key,
    required this.exercise,
    required this.onRestTimer,
  });

  final WorkoutExercise? exercise;
  final VoidCallback onRestTimer;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final firstSet = exercise == null || exercise!.sets.isEmpty
        ? null
        : exercise!.sets.first;
    final firstSegment = firstSet == null || firstSet.segments.isEmpty
        ? null
        : firstSet.segments.first;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (exercise != null) ...[
                ExerciseImageBadge(
                  exerciseId: exercise!.id,
                  name: exercise!.name,
                  muscleGroup: exercise!.muscleGroup,
                  imageUri: exercise!.imageUri,
                  size: 42,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  exercise?.name ?? 'Set actual',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _SoftChip(
                label: 'Set ${firstSet?.order ?? 1}',
                color: colors.primaryStrong,
                background: colors.raised,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LoggerMetric(
                  label: 'kg',
                  value: firstSegment?.weightKg.toStringAsFixed(0) ?? '-',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LoggerMetric(
                  label: 'Reps',
                  value: firstSegment?.reps.toString() ?? '-',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LoggerMetric(
                  label: 'RIR',
                  value: '${firstSet?.rir ?? '-'}',
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 58,
                width: 58,
                child: FilledButton(
                  onPressed: onRestTimer,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Icon(Icons.timer_outlined),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoggerMetric extends StatelessWidget {
  const _LoggerMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.raised,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(value, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    );
  }
}

class SetEditor extends StatelessWidget {
  const SetEditor({
    super.key,
    required this.set,
    required this.onChanged,
    this.showDoneCheckbox = true,
  });

  final WorkoutSet set;
  final ValueChanged<WorkoutSet> onChanged;
  final bool showDoneCheckbox;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'S${set.order}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(width: 8),
              SetTypeChip(
                type: set.setType,
                onChanged: (type) => onChanged(set.copyWith(setType: type)),
              ),
              const Spacer(),
              if (showDoneCheckbox)
                Checkbox(
                  value: set.done,
                  onChanged: (value) =>
                      onChanged(set.copyWith(done: value ?? false)),
                ),
            ],
          ),
          _SetMainFields(
            segment: set.segments.first,
            rir: set.rir,
            onSegmentChanged: (segment) {
              final segments = [...set.segments];
              segments[0] = segment;
              onChanged(set.copyWith(segments: segments));
            },
            onRirChanged: (rir) => onChanged(set.copyWith(rir: rir)),
          ),
          for (var i = 1; i < set.segments.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentEditor(
                label: 'Peso 2 / backoff',
                segment: set.segments[i],
                onChanged: (segment) {
                  final segments = [...set.segments];
                  segments[i] = segment;
                  onChanged(set.copyWith(segments: segments));
                },
                onRemove: () {
                  final segments = [...set.segments]..removeAt(i);
                  onChanged(set.copyWith(segments: segments));
                },
              ),
            ),
          if (set.segments.length < 2)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => onChanged(
                  set.copyWith(
                    segments: [
                      ...set.segments,
                      const WeightSegment(weightKg: 0, reps: 0),
                    ],
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Agregar peso 2'),
              ),
            ),
        ],
      ),
    );
  }
}

class _SetMainFields extends StatelessWidget {
  const _SetMainFields({
    required this.segment,
    required this.rir,
    required this.onSegmentChanged,
    required this.onRirChanged,
  });

  final WeightSegment segment;
  final int? rir;
  final ValueChanged<WeightSegment> onSegmentChanged;
  final ValueChanged<int?> onRirChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CompactSetField(
            key: ValueKey('kg-main-${segment.weightKg}'),
            label: 'Kg',
            value: segment.weightKg == 0
                ? ''
                : segment.weightKg.toStringAsFixed(0),
            onChanged: (value) => onSegmentChanged(
              WeightSegment(
                weightKg: double.tryParse(value.replaceAll(',', '.')) ?? 0,
                reps: segment.reps,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CompactSetField(
            key: ValueKey('reps-main-${segment.reps}'),
            label: 'Reps',
            value: segment.reps == 0 ? '' : segment.reps.toString(),
            onChanged: (value) => onSegmentChanged(
              WeightSegment(
                weightKg: segment.weightKg,
                reps: int.tryParse(value) ?? 0,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CompactSetField(
            key: ValueKey('rir-main-${rir ?? ''}'),
            label: 'RIR',
            value: rir?.toString() ?? '',
            onChanged: (value) => onRirChanged(int.tryParse(value)),
          ),
        ),
      ],
    );
  }
}

class _CompactSetField extends StatelessWidget {
  const _CompactSetField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      ),
      onChanged: onChanged,
    );
  }
}

class SegmentEditor extends StatelessWidget {
  const SegmentEditor({
    super.key,
    required this.label,
    required this.segment,
    required this.onChanged,
    this.onRemove,
  });

  final String label;
  final WeightSegment segment;
  final ValueChanged<WeightSegment> onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            key: ValueKey('kg-$label-${segment.weightKg}'),
            initialValue: segment.weightKg == 0
                ? ''
                : segment.weightKg.toStringAsFixed(0),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Kg'),
            onChanged: (value) => onChanged(
              WeightSegment(
                weightKg: double.tryParse(value.replaceAll(',', '.')) ?? 0,
                reps: segment.reps,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            key: ValueKey('reps-$label-${segment.reps}'),
            initialValue: segment.reps == 0 ? '' : segment.reps.toString(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Reps'),
            onChanged: (value) => onChanged(
              WeightSegment(
                weightKg: segment.weightKg,
                reps: int.tryParse(value) ?? 0,
              ),
            ),
          ),
        ),
        if (onRemove != null)
          IconButton(onPressed: onRemove, icon: const Icon(Icons.close)),
      ],
    );
  }
}

class SetTypeChip extends StatelessWidget {
  const SetTypeChip({super.key, required this.type, required this.onChanged});

  final SetType type;
  final ValueChanged<SetType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<SetType>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: SetType.normal, label: Text('Normal')),
        ButtonSegment(value: SetType.warmup, label: Text('Cal')),
        ButtonSegment(value: SetType.dropset, label: Text('Drop')),
      ],
      selected: {type},
      onSelectionChanged: (value) => onChanged(value.first),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: colors.textSecondary)),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        minHeight: 10,
        value: value.clamp(0, 1),
        backgroundColor: colors.raised,
        color: colors.primaryContainer,
      ),
    );
  }
}

class BodyWeightCard extends StatelessWidget {
  const BodyWeightCard({
    super.key,
    required this.user,
    required this.entries,
    required this.alertsEnabled,
    required this.onSaved,
  });

  final AppUser user;
  final List<BodyWeightEntry> entries;
  final bool alertsEnabled;
  final Future<void> Function(BodyWeightEntry entry) onSaved;

  @override
  Widget build(BuildContext context) {
    final sortedEntries = [...entries]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final latest = sortedEntries.isEmpty ? null : sortedEntries.first;
    final previous = sortedEntries.length >= 2 ? sortedEntries[1] : null;
    final recentWindow = _recentBodyWeightWindow(sortedEntries);
    final recentAverage = recentWindow.isEmpty
        ? null
        : recentWindow.fold<double>(0, (sum, entry) => sum + entry.weightKg) /
              recentWindow.length;
    final oldestRecent = recentWindow.length >= 2 ? recentWindow.last : null;
    return DashboardCard(
      icon: Icons.monitor_weight_outlined,
      title: 'Peso corporal',
      subtitle: latest == null
          ? 'Sin registros todavía. Activá alertas y cargá tu primer peso.'
          : '${latest.weightKg.toStringAsFixed(1)} kg registrados localmente',
      action: FilledButton(
        onPressed: () => _openWeightSheet(context),
        child: const Text('Registrar'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (latest != null) ...[
            Row(
              children: [
                Expanded(
                  child: _BodyWeightMiniMetric(
                    label: 'Último',
                    value: '${latest.weightKg.toStringAsFixed(1)} kg',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _BodyWeightMiniMetric(
                    label: 'Prom. reciente',
                    value: recentAverage == null
                        ? '-'
                        : '${recentAverage.toStringAsFixed(1)} kg',
                  ),
                ),
              ],
            ),
            if (previous != null) ...[
              const SizedBox(height: 10),
              _ProgressBar(value: _bodyWeightTrendValue(latest, previous)),
              const SizedBox(height: 8),
              Text(
                _weightDeltaLabel(latest, previous),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
            if (oldestRecent != null) ...[
              const SizedBox(height: 6),
              Text(
                _bodyWeightWindowLabel(latest, oldestRecent),
                style: TextStyle(color: context.appColors.textSecondary),
              ),
            ],
            if (sortedEntries.length >= 2) ...[
              const SizedBox(height: 12),
              Text(
                'Historial reciente',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              for (final entry in sortedEntries.take(5))
                _BodyWeightHistoryRow(entry: entry),
            ],
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              if (!alertsEnabled) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Activá Seguimiento de peso desde Perfil para programar alertas.',
                    ),
                  ),
                );
                return;
              }
              AgujetasNotificationResult? notificationResult;
              if (!kIsWeb) {
                notificationResult =
                    await NotificationService.scheduleBodyWeightReminder(
                      hour: 9,
                      minute: 0,
                    );
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_bodyWeightAlertMessage(notificationResult)),
                  ),
                );
              }
            },
            icon: Icon(
              alertsEnabled
                  ? Icons.notifications_active_outlined
                  : Icons.lock_outline,
            ),
            label: const Text('Alertarme cada mañana'),
          ),
        ],
      ),
    );
  }

  String _bodyWeightAlertMessage(
    AgujetasNotificationResult? notificationResult,
  ) {
    return switch (notificationResult) {
      AgujetasNotificationResult.scheduledExact =>
        'Alerta diaria exacta de peso programada 09:00',
      AgujetasNotificationResult.scheduledInexact ||
      null => 'Alerta diaria de peso programada 09:00',
      AgujetasNotificationResult.permissionDenied =>
        'Android no permitió notificaciones de peso',
      AgujetasNotificationResult.disabled =>
        'Las alertas de peso no están disponibles en este dispositivo',
      AgujetasNotificationResult.shown =>
        'Alerta diaria de peso programada 09:00',
    };
  }

  Future<void> _openWeightSheet(BuildContext context) async {
    final controller = TextEditingController();
    final weight = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Registrar peso',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Peso corporal kg',
                  prefixIcon: Icon(Icons.monitor_weight_outlined),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(double.tryParse(controller.text.replaceAll(',', '.'))),
                child: const Text('Guardar peso'),
              ),
            ],
          ),
        );
      },
    );
    if (weight == null || weight <= 0) return;
    await onSaved(
      BodyWeightEntry(
        id: const Uuid().v4(),
        userId: user.uid,
        weightKg: weight,
        recordedAt: DateTime.now(),
      ),
    );
  }

  String _weightDeltaLabel(BodyWeightEntry latest, BodyWeightEntry previous) {
    final delta = latest.weightKg - previous.weightKg;
    if (delta == 0) return 'Sin cambio respecto del registro anterior.';
    final sign = delta > 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(1)} kg respecto del registro anterior.';
  }

  List<BodyWeightEntry> _recentBodyWeightWindow(List<BodyWeightEntry> sorted) {
    if (sorted.isEmpty) return const [];
    final latestDate = sorted.first.recordedAt;
    final cutoff = latestDate.subtract(const Duration(days: 30));
    return sorted
        .where((entry) => entry.recordedAt.isAfter(cutoff))
        .take(10)
        .toList();
  }

  double _bodyWeightTrendValue(
    BodyWeightEntry latest,
    BodyWeightEntry previous,
  ) {
    if (previous.weightKg <= 0) return 0.5;
    final ratio = latest.weightKg / previous.weightKg;
    return ((ratio - 0.95) / 0.1).clamp(0.0, 1.0);
  }

  String _bodyWeightWindowLabel(
    BodyWeightEntry latest,
    BodyWeightEntry oldest,
  ) {
    final days = latest.recordedAt.difference(oldest.recordedAt).inDays.abs();
    final delta = latest.weightKg - oldest.weightKg;
    if (delta == 0) return 'Sin cambio en los últimos $days días registrados.';
    final sign = delta > 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(1)} kg en los últimos $days días registrados.';
  }
}

class _BodyWeightMiniMetric extends StatelessWidget {
  const _BodyWeightMiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _BodyWeightHistoryRow extends StatelessWidget {
  const _BodyWeightHistoryRow({required this.entry});

  final BodyWeightEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            Icons.monitor_weight_outlined,
            size: 16,
            color: colors.primaryStrong,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _shortDate(entry.recordedAt.toLocal()),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Text(
            '${entry.weightKg.toStringAsFixed(1)} kg',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

class SessionCalendarSheet extends StatelessWidget {
  const SessionCalendarSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    const days = [
      ('L', 'Push', true),
      ('M', 'Libre', false),
      ('X', 'Pull', true),
      ('J', 'Piernas', false),
      ('V', 'Empuje A', false),
      ('S', 'Técnica', false),
      ('D', 'Descanso', false),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text(
          'Calendario de sesiones',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        for (final day in days)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: day.$3
                    ? colors.primaryContainer
                    : colors.raised,
                child: Text(
                  day.$1,
                  style: TextStyle(
                    color: day.$3 ? Colors.white : colors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              title: Text(day.$2),
              subtitle: Text(day.$3 ? 'Completada' : 'Planificada'),
              trailing: Icon(day.$3 ? Icons.check_circle : Icons.chevron_right),
            ),
          ),
      ],
    );
  }
}

class ExerciseHistoryRecord {
  const ExerciseHistoryRecord({
    required this.session,
    required this.exercise,
    required this.set,
  });

  final LocalWorkoutSession session;
  final WorkoutExercise exercise;
  final WorkoutSet set;

  double get setVolume => _setVolume(set);

  String get dateLabel => _shortDate(session.finishedAt.toLocal());

  String get setSummary =>
      '${_formatKg(set.primaryWeightKg)} kg x ${set.totalReps}'
      '${set.rir == null ? '' : ' · RIR ${set.rir}'}';

  String get volumeSummary => _formatCompactVolume(setVolume);

  String get compactLabel =>
      'Último: $setSummary · ${_shortDate(session.finishedAt.toLocal())}';

  String get detailLabel =>
      'Último registro local: $setSummary en ${_sessionTitle(session)}.';

  String get sessionTitle => _sessionTitle(session);

  static ExerciseHistoryRecord? findLatest(
    List<LocalWorkoutSession> sessions,
    WorkoutExercise target,
  ) {
    final records = findAll(sessions, target);
    return records.isEmpty ? null : records.first;
  }

  static List<ExerciseHistoryRecord> findAll(
    List<LocalWorkoutSession> sessions,
    WorkoutExercise target,
  ) {
    final records = <ExerciseHistoryRecord>[];
    final ordered = [...sessions]
      ..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
    for (final session in ordered) {
      for (final exercise in session.exercises) {
        if (!_sameExercise(exercise, target)) continue;
        final sets = exercise.sets
            .where(
              (set) =>
                  set.setType != SetType.warmup &&
                  set.totalReps > 0 &&
                  set.primaryWeightKg > 0,
            )
            .toList();
        if (sets.isEmpty) continue;
        sets.sort((a, b) => _setVolume(b).compareTo(_setVolume(a)));
        records.add(
          ExerciseHistoryRecord(
            session: session,
            exercise: exercise,
            set: sets.first,
          ),
        );
      }
    }
    return records;
  }

  static ExerciseHistoryRecord? bestWeight(
    List<ExerciseHistoryRecord> records,
  ) {
    return _bestBy(records, (record) => record.set.primaryWeightKg);
  }

  static ExerciseHistoryRecord? bestVolume(
    List<ExerciseHistoryRecord> records,
  ) {
    return _bestBy(records, (record) => record.setVolume);
  }

  static ExerciseHistoryRecord? _bestBy(
    List<ExerciseHistoryRecord> records,
    double Function(ExerciseHistoryRecord record) score,
  ) {
    ExerciseHistoryRecord? best;
    var bestScore = -1.0;
    for (final record in records) {
      final candidateScore = score(record);
      if (candidateScore > bestScore) {
        best = record;
        bestScore = candidateScore;
      }
    }
    return best;
  }
}

class BestSetRecord {
  const BestSetRecord({
    required this.exerciseName,
    required this.set,
    required this.date,
  });

  final String exerciseName;
  final WorkoutSet set;
  final DateTime date;

  double get volume => _setVolume(set);
  double get weightKg => set.primaryWeightKg;

  String get summary =>
      '${_formatKg(weightKg)} kg x ${set.totalReps} · $exerciseName';

  String get dateLabel => _shortDate(date.toLocal());

  static BestSetRecord? bestWeight(List<LocalWorkoutSession> sessions) {
    return _bestBy(sessions, (candidate) => candidate.weightKg);
  }

  static BestSetRecord? bestVolume(List<LocalWorkoutSession> sessions) {
    return _bestBy(sessions, (candidate) => candidate.volume);
  }

  static BestSetRecord? _bestBy(
    List<LocalWorkoutSession> sessions,
    double Function(BestSetRecord candidate) score,
  ) {
    BestSetRecord? best;
    var bestScore = -1.0;
    for (final session in sessions) {
      for (final exercise in session.exercises) {
        for (final set in exercise.sets) {
          if (set.setType == SetType.warmup ||
              set.totalReps <= 0 ||
              set.primaryWeightKg <= 0) {
            continue;
          }
          final candidate = BestSetRecord(
            exerciseName: exercise.name,
            set: set,
            date: session.finishedAt,
          );
          final candidateScore = score(candidate);
          if (candidateScore > bestScore) {
            best = candidate;
            bestScore = candidateScore;
          }
        }
      }
    }
    return best;
  }
}

class WeeklyActivityDay {
  const WeeklyActivityDay({required this.label, required this.hasSession});

  final String label;
  final bool hasSession;
}

bool _sameExercise(WorkoutExercise a, WorkoutExercise b) {
  if (a.id.isNotEmpty && b.id.isNotEmpty && a.id == b.id) return true;
  return _normalizeExerciseKey(a.name) == _normalizeExerciseKey(b.name);
}

String _normalizeExerciseKey(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

const _allLibraryOptions = '__all__';

const List<String> _libraryMuscleOptions = [
  'Abdomen',
  'Abductores',
  'Aductores',
  'Antebrazos',
  'Biceps',
  'Espalda',
  'General',
  'Gluteos',
  'Hombros',
  'Pectoral',
  'Piernas',
  'Triceps',
];

const Map<String, List<String>> _libraryEquipmentOptions = {
  'Mancuernas': ['mancuerna', 'mancuernas'],
  'Barra': ['barra', 'barra ez'],
  'Cable / polea': ['cable', 'polea'],
  'Máquina': ['maquina', 'máquina', 'smith', 'palanca', 'trineo'],
  'Peso corporal': [
    'peso corporal',
    'flexion',
    'flexión',
    'dominada',
    'sentadilla',
    'abdominal',
  ],
  'Banda': ['banda', 'resistencia'],
  'Pesa rusa': ['pesa rusa', 'pesas rusas', 'kettlebell'],
};

bool _matchesEquipmentFilter(ExerciseCatalogEntry item, String equipment) {
  final keywords = _libraryEquipmentOptions[equipment];
  if (keywords == null) return true;
  final haystack = _normalizeLibraryText('${item.name} ${item.muscleGroup}');
  return keywords.any(
    (keyword) => haystack.contains(_normalizeLibraryText(keyword)),
  );
}

String _normalizeLibraryText(String value) {
  const replacements = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  var normalized = value.trim().toLowerCase();
  for (final entry in replacements.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }
  return normalized.replaceAll(RegExp(r'\s+'), ' ');
}

List<LocalWorkoutSession> _sessionsSince(
  List<LocalWorkoutSession> sessions,
  DateTime since,
) {
  return sessions
      .where((session) => session.finishedAt.toLocal().isAfter(since))
      .toList();
}

List<LocalWorkoutSession> _sessionsBetween(
  List<LocalWorkoutSession> sessions,
  DateTime start,
  DateTime end,
) {
  return sessions.where((session) {
    final finished = session.finishedAt.toLocal();
    return finished.isAfter(start) && finished.isBefore(end);
  }).toList();
}

List<WeeklyActivityDay> _weeklyActivity(List<LocalWorkoutSession> sessions) {
  final today = DateTime.now();
  final monday = DateTime(
    today.year,
    today.month,
    today.day,
  ).subtract(Duration(days: today.weekday - 1));
  final sessionDays = sessions
      .map((session) => _dateKey(session.finishedAt.toLocal()))
      .toSet();
  const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  return [
    for (var i = 0; i < 7; i++)
      WeeklyActivityDay(
        label: labels[i],
        hasSession: sessionDays.contains(
          _dateKey(monday.add(Duration(days: i))),
        ),
      ),
  ];
}

List<double> _weeklyVolumePoints(List<LocalWorkoutSession> sessions) {
  final today = DateTime.now();
  final monday = DateTime(
    today.year,
    today.month,
    today.day,
  ).subtract(Duration(days: today.weekday - 1));
  final volumes = [
    for (var i = 0; i < 7; i++)
      sessions
          .where(
            (session) => _sameDay(
              session.finishedAt.toLocal(),
              monday.add(Duration(days: i)),
            ),
          )
          .fold<double>(0, (sum, session) => sum + _sessionVolume(session)),
  ];
  final maxVolume = volumes.fold<double>(
    0,
    (max, volume) => volume > max ? volume : max,
  );
  if (maxVolume <= 0) return List<double>.filled(7, 0);
  return volumes.map((volume) => volume / maxVolume).toList();
}

double _progressRatio({
  required double value,
  required double baseline,
  required double fallbackMax,
}) {
  if (value <= 0) return 0;
  if (baseline > 0) return (value / baseline / 1.25).clamp(0.05, 1.0);
  return (value / fallbackMax).clamp(0.05, 1.0);
}

String _weeklyVolumeComparison(double current, double previous) {
  if (previous <= 0) {
    return 'Calculado desde sesiones guardadas localmente. Sin semana previa comparable.';
  }
  final delta = ((current - previous) / previous) * 100;
  final prefix = delta >= 0 ? '+' : '';
  return '$prefix${delta.toStringAsFixed(1)}% vs semana previa, desde historial local.';
}

String? _topExerciseByVolume(List<LocalWorkoutSession> sessions) {
  final volumeByName = <String, double>{};
  for (final session in sessions) {
    for (final exercise in session.exercises) {
      final volume = _exerciseVolume(exercise);
      if (volume <= 0) continue;
      volumeByName.update(
        exercise.name,
        (previous) => previous + volume,
        ifAbsent: () => volume,
      );
    }
  }
  if (volumeByName.isEmpty) return null;
  return volumeByName.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

int _trainingStreakDays(List<LocalWorkoutSession> sessions) {
  if (sessions.isEmpty) return 0;
  final sessionDays = sessions
      .map((session) => _dateOnly(session.finishedAt.toLocal()))
      .toSet();
  var cursor = sessionDays.reduce((a, b) => a.isAfter(b) ? a : b);
  var streak = 0;
  while (sessionDays.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

double _sessionVolume(LocalWorkoutSession session) => session.exercises
    .fold<double>(0, (sum, exercise) => sum + _exerciseVolume(exercise));

double _workoutVolume(List<WorkoutExercise> exercises) => exercises
    .fold<double>(0, (sum, exercise) => sum + _exerciseVolume(exercise));

double _exerciseVolume(WorkoutExercise exercise) => exercise.sets
    .where((set) => set.setType != SetType.warmup)
    .fold<double>(0, (sum, set) => sum + _setVolume(set));

double _setVolume(WorkoutSet set) => set.segments.fold<double>(
  0,
  (sum, segment) => sum + segment.weightKg * segment.reps,
);

String _sessionTitle(LocalWorkoutSession session) {
  final title = session.title?.trim();
  if (title != null && title.isNotEmpty) return title;
  final firstExercise = session.exercises.isEmpty
      ? 'Sesión'
      : session.exercises.first.name;
  return '${session.sessionMode} · $firstExercise';
}

String _sessionSubtitle(LocalWorkoutSession session) {
  return '${session.exercises.length} ejercicios · '
      '${_formatDuration(Duration(seconds: session.durationSeconds))} · '
      '${_formatCompactVolume(_sessionVolume(session))}';
}

String _scheduleSubtitle(AssignedSchedule schedule) {
  final routine = schedule.routineTitle?.trim();
  final routineLabel = routine == null || routine.isEmpty ? '' : ' · $routine';
  return '${_formatShortDateTime(schedule.scheduledFor)}$routineLabel';
}

String _goalSubtitle(AssignedGoal goal) {
  final current = _formatDecimal(goal.currentValue);
  final target = _formatDecimal(goal.targetValue);
  final due = goal.dueAt == null ? '' : ' · vence ${_shortDate(goal.dueAt!)}';
  return '$current / $target ${goal.unit}$due';
}

String _dateKey(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _shortDate(DateTime value) => '${value.day}/${value.month}';

String _formatDecimal(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);

String _formatShortDateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day}/${local.month} $hour:$minute';
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  return '${minutes}min';
}

String _formatCompactVolume(double volume) => '${volume.round()} kg-reps';

String _formatCompactVolumeValue(double volume) {
  if (volume >= 1000) {
    final compact = volume / 1000;
    return compact >= 10
        ? '${compact.round()}k'
        : '${compact.toStringAsFixed(1)}k';
  }
  return '${volume.round()}';
}

String _formatKg(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);

class MonthlySessionCalendarSheet extends StatefulWidget {
  const MonthlySessionCalendarSheet({
    super.key,
    required this.sessions,
    this.schedules = const [],
    this.onRepeatSession,
    this.onSaveSessionAsRoutine,
    this.onUpdateSession,
    this.onDeleteSession,
  });

  final List<LocalWorkoutSession> sessions;
  final List<AssignedSchedule> schedules;
  final ValueChanged<LocalWorkoutSession>? onRepeatSession;
  final Future<void> Function(LocalWorkoutSession session)?
  onSaveSessionAsRoutine;
  final Future<void> Function(LocalWorkoutSession session)? onUpdateSession;
  final Future<void> Function(LocalWorkoutSession session)? onDeleteSession;

  @override
  State<MonthlySessionCalendarSheet> createState() =>
      _MonthlySessionCalendarSheetState();
}

class _MonthlySessionCalendarSheetState
    extends State<MonthlySessionCalendarSheet> {
  late DateTime _visibleMonth;
  late List<LocalWorkoutSession> _sessions;
  late List<AssignedSchedule> _schedules;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _sessions = widget.sessions;
    _schedules = widget.schedules;
  }

  @override
  void didUpdateWidget(covariant MonthlySessionCalendarSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessions != widget.sessions) {
      _sessions = widget.sessions;
    }
    if (oldWidget.schedules != widget.schedules) {
      _schedules = widget.schedules;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final now = DateTime.now();
    final monthStart = DateTime(_visibleMonth.year, _visibleMonth.month);
    final firstGridDay = monthStart.subtract(
      Duration(days: monthStart.weekday - 1),
    );
    final sessionsByDay = _sessionsByDay(_sessions);
    final schedulesByDay = _schedulesByDay(_schedules);
    final monthSessions = _sessions
        .where(
          (session) =>
              session.finishedAt.toLocal().year == _visibleMonth.year &&
              session.finishedAt.toLocal().month == _visibleMonth.month,
        )
        .toList();
    final monthSchedules = _schedules
        .where(
          (schedule) =>
              schedule.scheduledFor.toLocal().year == _visibleMonth.year &&
              schedule.scheduledFor.toLocal().month == _visibleMonth.month,
        )
        .toList();
    final recentSessions = _sessions.take(6).toList();
    final monthVolume = monthSessions.fold<double>(
      0,
      (sum, session) => sum + _sessionVolume(session),
    );
    final monthDuration = monthSessions.fold<Duration>(
      Duration.zero,
      (sum, session) => sum + Duration(seconds: session.durationSeconds),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Calendario mensual',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Mes anterior',
              onPressed: () => _shiftMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            _SoftChip(
              label: '${_monthName(_visibleMonth.month)} ${_visibleMonth.year}',
              color: colors.primaryStrong,
              background: colors.raised,
            ),
            IconButton(
              tooltip: 'Mes siguiente',
              onPressed: () => _shiftMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Tocá un día con marca para revisar entrenamientos guardados y sesiones planificadas.',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 12),
        DashboardCard(
          icon: Icons.calendar_month,
          title:
              '${monthSessions.length} sesión${monthSessions.length == 1 ? '' : 'es'} y ${monthSchedules.length} schedule${monthSchedules.length == 1 ? '' : 's'} en ${_monthName(_visibleMonth.month)}',
          subtitle:
              '${_formatDuration(monthDuration)} acumulados · ${_formatCompactVolume(monthVolume)}',
          action: TextButton.icon(
            onPressed: _goToCurrentMonth,
            icon: const Icon(Icons.today),
            label: const Text('Hoy'),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final day in ['L', 'M', 'X', 'J', 'V', 'S', 'D'])
              Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 42,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemBuilder: (context, index) {
            final day = firstGridDay.add(Duration(days: index));
            final daySessions = sessionsByDay[_dateKey(day)];
            final daySchedules = schedulesByDay[_dateKey(day)];
            final inMonth = day.month == _visibleMonth.month;
            final isToday = _isSameDay(day, now);
            final hasSessions = daySessions != null && daySessions.isNotEmpty;
            final hasSchedules =
                daySchedules != null && daySchedules.isNotEmpty;
            final hasEntries = hasSessions || hasSchedules;
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: !hasEntries
                  ? null
                  : () => _openDayDetail(
                      context,
                      day,
                      daySessions ?? const [],
                      daySchedules ?? const [],
                    ),
              child: Container(
                decoration: BoxDecoration(
                  color: !hasEntries
                      ? colors.raised.withValues(alpha: inMonth ? 1 : 0.35)
                      : hasSessions
                      ? colors.primaryContainer
                      : colors.amberContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isToday ? colors.primaryStrong : colors.divider,
                    width: isToday ? 2 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 7,
                      top: 6,
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          color: hasSessions
                              ? Colors.white
                              : hasSchedules
                              ? colors.amber
                              : inMonth
                              ? colors.text
                              : colors.textSecondary.withValues(alpha: 0.45),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (hasSessions)
                      Positioned(
                        right: 5,
                        bottom: 5,
                        child: Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${daySessions.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    if (hasSchedules)
                      Positioned(
                        left: 6,
                        bottom: 5,
                        child: Icon(
                          Icons.event_available,
                          size: 13,
                          color: hasSessions ? Colors.white : colors.amber,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Sesiones de ${_monthName(_visibleMonth.month)}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (monthSessions.isEmpty)
          DashboardCard(
            icon: Icons.history,
            title: 'Sin entrenos en este mes',
            subtitle:
                'Usá las flechas del calendario para revisar meses anteriores o registrar una sesión nueva.',
          )
        else
          for (final session in monthSessions)
            Card(
              child: ListTile(
                leading: const Icon(Icons.fitness_center),
                title: Text(_sessionTitle(session)),
                subtitle: Text(_sessionSubtitle(session)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    _openSessionDetail(context, session.finishedAt, session),
              ),
            ),
        const SizedBox(height: 16),
        Text(
          'Schedules de ${_monthName(_visibleMonth.month)}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (monthSchedules.isEmpty)
          DashboardCard(
            icon: Icons.event_available_outlined,
            title: 'Sin sesiones planificadas',
            subtitle:
                'Cuando un entrenador agende sesiones, van a aparecer en este mes.',
          )
        else
          for (final schedule in monthSchedules)
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_available),
                title: Text(schedule.title),
                subtitle: Text(_scheduleSubtitle(schedule)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openScheduleDetail(context, schedule),
              ),
            ),
        const SizedBox(height: 16),
        Text(
          'Entrenos recientes',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (recentSessions.isEmpty)
          DashboardCard(
            icon: Icons.history,
            title: 'Sin entrenos locales todavía',
            subtitle:
                'Cuando finalices una sesión, va a aparecer acá y en el calendario mensual.',
          )
        else
          for (final session in recentSessions)
            Card(
              child: ListTile(
                leading: const Icon(Icons.history),
                title: Text(_sessionTitle(session)),
                subtitle: Text(_sessionSubtitle(session)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    _openSessionDetail(context, session.finishedAt, session),
              ),
            ),
      ],
    );
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  void _goToCurrentMonth() {
    final now = DateTime.now();
    setState(() => _visibleMonth = DateTime(now.year, now.month));
  }

  static Map<String, List<LocalWorkoutSession>> _sessionsByDay(
    List<LocalWorkoutSession> sessions,
  ) {
    final grouped = <String, List<LocalWorkoutSession>>{};
    for (final session in sessions) {
      final key = _dateKey(session.finishedAt.toLocal());
      grouped.putIfAbsent(key, () => []).add(session);
    }
    return grouped;
  }

  static Map<String, List<AssignedSchedule>> _schedulesByDay(
    List<AssignedSchedule> schedules,
  ) {
    final grouped = <String, List<AssignedSchedule>>{};
    for (final schedule in schedules) {
      final key = _dateKey(schedule.scheduledFor.toLocal());
      grouped.putIfAbsent(key, () => []).add(schedule);
    }
    return grouped;
  }

  void _openDayDetail(
    BuildContext context,
    DateTime date,
    List<LocalWorkoutSession> sessions,
    List<AssignedSchedule> schedules,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Entrenos del ${date.day}/${date.month}/${date.year}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '${sessions.length} sesión${sessions.length == 1 ? '' : 'es'} guardada${sessions.length == 1 ? '' : 's'} · ${schedules.length} schedule${schedules.length == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 12),
            for (final schedule in schedules)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available),
                title: Text(schedule.title),
                subtitle: Text(_scheduleSubtitle(schedule)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openScheduleDetail(context, schedule),
              ),
            for (final session in sessions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.fitness_center),
                title: Text(_sessionTitle(session)),
                subtitle: Text(_sessionSubtitle(session)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openSessionDetail(
                  context,
                  session.finishedAt.toLocal(),
                  session,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openScheduleDetail(BuildContext context, AssignedSchedule schedule) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(schedule.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              _scheduleSubtitle(schedule),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            if (schedule.note != null && schedule.note!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(schedule.note!),
            ],
            if (schedule.routineTitle != null) ...[
              const SizedBox(height: 12),
              DashboardCard(
                icon: Icons.fitness_center,
                title: 'Rutina sugerida',
                subtitle: schedule.routineTitle!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openSessionDetail(
    BuildContext context,
    DateTime date,
    LocalWorkoutSession session,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              _sessionTitle(session),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '${date.day}/${date.month}/${date.year} · ${_formatDuration(Duration(seconds: session.durationSeconds))} · ${_formatCompactVolume(_sessionVolume(session))}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            if (session.note != null) ...[
              const SizedBox(height: 8),
              Text(
                session.note!,
                style: TextStyle(color: context.appColors.textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onRepeatSession == null
                        ? null
                        : () {
                            Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst);
                            widget.onRepeatSession!(session);
                          },
                    icon: const Icon(Icons.replay),
                    label: const Text('Repetir sesión'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onSaveSessionAsRoutine == null
                        ? null
                        : () async {
                            await widget.onSaveSessionAsRoutine!(session);
                            if (context.mounted) {
                              Navigator.of(
                                context,
                              ).popUntil((route) => route.isFirst);
                            }
                          },
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Guardar rutina'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onUpdateSession == null
                        ? null
                        : () => _editSessionMetadata(context, session),
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('Editar nota'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onDeleteSession == null
                        ? null
                        : () => _confirmDeleteSession(context, session),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Borrar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final exercise in session.exercises)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ExerciseImageBadge(
                            exerciseId: exercise.id,
                            name: exercise.name,
                            muscleGroup: exercise.muscleGroup,
                            imageUri: exercise.imageUri,
                            size: 42,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exercise.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text(
                                  '${exercise.sets.length} series · ${_formatCompactVolume(_exerciseVolume(exercise))}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium,
                                ),
                              ],
                            ),
                          ),
                          if (exercise.isUnilateral)
                            const _SoftChip(
                              label: 'Unilateral',
                              color: Color(0xFF0B5F66),
                              background: Color(0xFFE2F3F2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Series registradas',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 6),
                      for (final set in exercise.sets)
                        _SessionSetHistoryRow(set: set),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editSessionMetadata(
    BuildContext context,
    LocalWorkoutSession session,
  ) async {
    final updated = await showDialog<LocalWorkoutSession>(
      context: context,
      builder: (_) => _EditSessionMetadataDialog(session: session),
    );
    if (updated == null) return;
    await widget.onUpdateSession?.call(updated);
    if (!mounted) return;
    setState(() {
      _sessions = [
        for (final item in _sessions)
          if (item.id == updated.id) updated else item,
      ]..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
    });
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDeleteSession(
    BuildContext context,
    LocalWorkoutSession session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Borrar sesión'),
        content: Text(
          'Esto elimina "${_sessionTitle(session)}" del historial local de este dispositivo. No borra rutinas ni ejercicios.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.onDeleteSession?.call(session);
    if (!mounted) return;
    setState(
      () =>
          _sessions = _sessions.where((item) => item.id != session.id).toList(),
    );
    if (context.mounted) Navigator.of(context).pop();
  }

  static String _dateKey(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _monthName(int month) => const [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ][month - 1];
}

class _EditSessionMetadataDialog extends StatefulWidget {
  const _EditSessionMetadataDialog({required this.session});

  final LocalWorkoutSession session;

  @override
  State<_EditSessionMetadataDialog> createState() =>
      _EditSessionMetadataDialogState();
}

class _EditSessionMetadataDialogState
    extends State<_EditSessionMetadataDialog> {
  late final TextEditingController _titleController = TextEditingController(
    text: _sessionTitle(widget.session),
  );
  late final TextEditingController _noteController = TextEditingController(
    text: widget.session.note ?? '',
  );

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar sesión'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Nota'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final nextTitle = _titleController.text.trim();
            final nextNote = _noteController.text.trim();
            Navigator.of(context).pop(
              widget.session.copyWith(
                title: nextTitle.isEmpty ? null : nextTitle,
                note: nextNote.isEmpty ? null : nextNote,
                clearTitle: nextTitle.isEmpty,
                clearNote: nextNote.isEmpty,
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _SessionSetHistoryRow extends StatelessWidget {
  const _SessionSetHistoryRow({required this.set});

  final WorkoutSet set;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              'S${set.order}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(child: Text(_segmentSummary(set.segments))),
          const SizedBox(width: 8),
          _SoftChip(
            label: _shortSetTypeLabel(set.setType),
            color: colors.primaryStrong,
            background: colors.surface,
          ),
          const SizedBox(width: 8),
          Text(
            set.rir == null ? 'RIR -' : 'RIR ${set.rir}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }

  static String _segmentSummary(List<WeightSegment> segments) {
    if (segments.isEmpty) return 'Sin carga registrada';
    return segments
        .map((segment) => '${_formatKg(segment.weightKg)} kg x ${segment.reps}')
        .join(' + ');
  }

  static String _shortSetTypeLabel(SetType type) => switch (type) {
    SetType.normal => 'Normal',
    SetType.warmup => 'Cal',
    SetType.dropset => 'Drop',
  };
}

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({
    super.key,
    required this.user,
    required this.repository,
    required this.exercises,
    required this.localSessions,
    required this.bodyWeights,
    required this.bodyWeightAlertsEnabled,
    required this.onOpenCalendar,
    required this.onBodyWeightSaved,
  });

  final AppUser user;
  final AgujetasRepository repository;
  final List<WorkoutExercise> exercises;
  final List<LocalWorkoutSession> localSessions;
  final List<BodyWeightEntry> bodyWeights;
  final bool bodyWeightAlertsEnabled;
  final VoidCallback onOpenCalendar;
  final Future<void> Function(BodyWeightEntry entry) onBodyWeightSaved;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final recentSessions = _sessionsSince(
      localSessions,
      DateTime.now().subtract(const Duration(days: 7)),
    );
    final previousSessions = _sessionsBetween(
      localSessions,
      DateTime.now().subtract(const Duration(days: 14)),
      DateTime.now().subtract(const Duration(days: 7)),
    );
    final activeVolume = _workoutVolume(exercises);
    final savedWeeklyVolume = recentSessions.fold<double>(
      0,
      (sum, session) => sum + _sessionVolume(session),
    );
    final previousWeeklyVolume = previousSessions.fold<double>(
      0,
      (sum, session) => sum + _sessionVolume(session),
    );
    final volume = savedWeeklyVolume > 0 ? savedWeeklyVolume : activeVolume;
    final volumeProgress = _progressRatio(
      value: volume,
      baseline: previousWeeklyVolume,
      fallbackMax: 12000,
    );
    final workingSets = savedWeeklyVolume > 0
        ? recentSessions
              .expand((session) => session.exercises)
              .expand((exercise) => exercise.sets)
              .where((set) => set.setType != SetType.warmup)
              .toList()
        : exercises
              .expand((exercise) => exercise.sets)
              .where((set) => set.setType != SetType.warmup)
              .toList();
    final dropSetCount = workingSets
        .where((set) => set.setType == SetType.dropset)
        .length;
    final dropSetRatio = workingSets.isEmpty
        ? 0.0
        : dropSetCount / workingSets.length;
    final weeklyActivity = _weeklyActivity(localSessions);
    final streak = _trainingStreakDays(localSessions);
    final bestWeight = BestSetRecord.bestWeight(localSessions);
    final bestVolume = BestSetRecord.bestVolume(localSessions);
    final topExercise = _topExerciseByVolume(recentSessions);
    return AppScaffold(
      title: 'Progreso',
      user: user,
      trailing: IconButton(
        tooltip: 'Calendario',
        onPressed: onOpenCalendar,
        icon: const Icon(Icons.calendar_month_outlined),
      ),
      menuActions: [
        AppMenuAction(
          icon: Icons.insights_outlined,
          label: 'Resumen de progreso',
          selected: true,
          onSelected: () {},
        ),
        AppMenuAction(
          icon: Icons.calendar_month_outlined,
          label: 'Calendario de sesiones',
          onSelected: onOpenCalendar,
        ),
      ],
      children: [
        Row(
          children: [
            Expanded(
              child: _ProgressMetricTile(
                icon: Icons.local_fire_department_outlined,
                label: 'Racha',
                value: '$streak',
                suffix: streak == 1 ? 'día' : 'días',
                color: colors.amber,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ProgressMetricTile(
                icon: Icons.scale_outlined,
                label: 'Volumen',
                value: _formatCompactVolumeValue(volume),
                suffix: 'kg sem.',
                color: colors.primaryStrong,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ProgressMetricTile(
                icon: Icons.calendar_today_outlined,
                label: 'Sesiones',
                value: '${localSessions.length}',
                suffix: 'totales',
              ),
            ),
          ],
        ),
        const _CompactSectionTitle('Actividad semanal'),
        _WeeklyActivityStrip(days: weeklyActivity),
        DashboardCard(
          icon: Icons.show_chart,
          title: 'Volumen semanal',
          subtitle: savedWeeklyVolume > 0
              ? _weeklyVolumeComparison(volume, previousWeeklyVolume)
              : 'Todavía sin historial semanal; uso la sesión actual como vista previa.',
          child: _VolumeChartCard(
            volume: volume,
            points: _weeklyVolumePoints(localSessions),
            primaryLabel: savedWeeklyVolume > 0
                ? 'Historial local'
                : 'Vista previa',
            secondaryLabel: topExercise,
          ),
        ),
        const _CompactSectionTitle('Marcas personales'),
        DashboardCard(
          icon: Icons.monitor_weight_outlined,
          title: 'Peso máximo',
          subtitle: bestWeight?.summary ?? 'Sin registros locales todavía',
          action: bestWeight == null
              ? null
              : _MiniValuePill(bestWeight.dateLabel),
        ),
        DashboardCard(
          icon: Icons.workspace_premium_outlined,
          title: 'Mejor serie',
          subtitle:
              bestVolume?.summary ?? 'Finalizá una sesión para calcularla',
          action: bestVolume == null ? null : const _MiniValuePill('PR'),
        ),
        DashboardCard(
          icon: Icons.monitor_weight_outlined,
          title: 'Volumen efectivo',
          subtitle: '${volume.round()} kg-reps sin contar calentamientos',
          child: _ProgressBar(value: workingSets.isEmpty ? 0 : volumeProgress),
        ),
        const _CompactSectionTitle('Hitos recientes'),
        DashboardCard(
          icon: Icons.auto_awesome,
          title: recentSessions.isEmpty
              ? 'Sin hitos semanales todavía'
              : 'Semana activa',
          subtitle: recentSessions.isEmpty
              ? 'Guardá sesiones para que Agujetas detecte marcas y consistencia.'
              : 'Completaste ${recentSessions.length} sesión${recentSessions.length == 1 ? '' : 'es'} en los últimos 7 días.',
          action: recentSessions.isEmpty
              ? null
              : _MiniValuePill('${recentSessions.length}/7'),
        ),
        DashboardCard(
          icon: Icons.layers_outlined,
          title: 'Dropsets',
          subtitle: '$dropSetCount de ${workingSets.length} series efectivas',
          child: _ProgressBar(value: dropSetRatio),
        ),
        BodyWeightCard(
          user: user,
          entries: bodyWeights,
          alertsEnabled: bodyWeightAlertsEnabled,
          onSaved: onBodyWeightSaved,
        ),
        DashboardCard(
          icon: Icons.calendar_month_outlined,
          title: 'Calendario',
          subtitle: 'Historial mensual, schedules y metas asignadas.',
          onTap: onOpenCalendar,
          action: Icon(Icons.chevron_right, color: colors.primaryStrong),
        ),
      ],
    );
  }
}

class _ProgressMetricTile extends StatelessWidget {
  const _ProgressMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.suffix,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String suffix;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color ?? colors.primaryStrong),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontSize: 20),
            ),
            Text(suffix, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _WeeklyActivityStrip extends StatelessWidget {
  const _WeeklyActivityStrip({required this.days});

  final List<WeeklyActivityDay> days;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final day in days)
            Column(
              children: [
                Text(day.label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 7),
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: day.hasSession
                        ? colors.primaryContainer
                        : colors.raised,
                    shape: BoxShape.circle,
                  ),
                  child: day.hasSession
                      ? const Icon(Icons.check, size: 15, color: Colors.white)
                      : null,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _VolumeChartCard extends StatelessWidget {
  const _VolumeChartCard({
    required this.volume,
    required this.points,
    required this.primaryLabel,
    required this.secondaryLabel,
  });

  final double volume;
  final List<double> points;
  final String primaryLabel;
  final String? secondaryLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      height: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SoftChip(
                  label: primaryLabel,
                  color: Colors.white,
                  background: colors.primaryContainer,
                ),
                if (secondaryLabel != null) ...[
                  const SizedBox(width: 6),
                  _SoftChip(
                    label: secondaryLabel!,
                    color: colors.primaryStrong,
                    background: colors.raised,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: CustomPaint(
              painter: _SparklinePainter(
                points: points,
                line: colors.primaryStrong,
                accent: colors.amber,
                grid: colors.divider,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          Text(
            '${volume.round()} kg-reps esta semana',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.points,
    required this.line,
    required this.accent,
    required this.grid,
  });

  final List<double> points;
  final Color line;
  final Color accent;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * i / (points.length - 1);
      final y = size.height * (1 - points[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke,
    );
    final bestIndex = points.indexOf(points.reduce((a, b) => a > b ? a : b));
    final best = Offset(
      size.width * bestIndex / (points.length - 1),
      size.height * (1 - points[bestIndex]),
    );
    canvas.drawCircle(best, 4, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.line != line ||
      oldDelegate.accent != accent ||
      oldDelegate.grid != grid;
}

class _MiniValuePill extends StatelessWidget {
  const _MiniValuePill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return _SoftChip(
      label: label,
      color: context.appColors.primaryStrong,
      background: context.appColors.raised,
    );
  }
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.user,
    required this.repository,
    required this.exercises,
    required this.localSessions,
    required this.routines,
    required this.editingRoutineId,
    required this.editingRoutineTitle,
    required this.customExercises,
    required this.onExercisesChanged,
    required this.onStartRoutine,
    required this.onEditRoutine,
    required this.onCreateRoutine,
    required this.onSaveRoutine,
    required this.onSaveEditingRoutine,
    required this.onSaveEditingRoutineAsCopy,
    required this.onDeleteRoutine,
    required this.onDuplicateRoutine,
    required this.onMoveRoutine,
    required this.onSaveCustomExercise,
    required this.onDeleteCustomExercise,
    required this.localGalleryEnabled,
  });

  final AppUser user;
  final AgujetasRepository repository;
  final List<WorkoutExercise> exercises;
  final List<LocalWorkoutSession> localSessions;
  final List<RoutineTemplate> routines;
  final String? editingRoutineId;
  final String? editingRoutineTitle;
  final List<ExerciseCatalogEntry> customExercises;
  final ValueChanged<List<WorkoutExercise>> onExercisesChanged;
  final ValueChanged<RoutineTemplate> onStartRoutine;
  final ValueChanged<RoutineTemplate> onEditRoutine;
  final ValueChanged<String> onCreateRoutine;
  final Future<void> Function(RoutineTemplate routine) onSaveRoutine;
  final Future<void> Function() onSaveEditingRoutine;
  final Future<void> Function() onSaveEditingRoutineAsCopy;
  final Future<void> Function(RoutineTemplate routine) onDeleteRoutine;
  final Future<void> Function(RoutineTemplate routine) onDuplicateRoutine;
  final Future<void> Function(int oldIndex, int newIndex) onMoveRoutine;
  final Future<void> Function(ExerciseCatalogEntry exercise)
  onSaveCustomExercise;
  final Future<void> Function(ExerciseCatalogEntry exercise)
  onDeleteCustomExercise;
  final bool localGalleryEnabled;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final Future<List<ExerciseCatalogEntry>> _catalogFuture =
      _loadCatalogSnapshot();
  String _query = '';
  bool _showMine = false;
  String? _selectedMuscleGroup;
  String? _selectedEquipment;
  bool _favoritesOnly = false;

  bool get _hasActiveLibraryFilters =>
      _selectedMuscleGroup != null ||
      _selectedEquipment != null ||
      _favoritesOnly;

  @override
  void initState() {
    super.initState();
    _showMine = widget.editingRoutineId != null;
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editingRoutineId == null && widget.editingRoutineId != null) {
      _showMine = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditingRoutine = widget.editingRoutineId != null;
    final editingTitle = widget.editingRoutineTitle ?? 'Rutina sin nombre';
    final showMine = _showMine;
    return AppScaffold(
      title: 'Biblioteca',
      user: widget.user,
      trailing: IconButton(
        tooltip: 'Crear ejercicio',
        onPressed: () => _openCustomExerciseSheet(),
        icon: const Icon(Icons.add_circle_outline),
      ),
      bottomAction: FilledButton.icon(
        onPressed: showMine && !isEditingRoutine
            ? _promptCreateRoutine
            : () => _openCustomExerciseSheet(),
        icon: Icon(showMine && !isEditingRoutine ? Icons.post_add : Icons.add),
        label: Text(
          showMine && !isEditingRoutine
              ? 'Nueva rutina'
              : 'Crear ejercicio personalizado',
        ),
      ),
      menuActions: [
        AppMenuAction(
          icon: Icons.search,
          label: 'Catálogo',
          selected: !showMine,
          onSelected: () => setState(() => _showMine = false),
        ),
        AppMenuAction(
          icon: Icons.bookmarks_outlined,
          label: 'Mis ejercicios',
          selected: showMine,
          onSelected: () => setState(() => _showMine = true),
        ),
      ],
      children: [
        TextField(
          onChanged: (value) => setState(() => _query = value.trim()),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Buscar ejercicio, músculo o rutina',
            suffixIcon: IconButton(
              tooltip: _hasActiveLibraryFilters ? 'Limpiar filtros' : 'Filtros',
              onPressed: _hasActiveLibraryFilters
                  ? _clearLibraryFilters
                  : _openMuscleFilter,
              icon: Icon(
                _hasActiveLibraryFilters ? Icons.filter_alt_off : Icons.tune,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _LibraryTabs(
          showMine: showMine,
          onChanged: (value) => setState(() => _showMine = value),
        ),
        _LibraryFilterChips(
          selectedMuscleGroup: _selectedMuscleGroup,
          selectedEquipment: _selectedEquipment,
          favoritesOnly: _favoritesOnly,
          onPickMuscleGroup: _openMuscleFilter,
          onPickEquipment: _openEquipmentFilter,
          onToggleFavorites: () =>
              setState(() => _favoritesOnly = !_favoritesOnly),
          onClear: _hasActiveLibraryFilters ? _clearLibraryFilters : null,
        ),
        const _LibraryAssetBanner(),
        if (!showMine)
          FutureBuilder<List<ExerciseCatalogEntry>>(
            future: _catalogFuture,
            builder: (context, snapshot) {
              final catalog = snapshot.data ?? _seedCatalogEntries();
              final filtered = _filterCatalog(catalog).take(18).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CompactSectionTitle(
                    _query.isEmpty ? 'Más usados' : 'Resultados',
                  ),
                  for (final item in filtered)
                    _CatalogTile(
                      item: item,
                      onTap: () {
                        final exercise = item.toWorkoutExercise();
                        showExerciseDetailSheet(
                          context,
                          exercise: exercise,
                          historyRecords: ExerciseHistoryRecord.findAll(
                            widget.localSessions,
                            exercise,
                          ),
                          onAdd: () => _addExercise(exercise),
                        );
                      },
                      onAdd: () => _addExercise(item.toWorkoutExercise()),
                    ),
                  if (filtered.isEmpty)
                    DashboardCard(
                      icon: Icons.search_off_outlined,
                      title: 'Sin resultados',
                      subtitle:
                          'Probá buscar por nombre, músculo o agregá un ejercicio propio.',
                      action: FilledButton(
                        onPressed: () => _openCustomExerciseSheet(),
                        child: const Text('Crear'),
                      ),
                    ),
                ],
              );
            },
          )
        else ...[
          DashboardCard(
            icon: isEditingRoutine
                ? Icons.edit_note_outlined
                : Icons.bookmarks_outlined,
            title: isEditingRoutine ? 'Editando: $editingTitle' : 'Rutina base',
            subtitle: isEditingRoutine
                ? '${widget.exercises.length} ejercicios. Los cambios se guardan en esta plantilla local.'
                : '${widget.exercises.length} ejercicios listos para editar, reordenar y asignar.',
            action: FilledButton(
              onPressed: () async {
                if (isEditingRoutine) {
                  await _saveEditingRoutineFromLibrary();
                  return;
                }
                final routine = RoutineTemplate(
                  id: const Uuid().v4(),
                  ownerId: widget.user.uid,
                  title: 'Rutina base Agujetas',
                  exercises: widget.exercises,
                );
                await widget.onSaveRoutine(routine);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rutina guardada localmente')),
                );
              },
              child: const Text('Guardar'),
            ),
            child: isEditingRoutine
                ? Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('routine-save-changes'),
                        onPressed: _saveEditingRoutineFromLibrary,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Guardar cambios'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          if (widget.exercises.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Agregá al menos un ejercicio antes de copiar.',
                                ),
                              ),
                            );
                            return;
                          }
                          await widget.onSaveEditingRoutineAsCopy();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copia guardada localmente'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_all_outlined),
                        label: const Text('Guardar copia'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.exercises.isEmpty
                            ? null
                            : () {
                                final routine = RoutineTemplate(
                                  id: widget.editingRoutineId!,
                                  ownerId: widget.user.uid,
                                  title: editingTitle,
                                  exercises: widget.exercises,
                                );
                                widget.onStartRoutine(routine);
                              },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Entrenar'),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('routine-add-from-catalog'),
                        onPressed: () => setState(() => _showMine = false),
                        icon: const Icon(Icons.search),
                        label: const Text('Agregar desde catálogo'),
                      ),
                    ],
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _promptCreateRoutine,
                        icon: const Icon(Icons.post_add),
                        label: const Text('Nueva rutina'),
                      ),
                    ],
                  ),
          ),
          if (widget.routines.isNotEmpty)
            DashboardCard(
              icon: Icons.inventory_2_outlined,
              title: 'Rutinas legacy importadas',
              subtitle:
                  '${widget.routines.length} rutinas y sesiones personalizadas disponibles offline.',
              child: Column(
                children: [
                  for (var i = 0; i < widget.routines.length; i++)
                    RoutineTemplateTile(
                      routine: widget.routines[i],
                      isEditing:
                          widget.routines[i].id == widget.editingRoutineId,
                      onStart: () => widget.onStartRoutine(widget.routines[i]),
                      onEdit: () => widget.onEditRoutine(widget.routines[i]),
                      onRename: () => _renameRoutine(widget.routines[i]),
                      onDuplicate: () =>
                          widget.onDuplicateRoutine(widget.routines[i]),
                      onDelete: () => _confirmDeleteRoutine(widget.routines[i]),
                      onMoveUp: i == 0
                          ? null
                          : () => widget.onMoveRoutine(i, i - 1),
                      onMoveDown: i == widget.routines.length - 1
                          ? null
                          : () => widget.onMoveRoutine(i, i + 1),
                    ),
                ],
              ),
            ),
          _CustomExercisesSection(
            items: widget.customExercises,
            query: _query,
            selectedMuscleGroup: _selectedMuscleGroup,
            selectedEquipment: _selectedEquipment,
            favoritesOnly: _favoritesOnly,
            localSessions: widget.localSessions,
            onCreate: () => _openCustomExerciseSheet(),
            onAddExercise: _addExercise,
            onEditExercise: _editCustomExercise,
            onDeleteExercise: _confirmDeleteCustomExercise,
          ),
          const _CompactSectionTitle('Orden de rutina'),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            proxyDecorator: stitchReorderProxy,
            onReorderStart: (_) => HapticFeedback.mediumImpact(),
            onReorderEnd: (_) => HapticFeedback.selectionClick(),
            itemCount: widget.exercises.length,
            onReorder: (oldIndex, newIndex) {
              final next = [...widget.exercises];
              final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
              final item = next.removeAt(oldIndex);
              next.insert(target, item);
              widget.onExercisesChanged(next);
            },
            itemBuilder: (context, index) {
              final exercise = widget.exercises[index];
              return _LibraryRoutineTile(
                key: ValueKey('library-${exercise.id}'),
                index: index,
                exercise: exercise,
                isEditingRoutine: isEditingRoutine,
                onTap: () => isEditingRoutine
                    ? _editRoutineExerciseDefaults(index, exercise)
                    : showExerciseDetailSheet(
                        context,
                        exercise: exercise,
                        historyRecords: ExerciseHistoryRecord.findAll(
                          widget.localSessions,
                          exercise,
                        ),
                      ),
                onEditDefaults: isEditingRoutine
                    ? () => _editRoutineExerciseDefaults(index, exercise)
                    : null,
                onRemoveExercise: () =>
                    _confirmRemoveRoutineExercise(index, exercise),
                onMoveUp: index == 0
                    ? null
                    : () {
                        final next = [...widget.exercises];
                        final item = next.removeAt(index);
                        next.insert(index - 1, item);
                        widget.onExercisesChanged(next);
                        HapticFeedback.selectionClick();
                      },
                onMoveDown: index == widget.exercises.length - 1
                    ? null
                    : () {
                        final next = [...widget.exercises];
                        final item = next.removeAt(index);
                        next.insert(index + 1, item);
                        widget.onExercisesChanged(next);
                        HapticFeedback.selectionClick();
                      },
              );
            },
          ),
        ],
      ],
    );
  }

  List<ExerciseCatalogEntry> _filterCatalog(
    List<ExerciseCatalogEntry> catalog,
  ) {
    if (_query.isEmpty) {
      final hasFilters =
          _selectedMuscleGroup != null ||
          _selectedEquipment != null ||
          _favoritesOnly;
      final usedCatalog = catalog.where((item) => item.usageCount > 0).toList();
      final source = hasFilters || usedCatalog.isEmpty ? catalog : usedCatalog;
      return source.where(_matchesLibraryFilters).toList();
    }
    final normalized = _normalizeLibraryText(_query);
    return catalog
        .where(
          (item) =>
              (_normalizeLibraryText(item.name).contains(normalized) ||
                  _normalizeLibraryText(
                    item.muscleGroup,
                  ).contains(normalized)) &&
              _matchesLibraryFilters(item),
        )
        .toList();
  }

  bool _matchesLibraryFilters(ExerciseCatalogEntry item) {
    if (_favoritesOnly && item.usageCount <= 0) return false;
    if (_selectedMuscleGroup != null &&
        item.muscleGroup != _selectedMuscleGroup) {
      return false;
    }
    if (_selectedEquipment != null &&
        !_matchesEquipmentFilter(item, _selectedEquipment!)) {
      return false;
    }
    return true;
  }

  Future<void> _openMuscleFilter() async {
    final options = {
      ..._libraryMuscleOptions,
      for (final item in widget.customExercises) item.muscleGroup,
    }.where((value) => value.trim().isNotEmpty).toList()..sort();
    final selected = await _showLibraryOptionSheet(
      title: 'Grupo muscular',
      options: options,
      currentValue: _selectedMuscleGroup,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _selectedMuscleGroup = selected == _allLibraryOptions ? null : selected;
    });
  }

  Future<void> _openEquipmentFilter() async {
    final selected = await _showLibraryOptionSheet(
      title: 'Equipamiento',
      options: _libraryEquipmentOptions.keys.toList(),
      currentValue: _selectedEquipment,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _selectedEquipment = selected == _allLibraryOptions ? null : selected;
    });
  }

  Future<String?> _showLibraryOptionSheet({
    required String title,
    required List<String> options,
    required String? currentValue,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final values = [_allLibraryOptions, ...options];
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final value in values)
                ListTile(
                  leading: Icon(
                    value == currentValue ||
                            (value == _allLibraryOptions &&
                                currentValue == null)
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                  ),
                  title: Text(value == _allLibraryOptions ? 'Todos' : value),
                  onTap: () => Navigator.of(context).pop(value),
                ),
            ],
          ),
        );
      },
    );
  }

  void _clearLibraryFilters() {
    setState(() {
      _selectedMuscleGroup = null;
      _selectedEquipment = null;
      _favoritesOnly = false;
    });
  }

  void _addExercise(WorkoutExercise exercise) {
    widget.onExercisesChanged([...widget.exercises, exercise]);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${exercise.name} agregado a la rutina')),
    );
  }

  Future<void> _saveEditingRoutineFromLibrary() async {
    if (widget.exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agregá al menos un ejercicio antes de guardar.'),
        ),
      );
      return;
    }
    await widget.onSaveEditingRoutine();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Rutina guardada localmente')));
  }

  Future<void> _promptCreateRoutine() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nueva rutina'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nombre de la rutina',
            hintText: 'Ej. Empuje pesado',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    final normalizedTitle = title?.trim();
    if (normalizedTitle == null || normalizedTitle.isEmpty) return;
    widget.onCreateRoutine(normalizedTitle);
    if (!mounted) return;
    setState(() {
      _showMine = true;
      _query = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rutina "$normalizedTitle" lista para editar')),
    );
  }

  Future<void> _editRoutineExerciseDefaults(
    int index,
    WorkoutExercise exercise,
  ) async {
    final updated = await showRoutineExerciseDefaultsSheet(
      context,
      exercise: exercise,
    );
    if (updated == null || !mounted) return;
    final next = [...widget.exercises];
    if (index < 0 || index >= next.length) return;
    next[index] = updated;
    widget.onExercisesChanged(next);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Defaults de ${updated.name} actualizados')),
    );
  }

  Future<void> _confirmRemoveRoutineExercise(
    int index,
    WorkoutExercise exercise,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitar ejercicio'),
        content: Text(
          'Esto quita "${exercise.name}" de esta rutina local. '
          'No borra tu historial ni el catálogo de ejercicios.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final next = [...widget.exercises];
    if (index < 0 || index >= next.length) return;
    next.removeAt(index);
    widget.onExercisesChanged(next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${exercise.name} quitado de la rutina')),
    );
  }

  Future<void> _renameRoutine(RoutineTemplate routine) async {
    final controller = TextEditingController(text: routine.title);
    final nextTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renombrar rutina'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nombre'),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (nextTitle == null || nextTitle.isEmpty || nextTitle == routine.title) {
      return;
    }
    await widget.onSaveRoutine(routine.copyWith(title: nextTitle));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Rutina renombrada a "$nextTitle"')));
  }

  Future<void> _confirmDeleteRoutine(RoutineTemplate routine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar rutina'),
        content: Text(
          'Esto elimina "${routine.title}" de este dispositivo. '
          'No borra tu historial de entrenamientos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.onDeleteRoutine(routine);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rutina "${routine.title}" eliminada')),
    );
  }

  Future<void> _openCustomExerciseSheet({
    ExerciseCatalogEntry? initialExercise,
    bool addToRoutine = true,
  }) async {
    final exercise = await showModalBottomSheet<ExerciseCatalogEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CustomExerciseSheet(
        catalogFuture: _catalogFuture,
        initialExercise: initialExercise,
        allowLocalGallery: widget.localGalleryEnabled,
      ),
    );
    if (exercise == null) return;
    await widget.onSaveCustomExercise(exercise);
    if (!mounted) return;
    if (addToRoutine) {
      _addExercise(exercise.toWorkoutExercise());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${exercise.name} actualizado localmente')),
      );
    }
  }

  Future<void> _editCustomExercise(ExerciseCatalogEntry exercise) {
    return _openCustomExerciseSheet(
      initialExercise: exercise,
      addToRoutine: false,
    );
  }

  Future<void> _confirmDeleteCustomExercise(
    ExerciseCatalogEntry exercise,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar ejercicio'),
        content: Text(
          'Esto elimina "${exercise.name}" de tus ejercicios personalizados. '
          'No borra sesiones históricas donde ya lo usaste.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.onDeleteCustomExercise(exercise);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${exercise.name} eliminado localmente')),
    );
  }
}

Future<List<ExerciseCatalogEntry>> _loadCatalogSnapshot() async {
  final raw = await rootBundle.loadString(
    'assets/user_data/catalogo_ejercicios_2026-05-13.json',
  );
  final decoded = jsonDecode(raw) as Map<String, Object?>;
  final rows = decoded['rows'] as List<dynamic>? ?? const [];
  return rows
      .whereType<Map>()
      .map(
        (item) => ExerciseCatalogEntry.fromJson(item.cast<String, Object?>()),
      )
      .where((item) => item.name.isNotEmpty)
      .toList()
    ..sort((a, b) {
      final usage = b.usageCount.compareTo(a.usageCount);
      if (usage != 0) return usage;
      return a.name.compareTo(b.name);
    });
}

List<ExerciseCatalogEntry> _seedCatalogEntries() {
  return seedWorkout()
      .map(
        (exercise) => ExerciseCatalogEntry(
          id: exercise.id,
          name: exercise.name,
          muscleGroup: exercise.muscleGroup,
          imageUri: exercise.imageUri,
          usageCount: 1,
        ),
      )
      .toList();
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.item,
    required this.onAdd,
    required this.onTap,
  });

  final ExerciseCatalogEntry item;
  final VoidCallback onAdd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ExerciseImageBadge(
                exerciseId: item.id,
                name: item.name,
                muscleGroup: item.muscleGroup,
                imageUri: item.imageUri,
                size: 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.muscleGroup}${item.usageCount > 0 ? ' · usado ${item.usageCount}x' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Favorito',
                onPressed: () {},
                icon: const Icon(Icons.star_border),
              ),
              IconButton.filledTonal(
                key: ValueKey('catalog-add-${item.id}'),
                tooltip: 'Agregar',
                onPressed: onAdd,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomExercisesSection extends StatelessWidget {
  const _CustomExercisesSection({
    required this.items,
    required this.query,
    required this.selectedMuscleGroup,
    required this.selectedEquipment,
    required this.favoritesOnly,
    required this.localSessions,
    required this.onCreate,
    required this.onAddExercise,
    required this.onEditExercise,
    required this.onDeleteExercise,
  });

  final List<ExerciseCatalogEntry> items;
  final String query;
  final String? selectedMuscleGroup;
  final String? selectedEquipment;
  final bool favoritesOnly;
  final List<LocalWorkoutSession> localSessions;
  final VoidCallback onCreate;
  final ValueChanged<WorkoutExercise> onAddExercise;
  final ValueChanged<ExerciseCatalogEntry> onEditExercise;
  final ValueChanged<ExerciseCatalogEntry> onDeleteExercise;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _normalizeLibraryText(query);
    final filtered = items.where((item) {
      if (favoritesOnly && item.usageCount <= 0) return false;
      if (selectedMuscleGroup != null &&
          item.muscleGroup != selectedMuscleGroup) {
        return false;
      }
      if (selectedEquipment != null &&
          !_matchesEquipmentFilter(item, selectedEquipment!)) {
        return false;
      }
      if (normalizedQuery.isEmpty) return true;
      return _normalizeLibraryText(item.name).contains(normalizedQuery) ||
          _normalizeLibraryText(item.muscleGroup).contains(normalizedQuery);
    }).toList();

    if (items.isEmpty) {
      return DashboardCard(
        icon: Icons.auto_awesome_motion_outlined,
        title: 'Tus ejercicios',
        subtitle:
            'Todavía no creaste ejercicios personalizados. Podés usar galería local o una imagen propia del repositorio.',
        action: FilledButton(onPressed: onCreate, child: const Text('Crear')),
      );
    }
    return DashboardCard(
      icon: Icons.auto_awesome_motion_outlined,
      title: 'Tus ejercicios',
      subtitle:
          query.isEmpty &&
              selectedMuscleGroup == null &&
              selectedEquipment == null &&
              !favoritesOnly
          ? '${items.length} ejercicios personalizados locales'
          : '${filtered.length} resultados en tus ejercicios',
      child: Column(
        children: [
          if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: context.appColors.raised,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sin resultados propios',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Podés crear un ejercicio nuevo o limpiar la búsqueda para ver todo tu catálogo local.',
                    style: TextStyle(color: context.appColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(onPressed: onCreate, child: const Text('Crear')),
                ],
              ),
            ),
          for (final item in filtered.take(12))
            _CustomExerciseTile(
              item: item,
              onTap: () {
                final exercise = item.toWorkoutExercise();
                showExerciseDetailSheet(
                  context,
                  exercise: exercise,
                  historyRecords: ExerciseHistoryRecord.findAll(
                    localSessions,
                    exercise,
                  ),
                  onAdd: () => onAddExercise(exercise),
                );
              },
              onAdd: () => onAddExercise(item.toWorkoutExercise()),
              onEdit: () => onEditExercise(item),
              onDelete: () => onDeleteExercise(item),
            ),
        ],
      ),
    );
  }
}

class _CustomExerciseTile extends StatelessWidget {
  const _CustomExerciseTile({
    required this.item,
    required this.onTap,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final ExerciseCatalogEntry item;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ExerciseImageBadge(
                exerciseId: item.id,
                name: item.name,
                muscleGroup: item.muscleGroup,
                imageUri: item.imageUri,
                size: 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.muscleGroup} · personalizado local',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opciones del ejercicio',
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuDivider(),
                  PopupMenuItem(value: 'delete', child: Text('Borrar')),
                ],
              ),
              IconButton.filledTonal(
                tooltip: 'Agregar',
                onPressed: onAdd,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoutineTemplateTile extends StatelessWidget {
  const RoutineTemplateTile({
    super.key,
    required this.routine,
    required this.isEditing,
    required this.onStart,
    required this.onEdit,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
  });

  final RoutineTemplate routine;
  final bool isEditing;
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final preview = routine.exercises.take(3).toList();
    final subtitle = routine.exercises
        .take(4)
        .map((exercise) => exercise.name)
        .join(', ');
    return Card(
      color: isEditing ? colors.primaryContainer.withValues(alpha: 0.1) : null,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 76,
                  height: 44,
                  child: Stack(
                    children: [
                      for (var i = 0; i < preview.length; i++)
                        Positioned(
                          left: i * 18,
                          child: ExerciseImageBadge(
                            exerciseId: preview[i].id,
                            name: preview[i].name,
                            muscleGroup: preview[i].muscleGroup,
                            imageUri: preview[i].imageUri,
                            size: 42,
                          ),
                        ),
                      if (preview.isEmpty)
                        const Icon(Icons.fitness_center_outlined, size: 32),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        routine.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      if (isEditing) ...[
                        _SoftChip(
                          label: 'En edición',
                          color: colors.primaryStrong,
                          background: colors.primaryContainer.withValues(
                            alpha: 0.16,
                          ),
                        ),
                        const SizedBox(height: 5),
                      ],
                      Text(
                        '${routine.exercises.length} ejercicios'
                        '${subtitle.isEmpty ? '' : ' · $subtitle'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Opciones de rutina',
                  onSelected: (value) {
                    switch (value) {
                      case 'rename':
                        onRename();
                        break;
                      case 'edit':
                        onEdit();
                        break;
                      case 'duplicate':
                        onDuplicate();
                        break;
                      case 'moveUp':
                        onMoveUp?.call();
                        break;
                      case 'moveDown':
                        onMoveDown?.call();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    const PopupMenuItem(
                      value: 'rename',
                      child: Text('Renombrar'),
                    ),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Text('Duplicar'),
                    ),
                    PopupMenuItem(
                      value: 'moveUp',
                      enabled: onMoveUp != null,
                      child: const Text('Subir'),
                    ),
                    PopupMenuItem(
                      value: 'moveDown',
                      enabled: onMoveDown != null,
                      child: const Text('Bajar'),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'delete', child: Text('Borrar')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Iniciar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryTabs extends StatelessWidget {
  const _LibraryTabs({required this.showMine, required this.onChanged});

  final bool showMine;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.appColors.raised,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _LibraryTabButton(
              label: 'Catálogo',
              selected: !showMine,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _LibraryTabButton(
              label: 'Mis ejercicios',
              selected: showMine,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryTabButton extends StatelessWidget {
  const _LibraryTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: selected ? colors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: selected ? Border.all(color: colors.divider) : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? colors.text : colors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryFilterChips extends StatelessWidget {
  const _LibraryFilterChips({
    required this.selectedMuscleGroup,
    required this.selectedEquipment,
    required this.favoritesOnly,
    required this.onPickMuscleGroup,
    required this.onPickEquipment,
    required this.onToggleFavorites,
    required this.onClear,
  });

  final String? selectedMuscleGroup;
  final String? selectedEquipment;
  final bool favoritesOnly;
  final VoidCallback onPickMuscleGroup;
  final VoidCallback onPickEquipment;
  final VoidCallback onToggleFavorites;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          _FilterPill(
            icon: Icons.accessibility_new,
            label: selectedMuscleGroup ?? 'Grupo muscular',
            selected: selectedMuscleGroup != null,
            onTap: onPickMuscleGroup,
          ),
          _FilterPill(
            icon: Icons.fitness_center,
            label: selectedEquipment ?? 'Equipamiento',
            selected: selectedEquipment != null,
            onTap: onPickEquipment,
          ),
          _FilterPill(
            icon: favoritesOnly ? Icons.star : Icons.star_border,
            label: 'Usados',
            selected: favoritesOnly,
            onTap: onToggleFavorites,
          ),
          if (onClear != null)
            _FilterPill(
              icon: Icons.close,
              label: 'Limpiar',
              selected: false,
              onTap: onClear!,
            ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? colors.primaryContainer : colors.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? colors.primaryStrong : colors.divider,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: colors.primaryStrong),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? colors.primaryStrong : null,
                    fontWeight: selected ? FontWeight.w800 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryAssetBanner extends StatelessWidget {
  const _LibraryAssetBanner();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.amberContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.amberContainer),
      ),
      child: Row(
        children: [
          Icon(Icons.offline_pin_outlined, color: colors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Imágenes propias locales: sin Lyfta y listas para funcionar offline.',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryRoutineTile extends StatelessWidget {
  const _LibraryRoutineTile({
    super.key,
    required this.index,
    required this.exercise,
    required this.isEditingRoutine,
    required this.onTap,
    this.onEditDefaults,
    required this.onRemoveExercise,
    this.onMoveUp,
    this.onMoveDown,
  });

  final int index;
  final WorkoutExercise exercise;
  final bool isEditingRoutine;
  final VoidCallback onTap;
  final VoidCallback? onEditDefaults;
  final VoidCallback onRemoveExercise;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ReorderGrip(index: index, label: 'Reordenar ${exercise.name}'),
              const SizedBox(width: 10),
              ExerciseImageBadge(
                exerciseId: exercise.id,
                name: exercise.name,
                muscleGroup: exercise.muscleGroup,
                imageUri: exercise.imageUri,
                size: 48,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${exercise.muscleGroup} · ${exercise.sets.length} series · ${exercise.isUnilateral ? 'unilateral' : 'bilateral'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textSecondary),
                    ),
                    if (isEditingRoutine) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Tocá para editar kg, reps, RIR y backoff',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: colors.primaryStrong),
                      ),
                    ],
                  ],
                ),
              ),
              if (onEditDefaults != null)
                IconButton(
                  tooltip: 'Editar defaults',
                  onPressed: onEditDefaults,
                  icon: const Icon(Icons.tune),
                ),
              IconButton(
                tooltip: 'Quitar de rutina',
                onPressed: onRemoveExercise,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              ReorderAccessibilityMenu(
                onMoveUp: onMoveUp,
                onMoveDown: onMoveDown,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExerciseImageBadge extends StatelessWidget {
  const ExerciseImageBadge({
    super.key,
    required this.exerciseId,
    required this.name,
    required this.muscleGroup,
    this.imageUri,
    this.size = 44,
  });

  final String exerciseId;
  final String name;
  final String muscleGroup;
  final String? imageUri;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final localGalleryImage =
        imageUri != null &&
        imageUri!.isNotEmpty &&
        !imageUri!.startsWith('app-image://') &&
        !imageUri!.startsWith('agujetas-image://');

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: localGalleryImage
          ? Icon(Icons.photo_library_outlined, color: colors.textSecondary)
          : FutureBuilder<ResolvedExerciseImage>(
              future: ExerciseImageResolver.instance.resolve(
                exerciseId: exerciseId,
                name: name,
                muscleGroup: muscleGroup,
                imageUri: imageUri,
              ),
              builder: (context, snapshot) {
                final resolved = snapshot.data;
                if (resolved == null) {
                  return Icon(
                    Icons.fitness_center,
                    color: colors.textSecondary,
                  );
                }
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(3),
                      child: SvgPicture.asset(
                        resolved.assetPath,
                        fit: BoxFit.contain,
                      ),
                    ),
                    if (resolved.legacyUriBlocked)
                      Positioned(
                        right: 3,
                        bottom: 3,
                        child: Icon(
                          Icons.verified_outlined,
                          size: 12,
                          color: colors.primaryStrong,
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class CustomExerciseSheet extends StatefulWidget {
  const CustomExerciseSheet({
    super.key,
    required this.catalogFuture,
    this.initialExercise,
    this.allowLocalGallery = true,
  });

  final Future<List<ExerciseCatalogEntry>> catalogFuture;
  final ExerciseCatalogEntry? initialExercise;
  final bool allowLocalGallery;

  @override
  State<CustomExerciseSheet> createState() => _CustomExerciseSheetState();
}

class _CustomExerciseSheetState extends State<CustomExerciseSheet> {
  final _nameController = TextEditingController();
  final _muscleController = TextEditingController(text: 'General');
  String? _imageUri;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialExercise;
    if (initial == null) return;
    _nameController.text = initial.name;
    _muscleController.text = initial.muscleGroup;
    _imageUri = initial.imageUri;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _muscleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.initialExercise != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isEditing ? 'Editar ejercicio' : 'Nuevo ejercicio',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _muscleController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Músculo'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ExerciseImageBadge(
                exerciseId: 'custom-preview',
                name: _nameController.text.trim().isEmpty
                    ? 'Ejercicio personalizado'
                    : _nameController.text.trim(),
                muscleGroup: _muscleController.text.trim().isEmpty
                    ? 'General'
                    : _muscleController.text.trim(),
                imageUri: _imageUri,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _imageUri ?? 'Sin imagen asociada',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickGalleryImage,
                  icon: Icon(
                    widget.allowLocalGallery
                        ? Icons.photo_library_outlined
                        : Icons.lock_outline,
                  ),
                  label: const Text('Galería'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickRepositoryImage,
                  icon: const Icon(Icons.image_search_outlined),
                  label: const Text('Repo'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(isEditing ? 'Guardar cambios' : 'Crear con 3 series'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickGalleryImage() async {
    if (!widget.allowLocalGallery) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Activá Galería local desde Perfil para usar imágenes del dispositivo.',
          ),
        ),
      );
      return;
    }
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _imageUri = picked.path);
  }

  Future<void> _pickRepositoryImage() async {
    final imageUri = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) =>
          RepositoryImagePicker(catalogFuture: widget.catalogFuture),
    );
    if (imageUri == null) return;
    setState(() => _imageUri = imageUri);
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      ExerciseCatalogEntry(
        id: widget.initialExercise?.id ?? 'custom_${const Uuid().v4()}',
        name: name,
        muscleGroup: _muscleController.text.trim().isEmpty
            ? 'General'
            : _muscleController.text.trim(),
        imageUri: _imageUri,
        usageCount: widget.initialExercise?.usageCount ?? 0,
        lastUsedDate: widget.initialExercise?.lastUsedDate,
        isCustom: true,
      ),
    );
  }
}

class RepositoryImagePicker extends StatelessWidget {
  const RepositoryImagePicker({super.key, required this.catalogFuture});

  final Future<List<ExerciseCatalogEntry>> catalogFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ExerciseCatalogEntry>>(
      future: catalogFuture,
      builder: (context, snapshot) {
        final catalog = snapshot.data ?? const <ExerciseCatalogEntry>[];
        final priorityItems = catalog
            .where((item) => item.usageCount > 0)
            .take(40)
            .toList();
        final fallbackItems = priorityItems.isEmpty
            ? catalog.take(40).toList()
            : priorityItems;
        return FutureBuilder<List<_RepositoryImageOption>>(
          future: _loadOptions(fallbackItems),
          builder: (context, optionSnapshot) {
            final options =
                optionSnapshot.data ?? const <_RepositoryImageOption>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Text(
                  'Imagen del repositorio',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Assets propios Agujetas. No se muestran imágenes Lyfta.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (options.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.image_search_outlined),
                    title: Text('Cargando imágenes propias'),
                  ),
                for (final option in options)
                  ListTile(
                    leading: ExerciseImageBadge(
                      exerciseId: option.item.id,
                      name: option.item.name,
                      muscleGroup: option.item.muscleGroup,
                      imageUri: option.uri,
                    ),
                    title: Text(option.item.name),
                    subtitle: Text(
                      'agujetas-generated · ${option.resolved.status}',
                    ),
                    onTap: () => Navigator.of(context).pop(option.uri),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<_RepositoryImageOption>> _loadOptions(
    List<ExerciseCatalogEntry> items,
  ) async {
    final options = <_RepositoryImageOption>[];
    for (final item in items) {
      final resolved = await ExerciseImageResolver.instance.resolve(
        exerciseId: item.id,
        name: item.name,
        muscleGroup: item.muscleGroup,
        imageUri: item.imageUri,
      );
      if (resolved.imageId == null) continue;
      options.add(
        _RepositoryImageOption(
          item: item,
          uri: resolved.uri,
          resolved: resolved,
        ),
      );
    }
    return options;
  }
}

class _RepositoryImageOption {
  const _RepositoryImageOption({
    required this.item,
    required this.uri,
    required this.resolved,
  });

  final ExerciseCatalogEntry item;
  final String uri;
  final ResolvedExerciseImage resolved;
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    required this.repository,
    required this.themeMode,
    required this.preferences,
    required this.onThemeModeChanged,
    required this.onPreferencesChanged,
    required this.onExportLocalBackup,
    required this.onImportLocalBackup,
    required this.onImportBundledLegacyData,
    required this.onDeleteLocalAccount,
  });

  final AppUser user;
  final AgujetasRepository repository;
  final ThemeMode themeMode;
  final LocalUserPreferences preferences;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<LocalUserPreferences> onPreferencesChanged;
  final Future<String> Function() onExportLocalBackup;
  final Future<LocalBackupImportResult> Function(String rawJson)
  onImportLocalBackup;
  final Future<LegacyLocalImportResult> Function() onImportBundledLegacyData;
  final Future<void> Function() onDeleteLocalAccount;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AppScaffold(
      title: 'Perfil',
      user: user,
      menuActions: [
        AppMenuAction(
          icon: Icons.person_outline,
          label: 'Cuenta',
          selected: true,
          onSelected: () {},
        ),
        AppMenuAction(
          icon: Icons.palette_outlined,
          label: 'Apariencia',
          onSelected: () {},
        ),
      ],
      children: [
        _ProfileHero(user: user, dark: dark),
        RoleSwitcher(user: user, repository: repository),
        PlanBillingCard(user: user, repository: repository),
        _SettingsSection(
          icon: Icons.palette_outlined,
          title: 'Apariencia',
          subtitle: 'Elegí cómo se ve Agujetas en este dispositivo.',
          child: SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('Sistema')),
              ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro')),
            ],
            selected: {themeMode},
            onSelectionChanged: (value) => onThemeModeChanged(value.first),
          ),
        ),
        _SettingsSection(
          icon: Icons.notifications_active_outlined,
          title: 'Permisos',
          subtitle:
              'Controlá notificaciones, sonidos de descanso e imágenes locales.',
          child: Column(
            children: [
              _SwitchSettingRow(
                icon: Icons.timer_outlined,
                title: 'Alertas de descanso',
                subtitle: 'Sonido y aviso aunque la app esté en segundo plano.',
                value: preferences.restAlertsEnabled,
                onChanged: (value) => onPreferencesChanged(
                  preferences.copyWith(restAlertsEnabled: value),
                ),
              ),
              _SwitchSettingRow(
                icon: Icons.monitor_weight_outlined,
                title: 'Seguimiento de peso',
                subtitle: 'Avisos cuando la tendencia se aleja de tu meta.',
                value: preferences.bodyWeightAlertsEnabled,
                onChanged: (value) => onPreferencesChanged(
                  preferences.copyWith(bodyWeightAlertsEnabled: value),
                ),
              ),
              _SwitchSettingRow(
                icon: Icons.photo_library_outlined,
                title: 'Galería local',
                subtitle: 'Sólo para ejercicios personalizados.',
                value: preferences.localGalleryEnabled,
                onChanged: (value) => onPreferencesChanged(
                  preferences.copyWith(localGalleryEnabled: value),
                ),
              ),
            ],
          ),
        ),
        _SettingsSection(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacidad y datos',
          subtitle: 'Tus datos de entrenamiento pertenecen a tu cuenta.',
          child: Column(
            children: [
              _ProfileActionRow(
                icon: Icons.download_outlined,
                title: 'Exportar mis datos',
                subtitle: 'Sesiones, rutinas, peso corporal y progreso.',
                onTap: () => _exportBackup(context),
              ),
              _ProfileActionRow(
                icon: Icons.upload_file_outlined,
                title: 'Importar respaldo',
                subtitle: 'Pegar JSON local exportado desde Agujetas.',
                onTap: () => _importBackup(context),
              ),
              _ProfileActionRow(
                icon: Icons.history_edu_outlined,
                title: 'Importar datos legacy incluidos',
                subtitle:
                    'Releer histórico y rutinas exportadas de Agujetas 1.x.',
                onTap: () => _importLegacyData(context),
              ),
              _ProfileActionRow(
                icon: Icons.delete_outline,
                title: 'Eliminar cuenta',
                subtitle: 'Borra datos locales, datos remotos propios y Auth.',
                danger: true,
                onTap: () => _deleteAccount(context),
              ),
            ],
          ),
        ),
        _SettingsSection(
          icon: Icons.security_outlined,
          title: 'Seguridad',
          subtitle: 'Google Sign-In, reglas Firestore y sesiones activas.',
          child: Column(
            children: [
              _ProfileActionRow(
                icon: Icons.verified_user_outlined,
                title: 'Cuenta Google verificada',
                subtitle: user.email,
                onTap: () {},
              ),
              _ProfileActionRow(
                icon: Icons.logout,
                title: 'Cerrar sesión',
                subtitle: 'Salir de esta sesión en el dispositivo.',
                onTap: repository.signOut,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final rawJson = await onExportLocalBackup();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Respaldo local exportado'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Copiá el JSON y guardalo fuera del dispositivo. Este respaldo permite restaurar sesiones, rutinas, peso corporal y ejercicios propios.',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 280,
                  child: SingleChildScrollView(child: SelectableText(rawJson)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            FilledButton.icon(
              onPressed: () async {
                try {
                  await Clipboard.setData(ClipboardData(text: rawJson));
                } catch (_) {}
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo exportar: $error')));
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    final rawJson = await showDialog<String>(
      context: context,
      builder: (_) => const _ImportLocalBackupDialog(),
    );
    if (rawJson == null || rawJson.trim().isEmpty) return;
    try {
      final result = await onImportLocalBackup(rawJson);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Respaldo importado: ${result.summary}.')),
      );
    } on FormatException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo importar: $error')));
    }
  }

  Future<void> _importLegacyData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Importar datos legacy'),
        content: const Text(
          'Esto relee los JSON incluidos de Agujetas 1.x y agrega sólo sesiones o rutinas que todavía no estén en este dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final result = await onImportBundledLegacyData();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.summary)));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron importar datos legacy: $error')),
      );
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          'Esto puede pedirte que vuelvas a ingresar con Google. Después borra de este dispositivo sesiones, rutinas, peso corporal, ejercicios personalizados, preferencias y el entrenamiento activo. También intenta borrar tus documentos remotos conocidos de Firestore y tu cuenta de Firebase Auth.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar cuenta'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await onDeleteLocalAccount();
    } on AccountDeletionRequiresRecentLoginException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar la cuenta: $error')),
      );
    }
  }
}

class _ImportLocalBackupDialog extends StatefulWidget {
  const _ImportLocalBackupDialog();

  @override
  State<_ImportLocalBackupDialog> createState() =>
      _ImportLocalBackupDialogState();
}

class _ImportLocalBackupDialogState extends State<_ImportLocalBackupDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Importar respaldo'),
      content: SizedBox(
        width: 520,
        child: TextField(
          controller: _controller,
          minLines: 6,
          maxLines: 10,
          decoration: const InputDecoration(
            labelText: 'JSON de respaldo',
            hintText: '{ "schema": "agujetas.localBackup", ... }',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Importar'),
        ),
      ],
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.user, required this.dark});

  final AppUser user;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          BrandMark(size: 92, dark: dark),
          const SizedBox(height: 12),
          Text(
            user.displayName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 3),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _SoftChip(
                label: user.plan.label,
                color: user.isPro ? colors.primaryStrong : colors.textSecondary,
                background: colors.raised,
              ),
              _SoftChip(
                label: 'Rol: ${user.activeRole.label}',
                color: colors.primaryStrong,
                background: colors.primaryContainer.withValues(alpha: 0.12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      child: child,
    );
  }
}

class _SwitchSettingRow extends StatefulWidget {
  const _SwitchSettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<_SwitchSettingRow> createState() => _SwitchSettingRowState();
}

class _SwitchSettingRowState extends State<_SwitchSettingRow> {
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(widget.icon, color: colors.primaryStrong),
      title: Text(widget.title),
      subtitle: Text(widget.subtitle),
      trailing: Switch(value: widget.value, onChanged: widget.onChanged),
    );
  }
}

class _ProfileActionRow extends StatelessWidget {
  const _ProfileActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final foreground = danger ? Colors.red.shade700 : colors.primaryStrong;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: foreground),
      title: Text(title, style: danger ? TextStyle(color: foreground) : null),
      subtitle: Text(subtitle),
      trailing: Icon(Icons.chevron_right, color: colors.textSecondary),
      onTap: onTap,
    );
  }
}

class RoleSwitcher extends StatelessWidget {
  const RoleSwitcher({super.key, required this.user, required this.repository});

  final AppUser user;
  final AgujetasRepository repository;

  @override
  Widget build(BuildContext context) {
    final selectedRole =
        user.canUseTrainerMode && user.activeRole == AppRole.trainer
        ? AppRole.trainer
        : AppRole.normal;
    return DashboardCard(
      icon: Icons.workspace_premium_outlined,
      title: 'Modo de cuenta',
      subtitle: user.isPro
          ? 'Alterna entre entrenar para vos y gestionar entrenados.'
          : 'El modo entrenador está incluido en Agujetas Pro.',
      action: _SoftChip(
        label: user.plan.label,
        color: user.isPro
            ? context.appColors.primaryStrong
            : context.appColors.textSecondary,
        background: context.appColors.raised,
      ),
      child: Row(
        children: [
          Expanded(
            child: _AccountModeButton(
              icon: Icons.person_outline,
              label: 'Modo usuario',
              selected: selectedRole == AppRole.normal,
              onTap: () => repository.setActiveRole(user, AppRole.normal),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _AccountModeButton(
              icon: Icons.groups_outlined,
              label: 'Modo entrenador',
              selected: selectedRole == AppRole.trainer,
              locked: !user.isPro,
              onTap: user.isPro
                  ? () => repository.setActiveRole(user, AppRole.trainer)
                  : () => _showTrainerUpgradeDialog(context),
            ),
          ),
        ],
      ),
    );
  }

  void _showTrainerUpgradeDialog(BuildContext context) {
    final isDemo = user.uid == 'demo-user';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modo entrenador es Pro'),
        content: const Text(
          'Con Agujetas Pro podés crear grupos de entrenados, compartir rutinas, asignar tareas, schedules y metas, y revisar progreso desde tu panel de entrenador.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Ahora no'),
          ),
          if (isDemo)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                showProPlansSheet(context, user: user, repository: repository);
              },
              child: const Text('Ver planes'),
            ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (isDemo) {
                repository.setActiveRole(
                  user.copyWith(
                    plan: AppPlan.pro,
                    roles: {...user.roles, AppRole.trainer},
                  ),
                  AppRole.trainer,
                );
                return;
              }
              showProPlansSheet(context, user: user, repository: repository);
            },
            child: Text(isDemo ? 'Activar Pro demo' : 'Ver planes'),
          ),
        ],
      ),
    );
  }
}

Future<void> showProPlansSheet(
  BuildContext context, {
  required AppUser user,
  required AgujetasRepository repository,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _ProPlansSheet(user: user, repository: repository),
  );
}

class PlanBillingCard extends StatelessWidget {
  const PlanBillingCard({
    super.key,
    required this.user,
    required this.repository,
  });

  final AppUser user;
  final AgujetasRepository repository;

  @override
  Widget build(BuildContext context) {
    final plan = SubscriptionPlanDefinition.forPlan(user.plan);
    return DashboardCard(
      icon: Icons.payments_outlined,
      title: 'Plan y suscripción',
      subtitle: plan.subtitle,
      action: _SoftChip(
        label: plan.priceLabel,
        color: user.isPro
            ? context.appColors.primaryStrong
            : context.appColors.textSecondary,
        background: context.appColors.raised,
      ),
      onTap: () =>
          showProPlansSheet(context, user: user, repository: repository),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final feature in plan.features.take(2))
            _PlanFeatureRow(text: feature),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () =>
                showProPlansSheet(context, user: user, repository: repository),
            icon: const Icon(Icons.workspace_premium_outlined),
            label: Text(user.isPro ? 'Gestionar plan' : 'Ver planes'),
          ),
        ],
      ),
    );
  }
}

class _ProPlansSheet extends StatelessWidget {
  const _ProPlansSheet({required this.user, required this.repository});

  final AppUser user;
  final AgujetasRepository repository;

  @override
  Widget build(BuildContext context) {
    final isDemo = user.uid == 'demo-user';
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Planes Agujetas',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Esta build deja definido el contrato Free/Pro. El cobro real queda pendiente de conectar con RevenueCat antes de producción.',
              style: TextStyle(color: context.appColors.textSecondary),
            ),
            const SizedBox(height: 14),
            for (final plan in SubscriptionPlanDefinition.all)
              _PlanOptionCard(
                plan: plan,
                current: plan.plan == user.plan,
                onSelected: plan.isPro
                    ? () => _activatePro(context, isDemo)
                    : () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }

  void _activatePro(BuildContext context, bool isDemo) {
    Navigator.of(context).pop();
    if (isDemo) {
      repository.setActiveRole(
        user.copyWith(
          plan: AppPlan.pro,
          roles: {...user.roles, AppRole.trainer},
        ),
        AppRole.trainer,
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Checkout RevenueCat pendiente: no se cobra nada en esta build.',
        ),
      ),
    );
  }
}

class _PlanOptionCard extends StatelessWidget {
  const _PlanOptionCard({
    required this.plan,
    required this.current,
    required this.onSelected,
  });

  final SubscriptionPlanDefinition plan;
  final bool current;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: current
            ? colors.primaryContainer.withValues(alpha: 0.12)
            : colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: current ? colors.primaryStrong : colors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _SoftChip(
                label: current ? 'Actual' : plan.priceLabel,
                color: current ? colors.primaryStrong : colors.textSecondary,
                background: colors.raised,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(plan.subtitle, style: TextStyle(color: colors.textSecondary)),
          const SizedBox(height: 10),
          for (final feature in plan.features) _PlanFeatureRow(text: feature),
          if (plan.entitlements.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entitlement in plan.entitlements)
                  _SoftChip(
                    label: entitlement.label,
                    color: colors.primaryStrong,
                    background: colors.primaryContainer.withValues(alpha: 0.1),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: current ? null : onSelected,
            child: Text(current ? 'Plan actual' : 'Elegir ${plan.title}'),
          ),
        ],
      ),
    );
  }
}

class _PlanFeatureRow extends StatelessWidget {
  const _PlanFeatureRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: context.appColors.primaryStrong,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _AccountModeButton extends StatelessWidget {
  const _AccountModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.locked = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final foreground = locked
        ? colors.textSecondary.withValues(alpha: 0.55)
        : selected
        ? Colors.white
        : colors.text;
    final background = locked
        ? colors.raised.withValues(alpha: 0.55)
        : selected
        ? colors.primaryStrong
        : colors.raised;
    return Opacity(
      opacity: locked ? 0.62 : 1,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? Colors.transparent : colors.divider,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  locked ? Icons.lock_outline : icon,
                  size: 18,
                  color: foreground,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CompactTimers extends StatelessWidget {
  const CompactTimers({
    super.key,
    required this.totalElapsed,
    required this.restRemaining,
    required this.totalRunning,
    required this.restRunning,
    required this.onToggleTotal,
    required this.onResetTotal,
    required this.onToggleRest,
    required this.onResetRest,
  });

  final Duration totalElapsed;
  final Duration restRemaining;
  final bool totalRunning;
  final bool restRunning;
  final VoidCallback onToggleTotal;
  final VoidCallback onResetTotal;
  final VoidCallback onToggleRest;
  final VoidCallback onResetRest;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: TimerCard(
              icon: Icons.timer_outlined,
              label: 'Tiempo total',
              value: _formatDuration(totalElapsed),
              running: totalRunning,
              onToggle: onToggleTotal,
              onReset: onResetTotal,
            ),
          ),
          Container(width: 1, height: 46, color: colors.divider),
          Expanded(
            child: TimerCard(
              icon: Icons.hourglass_bottom_outlined,
              label: 'Descanso',
              value: _formatDuration(restRemaining),
              running: restRunning,
              onToggle: onToggleRest,
              onReset: onResetRest,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

class TimerCard extends StatelessWidget {
  const TimerCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.running,
    required this.onToggle,
    required this.onReset,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool running;
  final VoidCallback onToggle;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.primaryStrong),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                Text(value, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onToggle,
            icon: Icon(running ? Icons.pause : Icons.play_arrow, size: 18),
            label: Text(running ? 'Pausar' : 'Iniciar'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(0, 34),
            ),
          ),
          IconButton(
            tooltip: 'Resetear $label',
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt),
            iconSize: 19,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          ),
        ],
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.child,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  final Widget? child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final card = Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.raised,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: colors.primaryStrong, size: 21),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(color: colors.textSecondary)),
            if (child != null) ...[const SizedBox(height: 12), child!],
          ],
        ),
      ),
    );
    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: card,
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text),
    );
  }
}

class AppMenuAction {
  const AppMenuAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;
  final bool selected;
}

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.children,
    this.user,
    this.trailing,
    this.bottomAction,
    this.menuActions = const [],
  });

  final String title;
  final AppUser? user;
  final Widget? trailing;
  final Widget? bottomAction;
  final List<AppMenuAction> menuActions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.appColors;
    return Column(
      children: [
        Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(bottom: BorderSide(color: colors.divider)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: colors.raised,
                backgroundImage: user?.photoUrl == null
                    ? null
                    : NetworkImage(user!.photoUrl!),
                child: user?.photoUrl == null
                    ? BrandMark(size: 28, dark: dark)
                    : null,
              ),
              const SizedBox(width: 10),
              BrandMark(size: 28, dark: dark),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontSize: title.contains('\n') ? 18 : 16,
                              height: title.contains('\n') ? 1.05 : 1.2,
                              color: colors.primaryStrong,
                            ),
                      ),
                    ),
                    if (menuActions.isNotEmpty)
                      PopupMenuButton<int>(
                        tooltip: 'Submenú',
                        position: PopupMenuPosition.under,
                        icon: const Icon(Icons.keyboard_arrow_down),
                        onSelected: (index) => menuActions[index].onSelected(),
                        itemBuilder: (context) => [
                          for (var i = 0; i < menuActions.length; i++)
                            PopupMenuItem<int>(
                              value: i,
                              child: Row(
                                children: [
                                  Icon(menuActions[i].icon, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(menuActions[i].label)),
                                  if (menuActions[i].selected)
                                    Icon(
                                      Icons.check,
                                      color: colors.primaryStrong,
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  flex: 0,
                  child: FittedBox(fit: BoxFit.scaleDown, child: trailing!),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            children: children,
          ),
        ),
        if (bottomAction != null)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.divider)),
            ),
            child: bottomAction,
          ),
      ],
    );
  }
}

class StitchBottomNav extends StatelessWidget {
  const StitchBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = [
    (Icons.home_outlined, Icons.home, 'Inicio'),
    (Icons.fitness_center_outlined, Icons.fitness_center, 'Entrenar'),
    (Icons.insights_outlined, Icons.insights, 'Progreso'),
    (Icons.library_books_outlined, Icons.library_books, 'Biblioteca'),
    (Icons.person_outline, Icons.person, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.divider)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _BottomNavItem(
                  icon: selectedIndex == i ? _items[i].$2 : _items[i].$1,
                  label: _items[i].$3,
                  selected: selectedIndex == i,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? colors.amberContainer.withValues(alpha: 0.55)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 21,
              color: selected ? colors.primaryStrong : colors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? colors.primaryStrong : colors.textSecondary,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class StitchSideMenu extends StatelessWidget {
  const StitchSideMenu({
    super.key,
    required this.selectedIndex,
    required this.user,
    required this.onSelect,
  });

  final int selectedIndex;
  final AppUser user;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.appColors;
    const items = [
      (Icons.home_outlined, 'Inicio'),
      (Icons.fitness_center_outlined, 'Entrenar'),
      (Icons.insights_outlined, 'Progreso'),
      (Icons.library_books_outlined, 'Biblioteca'),
      (Icons.person_outline, 'Perfil'),
    ];
    return Drawer(
      backgroundColor: colors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  BrandMark(size: 52, dark: dark),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agujetas',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: colors.primaryStrong),
                        ),
                        Text(
                          user.activeRole.label,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              for (var i = 0; i < items.length; i++)
                _DrawerItem(
                  icon: items[i].$1,
                  label: items[i].$2,
                  selected: selectedIndex == i,
                  onTap: () => onSelect(i),
                ),
              const Spacer(),
              Text(
                'Calendario, progreso y biblioteca viven como secciones principales; configuración queda solo para cuenta y preferencias.',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selected: selected,
        selectedTileColor: colors.raised,
        leading: Icon(icon, color: selected ? colors.primaryStrong : null),
        title: Text(
          label,
          style: TextStyle(
            color: selected ? colors.primaryStrong : colors.text,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.size, required this.dark});

  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      dark ? 'assets/brand/logo-dark.svg' : 'assets/brand/logo-light.svg',
      width: size,
      height: size,
      semanticsLabel: 'Agujetas',
    );
  }
}

Widget stitchReorderProxy(
  Widget child,
  int index,
  Animation<double> animation,
) {
  return AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final t = Curves.easeOutCubic.transform(animation.value);
      return Transform.scale(
        scale: 1 + (0.018 * t),
        child: Material(
          color: Colors.transparent,
          elevation: 10 * t,
          shadowColor: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(8),
          child: child,
        ),
      );
    },
  );
}

class ReorderGrip extends StatelessWidget {
  const ReorderGrip({super.key, required this.index, required this.label});

  final int index;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(
      index: index,
      child: Tooltip(
        message: label,
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Semantics(
            button: true,
            label: label,
            hint: 'Arrastra para cambiar el orden',
            child: const GripDots(),
          ),
        ),
      ),
    );
  }
}

class ReorderAccessibilityMenu extends StatelessWidget {
  const ReorderAccessibilityMenu({
    super.key,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ReorderAction>(
      tooltip: 'Mover',
      icon: const Icon(Icons.more_vert),
      enabled: onMoveUp != null || onMoveDown != null,
      onSelected: (action) {
        switch (action) {
          case _ReorderAction.up:
            onMoveUp?.call();
          case _ReorderAction.down:
            onMoveDown?.call();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _ReorderAction.up,
          enabled: onMoveUp != null,
          child: const Text('Mover arriba'),
        ),
        PopupMenuItem(
          value: _ReorderAction.down,
          enabled: onMoveDown != null,
          child: const Text('Mover abajo'),
        ),
      ],
    );
  }
}

enum _ReorderAction { up, down }

class GripDots extends StatelessWidget {
  const GripDots({super.key});

  @override
  Widget build(BuildContext context) {
    final color = context.appColors.textSecondary;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _GripDotRow(color: color),
          const SizedBox(height: 4),
          _GripDotRow(color: color),
        ],
      ),
    );
  }
}

class _GripDotRow extends StatelessWidget {
  const _GripDotRow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          if (i < 2) const SizedBox(width: 4),
        ],
      ],
    );
  }
}
