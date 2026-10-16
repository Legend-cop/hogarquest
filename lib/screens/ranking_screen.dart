import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/assignment.dart';
import '../models/badge.dart' as badge_model;
import '../models/logro.dart' as logro_model;
import '../models/task.dart';
import '../models/user.dart';
import '../providers/app_provider.dart';
import '../services/gamification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/mascots.dart';
import '../widgets/hq_design.dart';
import '../widgets/duo_widgets.dart';
import '../widgets/icono3d.dart';
import '../widgets/icons3d.dart';
import '../widgets/insignia_parche.dart';
import '../widgets/playful_motion.dart';
import '../widgets/user_avatar.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  int _seccion = 0; // 0 familiar · 1 liga · 2 fama
  int _periodo = 0; // 0 semanal · 1 mensual
  bool _cargando = true;
  List<(User, int, int)> _rankingSemanal = []; // (usuario, pts, perdidos)
  List<(User, int, int)> _rankingMensual = [];
  List<(User, int, int)> _rankingAnterior = []; // semana anterior (para ligas)
  int _puntosFamiliaSemana = 0;
  bool _ligasBloqueadas = true;
  List<_Recorde> _fama = [];
  late AppProvider _provider;

  static const _metaFamiliar = 100;

  @override
  void initState() {
    super.initState();
    _provider = context.read<AppProvider>();
    _provider.addListener(_onChange);
    _cargarDatos();
  }

  void _onChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cargarDatos();
    });
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final app = context.read<AppProvider>();
    final semanal = await _conPerdidos(app, 'semanal');
    final mensual = await _conPerdidos(app, 'mensual');
    final fama = await _calcularFama(app);
    final anterior = await app.rankingSemanaAnterior();
    final puntosFamilia = await app.puntosFamiliaSemana();
    if (!mounted) return;
    setState(() {
      _rankingSemanal = semanal;
      _rankingMensual = mensual;
      _rankingAnterior = anterior;
      _ligasBloqueadas = anterior.isEmpty;
      _puntosFamiliaSemana = puntosFamilia;
      _fama = fama;
      _cargando = false;
    });
  }

  /// Récords familiares (mejor racha, más XP, más tareas) para el Salón.
  Future<List<_Recorde>> _calcularFama(AppProvider app) async {
    final usuarios = await app.listarIntegrantes();
    if (usuarios.isEmpty) return [];

    final racha = usuarios.reduce((a, b) => b.racha > a.racha ? b : a);
    final xp = usuarios.reduce((a, b) => b.puntos > a.puntos ? b : a);
    var maxCompletadas = -1;
    User? masTareas;
    for (final u in usuarios) {
      final hist = await app.historialDe(u.id!);
      if (hist.length > maxCompletadas) {
        maxCompletadas = hist.length;
        masTareas = u;
      }
    }
    return [
      _Recorde(
        icon: Icons.local_fire_department,
        titulo: 'Mejor racha',
        valor: '${racha.racha} días',
        detalle: racha.nombre,
        color: AppColors.rojo,
        valorRacha: racha.racha,
      ),
      _Recorde(
        icon: Icons.bolt,
        titulo: 'Más XP',
        valor: '${xp.puntos} XP',
        detalle: xp.nombre,
        color: AppColors.amarillo,
      ),
      _Recorde(
        icon: Icons.check_circle,
        titulo: 'Más tareas completadas',
        valor: '${maxCompletadas < 0 ? 0 : maxCompletadas} tareas',
        detalle: masTareas?.nombre ?? '',
        color: AppColors.azul,
      ),
    ];
  }

  Future<List<(User, int, int)>> _conPerdidos(
    AppProvider app,
    String periodo,
  ) async {
    final base = await app.ranking(periodo);
    final resultado = <(User, int, int)>[];
    for (final (user, pts) in base) {
      final perdidos = await app.puntosCastigadosRecientes(
        user.id!,
        dias: periodo == 'semanal' ? 7 : 30,
      );
      resultado.add((user, pts, perdidos));
    }
    // Se ordena por el NETO del periodo (ganado - perdido), que es el que
    // le queda al integrante.
    resultado.sort((a, b) => (b.$2 - b.$3).compareTo(a.$2 - a.$3));
    return resultado;
  }

  /// Liga actual del usuario según sus puntos acumulados. La posición es su
  /// puesto en la clasificación de la semana anterior (-1 si no aparece).
  (String?, int) get _ligaUsuario {
    final user = _provider.usuarioActual;
    if (user == null) return (null, -1);
    final idx = _rankingAnterior.indexWhere((e) => e.$1.id == user.id);
    return (GamificationService.ligaDe(user.puntos), idx >= 0 ? idx + 1 : -1);
  }

  @override
  void dispose() {
    _provider.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    final user = _provider.usuarioActual;
    if (user == null) return const SizedBox.shrink();
    final esAdmin = user.esAdmin;

    final items = _periodo == 0 ? _rankingSemanal : _rankingMensual;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ReferenciaTitulo(
              esAdmin ? 'COMPITE EN FAMILIA' : 'CLASIFICACIÓN FAMILIAR',
              esAdmin ? 'Ranking' : 'Mi ranking',
              icono: Icono3DTipo.estrella,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PillSegment(
              index: _seccion,
              onChanged: (i) => setState(() => _seccion = i),
              items: const [
                (icon: Icons.groups_outlined, label: 'Familiar'),
                (icon: Icons.military_tech_outlined, label: 'Liga'),
                (icon: Icons.star_outline, label: 'Fama'),
              ],
            ),
          ),
          Expanded(
            child: switch (_seccion) {
              0 => _vistaFamiliar(esAdmin: esAdmin, items: items, user: user),
              1 => _vistaLiga(esAdmin: esAdmin, user: user),
              _ => _FamaTab(user: user),
            },
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // PESTAÑA FAMILIAR
  // -------------------------------------------------------------------------

  Widget _vistaFamiliar({
    required bool esAdmin,
    required List<(User, int, int)> items,
    required User user,
  }) {
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          if (esAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: SegmentTabs(
                const ['Semanal', 'Mensual'],
                _periodo,
                (i) => setState(() => _periodo = i),
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: EmptyState(
              mascota: MascotType.pepita,
              icon: Icons.leaderboard,
              message: 'No hay datos disponibles',
              hint: 'Completa tareas para ver el ranking.',
            ),
          ),
        ],
      );
    }

    final conPodio = items.length >= 3;
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        if (esAdmin)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: PillSegment(
              index: _periodo,
              onChanged: (i) => setState(() => _periodo = i),
              items: const [
                (icon: Icons.view_week_outlined, label: 'Semanal'),
                (icon: Icons.calendar_month_outlined, label: 'Mensual'),
              ],
            ),
          ),
        if (conPodio) _Podio(top3: items.sublist(0, 3)),
        for (var i = conPodio ? 3 : 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: _RankRow(
              posicion: i + 1,
              user: items[i].$1,
              puntos: items[i].$2,
              perdidos: items[i].$3,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: _MetaFamiliar(
            puntos: _puntosFamiliaSemana,
            meta: _metaFamiliar,
          ),
        ),
        if (!esAdmin && _fama.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _RecordsSeccion(records: _fama),
          ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // PESTAÑA LIGA
  // -------------------------------------------------------------------------

  Widget _vistaLiga({required bool esAdmin, required User user}) {
    final (liga, posicion) = _ligaUsuario;
    final idxLiga = GamificationService.indiceLiga(user.puntos);
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        if (!esAdmin && liga != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: _PosicionLiga(liga: liga, posicion: posicion, user: user),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: _LigasSeccion(idxLiga: idxLiga),
        ),
        if (_ligasBloqueadas)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: textoSuaveTema(context),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Completa una semana de tareas para desbloquear tu liga.',
                    style: TextStyle(
                      fontSize: 12,
                      color: textoSuaveTema(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Text(
            'Ranking de la liga',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: textoTema(context),
            ),
          ),
        ),
        for (var i = 0; i < _ligaRanking.length; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _LigaRow(
              posicion: i + 1,
              user: _ligaRanking[i].$1,
              pts: _ligaRanking[i].$2 - _ligaRanking[i].$3,
              esActual: _ligaRanking[i].$4 == 1,
            ),
          ),
      ],
    );
  }

  /// Lista usada para el "Ranking de la liga": la clasificación de la semana
  /// anterior (o la del periodo si no hay historial).
  List<(User, int, int, int)> get _ligaRanking {
    final fuente = _rankingAnterior.isNotEmpty
        ? _rankingAnterior
        : _rankingSemanal;
    final idActual = _provider.usuarioActual?.id;
    return [
      for (final (user, pts, perdidos) in fuente)
        (user, pts, perdidos, user.id == idActual ? 1 : 0),
    ];
  }
}

