import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/app_provider.dart';
import '../services/celebration_service.dart';
import '../services/mascota_service.dart';
import '../theme/app_theme.dart';
import '../widgets/aviso_robo.dart';
import '../widgets/confetti.dart';
import '../widgets/hq_logo.dart';
import '../widgets/icono3d.dart';
import '../widgets/mascots.dart';
import '../widgets/playful_motion.dart';
import 'inicio_screen.dart';
import 'perfil_screen.dart';
import 'ranking_screen.dart';
import 'retos_screen.dart';
import 'premios_screen.dart';
import 'tareas_screen.dart';

/// Controlador de navegación por pestañas, compartido entre pantallas
/// para poder saltar de tab desde el dashboard.
class ControlPestanas {
  static final ValueNotifier<int> index = ValueNotifier<int>(0);

  /// Índice de la pestaña Premios según el rol (admin: 5 pestañas,
  /// niño: 6 con Retos propio).
  static int premiosDe(bool esAdmin) => esAdmin ? 3 : 4;

  /// Índice de la pestaña Ranking según el rol.
  static int rankingDe(bool esAdmin) => esAdmin ? 2 : 3;
}

class NavegacionPrincipal extends StatefulWidget {
  const NavegacionPrincipal({super.key});

  @override
  State<NavegacionPrincipal> createState() => _NavegacionPrincipalState();
}

class _NavegacionPrincipalState extends State<NavegacionPrincipal> {
  int _index = 0;
  int? _puntosPrevios;

  // Asistente de la mascota: consejo contextual de la vista activa que se
  // oculta solo a los 8 s y vuelve a aparecer (con mensaje nuevo) al volver
  // a la vista.
  String? _globo;
  String? _globoAccion;
  VoidCallback? _globoIr;
  Timer? _globoTimer;
  int _globoToken = 0;

  // Mascota intermitente: aparece y desaparece sola (ciclo ~10 s visible /
  // ~18 s oculta). Con "Mascota siempre visible" en Ajustes se queda fija.
  bool _mascotaVisible = true;
  Timer? _mascotaTimer;

  late AppProvider _provider;

