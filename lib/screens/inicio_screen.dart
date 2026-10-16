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
import '../widgets/hq_logo.dart';
import '../widgets/icons3d.dart';
import '../widgets/level_progress.dart';
import '../widgets/mascots.dart';
import 'navegacion_principal.dart' show ControlPestanas;

/// Fecha en mayúsculas y español: "VIERNES, 25 DE SEPTIEMBRE".
String fechaEnMayusculas([DateTime? fecha]) {
  const dias = [
    'LUNES',
    'MARTES',
    'MIÉRCOLES',
    'JUEVES',
    'VIERNES',
    'SÁBADO',
    'DOMINGO',
  ];
  const meses = [
    'ENERO',
    'FEBRERO',
    'MARZO',
    'ABRIL',
    'MAYO',
    'JUNIO',
    'JULIO',
    'AGOSTO',
    'SEPTIEMBRE',
    'OCTUBRE',
    'NOVIEMBRE',
    'DICIEMBRE',
  ];
  final f = fecha ?? DateTime.now();
  return '${dias[f.weekday - 1]}, ${f.day} DE ${meses[f.month - 1]}';
}

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
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
      body: RefreshIndicator(
        onRefresh: () async {
          app.refrescar();
          await Future<void>.delayed(const Duration(milliseconds: 400));
        },
        child: user.esAdmin
            ? _AdminHomeView(app: app)
            : _ChildHomeView(app: app, user: user),
      ),
    );
  }
}

// =====================================================================
// INICIO ADMIN — igual a AdminHomeScreen de la referencia
// =====================================================================
class _AdminHomeView extends StatefulWidget {
  final AppProvider app;
  const _AdminHomeView({required this.app});

  @override
  State<_AdminHomeView> createState() => _AdminHomeViewState();
}

