import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/assignment.dart';
import '../models/badge.dart' as badge_model;
import '../models/task.dart';
import '../models/user.dart';
import '../providers/app_provider.dart';
import '../services/celebration_service.dart';
import '../services/gamification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/charts.dart';
import '../widgets/confetti.dart';
import '../widgets/duo_widgets.dart';
import '../widgets/empty_state.dart';
import '../widgets/progress_widgets.dart';
import '../widgets/user_avatar.dart';
import '../widgets/section_header.dart';
import 'home_shell.dart' show HomeTabs;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late AppProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<AppProvider>();
    _provider.addListener(_onChange);
  }

  @override
  void dispose() {
    _provider.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  bool _cumpleLanzado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lanzarCumpleSiAplica();
  }

  /// Si el usuario actual cumple años hoy, lanza confeti y suena una vez al día.
  Future<void> _lanzarCumpleSiAplica() async {
    if (_cumpleLanzado) return;
    final user = context.read<AppProvider>().usuarioActual;
    if (user == null || !user.esCumpleanosHoy) return;
    final prefs = await SharedPreferences.getInstance();
    final hoy = DateTime.now();
    final key = 'hq_cumple_${hoy.year}-${hoy.month}-${hoy.day}';
    if (prefs.getBool(key) == true) {
      _cumpleLanzado = true;
      return;
    }
    _cumpleLanzado = true;
    await prefs.setBool(key, true);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        lanzarConfeti(context);
        CelebrationService.instance.success();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();
    final user = app.usuarioActual;
    if (user == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(title: const Text('HogarQuest')),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: user.esAdmin
            ? _AdminDashboard(app: app)
            : _IntegranteDashboard(app: app, user: user),
      ),
    );
  }
}

