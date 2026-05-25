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
        return HomeShell(
          repository: repository,
          user: user,
          themeMode: themeMode,
          onThemeModeChanged: onThemeModeChanged,
        );
      },
    );
  }
}

extension AppUserUiX on AppUser {
  String get firstName {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return 'Atleta';
    return trimmed.split(RegExp(r'\s+')).first;
  }
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
  int _tab = 0;
  late List<WorkoutExercise> _workout;
  String _sessionMode = 'Fuerza';
  String? _lastInviteCode;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _workout = seedWorkout();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeDashboard(
        user: widget.user,
        repository: widget.repository,
        inviteCode: _lastInviteCode,
        notice: _notice,
        onInviteCreated: (code) => setState(() => _lastInviteCode = code),
        onNotice: (notice) => setState(() => _notice = notice),
        selectedSessionMode: _sessionMode,
        onSessionModeSelected: _selectSessionMode,
        onStartWorkout: () => _startWorkout(_sessionMode),
        onOpenCalendar: () => _openCalendar(context),
      ),
      TrainScreen(
        user: widget.user,
        repository: widget.repository,
        sessionMode: _sessionMode,
        exercises: _workout,
        onExercisesChanged: (items) => setState(() => _workout = items),
        onOpenLibrary: () => setState(() => _tab = 3),
      ),
      ProgressScreen(
        user: widget.user,
        repository: widget.repository,
        exercises: _workout,
        onOpenCalendar: () => _openCalendar(context),
      ),
      LibraryScreen(
        user: widget.user,
        repository: widget.repository,
        exercises: _workout,
        onExercisesChanged: (items) => setState(() => _workout = items),
      ),
      ProfileScreen(
        user: widget.user,
        repository: widget.repository,
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
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
      builder: (_) => const SessionCalendarSheet(),
    );
  }

  void _selectSessionMode(String mode) {
    _startWorkout(mode);
  }

  void _startWorkout(String mode) {
    setState(() {
      _sessionMode = mode;
      _tab = 1;
    });
  }
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
    required this.onSessionModeSelected,
    required this.onStartWorkout,
    required this.onOpenCalendar,
  });

  final AppUser user;
  final AgujetasRepository repository;
  final String? inviteCode;
  final String? notice;
  final ValueChanged<String> onInviteCreated;
  final ValueChanged<String> onNotice;
  final String selectedSessionMode;
  final ValueChanged<String> onSessionModeSelected;
  final VoidCallback onStartWorkout;
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
          : 'Hola, ${widget.user.firstName}',
      user: widget.user,
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
          const WeeklySummaryCard(),
          SessionModeSelector(
            selectedMode: widget.selectedSessionMode,
            onSelected: widget.onSessionModeSelected,
          ),
          RecommendedWorkoutCard(onStart: widget.onStartWorkout),
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
            busy: _busy,
            inviteCode: widget.inviteCode,
            onCreateInvite: _createInvite,
          )
        else
          _AthletePanel(
            controller: _inviteController,
            busy: _busy,
            onAcceptInvite: _acceptInvite,
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
    required this.busy,
    required this.inviteCode,
    required this.onCreateInvite,
  });

  final AppUser user;
  final AgujetasRepository repository;
  final bool busy;
  final String? inviteCode;
  final VoidCallback onCreateInvite;

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
                      (client) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(client.clientName),
                        subtitle: const Text(
                          'Rutinas, tareas, schedules y metas',
                        ),
                        trailing: const Icon(Icons.chevron_right),
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
}

class _AthletePanel extends StatelessWidget {
  const _AthletePanel({
    required this.controller,
    required this.busy,
    required this.onAcceptInvite,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onAcceptInvite;

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
      ],
    );
  }
}