class _AdminHomeViewState extends State<_AdminHomeView> {
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
        widget.app.puntosPorDiaGlobal(dias: 30),
      ]);
      if (!mounted) return;
      setState(() {
        _est = futuros[0] as Map<String, Object?>;
        _pendientes = futuros[1] as List<(Task, Assignment, User)>;
        _puntosPorDia = futuros[2] as List<(DateTime, int)>;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  /// Baja hasta la sección "Pendientes de aprobación" (la campana roja).
  void _irAprobaciones() {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final user = app.usuarioActual;
    if (user == null) return const SizedBox.shrink();
    if (_cargando && _est == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final est = _est ?? const <String, Object?>{};
    final integrantes = (est['usuarios'] as int?) ?? 0;
    final totalPuntos = (est['totalPuntos'] as int?) ?? 0;
    final tareasActivas = (est['tareasActivas'] as int?) ?? 0;
    final pendientes = _pendientes.length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Cabecera: logo + chip de XP.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const HqLogo(size: 32),
                    const SizedBox(width: 8),
                    Text(
                      'HogarQuest',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textoTema(context),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('✨', style: TextStyle(fontSize: 16)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: esOscuro(context)
                        ? AppColors.amarilloFondoOscuro
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: esOscuro(context)
                          ? AppColors.amarilloOscuro
                          : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt, color: AppColors.amarillo, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${user.puntos} XP',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.amarillo,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Fecha + saludo + campana de notificaciones.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fechaEnMayusculas(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.verde,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '¡Hola, ${user.nombre}!',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: textoTema(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: superficieTema(context),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: esOscuro(context)
                          ? Colors.white24
                          : AppColors.linea,
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.notifications_outlined,
                          color: textoTema(context),
                        ),
                        tooltip: 'Pendientes de aprobación',
                        onPressed: _irAprobaciones,
                      ),
                      if (pendientes > 0)
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: AppColors.rojo,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 4 tarjetas métricas.
            Row(
              children: [
                _MetricMini(
                  '$integrantes',
                  'INTEGRANTES',
                  azulFondoTema(context),
                  AppColors.azul,
                ),
                const SizedBox(width: 8),
                _MetricMini(
                  '$pendientes',
                  'PENDIENTES',
                  amarilloFondoTema(context),
                  AppColors.amarilloOscuro,
                ),
                const SizedBox(width: 8),
                _MetricMini(
                  '$totalPuntos',
                  'PUNTOS XP',
                  verdeFondoTema(context),
                  AppColors.verde,
                ),
                const SizedBox(width: 8),
                _MetricMini(
                  '$tareasActivas',
                  'TAREAS',
                  rosaFondoTema(context),
                  const Color(0xFFEC4899),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Accesos rápidos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textoTema(context),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickAccessCard(
                    icon: Icons.person_add_alt_1,
                    title: 'Integrantes',
                    iconColor: AppColors.verde,
                    onTap: () =>
                        Navigator.of(context).pushNamed('/admin/usuarios'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAccessCard(
                    icon: Icons.calendar_month_outlined,
                    title: 'Tareas',
                    iconColor: AppColors.verde,
                    onTap: () => ControlPestanas.index.value = 1,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAccessCard(
                    icon: Icons.card_giftcard,
                    title: 'Premios',
                    iconColor: AppColors.amarilloOscuro,
                    onTap: () =>
                        ControlPestanas.index.value = ControlPestanas.premiosDe(true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Gráfica de actividad + aprobaciones pendientes.
            LayoutBuilder(
              builder: (context, constraints) {
                final dosColumnas = constraints.maxWidth >= 900;
                final grafico = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: _TituloSeccion(
                            'Actividad familiar (30 días)',
                          ),
                        ),
                        _TrendPill(puntos: _puntosPorDia),
                      ],
                    ),
                    DuoCard(
                      child: BarChart(
                        data: _puntosPorDia,
                        labelFor: (d) => d.day.toString(),
                        highlightIndex: _puntosPorDia.isEmpty
                            ? null
                            : _puntosPorDia.length - 1,
                      ),
                    ),
                  ],
                );
                final aprobaciones = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TituloSeccion(
                      'Pendientes de aprobación',
                      key: _keyAprobaciones,
                    ),
                    if (_pendientes.isEmpty)
                      const EmptyState(
                        mascota: MascotType.nubecita,
                        icon: Icons.hourglass_empty,
                        message: 'Nada por aprobar',
                        hint: 'Las tareas completadas aparecerán aquí.',
                      )
                    else
                      ..._pendientes.map(
                        (p) => DuoCard(
                          padding: EdgeInsets.zero,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: verdeFondoTema(context),
                              child: Text(
                                p.$3.nombre.characters.first.toUpperCase(),
                                style: TextStyle(
                                  color: esOscuro(context)
                                      ? AppColors.verde
                                      : AppColors.verdeOscuro,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            title: Text(
                              p.$1.titulo,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      grafico,
                      const SizedBox(height: 24),
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

/// Tarjeta métrica compacta de la referencia: valor arriba, etiqueta abajo.
class _MetricMini extends StatelessWidget {
  final String value;
  final String label;
  final Color bgColor;
  final Color textColor;
  const _MetricMini(this.value, this.label, this.bgColor, this.textColor);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: textoSuaveTema(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Acceso rápido de la referencia: tarjeta blanca con icono en círculo tintado.
class _QuickAccessCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final Color iconColor;
  final VoidCallback onTap;
  const _QuickAccessCard({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.onTap,
  });

  @override
  State<_QuickAccessCard> createState() => _QuickAccessCardState();
}

class _QuickAccessCardState extends State<_QuickAccessCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: reduced ? 1 : (_down ? 0.95 : 1),
        duration: const Duration(milliseconds: 130),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: superficieTema(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: esOscuro(context) ? Colors.white24 : AppColors.linea,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textoTema(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// INICIO NIÑO — igual a ChildHomeScreen de la referencia
// =====================================================================
class _ChildHomeView extends StatefulWidget {
  final AppProvider app;
  final User user;
  const _ChildHomeView({required this.app, required this.user});

  @override
  State<_ChildHomeView> createState() => _ChildHomeViewState();
}

class _ChildHomeViewState extends State<_ChildHomeView> {
  List<(Task, Assignment)> _hoy = const [];
  List<(DateTime, int)> _puntosPorDia = const [];
  List<(DateTime, int)> _puntos84 = const [];
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
      final f = await Future.wait([
        widget.app.tareasPendientesDeHoy(widget.user.id!),
        widget.app.puntosPorDia(widget.user.id!, dias: 30),
        widget.app.puntosPorDiaGlobal(dias: 84),
      ]);
      if (!mounted) return;
      setState(() {
        _hoy = f[0] as List<(Task, Assignment)>;
        _puntosPorDia = f[1] as List<(DateTime, int)>;
        _puntos84 = f[2] as List<(DateTime, int)>;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    widget.app.removeListener(_onCambio);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    final n = _hoy.length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fechaEnMayusculas(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.verde,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '¡Hola, ${user.nombre}!',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: textoTema(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(color: AppColors.verde),
                    ),
                    color: verdeFondoTema(context),
                  ),
                  child: Text(
                    user.nombre.isNotEmpty
                        ? user.nombre.substring(0, 1).toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.verde,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Banner ámbar de pendientes (clicable → Tareas).
            GestureDetector(
              onTap: () => ControlPestanas.index.value = 1,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: amarilloFondoTema(context),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    // Icono 3D animado: la escoba barre mientras hay
                    // tareas; con todo listo aparece el trofeo celebrando.
                    SizedBox(
                      width: 38,
                      height: 38,
                      child: Center(
                        child: n > 0
                            ? const Broom3D(size: 34, animar: true)
                            : const Trophy3D(size: 34, animar: true),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n > 0
                                ? '¡Tienes $n tarea${n == 1 ? '' : 's'} pendiente${n == 1 ? '' : 's'} hoy!'
                                : '¡Todo listo por hoy!',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            n > 0
                                ? 'Completa primero las vencidas para desbloquear premios.'
                                : 'Excelente trabajo. ¡Sigue así!',
                            style: TextStyle(
                              fontSize: 12,
                              color: textoSuaveTema(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.verde,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            DuoButton(
              label: 'Comenzar tareas',
              onPressed: () => ControlPestanas.index.value = 1,
            ),
            const SizedBox(height: 24),
            // Nivel con su trazo de progreso animado: tarjeta propia arriba
            // de "Mi progreso" para que destaque.
            DuoCard(
              child: LevelProgress(
                puntos: user.puntos,
                nivel: GamificationService.nivelPara(user.puntos),
              ),
            ),
            const SizedBox(height: 24),
            const _TituloSeccion('Mi progreso'),
            DuoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Resumen de la semana actual.
                  Builder(
                    builder: (context) {
                      final h = DateTime.now();
                      final hd = DateTime(h.year, h.month, h.day);
                      final ini = hd.subtract(Duration(days: hd.weekday - 1));
                      final sem = _puntos84
                          .where((d) => !d.$1.isBefore(ini))
                          .fold<int>(0, (a, d) => a + d.$2);
                      final activos = _puntos84
                          .where((d) => !d.$1.isBefore(ini) && d.$2 > 0)
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
                    data: _puntosPorDia,
                    labelFor: (d) => d.day.toString(),
                    highlightIndex: _puntosPorDia.isEmpty
                        ? null
                        : _puntosPorDia.length - 1,
                  ),
                  const SizedBox(height: 14),
                  // Mapa de constancia (12 semanas).
                  StreakHeatmap(data: _puntos84, semanas: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Título de sección (w900).
class _TituloSeccion extends StatelessWidget {
  final String texto;
  const _TituloSeccion(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// Chip con la variación porcentual de la última semana vs. la anterior.
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
          color: verdeFondoTema(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'NUEVO',
          style: TextStyle(
            color: esOscuro(context) ? AppColors.verde : AppColors.verdeOscuro,
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
