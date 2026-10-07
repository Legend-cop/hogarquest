import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../providers/app_provider.dart';
import '../services/celebration_service.dart';
import '../services/gamification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/confetti.dart';
import '../widgets/mascots.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'ranking_screen.dart';
import 'rewards_screen.dart';
import 'tasks_screen.dart';

/// Controlador de navegación por pestañas, compartido entre pantallas
/// para poder saltar de tab desde el dashboard.
class HomeTabs {
  static final ValueNotifier<int> index = ValueNotifier<int>(0);
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int? _puntosPrevios;
  Offset? _mascotaPos;
  // Última posición guardada como fracción del área útil (0..1) para que
  // sobreviva a recargas y valga en cualquier tamaño de pantalla.
  Offset? _mascotaPosNorm;
  double _lastMaxX = 1;
  double _lastMaxY = 1;

  // Asistente: aparece en momentos clave con un mensaje útil de la vista
  // actual y se oculta sola a los pocos segundos (no está siempre visible).
  bool _mascotaVisible = false;
  String _mascotaMensaje = '';
  int _mascotaToken = 0;
  Timer? _mascotaTimer;

  late AppProvider _provider;

  @override
  void initState() {
    super.initState();
    HomeTabs.index.addListener(_onTabChange);
    _provider = context.read<AppProvider>();
    _puntosPrevios = _provider.usuarioActual?.puntos ?? 0;
    _provider.addListener(_onAppChange);
    unawaited(_restaurarPosMascota());
    // Saludo al abrir la app: la mascota recuerda las tareas del día.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (mounted) unawaited(_mostrarMascota());
      });
    });
  }

  /// Restaura la posición arrastrada de la mascota (fracciones 0..1 del
  /// área útil) para que sobreviva a recargas de la app.
  Future<void> _restaurarPosMascota() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('mascota_pos');
    if (raw == null) return;
    final parts = raw.split(',');
    if (parts.length != 2) return;
    final fx = double.tryParse(parts[0]);
    final fy = double.tryParse(parts[1]);
    if (fx == null || fy == null) return;
    if (mounted) setState(() => _mascotaPosNorm = Offset(fx, fy));
  }

  /// Guarda la posición actual de la mascota al soltar el arrastre.
  void _guardarPosMascota() {
    final pos = _mascotaPos;
    if (pos == null) return;
    final fx = pos.dx.clamp(8.0, _lastMaxX).toDouble() / _lastMaxX;
    final fy = pos.dy.clamp(8.0, _lastMaxY).toDouble() / _lastMaxY;
    unawaited(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'mascota_pos', '${fx.toStringAsFixed(4)},${fy.toStringAsFixed(4)}');
    }());
  }

  @override
  void dispose() {
    HomeTabs.index.removeListener(_onTabChange);
    _provider.removeListener(_onAppChange);
    _mascotaTimer?.cancel();
    super.dispose();
  }

  void _onTabChange() {
    if (!mounted) return;
    setState(() => _index = HomeTabs.index.value);
    // En cada vista la mascota aparece con información que le sirve allí.
    unawaited(_mostrarMascota());
  }

  /// Muestra la mascota-asistente con el mensaje de [vista] (o con
  /// [forzado]) y la oculta automáticamente a los 7 segundos.
  Future<void> _mostrarMascota({String? forzado}) async {
    final user = _provider.usuarioActual;
    if (user == null || user.esAdmin) return;
    final token = ++_mascotaToken;
    final vista = _index;
    final msg = forzado ?? await _mensajeMascota(_provider, user, vista);
    if (!mounted || token != _mascotaToken) return;
    setState(() {
      _mascotaMensaje = msg;
      _mascotaVisible = true;
    });
    _mascotaTimer?.cancel();
    _mascotaTimer = Timer(const Duration(seconds: 7), () {
      if (mounted) setState(() => _mascotaVisible = false);
    });
  }

  /// Celebra en el dispositivo del niño cuando le aprueban una tarea y suben
  /// sus puntos (el admin ya celebra al pulsar "Aprobar").
  void _onAppChange() {
    final u = _provider.usuarioActual;
    if (u == null) return;
    final antes = _puntosPrevios;
    _puntosPrevios = u.puntos;
    if (u.esAdmin) return;
    if (antes != null && u.puntos > antes && mounted) {
      final ganados = u.puntos - antes;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        lanzarConfeti(context);
        unawaited(CelebrationService.instance.success());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.verde,
            content: Text(
              '¡Bien hecho! +$ganados puntos',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
        );
        // La mascota aparece celebrando y refuerza la racha.
        unawaited(_mostrarMascota(
          forzado: u.racha >= 2
              ? '¡Ey, ${u.nombre}! +$ganados XP 🎉 ¡Llevas ${u.racha} días de racha 🔥'
              : '¡Ey, ${u.nombre}! +$ganados XP 🎉 ¡Sigue así!',
        ));
      });
    }
  }

  void _cambiarTab(int i) {
    HomeTabs.index.value = i;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final user =
        context.select<AppProvider, User?>((p) => p.usuarioActual);
    final esAdmin = user?.esAdmin ?? false;

    final screens = [
      const DashboardScreen(),
      const TasksScreen(),
      const RankingScreen(),
      const RewardsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: SafeArea(
        // El LayoutBuilder va FUERA del Stack para que Positioned sea hijo
        // directo de Stack (Positioned dentro de LayoutBuilder rompe en
        // release: su hijo se engancha a un RenderObject con BoxParentData).
        child: LayoutBuilder(
          builder: (context, constraints) {
            const size = 78.0;
            // Margen derecho de56px: deja espacio para que el globo de
            // diálogo (centrado sobre la mascota) siempre quepa en pantalla.
            final maxX =
                (constraints.maxWidth - size - 56).clamp(8.0, double.infinity);
            final maxY =
                (constraints.maxHeight - size - 8).clamp(8.0, double.infinity);
            _lastMaxX = maxX.toDouble();
            _lastMaxY = maxY.toDouble();
            final def = Offset(
              constraints.maxWidth - size - 56,
              constraints.maxHeight * 0.42,
            );
            final norm = _mascotaPosNorm;
            final Offset p;
            if (_mascotaPos != null) {
              p = _mascotaPos!;
            } else if (norm != null) {
              p = Offset(norm.dx * maxX, norm.dy * maxY);
            } else {
              p = def;
            }
            final cx = p.dx.clamp(8.0, maxX).toDouble();
            final cy = p.dy.clamp(8.0, maxY).toDouble();
            return Stack(
              children: [
                Column(
                  children: [
                    context.select<AppProvider, bool>((p) => p.sinConexion)
                        ? const _BannerSinConexion()
                        : const SizedBox.shrink(),
                    Expanded(
                        child: IndexedStack(index: _index, children: screens)),
                  ],
                ),
                // Mascota-asistente: aparece solo en momentos clave (apertura
                // de la app, cambio de vista, logros) con un mensaje útil de
                // esa vista y se oculta sola. Se puede arrastrar. Se ancla por
                // abajo: el globo crece hacia arriba y no tapa a la mascota.
                if (user != null && !user.esAdmin)
                  Positioned(
                    left: cx,
                    bottom: constraints.maxHeight - cy - size,
                    child: IgnorePointer(
                      ignoring: !_mascotaVisible,
                      child: AnimatedOpacity(
                        opacity: _mascotaVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 450),
                        child: AnimatedScale(
                          scale: _mascotaVisible ? 1 : 0.5,
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOutBack,
                          child: GestureDetector(
                            onPanStart: (_) =>
                                setState(() => _mascotaPos = Offset(cx, cy)),
                            onPanUpdate: (d) {
                              final base = _mascotaPos ?? def;
                              setState(
                                  () => _mascotaPos = base + d.delta);
                            },
                            onPanEnd: (_) => _guardarPosMascota(),
                            child: MascotWidget(
                              mascota: mascotaDeUser(user),
                              size: size,
                              flotante: true,
                              globo: _mascotaMensaje,
                              onInteract: (_) {
                                // Tocarla reinicia el reloj: la acompaña
                                // mientras el niño quiera.
                                _mascotaTimer?.cancel();
                                _mascotaTimer = Timer(
                                    const Duration(seconds: 7), () {
                                  if (mounted) {
                                    setState(() => _mascotaVisible = false);
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _cambiarTab,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(esAdmin ? Icons.fact_check_outlined : Icons.checklist_outlined),
            selectedIcon:
                Icon(esAdmin ? Icons.fact_check : Icons.checklist),
            label: 'Tareas',
          ),
          const NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard),
            label: 'Ranking',
          ),
          const NavigationDestination(
            icon: Icon(Icons.card_giftcard_outlined),
            selectedIcon: Icon(Icons.card_giftcard),
            label: 'Premios',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

/// Mensaje contextual de la mascota según la vista en la que está el niño.
/// Usa datos REALES para que sirva de algo: tareas de hoy, racha, posición
/// en el ranking, XP que falta para el premio o el nivel, progreso del reto.
Future<String> _mensajeMascota(AppProvider app, User user, int vista) async {
  final nombre = user.nombre;
  try {
    switch (vista) {
      case 0: // Inicio
        final hoy = await app.tareasPendientesDeHoy(user.id!);
        if (hoy.isNotEmpty) {
          return '¡Ey, $nombre! Tienes ${hoy.length} '
              '${hoy.length == 1 ? 'tarea pendiente' : 'tareas pendientes'} '
              'hoy 💪';
        }
        if (user.racha >= 3) {
          return '¡Ey, $nombre! Ya no queda nada hoy y llevas '
              '${user.racha} días de racha 🔥 ¡No la rompas!';
        }
        return '¡Ey, $nombre! Todo listo por hoy 🎉 ¡Buen trabajo!';
      case 1: // Tareas
        final hoy = await app.tareasPendientesDeHoy(user.id!);
        if (hoy.isNotEmpty) {
          return 'Te quedan ${hoy.length} de hoy. ¡Una a una y se acaba! 🚀';
        }
        final hist = await app.historialDe(user.id!);
        if (hist.isNotEmpty) {
          return '¡Completaste todo, $nombre! Eres imparable 🏆';
        }
        return 'Aún no tienes tareas. Pídele al administrador que te '
            'asigne 🙌';
      case 2: // Ranking
        final ranking = await app.ranking('semanal');
        final idx = ranking.indexWhere((e) => e.$1.id == user.id);
        if (idx == 0) {
          return '¡Estás primero, $nombre! 🥇 ¡Mantenlo así!';
        }
        if (idx > 0) {
          return 'Vas ${idx + 1}º de ${ranking.length} 💪 ¡A por el podio!';
        }
        return '¡A disputar el ranking esta semana, $nombre! 🏆';
      case 3: // Premios
        final recompensas = await app.listarRecompensas();
        if (recompensas.isNotEmpty) {
          final orden = [...recompensas]
            ..sort((a, b) => a.costoPuntos.compareTo(b.costoPuntos));
          final meta = orden
              .where((r) => r.costoPuntos > user.puntos)
              .toList();
          if (meta.isEmpty) {
            return '¡Tienes XP para cualquier premio, $nombre! 🎁';
          }
          final faltan = meta.first.costoPuntos - user.puntos;
          return 'Te faltan $faltan XP para «${meta.first.nombre}» '
              '🎁 ¡Tú puedes!';
        }
        return 'Sigue ganando XP: pronto habrá premios para canjear ✨';
      default: // Perfil (4)
        final falta =
            GamificationService.puntosParaSiguiente(user.puntos, user.nivel);
        if (user.racha >= 2) {
          return '$nombre, llevas ${user.racha} días de racha 🔥 '
              '¡A por la siguiente!';
        }
        if (falta > 0) {
          return 'Te faltan $falta XP para subir a '
              '«${GamificationService.nombreNivel(user.nivel + 1)}» ✨';
        }
        return '¡Sigue completando tareas para subir de nivel ⭐';
    }
  } catch (_) {
    return '¡Ey, $nombre! Estoy aquí contigo 😊';
  }
}

/// Aviso cuando el servidor está apagado y se muestran datos de la copia local.
class _BannerSinConexion extends StatelessWidget {  const _BannerSinConexion();

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Material(
      color: colores.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.cloud_off, size: 16, color: colores.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Servidor apagado: mostrando la última copia guardada. Los cambios se sincronizarán al reconectar.',
                  style: TextStyle(fontSize: 12, color: colores.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
