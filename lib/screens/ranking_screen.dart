import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/app_provider.dart';
import '../services/gamification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/duo_widgets.dart';
import '../widgets/empty_state.dart';
import '../widgets/user_avatar.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  int _pestana = 0; // 0 semanal · 1 mensual · 2 salón de la fama
  bool _cargando = true;
  List<(User, int, int)> _rankingSemanal = []; // (usuario, pts, perdidos)
  List<(User, int, int)> _rankingMensual = [];
  List<(User, int, int)> _rankingAnterior = []; // semana anterior (para ligas)
  int _puntosFamiliaSemana = 0;
  bool _ligasBloqueadas = true;
  List<(DateTime, int)> _puntosGlobal = [];
  List<(DateTime, int)> _puntosGlobal30 = [];
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
    final puntosGlobal = await app.puntosPorDiaGlobal(dias: 7);
    final puntosGlobal30 = await app.puntosPorDiaGlobal(dias: 30);
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
      _puntosGlobal = puntosGlobal;
      _puntosGlobal30 = puntosGlobal30;
      _fama = fama;
      _cargando = false;
    });
  }

  Future<List<_Recorde>> _calcularFama(AppProvider app) async {
    final usuarios = await app.listarIntegrantes();
    if (usuarios.isEmpty) return [];

    // Racha más larga.
    final racha = usuarios.reduce((a, b) => b.racha > a.racha ? b : a);
    // Más puntos XP acumulados.
    final xp = usuarios.reduce((a, b) => b.puntos > a.puntos ? b : a);
    // Más tareas completadas en la historia.
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
        icon: Icons.stars,
        titulo: 'Más puntos XP',
        valor: '${xp.puntos} pts',
        detalle: xp.nombre,
        color: AppColors.amarillo,
      ),
      _Recorde(
        icon: Icons.check_circle,
        titulo: 'Más tareas completadas',
        valor: '$maxCompletadas tareas',
        detalle: masTareas?.nombre ?? '',
        color: AppColors.verde,
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
    resultado.sort((a, b) =>
        (b.$2 - b.$3).compareTo(a.$2 - a.$3));
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

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Semanal'),
                  icon: Icon(Icons.date_range_outlined, size: 18),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Mensual'),
                  icon: Icon(Icons.calendar_today_outlined, size: 18),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text('Salón de la Fama'),
                  icon: Icon(Icons.emoji_events, size: 18),
                ),
              ],
              selected: {_pestana},
              onSelectionChanged: (s) =>
                  setState(() => _pestana = s.first),
            ),
          ),
          Expanded(
            child: switch (_pestana) {
              0 => _VistaSemanal(
                  items: _rankingSemanal,
                  puntosGlobal: _puntosGlobal,
                  ligas: _PanelLigas(
                    bloqueadas: _ligasBloqueadas,
                    ligaUsuario: _ligaUsuario.$1,
                    posicion: _ligaUsuario.$2,
                    totalIntegrantes: _rankingAnterior.length,
                    puntosFamilia: _puntosFamiliaSemana,
                    metaFamilia: _metaFamiliar,
                  ),
                ),
              1 => _RankingList(
                  title: 'Top 10 Mensual',
                  items: _rankingMensual,
                  resumen: _ResumenPeriodo(datos: _puntosGlobal30),
                ),
              _ => _FamaGrid(records: _fama),
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PANEL DE LIGAS
// ---------------------------------------------------------------------------

class _PanelLigas extends StatelessWidget {
  final bool bloqueadas;
  final String? ligaUsuario;
  final int posicion;
  final int totalIntegrantes;
  final int puntosFamilia;
  final int metaFamilia;

  const _PanelLigas({
    required this.bloqueadas,
    required this.ligaUsuario,
    required this.posicion,
    required this.totalIntegrantes,
    required this.puntosFamilia,
    required this.metaFamilia,
  });

  static const _definiciones = <(String, IconData, Color)>[
    ('Bronce', Icons.shield, Color(0xFFCD7F32)),
    ('Plata', Icons.shield, Color(0xFFB8B8B8)),
    ('Oro', Icons.emoji_events, Color(0xFFFFB300)),
    ('Obsidiana', Icons.diamond, Color(0xFF7B68EE)),
  ];

  int get _diasRestantes => 6 - (DateTime.now().weekday % 7);

  @override
  Widget build(BuildContext context) {
    final restantes = _diasRestantes;
    final progreso =
        (puntosFamilia / metaFamilia).clamp(0.0, 1.0);
    final texto = textoTema(context);
    final suave = textoSuaveTema(context);

    return DuoCard(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events,
                  color: AppColors.amarillo, size: 20),
              const SizedBox(width: 8),
              Text(
                'Ligas',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: texto),
              ),
              const Spacer(),
              Icon(Icons.schedule, size: 14, color: suave),
              const SizedBox(width: 4),
              Text(
                restantes <= 0
                    ? 'Último día'
                    : 'Quedan $restantes días',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: suave),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (nombre, icono, color) in _definiciones) ...[
                Expanded(
                  child: _LigaChip(
                    nombre: nombre,
                    icono: icono,
                    color: color,
                    activa: nombre == ligaUsuario,
                    atenuada: bloqueadas,
                  ),
                ),
                if (nombre != 'Obsidiana') const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (bloqueadas)
            Row(
              children: [
                Icon(Icons.lock_outline, size: 16, color: suave),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Completa una semana de tareas para desbloquear tu liga.',
                    style: TextStyle(fontSize: 12, color: suave),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(Icons.emoji_events, size: 16, color: suave),
                const SizedBox(width: 6),
                Text(
                  ligaUsuario == null
                      ? 'Sin liga esta semana'
                      : '$ligaUsuario · puesto $posicion de $totalIntegrantes',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: suave),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Meta familiar',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: suave),
                ),
              ),
              Text(
                '$puntosFamilia/$metaFamilia pts',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: progreso >= 1.0
                        ? AppColors.verdeOscuro
                        : suave),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 10,
              backgroundColor: AppColors.linea,
              color: progreso >= 1.0 ? AppColors.verde : AppColors.azul,
            ),
          ),
        ],
      ),
    );
  }
}