// ---------------------------------------------------------------------------
// PESTAÑAS: se usan PageTitle + SegmentTabs de hq_design.dart
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// META FAMILIAR
// ---------------------------------------------------------------------------

/// Meta familiar estilo referencia: CardBox con el título en una línea
/// (w900) y ProgressLine azul; el niño ve además cuánto falta.
class _MetaFamiliar extends StatelessWidget {
  final int puntos;
  final int meta;
  const _MetaFamiliar({required this.puntos, required this.meta});

  @override
  Widget build(BuildContext context) {
    final prog = meta <= 0 ? 0.0 : (puntos / meta).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.verdeProfundo,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Meta familiar',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: prog,
              minHeight: 10,
              color: Colors.amber,
              backgroundColor: Colors.white24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$puntos / $meta pts conseguidos',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// POSICIÓN DEL NIÑO EN SU LIGA (tarjeta amarilla estilo referencia)
// ---------------------------------------------------------------------------

class _PosicionLiga extends StatelessWidget {
  final String liga;
  final int posicion;
  final User user;

  const _PosicionLiga({
    required this.liga,
    required this.posicion,
    required this.user,
  });

  static Color _colorLiga(String liga) {
    switch (liga) {
      case 'Bronce':
        return AppColors.bronce;
      case 'Plata':
        return AppColors.plata;
      case 'Oro':
        return AppColors.oro;
      case 'Platino':
        return const Color(0xFF7FD1C7);
      case 'Zafiro':
        return const Color(0xFF2B59C3);
      case 'Esmeralda':
        return const Color(0xFF10B981);
      case 'Rubí':
        return const Color(0xFFDC2626);
      case 'Amatista':
        return const Color(0xFF8B5CF6);
      case 'Topacio':
        return const Color(0xFFEAB308);
      case 'Obsidiana':
        return const Color(0xFF1F2937);
      case 'Cristal':
        return const Color(0xFF67E8F9);
      case 'Perla':
        return const Color(0xFFCBD5E1);
      case 'Coral':
        return const Color(0xFFF87171);
      case 'Ámbar':
        return const Color(0xFFD97706);
      case 'Jade':
        return const Color(0xFF059669);
      case 'Cobalto':
        return const Color(0xFF1D4ED8);
      case 'Celeste':
        return const Color(0xFF38BDF8);
      case 'Estelar':
        return const Color(0xFFA78BFA);
      case 'Galáctica':
        return const Color(0xFF7C3AED);
      case 'Corona':
        return AppColors.oro;
      default:
        return AppColors.verde;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorLiga(liga);
    final idx = GamificationService.indiceLiga(user.puntos);
    final faltan = GamificationService.puntosParaSiguienteLiga(user.puntos);
    final sig = idx + 1 < GamificationService.ligas.length
        ? GamificationService.ligas[idx + 1]
        : null;
    return CardBox(
      color: amarilloFondoTema(context),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Medal3D(
                size: 34,
                tono: medalTonoDe(liga),
                animar: false,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu liga actual',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textoTema(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  liga,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: textoTema(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  faltan > 0 && sig != null
                      ? 'Faltan $faltan pts para $sig'
                      : '¡Liga máxima alcanzada! 👑',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textoSuaveTema(context),
                  ),
                ),
              ],
            ),
          ),
          Trophy3D(size: 40, animar: false),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LIGAS (carrusel horizontal de 20 escalones)
// ---------------------------------------------------------------------------

/// Carrusel de las 20 ligas: la actual al centro y grande, las alcanzadas
/// con medalla brillante y las futuras apagadas con candado. Desliza para
/// ver toda la escalera.
class _LigasSeccion extends StatefulWidget {
  final int idxLiga;

  const _LigasSeccion({required this.idxLiga});

  @override
  State<_LigasSeccion> createState() => _LigasSeccionState();
}

class _LigasSeccionState extends State<_LigasSeccion> {
  late final PageController _ctrl;
  late int _pagina;

  @override
  void initState() {
    super.initState();
    _pagina = widget.idxLiga;
    _ctrl = PageController(
      initialPage: widget.idxLiga,
      viewportFraction: 0.54,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ligas = GamificationService.ligas;
    final suave = textoSuaveTema(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Ligas · ${ligas[widget.idxLiga]}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 196,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: ligas.length,
            onPageChanged: (i) => setState(() => _pagina = i),
            itemBuilder: (context, i) {
              final actual = i == widget.idxLiga;
              final alcanzada = i <= widget.idxLiga;
              final umbral = GamificationService.umbralLiga(i);
              return AnimatedPadding(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: EdgeInsets.symmetric(
                  horizontal: actual ? 2 : 6,
                  vertical: actual ? 0 : 8,
                ),
                child: Opacity(
                  opacity: alcanzada ? 1 : 0.45,
                  child: CardBox(
                    color: actual ? amarilloFondoTema(context) : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Medal3D(
                          size: actual ? 60 : 46,
                          tono: medalTonoDe(ligas[i]),
                          animar: actual,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ligas[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: actual ? 15 : 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          alcanzada
                              ? (actual
                                  ? 'Tu liga · $umbral pts'
                                  : 'Alcanzada ✓')
                              : 'Desde $umbral pts',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: suave,
                          ),
                        ),
                        if (!alcanzada) ...[
                          const SizedBox(height: 6),
                          Icon(Icons.lock_rounded, size: 14, color: suave),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Puntitos que marcan la página actual del carrusel.
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < ligas.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == _pagina ? 14 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i == _pagina
                        ? AppColors.verde
                        : suave.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Fila del "Ranking de la liga" estilo referencia: CardBox, número 20 w900,
/// chip "¡Eres tú!" cuando la fila es la propia.
class _LigaRow extends StatelessWidget {
  final int posicion;
  final User user;
  final int pts;
  final bool esActual;

  const _LigaRow({
    required this.posicion,
    required this.user,
    required this.pts,
    required this.esActual,
  });

  @override
  Widget build(BuildContext context) {
    final tinta = textoTema(context);
    return CardBox(
      color: esActual ? verdeFondoTema(context) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$posicion',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: tinta,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user.nombre,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w900, color: tinta),
            ),
          ),
          if (esActual) ...[
            const Chip(label: Text('¡Eres tú!')),
            const SizedBox(width: 8),
          ],
          Text(
            '$pts XP',
            style: TextStyle(fontWeight: FontWeight.w800, color: tinta),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PODIO TOP 3
// ---------------------------------------------------------------------------

/// Podio de los 3 primeros estilo referencia: barras 130/90/70 en
/// amarillo/azul/plata con el puesto dentro (28 w900 blanco) y 🏆 sobre el 1.º.
class _Podio extends StatelessWidget {
  final List<(User, int, int)> top3;

  const _Podio({required this.top3});

  @override
  Widget build(BuildContext context) {
    // Orden visual clásico: 2.º, 1.º, 3.º.
    final orden = <((User, int, int), int, double, Color)>[
      (top3[1], 2, 90.0, AppColors.azul),
      (top3[0], 1, 130.0, AppColors.amarillo),
      (top3[2], 3, 70.0, AppColors.morado),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SizedBox(
        height: 260,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < orden.length; i++) ...[
              Expanded(
                child: _PodioPuesto(
                  item: orden[i].$1,
                  lugar: orden[i].$2,
                  alto: orden[i].$3,
                  color: orden[i].$4,
                ),
              ),
              if (i < orden.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _PodioPuesto extends StatelessWidget {
  final (User, int, int) item;
  final int lugar;
  final double alto;
  final Color color;

  const _PodioPuesto({
    required this.item,
    required this.lugar,
    required this.alto,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final (user, puntos, perdidos) = item;
    final neto = puntos - perdidos;
    final esCampeon = lugar == 1;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (esCampeon) const Text('🏆', style: TextStyle(fontSize: 28)),
        UserAvatar(user: user, radius: esCampeon ? 30 : 24),
        const SizedBox(height: 4),
        Text(
          user.nombre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        Text(
          '$neto XP',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        // Bloque de color sólido con el puesto dentro (28 w900 blanco).
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: alto),
          duration: Duration(milliseconds: hqReduceMotion(context) ? 0 : 650),
          curve: Curves.easeOutBack,
          builder: (context, animatedHeight, child) => Container(
            height: animatedHeight,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: animatedHeight < 28 ? const SizedBox.shrink() : child,
          ),
          child: Text(
            '$lugar',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// FILA DEL RANKING (4.º en adelante)
// ---------------------------------------------------------------------------

class _RankRow extends StatelessWidget {
  final int posicion;
  final User user;
  final int puntos;
  final int perdidos;

  const _RankRow({
    required this.posicion,
    required this.user,
    required this.puntos,
    required this.perdidos,
  });

  @override
  Widget build(BuildContext context) {
    final neto = puntos - perdidos;
    return CardBox(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$posicion',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          UserAvatar(user: user, radius: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user.nombre,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$neto XP',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: AppColors.verde,
                ),
              ),
              if (perdidos > 0)
                Text(
                  '−$perdidos xp perdidos',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.rojo,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// RÉCORDS FAMILIARES (niño)
// ---------------------------------------------------------------------------

class _Recorde {
  final IconData icon;
  final String titulo;
  final String valor;
  final String detalle;
  final Color color;

  /// Días de racha (solo el récord de fuego): la llama 3D crece con ellos.
  final int? valorRacha;

  const _Recorde({
    required this.icon,
    required this.titulo,
    required this.valor,
    required this.detalle,
    required this.color,
    this.valorRacha,
  });
}

/// Récords familiares: tarjetas grandes con icono 3D animado, el valor
/// gigante con el color del récord y el nombre de quien lo tiene. Cada
/// tarjeta entra deslizándose (entrada escalonada).
class _RecordsSeccion extends StatelessWidget {
  final List<_Recorde> records;
  const _RecordsSeccion({required this.records});

  static Widget _icono(IconData icon, {int? racha}) {
    if (icon == Icons.local_fire_department) {
      return Flame3D(size: 36, animar: true, racha: racha);
    }
    if (icon == Icons.bolt) return Bolt3D(size: 36, animar: true);
    if (icon == Icons.check_circle) {
      return ClipboardCheck3D(size: 36, animar: true);
    }
    return Trophy3D(size: 36, animar: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Récords familiares',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 8),
            Trophy3D(size: 22, animar: true),
          ],
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < records.length; i++)
          PlayfulEntrance(
            delayMs: i * 110,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CardBox(
                color: records[i].color.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: records[i].color.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _icono(records[i].icon, racha: records[i].valorRacha),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            records[i].titulo,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: textoSuaveTema(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            records[i].valor,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: records[i].color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.person_rounded,
                                size: 14,
                                color: textoSuaveTema(context),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  records[i].detalle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: textoSuaveTema(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SALÓN DE LA FAMA (insignias + logros en camino)
// ---------------------------------------------------------------------------

class _MetaProgreso {
  final String nombre;
  final int valor;
  final int max;

  /// Nombre del icono 3D de la colección (ver `insignia3D`).
  final String icono;

  const _MetaProgreso({
    required this.nombre,
    required this.valor,
    required this.max,
    required this.icono,
  });
}

class _FamaTab extends StatefulWidget {
  final User user;
  const _FamaTab({required this.user});

  @override
  State<_FamaTab> createState() => _FamaTabState();
}

class _FamaTabState extends State<_FamaTab> {
  List<(badge_model.Badge, int, int, bool)> _insignias = [];
  List<_MetaProgreso> _metas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final app = context.read<AppProvider>();
    final id = widget.user.id;
    final historial = id != null
        ? await app.historialDe(id)
        : <(Task, Assignment)>[];
    final catalogo = await app.listarInsignias();
    final tareas = await app.listarTareas();
    final retos = await app.listarRetos();

    final detalle = GamificationService.detalleInsignias(
      catalogo: catalogo,
      puntos: widget.user.puntos,
      racha: widget.user.racha,
      aprobadas: historial.map((h) => h.$2).toList(),
      tareas: tareas,
    );

    // Días con al menos una tarea aprobada en los últimos 7 días.
    final corte = DateTime.now().subtract(const Duration(days: 7));
    final dias = <String>{};
    var retosAprobados = 0;
    final aprobadas = <Assignment>[];
    final porDia = <String, int>{};
    for (final h in historial) {
      final a = h.$2;
      final f = a.fechaAprobada;
      if (a.aprobada) {
        aprobadas.add(a);
        if (f != null) {
          final k = '${f.year}-${f.month}-${f.day}';
          porDia[k] = (porDia[k] ?? 0) + 1;
        }
      }
      if (a.aprobada && f != null && f.isAfter(corte)) {
        dias.add('${f.year}-${f.month}-${f.day}');
      }
    }
    for (final r in retos) {
      if (r.aprobados.contains(widget.user.id)) retosAprobados++;
    }

    final logradas = detalle.where((d) => d.$4).length;
    var maxPorDia = 0;
    for (final n in porDia.values) {
      if (n > maxPorDia) maxPorDia = n;
    }

    // "Logros en camino": metas editables por el admin (caja `logros`).
    final logros = await app.listarLogros();
    int valorDe(String tipo) {
      switch (tipo) {
        case 'semana_perfecta':
          return dias.length > 7 ? 7 : dias.length;
        case 'retos':
          return retosAprobados;
        case 'racha':
          return widget.user.racha;
        case 'insignias':
          return logradas;
        case 'tareas':
          return aprobadas.length;
        case 'puntos':
          return widget.user.puntos;
        case 'nivel':
          return widget.user.nivel;
        case 'diarias':
          return maxPorDia;
        default:
          return 0;
      }
    }

    if (!mounted) return;
    setState(() {
      _insignias = detalle;
      _metas = [
        for (final l in logros)
          _MetaProgreso(
            nombre: l.nombre,
            valor: valorDe(l.tipo),
            max: l.meta <= 0 ? 1 : l.meta,
            icono: l.icono,
          ),
      ];
      _cargando = false;
    });
  }

  /// Panel de gestión de insignias (solo admin): alta, edición y borrado.
  /// En pantallas anchas se abre como panel lateral; en angostas como sheet.
  Future<void> _gestionarInsignias() async {
    final ancho = MediaQuery.sizeOf(context).width;
    final panel = _GestionarInsignias(onChanged: _cargar);
    if (ancho >= 700) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          alignment: Alignment.centerRight,
          insetPadding: EdgeInsets.zero,
          child: SizedBox(
            width: 400,
            height: MediaQuery.sizeOf(ctx).height,
            child: panel,
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.8,
          child: panel,
        ),
      );
    }
    if (mounted) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_insignias.isEmpty) {
      return const EmptyState(
        mascota: MascotType.dragito,
        icon: Icons.emoji_events,
        message: 'Aún no hay insignias.',
        hint: 'Completa tareas para empezar a coleccionar.',
      );
    }
    final logradas = _insignias.where((d) => d.$4).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // ---- Insignias ----
        Row(
          children: [
            Expanded(
              child: Text(
                'Insignias ($logradas de ${_insignias.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (widget.user.esAdmin)
              IconButton(
                onPressed: _gestionarInsignias,
                tooltip: 'Gestionar insignias y logros',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.tune_rounded, size: 22),
              ),
            Trophy3D(size: 26),
            const SizedBox(width: 4),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.8,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final d in _insignias)
              CardBox(
                margin: EdgeInsets.zero,
                color: d.$4
                    ? amarilloFondoTema(context)
                    : superficieTema(context),
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                child: InsigniaParche(
                  icono: d.$1.icono,
                  nombre: d.$1.nombre,
                  lograda: d.$4,
                  actual: d.$2,
                  meta: d.$3,
                  size: 66,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // ---- Logros en camino (metas editables por el admin) ----
        const Text(
          'Logros en camino',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        for (final (i, m) in _metas.indexed)
          PlayfulEntrance(
            delayMs: i * 90,
            child: CardBox(
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      insignia3D(m.icono, size: 24, animar: false),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          m.nombre,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        '${m.valor}/${m.max}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: m.valor >= m.max
                              ? AppColors.verde
                              : textoSuaveTema(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ProgressLine(
                    m.max <= 0 ? 0 : (m.valor / m.max).clamp(0.0, 1.0),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// GESTIÓN DE INSIGNIAS (solo admin): CRUD persistente del catálogo de logros.
// ---------------------------------------------------------------------------

/// Colección de iconos disponibles para las insignias (22).
const List<String> _iconosInsignia = [
  'emoji_events',
  'military_tech',
  'star',
  'local_fire_department',
  'flash_on',
  'schedule',
  'task_alt',
  'checklist',
  'flag',
  'check_circle',
  'favorite',
  'school',
  'menu_book',
  'handshake',
  'groups',
  'home',
  'gift',
  'key',
  'park',
  'cleaning_services',
  'restaurant',
  'inventory_2',
];

class _GestionarInsignias extends StatefulWidget {
  final Future<void> Function()? onChanged;
  const _GestionarInsignias({this.onChanged});

  @override
  State<_GestionarInsignias> createState() => _GestionarInsigniasState();
}

class _GestionarInsigniasState extends State<_GestionarInsignias> {
  List<badge_model.Badge> _lista = [];
  List<logro_model.Logro> _logros = [];
  bool _cargando = true;

  /// 0 = insignias, 1 = logros en camino.
  int _pestana = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final app = context.read<AppProvider>();
    final lista = await app.listarInsignias();
    final logros = await app.listarLogros();
    if (!mounted) return;
    setState(() {
      _lista = lista;
      _logros = logros;
      _cargando = false;
    });
    await widget.onChanged?.call();
  }

  Future<void> _nueva() async {
    final app = context.read<AppProvider>();
    if (_pestana == 0) {
      final nueva = await showDialog<badge_model.Badge>(
        context: context,
        builder: (_) => const _InsigniaFormDialog(),
      );
      if (nueva == null) return;
      await app.crearInsignia(nueva);
    } else {
      final nuevo = await showDialog<logro_model.Logro>(
        context: context,
        builder: (_) => const _LogroFormDialog(),
      );
      if (nuevo == null) return;
      await app.crearLogro(nuevo);
    }
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              const Icon(Icons.emoji_events_outlined, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Gestionar insignias y logros',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      PillSegment(
                        index: _pestana,
                        onChanged: (i) => setState(() => _pestana = i),
                        items: const [
                          (icon: Icons.emoji_events_outlined, label: 'Insignias'),
                          (icon: Icons.flag_outlined, label: 'Logros'),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                        child: Text(
                          _pestana == 0
                              ? 'Cada insignia mide una métrica con una meta. '
                                  'Los integrantes la ganan al llegar a la meta.'
                              : 'Cada logro es una meta de progreso que se '
                                  'muestra en "Logros en camino" del salón de '
                                  'la fama. El avance depende del tipo elegido.',
                          style: TextStyle(
                            fontSize: 12,
                            color: textoSuaveTema(context),
                          ),
                        ),
                      ),
                      if (_pestana == 0)
                        for (final b in _lista)
                          _InsigniaCard(insignia: b, onChanged: _cargar)
                      else
                        for (final l in _logros)
                          _LogroCard(logro: l, onChanged: _cargar),
                    ],
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: DuoButton(
              label: _pestana == 0 ? 'Nueva insignia' : 'Nuevo logro',
              icon: Icons.add,
              onPressed: _nueva,
            ),
          ),
        ),
      ],
    );
  }
}

class _InsigniaCard extends StatelessWidget {
  final badge_model.Badge insignia;
  final Future<void> Function() onChanged;

  const _InsigniaCard({required this.insignia, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DuoCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: amarilloFondoTema(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: insignia3D(insignia.icono, size: 24, animar: false),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insignia.nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${badge_model.etiquetaMetrica(insignia.metrica)} · meta '
                  '${insignia.meta}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: textoSuaveTema(context),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.azul),
            onPressed: () => _editar(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: AppColors.rojo),
            onPressed: () => _eliminar(context),
          ),
        ],
      ),
    );
  }

  Future<void> _editar(BuildContext context) async {
    final app = context.read<AppProvider>();
    final editada = await showDialog<badge_model.Badge>(
      context: context,
      builder: (_) => _InsigniaFormDialog(inicial: insignia),
    );
    if (editada == null) return;
    await app.editarInsignia(editada);
    await onChanged();
  }

  Future<void> _eliminar(BuildContext context) async {
    final app = context.read<AppProvider>();
    final id = insignia.id;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar insignia?'),
        content: Text(
          '"${insignia.nombre}" dejará de existir. '
          'Las que ya se ganaron se conservan.',
        ),
        actions: [
          DialogActions(
            onCancel: () => Navigator.pop(ctx, false),
            primary: DuoButton(
              fullWidth: false,
              label: 'Eliminar',
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await app.eliminarInsignia(id);
    await onChanged();
  }
}

class _InsigniaFormDialog extends StatefulWidget {
  final badge_model.Badge? inicial;
  const _InsigniaFormDialog({this.inicial});

  @override
  State<_InsigniaFormDialog> createState() => _InsigniaFormDialogState();
}

class _InsigniaFormDialogState extends State<_InsigniaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _descripcion;
  late final TextEditingController _meta;
  late String _icono;
  late String _metrica;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.inicial?.nombre ?? '');
    _descripcion = TextEditingController(
      text: widget.inicial?.descripcion ?? '',
    );
    _meta = TextEditingController(
      text: (widget.inicial?.meta ?? 1).toString(),
    );
    _icono = widget.inicial?.icono ?? 'emoji_events';
    _metrica = widget.inicial?.metrica ?? 'tareas';
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _meta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.inicial == null ? 'Nueva insignia' : 'Editar insignia',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombre,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descripcion,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _metrica,
                decoration: const InputDecoration(labelText: 'Mide'),
                items: [
                  for (final m in badge_model.metricasInsignia)
                    DropdownMenuItem(
                      value: m,
                      child: Text(badge_model.etiquetaMetrica(m)),
                    ),
                ],
                onChanged: (v) => setState(() => _metrica = v ?? 'tareas'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _meta,
                decoration: const InputDecoration(labelText: 'Meta'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = v == null ? null : int.tryParse(v);
                  if (n == null || n < 1) return 'Número válido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Icono',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: amarilloFondoTema(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: insignia3D(_icono, size: 34, animar: false),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final i in _iconosInsignia)
                    GestureDetector(
                      onTap: () => setState(() => _icono = i),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _icono == i
                              ? amarilloFondoTema(context)
                              : superficieTema(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _icono == i
                                ? AppColors.amarillo
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: insignia3D(i, size: 26, animar: false),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        DialogActions(
          onCancel: () => Navigator.pop(context),
          primary: DuoButton(
            fullWidth: false,
            label: 'Guardar',
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.pop(
                context,
                badge_model.Badge(
                  id: widget.inicial?.id,
                  nombre: _nombre.text.trim(),
                  descripcion: _descripcion.text.trim(),
                  icono: _icono,
                  meta: int.tryParse(_meta.text) ?? 1,
                  metrica: _metrica,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// LOGROS EN CAMINO (solo admin): CRUD persistente de las metas de progreso.
// ---------------------------------------------------------------------------

class _LogroCard extends StatelessWidget {
  final logro_model.Logro logro;
  final Future<void> Function() onChanged;

  const _LogroCard({required this.logro, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DuoCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: amarilloFondoTema(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: insignia3D(logro.icono, size: 24, animar: false),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  logro.nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${logro_model.etiquetaTipoLogro(logro.tipo)} · meta '
                  '${logro.meta}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: textoSuaveTema(context),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.azul),
            onPressed: () => _editar(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: AppColors.rojo),
            onPressed: () => _eliminar(context),
          ),
        ],
      ),
    );
  }

  Future<void> _editar(BuildContext context) async {
    final app = context.read<AppProvider>();
    final editado = await showDialog<logro_model.Logro>(
      context: context,
      builder: (_) => _LogroFormDialog(inicial: logro),
    );
    if (editado == null) return;
    await app.editarLogro(editado);
    await onChanged();
  }

  Future<void> _eliminar(BuildContext context) async {
    final app = context.read<AppProvider>();
    final id = logro.id;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar logro?'),
        content: Text(
          '"${logro.nombre}" dejará de mostrarse en '
          '"Logros en camino".',
        ),
        actions: [
          DialogActions(
            onCancel: () => Navigator.pop(ctx, false),
            primary: DuoButton(
              fullWidth: false,
              label: 'Eliminar',
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await app.eliminarLogro(id);
    await onChanged();
  }
}

class _LogroFormDialog extends StatefulWidget {
  final logro_model.Logro? inicial;
  const _LogroFormDialog({this.inicial});

  @override
  State<_LogroFormDialog> createState() => _LogroFormDialogState();
}

class _LogroFormDialogState extends State<_LogroFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _meta;
  late String _icono;
  late String _tipo;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.inicial?.nombre ?? '');
    _meta = TextEditingController(
      text: (widget.inicial?.meta ?? 1).toString(),
    );
    _icono = widget.inicial?.icono ?? 'emoji_events';
    _tipo = widget.inicial?.tipo ?? 'tareas';
  }

  @override
  void dispose() {
    _nombre.dispose();
    _meta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.inicial == null ? 'Nuevo logro' : 'Editar logro',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombre,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _tipo,
                decoration: const InputDecoration(labelText: 'Mide'),
                items: [
                  for (final t in logro_model.tiposLogro)
                    DropdownMenuItem(
                      value: t,
                      child: Text(logro_model.etiquetaTipoLogro(t)),
                    ),
                ],
                onChanged: (v) => setState(() => _tipo = v ?? 'tareas'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _meta,
                decoration: const InputDecoration(labelText: 'Meta'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = v == null ? null : int.tryParse(v);
                  if (n == null || n < 1) return 'Número válido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Icono',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: amarilloFondoTema(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: insignia3D(_icono, size: 34, animar: false),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final i in _iconosInsignia)
                    GestureDetector(
                      onTap: () => setState(() => _icono = i),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _icono == i
                              ? amarilloFondoTema(context)
                              : superficieTema(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _icono == i
                                ? AppColors.amarillo
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: insignia3D(i, size: 26, animar: false),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        DialogActions(
          onCancel: () => Navigator.pop(context),
          primary: DuoButton(
            fullWidth: false,
            label: 'Guardar',
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.pop(
                context,
                logro_model.Logro(
                  id: widget.inicial?.id,
                  nombre: _nombre.text.trim(),
                  icono: _icono,
                  tipo: _tipo,
                  meta: int.tryParse(_meta.text) ?? 1,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