  @override
  void initState() {
    super.initState();
    ControlPestanas.index.addListener(_onTabChange);
    MascotaService.siempreVisible.addListener(_onPrefMascota);
    _provider = context.read<AppProvider>();
    _puntosPrevios = _provider.usuarioActual?.puntos ?? 0;
    _provider.addListener(_onAppChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _programarGlobo();
      _programarCicloMascota();
      _avisarRobosPendientes();
    });
  }

  /// Al abrir la app, si alguien le robó una tarea o un reto desde la última
  /// visita, el niño ve el diálogo animado "¡Te robaron!".
  Future<void> _avisarRobosPendientes() async {
    final u = _provider.usuarioActual;
    if (u == null || u.esAdmin) return;
    final avisos = await _provider.robosNoVistos();
    if (!mounted || avisos.isEmpty) return;
    await mostrarAvisoRobo(context, avisos);
  }

  @override
  void dispose() {
    _globoTimer?.cancel();
    _mascotaTimer?.cancel();
    ControlPestanas.index.removeListener(_onTabChange);
    MascotaService.siempreVisible.removeListener(_onPrefMascota);
    _provider.removeListener(_onAppChange);
    super.dispose();
  }

  void _onTabChange() {
    if (!mounted) return;
    setState(() => _index = ControlPestanas.index.value);
    _programarGlobo();
    // En cada cambio de vista la mascota vuelve a asomarse un rato.
    _programarCicloMascota();
  }

  void _onPrefMascota() {
    if (!mounted) return;
    _programarCicloMascota();
  }

  /// Ciclo intermitente de la mascota: visible ~10 s → oculta ~18 s, en
  /// bucle. Con la preferencia "siempre visible" se cancela el temporizador
  /// y la mascota no se va nunca.
  void _programarCicloMascota() {
    _mascotaTimer?.cancel();
    if (MascotaService.siempreVisible.value) {
      if (!_mascotaVisible) setState(() => _mascotaVisible = true);
      return;
    }
    setState(() => _mascotaVisible = true);
    _mascotaTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      setState(() => _mascotaVisible = false);
      _mascotaTimer = Timer(const Duration(seconds: 18), () {
        if (!mounted) return;
        _programarCicloMascota();
      });
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
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      });
    }
  }

  void _cambiarTab(int i) {
    ControlPestanas.index.value = i;
    setState(() => _index = i);
  }

  /// Muestra el consejo de la vista activa y lo oculta solo a los 8 s.
  /// Al cambiar de pestaña se cancela el temporizador y aparece uno nuevo
  /// (la mascota vuelve a guiar en cada vista).
  Future<void> _programarGlobo() async {
    final token = ++_globoToken;
    _globoTimer?.cancel();
    final consejo = await _consejoVista(_index);
    if (!mounted || token != _globoToken) return;
    setState(() {
      _globo = consejo.texto;
      _globoAccion = consejo.accion;
      _globoIr = consejo.ir;
    });
    _globoTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted || token != _globoToken) return;
      setState(() {
        _globo = null;
        _globoAccion = null;
        _globoIr = null;
      });
    });
  }

  /// Consejo de la mascota según la vista activa: usa datos reales (tareas
  /// pendientes, retos, posición, premios...) para guiar al usuario y, cuando
  /// tiene sentido, propone navegar allí con el botón del globo.
  Future<({String texto, String? accion, VoidCallback? ir})> _consejoVista(
    int i,
  ) async {
    final user = _provider.usuarioActual;
    final esAdmin = user?.esAdmin ?? false;
    final rnd = math.Random();
    String? accion;
    VoidCallback? ir;
    var texto = '¡Tócame si necesitas ayuda! 👋';

    Future<void> sugerir(int tab, String label) async {
      accion = label;
      ir = () => ControlPestanas.index.value = tab;
    }

    if (user == null) return (texto: texto, accion: null, ir: null);

    if (esAdmin) {
      switch (i) {
        case 0: // Inicio
          final n = (await _provider.pendientesDeAprobacion()).length;
          texto = n > 0
              ? '¡$n tarea${n == 1 ? '' : 's'} esperan tu aprobación! 👀'
              : '¡Todo al día, jefe! Eres un crack 🦉';
          if (n > 0) await sugerir(1, 'Ir a aprobar');
          break;
        case 1: // Tareas (con Retos como segmento)
          texto = rnd.nextBool()
              ? 'Aquí planificas la semana con un toque 🗓️'
              : 'Agrega tareas desde el Libro de Tareas ✨';
          break;
        case 2: // Ranking
          texto = 'Mira cómo va la familia esta semana 🏆';
          break;
        case 3: // Premios
          texto = 'Crea premios para motivar a los peques 🎁';
          break;
        default: // Perfil
          texto = 'Toca a ${mascotaDeUser(user).nombre} para saludar 👋';
      }
    } else {
      switch (i) {
        case 0: // Inicio
          final n = (await _provider.tareasPendientesDeHoy(user.id!)).length;
          if (n > 0) {
            texto = '¡Te faltan $n tarea${n == 1 ? '' : 's'} hoy! 💪';
            await sugerir(1, 'Ir a tareas');
          } else {
            texto = '¡Todo listo por hoy! Mira tus premios 🎁';
            await sugerir(4, 'Ver premios');
          }
          break;
        case 1: // Tareas
          final n = (await _provider.tareasPendientesDeHoy(user.id!)).length;
          texto = n > 0
              ? (rnd.nextBool()
                  ? 'Empieza por la más fácil, ¡tú puedes! 🚀'
                  : '¡$n por hacer! Cada una suma puntos ✨')
              : 'Sin tareas pendientes. ¡A descansar! 😴';
          break;
        case 2: // Retos
          final retos = await _provider.retosDeLaSemana();
          if (retos.isEmpty) {
            texto = 'Aún no hay reto; pídeselo al admin 🙏';
          } else {
            final reto = retos.first;
            final ya = reto.cumplidos.contains(user.id);
            texto = ya
                ? '¡Ya marcaste «${reto.titulo}»! Espera la aprobación 🙌'
                : '¡Reto de la semana: «${reto.titulo}»! 🔥';
          }
          break;
        case 3: // Ranking
          final r = await _provider.ranking('semanal');
          final idx = r.indexWhere((e) => e.$1.id == user.id);
          if (idx < 0) {
            texto = 'Completa tareas para aparecer aquí 📈';
          } else if (idx == 0) {
            texto = '¡Vas líder de la semana! 👑';
          } else {
            texto =
                'Vas #${idx + 1} esta semana. ¡Vamos por el 1er puesto! 🏅';
          }
          break;
        case 4: // Premios
          final recompensas = await _provider.listarRecompensas();
          final disponibles = [...recompensas]
            ..sort((a, b) => a.costoPuntos.compareTo(b.costoPuntos));
          if (disponibles.isEmpty) {
            texto = 'Aún no hay premios. Pídeselos al admin 🙏';
          } else {
            final barato = disponibles.first;
            if (user.puntos >= barato.costoPuntos) {
              texto = '¡Ya puedes canjear «${barato.nombre}»! 🎁';
            } else {
              final faltan = barato.costoPuntos - user.puntos;
              texto = 'Te faltan $faltan pts para «${barato.nombre}» 💪';
            }
          }
          break;
        default: // Perfil
          texto = 'Toca a ${mascotaDeUser(user).nombre} para cambiarla 👋';
      }
    }
    return (texto: texto, accion: accion, ir: ir);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AppProvider, User?>((p) => p.usuarioActual);
    final esAdmin = user?.esAdmin ?? false;

    // Navegación de la referencia: admin con 5 pestañas (Retos dentro de
    // Tareas como segmento) y niño con 6 pestañas (Retos propio).
    final screens = esAdmin
        ? const [
            InicioScreen(),
            TareasScreen(),
            RankingScreen(),
            PremiosScreen(),
            PerfilScreen(),
          ]
        : const [
            InicioScreen(),
            TareasScreen(),
            RetosScreen(),
            RankingScreen(),
            PremiosScreen(),
            PerfilScreen(),
          ];

    final destinations = esAdmin
        ? const [
            NavigationDestination(
              icon: HqLogo(size: 24),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icono3D(tipo: Icono3DTipo.check, size: 26),
              label: 'Tareas',
            ),
            NavigationDestination(
              icon: Icono3D(tipo: Icono3DTipo.estrella, size: 26),
              label: 'Ranking',
            ),
            NavigationDestination(
              icon: Icono3D(tipo: Icono3DTipo.regalo, size: 26),
              label: 'Premios',
            ),
            NavigationDestination(
              icon: Icono3D(tipo: Icono3DTipo.persona, size: 26),
              label: 'Perfil',
            ),
          ]
        : const [
            NavigationDestination(
              icon: HqLogo(size: 24),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icono3D(tipo: Icono3DTipo.check, size: 26),
              label: 'Tareas',
            ),
            NavigationDestination(
              icon: Icono3D(tipo: Icono3DTipo.bandera, size: 26),
              label: 'Retos',
            ),
            NavigationDestination(
              icon: Icono3D(tipo: Icono3DTipo.estrella, size: 26),
              label: 'Ranking',
            ),
            NavigationDestination(
              icon: Icono3D(tipo: Icono3DTipo.regalo, size: 26),
              label: 'Premios',
            ),
            NavigationDestination(
              icon: Icono3D(tipo: Icono3DTipo.persona, size: 26),
              label: 'Perfil',
            ),
          ];

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                context.select<AppProvider, bool>((p) => p.sinConexion)
                    ? const _BannerSinConexion()
                    : const SizedBox.shrink(),
                Expanded(
                  child: PlayfulIndexedStack(index: _index, children: screens),
                ),
              ],
            ),
          ),
          // Mascota compañera: intermitente por defecto (aparece y se va),
          // forzada a visible mientras hay consejo del globo, y fija si el
          // usuario activó "Mascota siempre visible" en Ajustes. Reacciona
          // al toque (salto, chispas y frase) en la esquina inferior derecha.
          if (user != null)
            Positioned(
              right: 10,
              bottom: 12,
              child: AnimatedOpacity(
                opacity: (_mascotaVisible || _globo != null) ? 1 : 0,
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOut,
                child: IgnorePointer(
                  ignoring: !(_mascotaVisible || _globo != null),
                  child: MascotWidget(
                    mascota: mascotaDeUser(user),
                    size: 86,
                    flotante: true,
                    globo: _globo,
                    globoAccion: _globoAccion,
                    onGloboAccion:
                        _globoIr == null ? null : () => _globoIr?.call(),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.superficieOscura
              : Colors.white,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white24
                  : AppColors.linea,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index.clamp(0, destinations.length - 1),
          onDestinationSelected: _cambiarTab,
          destinations: destinations,
        ),
      ),
    );
  }
}

/// Aviso cuando el servidor está apagado y se muestran datos de la copia local.
class _BannerSinConexion extends StatelessWidget {
  const _BannerSinConexion();

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
                  style: TextStyle(
                    fontSize: 12,
                    color: colores.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
