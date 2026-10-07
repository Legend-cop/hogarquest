import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/assignment.dart';
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
import '../widgets/hq_design.dart';
import '../widgets/icons3d.dart';
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
        onRefresh: () async {
          // Notifica al provider para que las vistas recarguen sus datos.
          app.refrescar();
          await Future<void>.delayed(const Duration(milliseconds: 400));
        },
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
          BoxShadow(
            color: Color(0x22000000),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
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
// TENDENCIA
// =====================================================================

/// Pill de tendencia "+N%" estilo referencia, comparando la última semana
/// de puntos familiares con la anterior.
class _TrendPill extends StatelessWidget {
  final List<(DateTime, int)> puntos;

  const _TrendPill({required this.puntos});

  @override
  Widget build(BuildContext context) {
    final n = puntos.length;
    if (n < 2) return const SizedBox.shrink();
    final inicio = n > 14 ? n - 14 : 0;
    final semanaActual = puntos.sublist(n >= 7 ? n - 7 : 0).fold<int>(
          0,
          (s, d) => s + d.$2,
        );
    final semanaAnterior = puntos
        .sublist(n >= 14 ? n - 14 : 0, n >= 7 ? n - 7 : inicio)
        .fold<int>(0, (s, d) => s + d.$2);

    if (semanaAnterior <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.verdeFondo,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'NUEVO',
          style: TextStyle(
            color: AppColors.verdeOscuro,
            fontWeight: FontWeight.w900,
            fontSize: 11,
          ),
        ),
      );
    }

    final cambio =
        ((semanaActual - semanaAnterior) * 100) ~/ semanaAnterior;
    final positivo = cambio >= 0;
    final color = positivo ? AppColors.verdeOscuro : AppColors.rojo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${positivo ? '+' : ''}$cambio%',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _IntegranteDashboard extends StatefulWidget {
  final AppProvider app;
  final User user;

  const _IntegranteDashboard({required this.app, required this.user});

  @override
  State<_IntegranteDashboard> createState() => _IntegranteDashboardState();
}

class _IntegranteDashboardState extends State<_IntegranteDashboard> {
  List<(Task, Assignment)> _tareas = const [];
  List<(DateTime, int)> _puntosPorDia = const [];
  List<(Task, Assignment)> _hoy = const [];
  List<(DateTime, int)> _puntosGlobal84 = const [];
  bool _cargando = true;

