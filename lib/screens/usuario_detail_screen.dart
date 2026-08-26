import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../models/castigo.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/charts.dart';
import '../widgets/duo_widgets.dart';
import '../widgets/section_header.dart';
import '../widgets/user_avatar.dart';

/// Resumen de la actividad de un integrante: HOY y SEMANA.
/// Lo usa el admin al tocar un usuario.
class DetailUsuarioScreen extends StatefulWidget {
  final int usuarioId;

  const DetailUsuarioScreen({super.key, required this.usuarioId});

  @override
  State<DetailUsuarioScreen> createState() => _DetailUsuarioScreenState();
}

class _DetailUsuarioScreenState extends State<DetailUsuarioScreen> {
  late Map<String, Object?> _resumen;
  bool _cargando = true;
  bool _cargandoResumen = false;

  @override
  void initState() {
    super.initState();
    context.read<AppProvider>().addListener(_onChange);
    _cargar();
  }

  @override
  void dispose() {
    context.read<AppProvider>().removeListener(_onChange);
    super.dispose();
  }

  /// Solo reconstruye si los datos del integrante realmente cambiaron. Así los
  /// avisos periódicos del provider (timer de 30s, sincronización) no provocan
  /// reconstrucciones innecesarias mientras el usuario hace scroll.
  bool _mismoResumen(Map<String, Object?> r) {
    final u1 = _resumen['usuario'] as User?;
    final u2 = r['usuario'] as User?;
    return _resumen['puntosSemana'] == r['puntosSemana'] &&
        _resumen['puntosHoy'] == r['puntosHoy'] &&
        _resumen['aprobadasSemana'] == r['aprobadasSemana'] &&
        _resumen['castigosSemana'] == r['castigosSemana'] &&
        _resumen['pendientes'] == r['pendientes'] &&
        (_resumen['tareasHoy'] as List).length ==
            (r['tareasHoy'] as List).length &&
        u1?.puntos == u2?.puntos &&
        u1?.nivel == u2?.nivel &&
        u1?.racha == u2?.racha &&
        u1?.foto == u2?.foto;
  }

  Future<void> _cargar() async {
    final r =
        await context.read<AppProvider>().resumenIntegrante(widget.usuarioId);
    if (!mounted) return;
    if (_cargando) {
      setState(() {
        _resumen = r;
        _cargando = false;
      });
      return;
    }
    if (_mismoResumen(r)) return;
    setState(() {
      _resumen = r;
    });
  }

  void _onChange() {
    if (mounted && !_cargandoResumen) {
      _cargandoResumen = true;
      _cargar().whenComplete(() {
        if (mounted) _cargandoResumen = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        appBar: AppBar(title: const Text('Integrante')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final res = _resumen;
    final user = res['usuario'] as User?;

        return Scaffold(
          appBar: AppBar(
            title: Text(user?.nombre ?? 'Integrante'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(user: user),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _Caja(
                            icon: Icons.today,
                            label: 'Puntos HOY',
                            value: '${res['puntosHoy']}',
                            color: AppColors.azul,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Caja(
                            icon: Icons.date_range,
                            label: 'Puntos 7 días',
                            value: '${res['puntosSemana']}',
                            color: AppColors.verde,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Caja(
                            icon: Icons.emoji_events,
                            label: 'Aprobadas',
                            value: '${res['aprobadasSemana']}',
                            color: AppColors.amarillo,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Caja(
                            icon: Icons.gavel,
                            label: 'Castigos',
                            value: '-${res['castigosSemana']}',
                            color: AppColors.rojo,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _TareasHoyCard(tareas: (res['tareasHoy'] as List)),
                    const SizedBox(height: 20),
                    _SemanasCard(user: user),
                    const SizedBox(height: 20),
                    RepaintBoundary(
                      child: _GraficoCumplimiento(usuarioId: widget.usuarioId),
                    ),
                    const SizedBox(height: 20),
                    _CastigosCard(usuarioId: widget.usuarioId),
                  ],
                ),
              ),
            ),
          ),
        );
  }
}

class _Header extends StatelessWidget {
  final User? user;
  const _Header({this.user});

  @override
  Widget build(BuildContext context) {
    final u = user;
    return DuoCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (u != null)
            UserAvatar(user: u, radius: 28)
          else
            const CircleAvatar(child: Icon(Icons.person)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        u?.nombre ?? '—',
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (u != null && !u.activo) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.grisMedio.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Inactivo',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.grisMedio)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Nivel ${u?.nivel ?? 1} · ${u?.puntos ?? 0} pts · 🔥 ${u?.racha ?? 0} días',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.grisMedio),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Caja extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _Caja({
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
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.grisOscuro)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, color: AppColors.grisMedio)),
        ],
      ),
    );
  }
}

class _TareasHoyCard extends StatelessWidget {
  final List tareas;
  const _TareasHoyCard({required this.tareas});