class _LigaChip extends StatelessWidget {
  final String nombre;
  final IconData icono;
  final Color color;
  final bool activa;
  final bool atenuada;

  const _LigaChip({
    required this.nombre,
    required this.icono,
    required this.color,
    required this.activa,
    required this.atenuada,
  });

  @override
  Widget build(BuildContext context) {
    final opacidad = atenuada ? 0.35 : 1.0;
    return Opacity(
      opacity: opacidad,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: activa
              ? color.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: activa ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              nombre,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: textoTema(context),
              ),
            ),
            if (activa) ...[
              const SizedBox(height: 2),
              Text(
                'Tu liga',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ] else
              const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// VISTA SEMANAL (panel + gráfica + podio + filas)
// ---------------------------------------------------------------------------

class _VistaSemanal extends StatelessWidget {
  final List<(User, int, int)> items;
  final List<(DateTime, int)> puntosGlobal;
  final _PanelLigas ligas;

  const _VistaSemanal({
    required this.items,
    required this.puntosGlobal,
    required this.ligas,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ligas,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            'Top 10 Semanal',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textoTema(context)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            'XP del periodo = tareas + retos − castigos. El orden es por el resultado final (neto).',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: textoSuaveTema(context)),
          ),
        ),
        if (puntosGlobal.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: _GraficaPuntos(datos: puntosGlobal),
          ),
        Expanded(
          child: items.isEmpty
              ? EmptyState(
                  icon: Icons.leaderboard,
                  message: 'No hay datos disponibles',
                  hint: 'Completa tareas para ver el ranking.',
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    if (items.length >= 3) ...[
                      _Podio(top3: items.sublist(0, 3)),
                      const SizedBox(height: 8),
                    ],
                    for (var i = items.length >= 3 ? 3 : 0; i < items.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _RankRow(
                          posicion: i + 1,
                          user: items[i].$1,
                          puntos: items[i].$2,
                          perdidos: items[i].$3,
                          destacado: false,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// PODIO TOP 3 (estilo 3D)
// ---------------------------------------------------------------------------

class _Podio extends StatelessWidget {
  final List<(User, int, int)> top3;

  const _Podio({required this.top3});

  @override
  Widget build(BuildContext context) {
    // Orden visual clásico: 2.º, 1.º, 3.º.
    final orden = [
      (top3[1], 2, 78.0, const Color(0xFFB8B8B8)),
      (top3[0], 1, 104.0, const Color(0xFFFFB300)),
      (top3[2], 3, 62.0, const Color(0xFFCD7F32)),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (item, lugar, alto, color) in orden) ...[
          Expanded(
            child: _PodioPuesto(
              item: item,
              lugar: lugar,
              alto: alto,
              color: color,
            ),
          ),
          if (lugar != 3) const SizedBox(width: 8),
        ],
      ],
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

  String get _medalla => switch (lugar) {
        1 => '🥇',
        2 => '🥈',
        _ => '🥉',
      };

  @override
  Widget build(BuildContext context) {
    final (user, puntos, perdidos) = item;
    final neto = puntos - perdidos;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_medalla, style: const TextStyle(fontSize: 26)),
        const SizedBox(height: 4),
        UserAvatar(user: user, radius: lugar == 1 ? 26 : 20),
        const SizedBox(height: 4),
        Text(
          user.nombre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        Text(
          '= $neto pts',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: neto >= 0 ? AppColors.verdeOscuro : AppColors.rojo,
          ),
        ),
        const SizedBox(height: 6),
        // Bloque "3D": cara superior clara + cuerpo con borde inferior grueso.
        Container(
          height: alto,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.25),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10)),
            border: Border(
              top: BorderSide(color: color, width: 3),
              bottom: BorderSide(color: color, width: 6),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                offset: const Offset(0, 5),
                blurRadius: 0,
              ),
            ],
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '$lugar.º',
            style: TextStyle(
              fontSize: lugar == 1 ? 20 : 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

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

/// Resumen de puntos de la familia en un periodo (total y días activos).
class _ResumenPeriodo extends StatelessWidget {
  final List<(DateTime, int)> datos;

  const _ResumenPeriodo({required this.datos});

  @override
  Widget build(BuildContext context) {
    final total = datos.fold<int>(0, (s, e) => s + e.$2);
    final diasActivos = datos.where((e) => e.$2 > 0).length;
    return DuoCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.verdeFondo,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resumen (30 días)',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: textoSuaveTema(context))),
                const SizedBox(height: 2),
                Text('$total pts familia',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.verdeOscuro)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text('$diasActivos',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.grisOscuro)),
                Text('días activos',
                    style: TextStyle(fontSize: 11, color: textoSuaveTema(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Gráfica de barras simple: puntos ganados por día (últimos 7 días).
class _GraficaPuntos extends StatelessWidget {
  final List<(DateTime, int)> datos;

  const _GraficaPuntos({required this.datos});

  static const _diasAbrev = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final maxV = datos.fold<int>(0, (m, d) => d.$2 > m ? d.$2 : m);

    return DuoCard(
      padding: const EdgeInsets.all(16),
      color: AppColors.verdeFondo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, color: AppColors.verdeOscuro, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Puntos de la familia (7 días)',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: AppColors.verdeOscuro),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < datos.length; i++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${datos[i].$2}',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: textoTema(context)),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: maxV == 0
                              ? 4
                              : (datos[i].$2 / maxV) * 90,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: datos[i].$2 > 0
                                ? AppColors.verde
                                : AppColors.verde.withValues(alpha: 0.25),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _diasAbrev[datos[i].$1.weekday - 1],
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: textoSuaveTema(context)),
                        ),
                      ],
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

class _RankingList extends StatelessWidget {
  final String title;
  final List<(User, int, int)> items;
  final Widget? resumen;

  const _RankingList({
    required this.title,
    required this.items,
    this.resumen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            title,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textoTema(context)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            'XP del periodo = tareas + retos − castigos. El orden es por el resultado final (neto).',
            style: TextStyle(fontSize: 11, color: textoSuaveTema(context)),
          ),
        ),
        if (resumen != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: resumen!,
          ),
        Expanded(
          child: items.isEmpty
              ? EmptyState(
                  icon: Icons.leaderboard,
                  message: 'No hay datos disponibles',
                  hint: 'Completa tareas para ver el ranking.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final (user, puntos, perdidos) = items[i];
                    final esTop3 = i < 3;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _RankRow(
                        posicion: i + 1,
                        user: user,
                        puntos: puntos,
                        perdidos: perdidos,
                        destacado: esTop3,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Salón de la Fama: récords de la familia en cuadrícula.
class _FamaGrid extends StatelessWidget {
  final List<_Recorde> records;

  const _FamaGrid({required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const EmptyState(
        icon: Icons.emoji_events,
        message: 'Aún no hay campeones.',
        hint: 'Completa tareas y mantén tu racha para entrar al Salón de la Fama.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.emoji_events, size: 46, color: Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Salón de la Fama',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Los récords de la familia',
            style: TextStyle(color: textoSuaveTema(context)),
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final columnas = constraints.maxWidth >= 700 ? 3 : 1;
            if (columnas == 1) {
              return Column(
                children: [
                  for (final r in records)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _FamaCard(r: r),
                    ),
                ],
              );
            }
            return GridView.count(
              crossAxisCount: columnas,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.6,
              children: [for (final r in records) _FamaCard(r: r)],
            );
          },
        ),
      ],
    );
  }
}

class _FamaCard extends StatelessWidget {
  final _Recorde r;

  const _FamaCard({required this.r});

  @override
  Widget build(BuildContext context) {
    return DuoCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: r.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(r.icon, color: r.color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  r.titulo,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: textoSuaveTema(context)),
                ),
                Text(
                  r.detalle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Text(
            r.valor,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: r.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final int posicion;
  final User user;
  final int puntos;
  final int perdidos;
  final bool destacado;

  const _RankRow({
    required this.posicion,
    required this.user,
    required this.puntos,
    required this.perdidos,
    required this.destacado,
  });

  String get _medalla {
    switch (posicion) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final neto = puntos - perdidos;
    return DuoCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: destacado ? null : Colors.white,
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              _medalla.isNotEmpty ? _medalla : '$posicion',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: _medalla.isNotEmpty ? 24 : 18,
                fontWeight: FontWeight.w800,
                color: destacado ? AppColors.grisOscuro : AppColors.grisMedio,
              ),
            ),
          ),
          const SizedBox(width: 10),
          UserAvatar(user: user, radius: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.nombre,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15),
                ),
                Text(
                  '${user.edad} años · 🔥 ${user.racha} días',
                  style:
                      TextStyle(fontSize: 12, color: textoSuaveTema(context)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$puntos',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.verdeOscuro)),
                  Text(' XP',
                      style: TextStyle(
                          fontSize: 11, color: textoSuaveTema(context))),
                ],
              ),
              if (perdidos > 0)
                Text(
                  '−$perdidos castigos',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.rojo),
                )
              else
                Text('Nivel ${user.nivel}',
                    style: TextStyle(
                        fontSize: 11, color: textoSuaveTema(context))),
              Text(
                '= $neto pts',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: neto >= 0 ? AppColors.verdeOscuro : AppColors.rojo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