  Future<void> _cargar() async {
    try {
      final f = await Future.wait([
        widget.app.tareasConAsignacionDe(widget.user.id!),
        widget.app.puntosPorDia(widget.user.id!, dias: 30),
        widget.app.tareasPendientesDeHoy(widget.user.id!),
        widget.app.puntosPorDiaGlobal(dias: 84),
      ]);
      if (!mounted) return;
      setState(() {
        _tareas = f[0] as List<(Task, Assignment)>;
        _puntosPorDia = f[1] as List<(DateTime, int)>;
        _hoy = f[2] as List<(Task, Assignment)>;
        _puntosGlobal84 = f[3] as List<(DateTime, int)>;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
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

  /// ¿La tarea es del día actual? Día de la semana de hoy, o con fecha
  /// límite que vence hoy (mismo criterio que la pantalla Tareas).
  static bool _esDeHoy(Task task) {
    if (task.dia.isNotEmpty) {
      const nombres = [
        'domingo',
        'lunes',
        'martes',
        'miercoles',
        'jueves',
        'viernes',
        'sabado',
      ];
      return task.dia == nombres[DateTime.now().weekday % 7];
    }
    final fl = task.fechaLimite;
    if (fl == null) return false;
    final f = fl.toLocal();
    final now = DateTime.now();
    return f.year == now.year && f.month == now.month && f.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    final tareas = _tareas;
    final puntosPorDia = _puntosPorDia;
    final hoy = _hoy;
    final puntosGlobal84 = _puntosGlobal84;

    // Solo tareas del día actual: por día cada niño ve las suyas de hoy
    // (el admin gestiona la semana completa desde su vista).
    final pendientes = tareas
        .where((t) => !t.$2.completada && _esDeHoy(t.$1))
        .toList();

    final progreso = GamificationService.progresoNivel(user.puntos, user.nivel);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageTitle('¡Hola, ${user.nombre}! 👋'),
            if (user.esCumpleanosHoy) _CumpleanosBanner(nombre: user.nombre),
            if (user.esCumpleanosHoy) const SizedBox(height: 16),
            if (hoy.isNotEmpty) ...[
              _BannerPendientesHoy(tareas: hoy, onTap: _irATareas),
              const SizedBox(height: 12),
            ],
            _ComenzarTareasButton(
              onStart: _irATareas,
            ),
            const SizedBox(height: 12),
            _NivelCard(
              user: user,
              progresoNivel: progreso,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    'Racha',
                    '${user.racha}',
                    Icons.local_fire_department,
                    AppColors.rojoFondo,
                    iconoWidget: Flame3D(size: 34),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetricCard(
                    'XP',
                    '${user.puntos}',
                    Icons.bolt,
                    AppColors.verdeFondo,
                    iconoWidget: Bolt3D(size: 34),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _TituloSeccion('Mi progreso'),
            DuoCard(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Resumen de la semana (antes tarjeta aparte).
                    Builder(
                      builder: (context) {
                        final h = DateTime.now();
                        final hd = DateTime(h.year, h.month, h.day);
                        final ini =
                            hd.subtract(Duration(days: hd.weekday - 1));
                        final sem = puntosGlobal84
                            .where((d) => !d.$1.isBefore(ini))
                            .fold<int>(0, (a, d) => a + d.$2);
                        final activos = puntosGlobal84
                            .where(
                                (d) => !d.$1.isBefore(ini) && d.$2 > 0)
                            .length;
                        return Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$sem',
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.verde,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'puntos esta semana',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textoSuaveTema(context),
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
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.azul,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'días activos',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textoSuaveTema(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // Gráfico de actividad de los últimos 30 días.
                    BarChart(
                      data: puntosPorDia,
                      labelFor: (d) => d.day.toString(),
                      highlightIndex: puntosPorDia.length - 1,
                    ),
                    const SizedBox(height: 14),
                    // Mapa de constancia (12 semanas).
                    StreakHeatmap(data: puntosGlobal84, semanas: 12),
                  ],
                ),
              ),
            ),
            _TituloSeccion(
              'Mis tareas',
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
              ...pendientes
                  .take(3)
                  .map(
                    (t) => _MiniTaskCard(
                      titulo: t.$1.titulo,
                      puntos: t.$1.puntos,
                      dificultad: t.$1.dificultad,
                    ),
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
    try {
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  void _irATareas() => HomeTabs.index.value = 1;
  void _irAPremios() => HomeTabs.index.value = 3;
  void _irAInicio() {
    HomeTabs.index.value = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keyAprobaciones.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
        );
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
    final totalPuntos = (est['totalPuntos'] as int?) ?? 0;
    final integrantes = (est['usuarios'] as int?) ?? 0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.all(16),
          children: [
            PageTitle(
              'Inicio',
              subtitle: '¡Hola, ${app.usuarioActual?.nombre ?? 'Admin'}! 👋',
              actions: [
                _CampanaPendientes(
                  pendientes: pendientes.length,
                  onTap: _irAInicio,
                ),
              ],
            ),
            if (app.usuarioActual?.esCumpleanosHoy ?? false)
              _CumpleanosBanner(nombre: app.usuarioActual!.nombre),
            if (app.usuarioActual?.esCumpleanosHoy ?? false)
              const SizedBox(height: 16),
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
                      MetricCard(
                        'Integrantes',
                        integrantes.toString(),
                        Icons.groups,
                        AppColors.azulFondo,
                        iconoWidget: People3D(size: 34),
                      ),
                      MetricCard(
                        'Aprobaciones',
                        pendientes.length.toString(),
                        Icons.pending_actions,
                        AppColors.amarilloFondo,
                        iconoWidget: ClipboardClock3D(size: 34),
                      ),
                      MetricCard(
                        'Puntos XP',
                        totalPuntos.toString(),
                        Icons.bolt,
                        AppColors.verdeFondo,
                        iconoWidget: Bolt3D(size: 34),
                      ),
                      MetricCard(
                        'Tareas',
                        tareasActivas.toString(),
                        Icons.task_alt,
                        AppColors.rojoFondo,
                        iconoWidget: ClipboardCheck3D(size: 34),
                      ),
                    ];
                    return items[i];
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            // ===== Accesos rápidos estilo zip (OutlinedButton) =====
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.person_add_alt,
                    label: 'Integrantes',
                    onTap: () =>
                        Navigator.of(context).pushNamed('/admin/usuarios'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.playlist_add,
                    label: 'Nueva tarea',
                    onTap: _irATareas,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.card_giftcard,
                    label: 'Premios',
                    onTap: _irAPremios,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final dosColumnas = constraints.maxWidth >= 900;
                final grafico = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TituloSeccion(
                      'Actividad familiar (30 días)',
                      trailing: _TrendPill(puntos: puntosPorDia),
                    ),
                    DuoCard(
                      child: BarChart(
                        data: puntosPorDia,
                        labelFor: (d) => d.day.toString(),
                        highlightIndex: puntosPorDia.length - 1,
                      ),
                    ),
                  ],
                );
                final aprobaciones = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TituloSeccion(
                      'Pendientes de aprobación',
                      key: _keyAprobaciones,
                    ),
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
                                style: const TextStyle(
                                  color: AppColors.verdeOscuro,
                                ),
                              ),
                            ),
                            title: Text(p.$1.titulo),
                            subtitle: Text(
                              '${p.$3.nombre} · +${p.$1.puntos} pts',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: AppColors.rojo,
                                  ),
                                  tooltip: 'Rechazar',
                                  onPressed: () =>
                                      app.rechazarAsignacion(p.$2.id!),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.check,
                                    color: AppColors.verde,
                                  ),
                                  tooltip: 'Aprobar',
                                  onPressed: () {
                                    lanzarConfeti(context);
                                    unawaited(
                                      CelebrationService.instance.success(),
                                    );
                                    app.aprobarAsignacion(p.$2.id!);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
                if (!dosColumnas) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      grafico,
                      const SizedBox(height: 16),
                      aprobaciones,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: grafico),
                    const SizedBox(width: 16),
                    Expanded(child: aprobaciones),
                  ],
                );
              },
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

/// Banner "¡Tienes N tareas pendientes hoy!" exacto del zip: CardBox amarillo
/// con un solo texto w900 (conserva el tap para saltar a las tareas).
class _BannerPendientesHoy extends StatelessWidget {
  final List<(Task, Assignment)> tareas;
  final VoidCallback onTap;

  const _BannerPendientesHoy({required this.tareas, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final n = tareas.length;
    return CardBox(
      color: AppColors.amarilloFondo,
      child: InkWell(
        onTap: onTap,
        child: Text(
          '¡Tienes $n tarea${n == 1 ? '' : 's'} pendiente${n == 1 ? '' : 's'} hoy!',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

/// Título de sección estilo referencia: 18 w900 con aire superior.
class _TituloSeccion extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _TituloSeccion(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Campana de notificaciones con punto rojo (acciones del PageTitle):
/// baja a la sección de aprobaciones pendientes.
class _CampanaPendientes extends StatelessWidget {
  final int pendientes;
  final VoidCallback onTap;

  const _CampanaPendientes({required this.pendientes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: pendientes > 0 ? onTap : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none, size: 26),
          if (pendientes > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.rojo,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Botón grande "COMENZAR TAREAS" idéntico al zip (FilledButton.icon).
class _ComenzarTareasButton extends StatelessWidget {
  final VoidCallback onStart;

  const _ComenzarTareasButton({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onStart,
      icon: const Icon(Icons.rocket_launch),
      label: const Text('COMENZAR TAREAS'),
    );
  }
}

/// Tarjeta de nivel estilo referencia: "Nivel N - Nombre" w900, barra lisa
/// y "Te faltan N XP para subir" tenue.
class _NivelCard extends StatelessWidget {
  final User user;
  final double progresoNivel;

  const _NivelCard({
    required this.user,
    required this.progresoNivel,
  });

  @override
  Widget build(BuildContext context) {
    final restantes = GamificationService.puntosParaSiguiente(
      user.puntos,
      user.nivel,
    );
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nivel ${user.nivel} - ${GamificationService.nombreNivel(user.nivel)}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ProgressLine(progresoNivel),
          const SizedBox(height: 6),
          Text(
            restantes > 0
                ? 'Te faltan $restantes XP para subir'
                : '¡Nivel máximo!',
            style: TextStyle(
              color: restantes > 0
                  ? textoSuaveTema(context)
                  : AppColors.verdeOscuro,
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    return DuoCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '+$puntos pts · ${dificultad.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textoSuaveTema(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: textoSuaveTema(context)),
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
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