class WeeklySummaryCard extends StatelessWidget {
  const WeeklySummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    const days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return DashboardCard(
      icon: Icons.calendar_month_outlined,
      title: 'Resumen semanal',
      subtitle: '3 sesiones previstas, 2 completadas y una recomendada hoy.',
      action: _SoftChip(
        label: 'Plan Pro',
        color: colors.amber,
        background: colors.amberContainer.withValues(alpha: 0.45),
      ),
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

class RecommendedWorkoutCard extends StatelessWidget {
  const RecommendedWorkoutCard({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DashboardCard(
      icon: Icons.fitness_center,
      title: 'Empuje A',
      subtitle: 'Pecho, hombro y tríceps',
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
                  label: '6 ejercicios',
                ),
              ),
              Expanded(
                child: _InlineMeta(icon: Icons.schedule, label: '~55 min'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Iniciar entrenamiento'),
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

class TrainScreen extends StatelessWidget {
  const TrainScreen({
    super.key,
    required this.user,
    required this.repository,
    required this.sessionMode,
    required this.exercises,
    required this.onExercisesChanged,
    required this.onOpenLibrary,
  });

  final AppUser user;
  final AgujetasRepository repository;
  final String sessionMode;
  final List<WorkoutExercise> exercises;
  final ValueChanged<List<WorkoutExercise>> onExercisesChanged;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Entrenar · $sessionMode',
      user: user,
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
          onSelected: onOpenLibrary,
        ),
      ],
      trailing: FilledButton.icon(
        onPressed: () async {
          await repository.saveSession(user: user, exercises: exercises);
          if (!kIsWeb) {
            await NotificationService.showSessionSaved();
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sesión guardada en Firebase')),
            );
          }
        },
        icon: const Icon(Icons.check),
        label: const Text('Guardar'),
      ),
      children: [
        _SessionIntentCard(mode: sessionMode),
        const CompactTimers(),
        CurrentSetLogger(
          exercise: exercises.isEmpty ? null : exercises.first,
          onRestTimer: () async {
            if (!kIsWeb) {
              await NotificationService.scheduleRestFinished(
                const Duration(seconds: 90),
              );
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Alerta de descanso programada en 01:30'),
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
          itemCount: exercises.length,
          onReorder: (oldIndex, newIndex) {
            final next = [...exercises];
            final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
            final item = next.removeAt(oldIndex);
            next.insert(target, item);
            onExercisesChanged(next);
          },
          itemBuilder: (context, index) {
            final exercise = exercises[index];
            return ExerciseCard(
              key: ValueKey(exercise.id),
              index: index,
              exercise: exercise,
              onChanged: (updated) {
                final next = [...exercises];
                next[index] = updated;
                onExercisesChanged(next);
              },
              onMoveUp: index == 0
                  ? null
                  : () {
                      final next = [...exercises];
                      final item = next.removeAt(index);
                      next.insert(index - 1, item);
                      onExercisesChanged(next);
                      HapticFeedback.selectionClick();
                    },
              onMoveDown: index == exercises.length - 1
                  ? null
                  : () {
                      final next = [...exercises];
                      final item = next.removeAt(index);
                      next.insert(index + 1, item);
                      onExercisesChanged(next);
                      HapticFeedback.selectionClick();
                    },
            );
          },
        ),
      ],
    );
  }
}

class _SessionIntentCard extends StatelessWidget {
  const _SessionIntentCard({required this.mode});

  final String mode;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
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
                Text(
                  'Modo $mode',
                  style: Theme.of(context).textTheme.titleMedium,
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
    required this.onChanged,
    this.onMoveUp,
    this.onMoveDown,
  });

  final int index;
  final WorkoutExercise exercise;
  final ValueChanged<WorkoutExercise> onChanged;
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
  const SetEditor({super.key, required this.set, required this.onChanged});

  final WorkoutSet set;
  final ValueChanged<WorkoutSet> onChanged;

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
    required this.repository,
  });

