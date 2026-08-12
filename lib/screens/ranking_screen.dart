import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/duo_widgets.dart';
import '../widgets/empty_state.dart';
import '../widgets/user_avatar.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _cargando = true;
  List<(User, int, int)> _rankingSemanal = []; // (usuario, pts, perdidos)
  List<(User, int, int)> _rankingMensual = [];
  List<(DateTime, int)> _puntosGlobal = [];
  List<_Recorde> _fama = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<AppProvider>().addListener(_onChange);
    _cargarDatos();
  }

  void _onChange() {
    if (mounted) _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final app = context.read<AppProvider>();
    final semanal = await _conPerdidos(app, 'semanal');
    final mensual = await _conPerdidos(app, 'mensual');
    final puntosGlobal = await app.puntosPorDiaGlobal(dias: 7);
    final fama = await _calcularFama(app);
    if (!mounted) return;
    setState(() {
      _rankingSemanal = semanal;
      _rankingMensual = mensual;
      _puntosGlobal = puntosGlobal;
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
    return resultado;
  }

  @override
  void dispose() {
    context.read<AppProvider>().removeListener(_onChange);
    _tabController.dispose();
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
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Semanal', icon: Icon(Icons.date_range_outlined)),
                Tab(text: 'Mensual', icon: Icon(Icons.calendar_today_outlined)),
                Tab(text: 'Salón de la Fama', icon: Icon(Icons.emoji_events)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _RankingList(
                  title: 'Top 10 Semanal',
                  items: _rankingSemanal,
                  puntosGlobal: _puntosGlobal,
                ),
                _RankingList(title: 'Top 10 Mensual', items: _rankingMensual),
                _FamaList(records: _fama),
              ],
            ),
          ),
        ],
      ),
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
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.grisOscuro),
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
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.grisMedio),
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
  final List<(DateTime, int)>? puntosGlobal;

  const _RankingList({required this.title, required this.items, this.puntosGlobal});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            title,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.grisOscuro),
          ),
        ),
        if (puntosGlobal != null && puntosGlobal!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: _GraficaPuntos(datos: puntosGlobal!),
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
                    return _RankRow(
                      posicion: i + 1,
                      user: user,
                      puntos: puntos,
                      perdidos: perdidos,
                      destacado: esTop3,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FamaList extends StatelessWidget {
  final List<_Recorde> records;

  const _FamaList({required this.records});

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
        const Center(
          child: Text(
            'Los récords de la familia',
            style: TextStyle(color: AppColors.grisMedio),
          ),
        ),
        const SizedBox(height: 20),
        for (final r in records)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DuoCard(
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
                      children: [
                        Text(
                          r.titulo,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.grisMedio),
                        ),
                        Text(
                          r.detalle,
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
            ),
          ),
      ],
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
                      const TextStyle(fontSize: 12, color: AppColors.grisMedio),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$puntos XP',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.verdeOscuro),
              ),
              if (perdidos > 0)
                Text(
                  '-$perdidos castigados',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.rojo),
                )
              else
                Text('Nivel ${user.nivel}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.grisMedio)),
            ],
          ),
        ],
      ),
    );
  }
}