/// Banner festivo que aparece en el inicio cuando es el cumpleaños del
/// usuario actual. Acompaña el confeti y el sonido de celebración.
class _CumpleanosBanner extends StatelessWidget {
  final String nombre;
  const _CumpleanosBanner({required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF4B4B), Color(0xFFFFD900)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Text('🎉🎂', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '¡Feliz cumpleaños, $nombre!',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// INTEGRANTE
// =====================================================================
class _IntegranteDashboard extends StatefulWidget {
  final AppProvider app;
  final User user;

  const _IntegranteDashboard({required this.app, required this.user});

  @override
  State<_IntegranteDashboard> createState() => _IntegranteDashboardState();
}

class _IntegranteDashboardState extends State<_IntegranteDashboard> {
  List<(Task, Assignment)> _tareas = const [];
  List<int> _insigniasIds = const [];
  List<badge_model.Badge> _insignias = const [];
  List<(DateTime, int)> _puntosPorDia = const [];
  List<(Task, Assignment)> _hoy = const [];
  List<(DateTime, int)> _puntosGlobal84 = const [];
  bool _cargando = true;

  Future<void> _cargar() async {
    final f = await Future.wait([
      widget.app.tareasConAsignacionDe(widget.user.id!),
      widget.app.insigniasDe(widget.user.id!),
      widget.app.listarInsignias(),
      widget.app.puntosPorDia(widget.user.id!, dias: 30),
      widget.app.tareasPendientesDeHoy(widget.user.id!),
      widget.app.puntosPorDiaGlobal(dias: 84),
    ]);
    if (!mounted) return;
    setState(() {
      _tareas = f[0] as List<(Task, Assignment)>;
      _insigniasIds = f[1] as List<int>;
      _insignias = f[2] as List<badge_model.Badge>;
      _puntosPorDia = f[3] as List<(DateTime, int)>;
      _hoy = f[4] as List<(Task, Assignment)>;
      _puntosGlobal84 = f[5] as List<(DateTime, int)>;
      _cargando = false;
    });
  }

  void _onCambio() {
    if (mounted) _cargar();
  }

  @override
  void initState() {
    super.initState();
    widget.app.addListener(_onCambio);
    _cargar();
  }

  @override
  void dispose() {
    widget.app.removeListener(_onCambio);
    super.dispose();
  }

  void _irATareas() => HomeTabs.index.value = 1;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    final tareas = _tareas;
    final insigniasIds = _insigniasIds;
    final insignias = _insignias;
    final puntosPorDia = _puntosPorDia;
    final hoy = _hoy;
    final puntosGlobal84 = _puntosGlobal84;

    final pendientes = tareas
        .where((t) => !t.$2.completada)
        .toList();

    final progreso = GamificationService.progresoNivel(user.puntos, user.nivel);
    final restantes =
        GamificationService.puntosParaSiguiente(user.puntos, user.nivel);

    return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (user.esCumpleanosHoy)
                  _CumpleanosBanner(nombre: user.nombre),
                if (user.esCumpleanosHoy) const SizedBox(height: 16),
                if (hoy.isNotEmpty)
                  _RecordatorioHoy(tareas: hoy, onTap: _irATareas),
                const SizedBox(height: 16),
                _LeccionDelDiaCard(
                  user: user,
                  progresoNivel: progreso,
                  pendientes: pendientes.length,
                  onStart: _irATareas,
                ),
                const SizedBox(height: 16),
                DuoCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.military_tech,
                              size: 20, color: AppColors.amarillo),
                          const SizedBox(width: 6),
                          Text(
                            'Nivel ${user.nivel} · '
                            '${GamificationService.nombreNivel(user.nivel)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          const Spacer(),
                          if (restantes > 0)
                            Text(
                              '$restantes pts para subir',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.grisMedio),
                            )
                          else
                            const Text('¡Nivel máximo!',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.verdeOscuro)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SegmentedProgressBar(
                        progress: progreso,
                        color: AppColors.amarillo,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _RachaPill(
                              icon: Icons.local_fire_department,
                              value: user.racha,
                              label: 'días de racha'),
                          const SizedBox(width: 8),
                          _RachaPill(
                              icon: Icons.stars,
                              value: user.puntos,
                              label: 'XP acumulado'),
                        ],
                      ),
                    ],
                  ),
                ),
                SectionHeader(title: 'Mi actividad (30 días)'),
                DuoCard(
                  child: BarChart(
                    data: puntosPorDia,
                    labelFor: (d) => d.day.toString(),
                    highlightIndex: puntosPorDia.length - 1,
                  ),
                ),
                SectionHeader(title: 'Esta semana'),
                DuoCard(
                  child: Builder(
                    builder: (context) {
                      final h = DateTime.now();
                      final hd = DateTime(h.year, h.month, h.day);
                      final ini = hd.subtract(Duration(days: hd.weekday - 1));
                      final sem = puntosGlobal84
                          .where((d) => !d.$1.isBefore(ini))
                          .fold<int>(0, (a, d) => a + d.$2);
                      final activos = puntosGlobal84
                          .where((d) => !d.$1.isBefore(ini) && d.$2 > 0)
                          .length;
                      return Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sem.toString(),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.verde,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'puntos esta semana',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.grisMedio,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$activos / 7',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.azul,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'días activos',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.grisMedio,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SectionHeader(title: 'Constancia (12 semanas)'),
                DuoCard(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: StreakHeatmap(
                      data: puntosGlobal84,
                      semanas: 12,
                    ),
                  ),
                ),
                SectionHeader(
                  title: 'Mis tareas',
                  trailing: TextButton(
                    onPressed: _irATareas,
                    child: const Text('Ver todas'),
                  ),
                ),
                if (pendientes.isEmpty)
                  const EmptyState(
                    icon: Icons.task_alt,
                    message: '¡Sin tareas pendientes!',
                    hint: 'Revisa el ranking y las recompensas.',
                  )
                else
                  ...pendientes.take(3).map(
                        (t) => _MiniTaskCard(
                            titulo: t.$1.titulo,
                            puntos: t.$1.puntos,
                            dificultad: t.$1.dificultad),
                      ),
                SectionHeader(title: 'Insignias'),
                if (insigniasIds.isEmpty)
                  const Text('Completa tareas para ganar insignias.',
                      style: TextStyle(color: AppColors.grisMedio))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final b in insignias)
                        if (insigniasIds.contains(b.id))
                          Chip(
                            avatar: const Icon(Icons.emoji_events),
                            label: Text(b.nombre),
                            backgroundColor:
                                AppColors.amarillo.withValues(alpha: 0.15),
                          ),
                    ],
                  ),
              ],
            ),
          ),
        );
  }
}

// =====================================================================
// ADMIN
// =====================================================================
class _AdminDashboard extends StatefulWidget {
  final AppProvider app;

  const _AdminDashboard({required this.app});

  @override
  State<_AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<_AdminDashboard> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _keyAprobaciones = GlobalKey();
  Map<String, Object?>? _est;
  List<(Task, Assignment, User)> _pendientes = const [];
  List<(DateTime, int)> _puntosPorDia = const [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    widget.app.addListener(_onCambio);
    _cargar();
  }

  void _onCambio() {
    if (mounted) _cargar();
  }