  final AppUser user;
  final AgujetasRepository repository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BodyWeightEntry>>(
      stream: repository.watchBodyWeights(user.uid),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <BodyWeightEntry>[];
        final latest = entries.isEmpty ? null : entries.first;
        return DashboardCard(
          icon: Icons.monitor_weight_outlined,
          title: 'Peso corporal',
          subtitle: latest == null
              ? 'Sin registros todavía. Activa alertas y carga tu primer peso.'
              : '${latest.weightKg.toStringAsFixed(1)} kg registrados recientemente',
          action: FilledButton(
            onPressed: () => _openWeightSheet(context),
            child: const Text('Registrar'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (entries.length >= 2)
                _ProgressBar(
                  value: (entries.first.weightKg / entries[1].weightKg).clamp(
                    0.75,
                    1.25,
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  if (!kIsWeb) {
                    await NotificationService.scheduleBodyWeightReminder(
                      hour: 9,
                      minute: 0,
                    );
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Alerta diaria de peso programada 09:00'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Alertarme cada mañana'),
              ),
            ],
          ),
        );
      },
    );
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
    await repository.saveBodyWeight(
      user: user,
      entry: BodyWeightEntry(
        id: const Uuid().v4(),
        userId: user.uid,
        weightKg: weight,
        recordedAt: DateTime.now(),
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

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({
    super.key,
    required this.user,
    required this.repository,
    required this.exercises,
    required this.onOpenCalendar,
  });

  final AppUser user;
  final AgujetasRepository repository;
  final List<WorkoutExercise> exercises;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final workingSets = exercises
        .expand((exercise) => exercise.sets)
        .where((set) => set.setType != SetType.warmup)
        .toList();
    final volume = workingSets.fold<double>(
      0,
      (sum, set) =>
          sum +
          set.segments.fold<double>(
            0,
            (subtotal, segment) => subtotal + segment.weightKg * segment.reps,
          ),
    );
    return AppScaffold(
      title: 'Progreso',
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
        const SectionHeader(
          title: 'Rendimiento',
          subtitle: 'Volumen, consistencia y calidad de series.',
        ),
        Row(
          children: [
            Expanded(
              child: MetricCard(label: 'Semana', value: '3/5'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricCard(label: 'Mejor racha', value: '12 d'),
            ),
          ],
        ),
        DashboardCard(
          icon: Icons.monitor_weight_outlined,
          title: 'Volumen efectivo',
          subtitle: '${volume.round()} kg-reps sin contar calentamientos',
          child: _ProgressBar(value: workingSets.isEmpty ? 0 : 0.68),
        ),
        DashboardCard(
          icon: Icons.timeline_outlined,
          title: 'Dropsets registrados',
          subtitle:
              '${workingSets.where((set) => set.setType == SetType.dropset).length} series con reducción de peso',
          child: const _ProgressBar(value: 0.42),
        ),
        BodyWeightCard(user: user, repository: repository),
        DashboardCard(
          icon: Icons.calendar_month_outlined,
          title: 'Calendario',
          subtitle:
              'Schedules y metas asignadas viven acá, no en configuración.',
          onTap: onOpenCalendar,
          action: Icon(
            Icons.chevron_right,
            color: context.appColors.primaryStrong,
          ),
        ),
      ],
    );
  }
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.user,
    required this.repository,
    required this.exercises,
    required this.onExercisesChanged,
  });

  final AppUser user;
  final AgujetasRepository repository;
  final List<WorkoutExercise> exercises;
  final ValueChanged<List<WorkoutExercise>> onExercisesChanged;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final Future<List<ExerciseCatalogEntry>> _catalogFuture =
      _loadCatalogSnapshot();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Biblioteca',
      menuActions: [
        AppMenuAction(
          icon: Icons.search,
          label: 'Catálogo',
          selected: true,
          onSelected: () {},
        ),
        AppMenuAction(
          icon: Icons.add_circle_outline,
          label: 'Crear ejercicio',
          onSelected: _openCustomExerciseSheet,
        ),
      ],
      children: [
        TextField(
          onChanged: (value) => setState(() => _query = value.trim()),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Buscar ejercicio, músculo o rutina',
            suffixIcon: IconButton(
              tooltip: 'Filtros',
              onPressed: () {},
              icon: const Icon(Icons.tune),
            ),
          ),
        ),
        DashboardCard(
          icon: Icons.add_circle_outline,
          title: 'Ejercicio personalizado',
          subtitle:
              'Crea un ejercicio con 3 series predeterminadas y asócialo a una imagen local o del repositorio.',
          action: FilledButton(
            onPressed: _openCustomExerciseSheet,
            child: const Text('Crear'),
          ),
        ),
        DashboardCard(
          icon: Icons.bookmarks_outlined,
          title: 'Rutina base',
          subtitle:
              '${widget.exercises.length} ejercicios listos para editar y asignar',
          action: FilledButton(
            onPressed: () async {
              final routine = RoutineTemplate(
                id: const Uuid().v4(),
                ownerId: widget.user.uid,
                title: 'Rutina base Agujetas',
                exercises: widget.exercises,
              );
              await widget.repository.saveRoutineTemplate(
                owner: widget.user,
                routine: routine,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rutina guardada')),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ),
        StreamBuilder<List<ExerciseCatalogEntry>>(
          stream: widget.repository.watchCustomExercises(widget.user.uid),
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <ExerciseCatalogEntry>[];
            if (items.isEmpty) return const SizedBox.shrink();
            return DashboardCard(
              icon: Icons.auto_awesome_motion_outlined,
              title: 'Tus ejercicios',
              subtitle: '${items.length} ejercicios personalizados',
              child: Column(
                children: [
                  for (final item in items.take(5))
                    _CatalogTile(
                      item: item,
                      onAdd: () => _addExercise(item.toWorkoutExercise()),
                    ),
                ],
              ),
            );
          },
        ),
        FutureBuilder<List<ExerciseCatalogEntry>>(
          future: _catalogFuture,
          builder: (context, snapshot) {
            final catalog = snapshot.data ?? const <ExerciseCatalogEntry>[];
            final filtered = _filterCatalog(catalog).take(8).toList();
            return DashboardCard(
              icon: Icons.dataset_outlined,
              title: 'Catálogo importado',
              subtitle:
                  '${catalog.length} ejercicios desde tus JSON y el catálogo migrado.',
              child: Column(
                children: [
                  for (final item in filtered)
                    _CatalogTile(
                      item: item,
                      onAdd: () => _addExercise(item.toWorkoutExercise()),
                    ),
                ],
              ),
            );
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
            return Card(
              key: ValueKey('library-${exercise.id}'),
              child: ListTile(
                leading: ReorderGrip(
                  index: index,
                  label: 'Reordenar ${exercise.name}',
                ),
                title: Text(exercise.name),
                subtitle: Text(
                  '${exercise.muscleGroup} - ${exercise.isUnilateral ? 'unilateral' : 'bilateral'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExerciseImageBadge(
                      exerciseId: exercise.id,
                      name: exercise.name,
                      muscleGroup: exercise.muscleGroup,
                      imageUri: exercise.imageUri,
                    ),
                    ReorderAccessibilityMenu(
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
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  List<ExerciseCatalogEntry> _filterCatalog(
    List<ExerciseCatalogEntry> catalog,
  ) {
    if (_query.isEmpty) {
      return catalog.where((item) => item.usageCount > 0).toList();
    }
    final normalized = _query.toLowerCase();
    return catalog
        .where(
          (item) =>
              item.name.toLowerCase().contains(normalized) ||
              item.muscleGroup.toLowerCase().contains(normalized),
        )
        .toList();
  }

  void _addExercise(WorkoutExercise exercise) {
    widget.onExercisesChanged([...widget.exercises, exercise]);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${exercise.name} agregado a la rutina')),
    );
  }

  Future<void> _openCustomExerciseSheet() async {
    final exercise = await showModalBottomSheet<ExerciseCatalogEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CustomExerciseSheet(catalogFuture: _catalogFuture),
    );
    if (exercise == null) return;
    await widget.repository.saveCustomExercise(
      owner: widget.user,
      exercise: exercise,
    );
    _addExercise(exercise.toWorkoutExercise());
  }

  static Future<List<ExerciseCatalogEntry>> _loadCatalogSnapshot() async {
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
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({required this.item, required this.onAdd});

  final ExerciseCatalogEntry item;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ExerciseImageBadge(
        exerciseId: item.id,
        name: item.name,
        muscleGroup: item.muscleGroup,
        imageUri: item.imageUri,
      ),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${item.muscleGroup}${item.usageCount > 0 ? ' - usado ${item.usageCount}x' : ''}',
      ),
      trailing: IconButton(
        tooltip: 'Agregar',
        onPressed: onAdd,
        icon: const Icon(Icons.add_circle_outline),
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
  const CustomExerciseSheet({super.key, required this.catalogFuture});

  final Future<List<ExerciseCatalogEntry>> catalogFuture;

  @override
  State<CustomExerciseSheet> createState() => _CustomExerciseSheetState();
}

class _CustomExerciseSheetState extends State<CustomExerciseSheet> {
  final _nameController = TextEditingController();
  final _muscleController = TextEditingController(text: 'General');
  String? _imageUri;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nuevo ejercicio',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _muscleController,
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
                  icon: const Icon(Icons.photo_library_outlined),
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
            label: const Text('Crear con 3 series'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickGalleryImage() async {
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
        id: 'custom_${const Uuid().v4()}',
        name: name,
        muscleGroup: _muscleController.text.trim().isEmpty
            ? 'General'
            : _muscleController.text.trim(),
        imageUri: _imageUri,
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
    required this.onThemeModeChanged,
  });

  final AppUser user;
  final AgujetasRepository repository;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

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
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.appColors.surface,
            border: Border.all(color: context.appColors.divider),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              BrandMark(size: 72, dark: dark),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agujetas',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'Cuenta comercial lista para Android e iOS',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        DashboardCard(
          icon: Icons.account_circle_outlined,
          title: user.displayName,
          subtitle: '${user.email}\nRol activo: ${user.activeRole.label}',
        ),
        DashboardCard(
          icon: Icons.palette_outlined,
          title: 'Apariencia',
          subtitle: 'Sistema / Claro / Oscuro',
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
        FilledButton.tonalIcon(
          onPressed: repository.signOut,
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
        ),
      ],
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('La compra Pro se conectará al checkout.'),
                ),
              );
            },
            child: Text(isDemo ? 'Activar Pro demo' : 'Ver planes'),
          ),
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
  const CompactTimers({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: MetricCard(label: 'Tiempo total', value: '00:00'),
        ),
        SizedBox(width: 10),
        Expanded(
          child: MetricCard(label: 'Descanso', value: '02:00'),
        ),
      ],
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
    this.menuActions = const [],
  });

  final String title;
  final AppUser? user;
  final Widget? trailing;
  final List<AppMenuAction> menuActions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.appColors;
    return Column(
      children: [
        Container(
          height: 64,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontSize: 16,
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
        height: 80,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
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
            width: 42,
            height: 28,
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