  @override
  Widget build(BuildContext context) {
    final pendientes = tareas
        .where((m) => (m as Map)['estado'] == 'pendiente')
        .toList();
    final completadas = tareas
        .where((m) => (m as Map)['estado'] != 'pendiente')
        .toList();

    return DuoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tareas de HOY',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (tareas.isEmpty)
            const Text('Hoy no tiene tareas asignadas.',
                style: TextStyle(color: AppColors.grisMedio))
          else ...[
            // Pendientes
            for (final m in pendientes)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.hourglass_empty,
                    color: AppColors.amarillo, size: 22),
                title: Text((m as Map)['titulo'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Pendiente · +${m['puntos']} pts',
                    style: const TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.schedule,
                    size: 16, color: AppColors.grisMedio),
              ),
            // Completadas
            for (final m in completadas)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  (m as Map)['estado'] == 'aprobada'
                      ? Icons.check_circle
                      : Icons.verified,
                  color: AppColors.verde,
                  size: 22,
                ),
                title: Text(m['titulo'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  (m['estado'] as String) == 'aprobada'
                      ? 'Aprobada · +${m['puntos']} pts'
                      : 'Completada, esperando aprobación',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SemanasCard extends StatelessWidget {
  final User? user;
  const _SemanasCard({this.user});

  @override
  Widget build(BuildContext context) {
    return DuoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Semana',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _linea(Icons.stars, 'Racha actual', '${user?.racha ?? 0} días',
              AppColors.rojo),
          _linea(Icons.military_tech, 'Nivel', '${user?.nivel ?? 1}',
              AppColors.amarillo),
          _linea(Icons.stars, 'Puntos totales', '${user?.puntos ?? 0} pts',
              AppColors.morado),
          const SizedBox(height: 8),
          const Text(
            'Detalles del día arriba: pendientes y aprobadas de HOY. '
            'La semana suma los últimos 7 días.',
            style: TextStyle(fontSize: 12, color: AppColors.grisMedio),
          ),
        ],
      ),
    );
  }

  Widget _linea(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: AppColors.grisMedio)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _CastigosCard extends StatefulWidget {
  final int usuarioId;
  const _CastigosCard({required this.usuarioId});

  @override
  State<_CastigosCard> createState() => _CastigosCardState();
}

class _CastigosCardState extends State<_CastigosCard> {
  List<Castigo> _castigos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final app = context.read<AppProvider>();
    final castigos = await app.castigosDe(widget.usuarioId);
    if (mounted) {
      setState(() {
        _castigos = castigos.reversed.toList();
        _cargando = false;
      });
    }
  }

  Future<void> _revertir(Castigo c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revertir castigo'),
        content: Text(
            '¿Perdonar "${c.motivo}" y devolver +${c.puntos} pts al integrante?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Perdonar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await context.read<AppProvider>().revertirCastigo(c.id!);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_castigos.isEmpty) {
      return DuoCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: const [
            Icon(Icons.check_circle, color: AppColors.verde, size: 20),
            SizedBox(width: 10),
            Text('Sin castigos ni quitas',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }
    final tareas = _castigos.where((c) => c.esTarea).toList();
    final disciplina = _castigos.where((c) => c.esDisciplina).toList();
    return DuoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Castigos y quitas',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (tareas.isNotEmpty) ...[
            const Text('Por tareas sin cumplir',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.grisMedio)),
            for (final c in tareas)
              _filaCastigo(c, Icons.event_busy, Colors.orange),
            const SizedBox(height: 8),
          ],
          if (disciplina.isNotEmpty) ...[
            const Text('Castigos (disciplina)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.grisMedio)),
            for (final c in disciplina)
              _filaCastigo(c, Icons.gavel, AppColors.rojo),
          ],
          const Text(
            'Toca el botón de restaurar para perdonar un castigo y devolver los puntos.',
            style: TextStyle(fontSize: 11, color: AppColors.grisMedio),
          ),
        ],
      ),
    );
  }

  Widget _filaCastigo(Castigo c, IconData icono, Color color) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icono, color: color, size: 22),
      title: Text(c.motivo,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${c.fecha.day}/${c.fecha.month} · '
        '${c.esTarea ? 'Tarea sin cumplir' : 'Disciplina'}',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('-${c.puntos} pts',
              style: const TextStyle(
                  color: AppColors.rojo,
                  fontWeight: FontWeight.w800)),
          IconButton(
            icon: const Icon(Icons.restore,
                color: AppColors.verde, size: 20),
            tooltip: 'Perdonar castigo',
            onPressed: () => _revertir(c),
          ),
        ],
      ),
    );
  }
}

/// Gráfico visual de cumplimiento (puntos ganados) de un integrante
/// en los últimos 7 y 30 días.
class _GraficoCumplimiento extends StatefulWidget {
  final int usuarioId;
  const _GraficoCumplimiento({required this.usuarioId});

  @override
  State<_GraficoCumplimiento> createState() => _GraficoCumplimientoState();
}

class _GraficoCumplimientoState extends State<_GraficoCumplimiento> {
  late Future<List<(DateTime, int)>> _fut7;
  late Future<List<(DateTime, int)>> _fut30;

  @override
  void initState() {
    super.initState();
    _cargar();
    context.read<AppProvider>().addListener(_onChange);
  }

  @override
  void dispose() {
    context.read<AppProvider>().removeListener(_onChange);
    super.dispose();
  }

  void _cargar() {
    final app = context.read<AppProvider>();
    _fut7 = app.puntosPorDia(widget.usuarioId, dias: 7);
    _fut30 = app.puntosPorDia(widget.usuarioId, dias: 30);
  }

  void _onChange() {
    if (mounted) {
      _cargar();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final dias = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    return DuoCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cumplimiento',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: FutureBuilder<List<(DateTime, int)>>(
              future: _fut7,
              builder: (context, snap) {
                final datos = snap.data ?? const <(DateTime, int)>[];
                return BarChart(
                  data: datos,
                  labelFor: (d) => dias[d.weekday - 1],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<(DateTime, int)>>(
            future: _fut30,
            builder: (context, snap) {
              final datos = snap.data ?? const <(DateTime, int)>[];
              final total = datos.fold<int>(0, (s, e) => s + e.$2);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Últimos 30 días: $total pts',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.grisMedio)),
                  Text('${datos.where((e) => e.$2 > 0).length} días activos',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.grisMedio)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}