  Future<void> _cargar() async {
    final futuros = await Future.wait([
      widget.app.estadisticas(),
      widget.app.pendientesDeAprobacion(),
      widget.app.listarIntegrantes(),
      widget.app.puntosPorDiaGlobal(dias: 30),
    ]);
    if (!mounted) return;
    setState(() {
      _est = futuros[0] as Map<String, Object?>;
      _pendientes = futuros[1] as List<(Task, Assignment, User)>;
      _puntosPorDia = futuros[3] as List<(DateTime, int)>;
      _cargando = false;
    });
  }

  void _irATareas() => HomeTabs.index.value = 1;
  void _irAPremios() => HomeTabs.index.value = 4;
  void _irAInicio() {
    HomeTabs.index.value = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keyAprobaciones.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 400));
      }
    });
  }

  @override
  void dispose() {
    widget.app.removeListener(_onCambio);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    if (_cargando && _est == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final est = _est!;
    final pendientes = _pendientes;
    final puntosPorDia = _puntosPorDia;

    final tareasActivas = (est['tareasActivas'] as int?) ?? 0;
    final aprobadas = (est['aprobadas'] as int?) ?? 0;
    final totalPuntos = (est['totalPuntos'] as int?) ?? 0;
    final integrantes = (est['usuarios'] as int?) ?? 0;

    return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              children: [
                if (app.usuarioActual?.esCumpleanosHoy ?? false)
                  _CumpleanosBanner(nombre: app.usuarioActual!.nombre),
                if (app.usuarioActual?.esCumpleanosHoy ?? false)
                  const SizedBox(height: 16),
                const _AdminHeader(),
                const SizedBox(height: 16),
                if (pendientes.isNotEmpty) ...[
                  _RecordatorioAprobaciones(
                      cantidad: pendientes.length, onTap: _irAInicio),
                  const SizedBox(height: 16),
                ],
                // ===== Las 4 tarjetas compactas y responsivas =====
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = constraints.maxWidth >= 560 ? 4 : 2;
                    final anchoPorCard =
                        (constraints.maxWidth - (cols - 1) * 10) / cols;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        mainAxisExtent: anchoPorCard <= 130 ? 132 : 120,
                      ),
                      itemCount: 4,
                      itemBuilder: (context, i) {
                        final items = [
                          (
                            icon: Icons.group,
                            label: 'Integrantes',
                            value: integrantes.toString(),
                            color: AppColors.azul,
                          ),
                          (
                            icon: Icons.fact_check,
                            label: 'Activas',
                            value: tareasActivas.toString(),
                            color: AppColors.verde,
                          ),
                          (
                            icon: Icons.task_alt,
                            label: 'Aprobadas',
                            value: aprobadas.toString(),
                            color: AppColors.amarillo,
                          ),
                          (
                            icon: Icons.stars,
                            label: 'XP total',
                            value: totalPuntos.toString(),
                            color: AppColors.morado,
                          ),
                        ];
                        final item = items[i];
                        return _StatCard(
                          icon: item.icon,
                          label: item.label,
                          value: item.value,
                          color: item.color,
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                // ===== Acciones del admin =====
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.person_add_alt,
                        label: 'Integrantes',
                        onTap: () => Navigator.of(context)
                            .pushNamed('/admin/usuarios'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.playlist_add,
                        label: 'Nueva tarea',
                        onTap: _irATareas,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.card_giftcard,
                        label: 'Premios',
                        onTap: _irAPremios,
                      ),
                    ),
                  ],
                ),
                SectionHeader(title: 'Actividad familiar (30 días)'),
                DuoCard(
                  child: BarChart(
                    data: puntosPorDia,
                    labelFor: (d) => d.day.toString(),
                    highlightIndex: puntosPorDia.length - 1,
                  ),
                ),
                SectionHeader(key: _keyAprobaciones, title: 'Pendientes de aprobación'),
                if (pendientes.isEmpty)
                  const EmptyState(
                    icon: Icons.hourglass_empty,
                    message: 'Nada por aprobar',
                    hint: 'Las tareas completadas aparecerán aquí.',
                  )
                else
                  ...pendientes.map(
                    (p) => DuoCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.verdeFondo,
                          child: Text(
                            p.$3.nombre.characters.first.toUpperCase(),
                            style:
                                const TextStyle(color: AppColors.verdeOscuro),
                          ),
                        ),
                        title: Text(p.$1.titulo),
                        subtitle: Text('${p.$3.nombre} · +${p.$1.puntos} pts'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.close, color: AppColors.rojo),
                              tooltip: 'Rechazar',
                              onPressed: () =>
                                  app.rechazarAsignacion(p.$2.id!),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check,
                                  color: AppColors.verde),
                              tooltip: 'Aprobar',
                              onPressed: () {
                                 lanzarConfeti(context);
                                 unawaited(CelebrationService.instance.success());
                                 app.aprobarAsignacion(p.$2.id!);
                               },
                             ),
                           ],
                         ),
                       ),
                     ),
                   ),
              ],
            ),
          ),
        );
  }
}

