import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uuid/uuid.dart';

import 'app_theme.dart';
import 'firebase_options.dart';
import 'models.dart';
import 'repositories.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(child: BrandMark(size: 112, dark: dark)),
              const SizedBox(height: 24),
              Text(
                'Agujetas',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Entrenamiento, rutinas y seguimiento para atletas y entrenadores.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: _loading ? null : _signIn,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.account_circle_outlined),
                label: const Text('Continuar con Google'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          AgujetasApp(repository: DemoAgujetasRepository()),
                    ),
                  );
                },
                child: const Text('Ver demo sin guardar'),
              ),
              const SizedBox(height: 12),
              Text(
                'Tus rutinas y progreso se guardan en Firebase. No usamos Storage mientras el proyecto siga sin plan pago.',
                style: Theme.of(context).textTheme.labelMedium,
                textAlign: TextAlign.center,
              ),
            ],
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
      setState(() => _error = 'No se pudo iniciar sesion: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
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
      ),
      TrainScreen(
        user: widget.user,
        repository: widget.repository,
        exercises: _workout,
        onExercisesChanged: (items) => setState(() => _workout = items),
      ),
      ProgressScreen(exercises: _workout),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Entrenar',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            label: 'Progreso',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_list_outlined),
            selectedIcon: Icon(Icons.view_list),
            label: 'Biblioteca',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
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
  });

  final AppUser user;
  final AgujetasRepository repository;
  final String? inviteCode;
  final String? notice;
  final ValueChanged<String> onInviteCreated;
  final ValueChanged<String> onNotice;

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final _inviteController = TextEditingController();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final isTrainerMode = widget.user.activeRole == AppRole.trainer;
    return AppScaffold(
      title: isTrainerMode ? 'Panel entrenador' : 'Inicio',
      user: widget.user,
      children: [
        if (widget.notice != null) InfoBanner(text: widget.notice!),
        RoleSwitcher(user: widget.user, repository: widget.repository),
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
      widget.onNotice('Codigo de invitacion creado: ${invite.code}');
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
      widget.onNotice('No se pudo aceptar el codigo: $error');
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
              ? 'Genera un codigo para vincular usuarios.'
              : 'Codigo activo: $inviteCode',
          action: FilledButton(
            onPressed: busy ? null : onCreateInvite,
            child: Text(inviteCode == null ? 'Crear codigo' : 'Crear otro'),
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
                  ? 'Aun no hay vinculaciones.'
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
              'Asigna volumen semanal, habitos, sesiones y objetivos medibles.',
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
        const DashboardCard(
          icon: Icons.bolt_outlined,
          title: 'Entrenamiento autogestionado',
          subtitle:
              'Crea rutinas, registra series, mira progreso y exporta tus datos.',
        ),
        DashboardCard(
          icon: Icons.link_outlined,
          title: 'Vincular entrenador',
          subtitle:
              'Ingresa un codigo si un entrenador te comparte rutina o schedule.',
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Codigo'),
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

class TrainScreen extends StatelessWidget {
  const TrainScreen({
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
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Entrenar',
      user: user,
      trailing: FilledButton.icon(
        onPressed: () async {
          await repository.saveSession(user: user, exercises: exercises);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sesion guardada en Firebase')),
            );
          }
        },
        icon: const Icon(Icons.check),
        label: const Text('Guardar'),
      ),
      children: [
        const CompactTimers(),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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
            );
          },
        ),
      ],
    );
  }
}

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.index,
    required this.exercise,
    required this.onChanged,
  });

  final int index;
  final WorkoutExercise exercise;
  final ValueChanged<WorkoutExercise> onChanged;

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
                ReorderableDelayedDragStartListener(
                  index: index,
                  child: const GripDots(),
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
          for (var i = 0; i < set.segments.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: SegmentEditor(
                label: i == 0 ? 'Peso principal' : 'Peso 2 / backoff',
                segment: set.segments[i],
                onChanged: (segment) {
                  final segments = [...set.segments];
                  segments[i] = segment;
                  onChanged(set.copyWith(segments: segments));
                },
                onRemove: i == 0
                    ? null
                    : () {
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

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, required this.exercises});

  final List<WorkoutExercise> exercises;

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
      children: [
        DashboardCard(
          icon: Icons.monitor_weight_outlined,
          title: 'Volumen efectivo',
          subtitle: '${volume.round()} kg-reps sin contar calentamientos',
        ),
        DashboardCard(
          icon: Icons.timeline_outlined,
          title: 'Dropsets registrados',
          subtitle:
              '${workingSets.where((set) => set.setType == SetType.dropset).length} series con reduccion de peso',
        ),
        const DashboardCard(
          icon: Icons.calendar_month_outlined,
          title: 'Calendario',
          subtitle:
              'Schedules y metas asignadas viven aca, no en configuracion.',
        ),
      ],
    );
  }
}

class LibraryScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Biblioteca',
      children: [
        DashboardCard(
          icon: Icons.bookmarks_outlined,
          title: 'Rutina base',
          subtitle:
              '${exercises.length} ejercicios listos para editar y asignar',
          action: FilledButton(
            onPressed: () async {
              final routine = RoutineTemplate(
                id: const Uuid().v4(),
                ownerId: user.uid,
                title: 'Rutina base Agujetas',
                exercises: exercises,
              );
              await repository.saveRoutineTemplate(
                owner: user,
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
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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
            return ListTile(
              key: ValueKey('library-${exercise.id}'),
              leading: ReorderableDelayedDragStartListener(
                index: index,
                child: const GripDots(),
              ),
              title: Text(exercise.name),
              subtitle: Text(
                '${exercise.muscleGroup} - ${exercise.isUnilateral ? 'unilateral' : 'bilateral'}',
              ),
              trailing: const Icon(Icons.add_circle_outline),
            );
          },
        ),
      ],
    );
  }
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
      children: [
        Center(child: BrandMark(size: 84, dark: dark)),
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
          label: const Text('Cerrar sesion'),
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
    return DashboardCard(
      icon: Icons.switch_account_outlined,
      title: 'Modo de uso',
      subtitle: 'Entrena solo o gestiona entrenados desde la misma cuenta.',
      child: SegmentedButton<AppRole>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: AppRole.normal, label: Text('Normal')),
          ButtonSegment(value: AppRole.trainer, label: Text('Entrenador')),
        ],
        selected: {user.activeRole},
        onSelectionChanged: (value) =>
            repository.setActiveRole(user, value.first),
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
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

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.children,
    this.user,
    this.trailing,
  });

  final String title;
  final AppUser? user;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                BrandMark(size: 36, dark: dark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          sliver: SliverList.list(children: children),
        ),
      ],
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

class GripDots extends StatelessWidget {
  const GripDots({super.key});

  @override
  Widget build(BuildContext context) {
    final color = context.appColors.textSecondary;
    return SizedBox(
      width: 36,
      height: 44,
      child: Center(
        child: Wrap(
          spacing: 3,
          runSpacing: 3,
          children: List.generate(
            6,
            (_) => Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}
