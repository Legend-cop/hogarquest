import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/assignment.dart';
import '../models/badge.dart' as badge_model;
import '../models/task.dart';
import '../models/user.dart';
import '../providers/app_provider.dart';
import '../services/gamification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/hq_design.dart';
import '../widgets/icons3d.dart';
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
      AppProvider app, String periodo) async {
    final base = await app.ranking(periodo);
    final resultado = <(User, int, int)>[];
    for (final (user, pts) in base) {
      final perdidos = await app.puntosCastigadosRecientes(user.id!,
          dias: periodo == 'semanal' ? 7 : 30);
      resultado.add((user, pts, perdidos));
    }
    // Se ordena por el NETO del periodo (ganado - perdido), que es el que
    // le queda al integrante.
    resultado.sort((a, b) => (b.$2 - b.$3).compareTo(a.$2 - a.$3));
    return resultado;
  }

  /// Liga actual del usuario según el ranking de la semana anterior.
  (String?, int) get _ligaUsuario {
    final id = _provider.usuarioActual?.id;
    if (id == null || _ligasBloqueadas) return (null, -1);
    final idx = _rankingAnterior.indexWhere((e) => e.$1.id == id);
    if (idx < 0) return (null, -1);
    return (
      GamificationService.ligaDe(idx + 1, _rankingAnterior.length),
      idx + 1,
    );
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PageTitle(esAdmin ? 'Ranking' : 'Mi ranking'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentTabs(
              const ['Familiar', 'Liga', 'Fama'],
              _seccion,
              (i) => setState(() => _seccion = i),
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

  Widget _vistaFamiliar(
      {required bool esAdmin,
      required List<(User, int, int)> items,
      required User user}) {
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
            child: SegmentTabs(
              const ['Semanal', 'Mensual'],
              _periodo,
              (i) => setState(() => _periodo = i),
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
        if (esAdmin)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'XP = tareas + retos − castigos',
              style: TextStyle(
                fontSize: 12,
                color: textoSuaveTema(context),
              ),
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
          child: _LigasSeccion(
            ligaUsuario: liga,
            bloqueadas: _ligasBloqueadas,
          ),
        ),
        if (_ligasBloqueadas)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Icon(Icons.lock_outline,
                    size: 16, color: textoSuaveTema(context)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Completa una semana de tareas para desbloquear tu liga.',
                    style:
                        TextStyle(fontSize: 12, color: textoSuaveTema(context)),
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
    final fuente =
        _rankingAnterior.isNotEmpty ? _rankingAnterior : _rankingSemanal;
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
    final faltan = meta - puntos;
    final prog = meta <= 0 ? 0.0 : (puntos / meta).clamp(0.0, 1.0);
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Meta familiar $puntos/$meta pts',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ProgressLine(prog, color: AppColors.azul),
          if (faltan > 0) ...[
            const SizedBox(height: 10),
            Text(
              'Faltan $faltan puntos para completar la meta juntos.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textoSuaveTema(context),
              ),
            ),
          ],
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

  const _PosicionLiga(
      {required this.liga, required this.posicion, required this.user});

  @override
  Widget build(BuildContext context) {
    return CardBox(
      color: AppColors.amarilloFondo,
      child: Text(
        'Tu posición en Liga $liga: $posicion.º puesto · '
        '${user.nombre} · ${user.puntos} XP acumulados',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: AppColors.grisOscuro,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LIGAS MENSUALES
// ---------------------------------------------------------------------------

/// Sección de ligas estilo referencia: CardBox con el título de la liga
/// actual (18 w900) y fila de medallones; las ligas por alcanzar al 35%.
class _LigasSeccion extends StatelessWidget {
  final String? ligaUsuario;
  final bool bloqueadas;

  const _LigasSeccion({required this.ligaUsuario, required this.bloqueadas});

  static const _definiciones = <(String, Color)>[
    ('Bronce', AppColors.bronce),
    ('Plata', AppColors.plata),
    ('Oro', AppColors.oro),
    ('Platino', Color(0xFF7FD1C7)),
    ('Zafiro', Color(0xFF2B59C3)),
  ];

  @override
  Widget build(BuildContext context) {
    final idx = ligaUsuario == null
        ? -1
        : _definiciones.indexWhere((e) => e.$1 == ligaUsuario);
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ligaUsuario == null ? 'Ligas mensuales' : 'Liga $ligaUsuario',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < _definiciones.length; i++)
                Expanded(
                  child: Opacity(
                    opacity:
                        (bloqueadas || idx < 0 || i > idx) ? 0.35 : 1.0,
                    child: Column(
                      children: [
                        Medal3D(
                          size: i == idx ? 46 : 34,
                          tono: medalTonoDe(_definiciones[i].$1),
                          animar: i == idx,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _definiciones[i].$1,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fila del "Ranking de la liga" estilo referencia: CardBox, número 20 w900,
/// chip "Tu familia" cuando la fila es la propia.
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
    final tinta = esActual ? AppColors.grisOscuro : textoTema(context);
    return CardBox(
      color: esActual ? AppColors.verdeFondo : null,
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
            const Chip(label: Text('Tu familia')),
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
        if (esCampeon)
          const Text('🏆', style: TextStyle(fontSize: 28)),
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
        Container(
          height: alto,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
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

  const _Recorde({
    required this.icon,
    required this.titulo,
    required this.valor,
    required this.detalle,
    required this.color,
  });
}

/// Récords familiares estilo referencia: título 18 w900 + tarjetas con una
/// sola línea "emoji Título: valor · persona".
class _RecordsSeccion extends StatelessWidget {
  final List<_Recorde> records;
  const _RecordsSeccion({required this.records});

  static String _emojiDe(IconData icon) {
    if (icon == Icons.local_fire_department) return '🔥';
    if (icon == Icons.bolt) return '⚡';
    if (icon == Icons.check_circle) return '✅';
    return '⭐';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Récords familiares',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        for (final r in records)
          CardBox(
            child: Text(
              '${_emojiDe(r.icon)} ${r.titulo}: ${r.valor} · ${r.detalle}',
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
  final IconData icon;

  const _MetaProgreso({
    required this.nombre,
    required this.valor,
    required this.max,
    required this.icon,
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
    for (final h in historial) {
      final a = h.$2;
      final f = a.fechaAprobada;
      if (a.aprobada && f != null && f.isAfter(corte)) {
        dias.add('${f.year}-${f.month}-${f.day}');
      }
    }
    for (final r in retos) {
      if (r.aprobados.contains(widget.user.id)) retosAprobados++;
    }

    final logradas = detalle.where((d) => d.$4).length;

    if (!mounted) return;
    setState(() {
      _insignias = detalle;
      _metas = [
        _MetaProgreso(
            nombre: 'Semana perfecta',
            valor: dias.length > 7 ? 7 : dias.length,
            max: 7,
            icon: Icons.calendar_today_outlined),
        _MetaProgreso(
            nombre: 'Maestro de retos',
            valor: retosAprobados,
            max: retos.length,
            icon: Icons.flag_outlined),
        _MetaProgreso(
            nombre: 'Racha legendaria',
            valor: widget.user.racha,
            max: 30,
            icon: Icons.local_fire_department),
        _MetaProgreso(
            nombre: 'Coleccionista',
            valor: logradas,
            max: detalle.length,
            icon: Icons.emoji_events),
      ];
      _cargando = false;
    });
  }

  /// Icono 3D de la insignia por su nombre de icono (sin animación en el
  /// grid para no saturar).
  Widget _icono3D(String nombre, {double size = 28}) =>
      insignia3D(nombre, size: size, animar: false);

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_insignias.isEmpty) {
      return const EmptyState(
        icon: Icons.emoji_events,
        message: 'Aún no hay insignias.',
        hint: 'Completa tareas para empezar a coleccionar.',
      );
    }
    final logradas = _insignias.where((d) => d.$4).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
            Trophy3D(size: 26),
            const SizedBox(width: 4),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final d in _insignias)
              Opacity(
                opacity: d.$4 ? 1 : 0.4,
                child: CardBox(
                  margin: EdgeInsets.zero,
                  color: d.$4 ? AppColors.amarilloFondo : AppColors.fondo,
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _icono3D(d.$1.icono, size: 28),
                      const SizedBox(height: 4),
                      Text(
                        d.$1.nombre,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // ---- Logros en camino ----
        const Text(
          'Logros en camino',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        for (final m in _metas)
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${m.nombre}  ${m.valor}/${m.max}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                ProgressLine(
                  m.max <= 0 ? 0 : (m.valor / m.max).clamp(0.0, 1.0),
                ),
              ],
            ),
          ),
      ],
    );
  }
}