// =====================================================================
// WIDGETS AUXILIARES
// =====================================================================

/// Recordatorio para el admin: hay tareas completadas por aprobar.
class _RecordatorioAprobaciones extends StatelessWidget {
  final int cantidad;
  final VoidCallback onTap;

  const _RecordatorioAprobaciones(
      {required this.cantidad, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.moradoClaro.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.assignment_turned_in,
                  color: AppColors.morado, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tienes $cantidad tarea${cantidad == 1 ? '' : 's'} completada${cantidad == 1 ? '' : 's'} por aprobar',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.grisOscuro,
                      fontSize: 14),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.grisMedio),
            ],
          ),
        ),
      ),
    );
  }
}

/// Recordatorio de tareas pendientes de HOY para el integrante.
class _RecordatorioHoy extends StatelessWidget {
  final List<(Task, Assignment)> tareas;
  final VoidCallback onTap;

  const _RecordatorioHoy({required this.tareas, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.amarillo.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.notifications_active,
                  color: AppColors.verdeOscuro, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¡Tienes ${tareas.length} tarea${tareas.length == 1 ? '' : 's'} pendiente${tareas.length == 1 ? '' : 's'} hoy!',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.grisOscuro,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tareas.map((t) => t.$1.titulo).take(3).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.grisMedio),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.grisMedio),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta principal estilo "lección del día" de Duolingo.
class _LeccionDelDiaCard extends StatelessWidget {
  final User user;
  final double progresoNivel;
  final int pendientes;
  final VoidCallback onStart;

  const _LeccionDelDiaCard({
    required this.user,
    required this.progresoNivel,
    required this.pendientes,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.linea, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              UserAvatar(
                user: user,
                radius: 30,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¡Hola, ${user.nombre}!',
                      style: const TextStyle(
                        color: AppColors.grisOscuro,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pendientes > 0
                          ? '$pendientes tareas te esperan'
                          : 'Todo listo por hoy 🎉',
                      style: const TextStyle(
                          color: AppColors.grisMedio, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ProgressRing(
            progress: progresoNivel,
            color: AppColors.verde,
            trackColor: AppColors.verdeFondo,
            strokeWidth: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('NIVEL',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.grisMedio)),
                Text(
                  '${user.nivel}',
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.grisOscuro),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DuoButton(
            label: pendientes > 0 ? 'Comenzar tareas' : 'Ver recompensas',
            icon: pendientes > 0 ? Icons.rocket_launch : Icons.card_giftcard,
            onPressed: pendientes > 0
                ? onStart
                : () => HomeTabs.index.value = 4,
          ),
        ],
      ),
    );
  }
}

class _RachaPill extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;

  const _RachaPill({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.verdeFondo,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.verdeOscuro),
            const SizedBox(width: 6),
            Text(
              '$value',
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.grisOscuro),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.grisMedio),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.grisOscuro, Color(0xFF5A5A5A)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.admin_panel_settings, size: 44, color: Colors.white),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Panel del administrador',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Gestiona integrantes, tareas y premios.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DuoCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          AnimatedNumber(
            value: int.tryParse(value) ?? 0,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.grisOscuro),
          ),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.grisMedio)),
        ],
      ),
    );
  }
}

class _MiniTaskCard extends StatelessWidget {
  final String titulo;
  final int puntos;
  final String dificultad;

  const _MiniTaskCard({
    required this.titulo,
    required this.puntos,
    required this.dificultad,
  });

  Color get _dificultadColor {
    switch (dificultad.toLowerCase()) {
      case 'fácil':
      case 'facil':
        return AppColors.verde;
      case 'media':
        return AppColors.amarillo;
      default:
        return AppColors.rojo;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DuoCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          DuoIconBadge(icon: Icons.checklist, color: AppColors.azul, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  dificultad.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.grisMedio),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _dificultadColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '+$puntos',
              style: TextStyle(
                  color: _dificultadColor, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.verdeFondo,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.verdeOscuro, size: 26),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

