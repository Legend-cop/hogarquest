import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/confetti.dart';
import '../widgets/duo_widgets.dart';
import '../widgets/empty_state.dart';
import '../widgets/user_avatar.dart';
import '../models/tarea_catalogo.dart';
import '../models/task.dart';
import '../models/assignment.dart';
import '../models/user.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _cargando = true;
  List<(Task, Assignment)> _misTareas = [];
  List<(Task, Assignment)> _historial = [];
  List<Task> _todasLasTareas = [];
  User? _usuarioActual;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<AppProvider>().addListener(_onChange);
    _cargarDatos();
  }

  @override
  void dispose() {
    context.read<AppProvider>().removeListener(_onChange);
    _tabController.dispose();
    super.dispose();
  }

  void _onChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cargarDatos();
    });
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final app = context.read<AppProvider>();
    final user = app.usuarioActual;
    if (user == null) return;
    setState(() => _usuarioActual = user);

    if (user.esAdmin) {
      final tareas = await app.listarTareas();
      setState(() => _todasLasTareas = tareas);
    } else {
      final mis = await app.tareasConAsignacionDe(user.id!);
      final hist = await app.historialDe(user.id!);
      setState(() {
        _misTareas = mis;
        _historial = hist;
      });
    }
    setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final esAdmin = _usuarioActual?.esAdmin ?? false;

    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (esAdmin) {
      return _AdminTasksList(tareas: _todasLasTareas, onRefresh: _cargarDatos);
    }
    return SafeArea(
      bottom: false,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              color: Theme.of(context).colorScheme.surface,
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Pendientes', icon: Icon(Icons.hourglass_top)),
                  Tab(text: 'Historial', icon: Icon(Icons.history_toggle_off)),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _IntegranteTasksList(misTareas: _misTareas),
                  _HistorialTasksList(historial: _historial),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminTasksList extends StatefulWidget {
  final List<Task> tareas;
  final Future<void> Function() onRefresh;

  const _AdminTasksList({required this.tareas, required this.onRefresh});

  @override
  State<_AdminTasksList> createState() => _AdminTasksListState();
}

class _AdminTasksListState extends State<_AdminTasksList>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Map<int, List<User>> _asignados = {};
  List<TareaCatalogo> _catalogo = [];
  bool _cargandoAsignados = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _cargarAsignados();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarAsignados() async {
    final app = context.read<AppProvider>();
    final results = await Future.wait([
      app.asignadosPorTarea(),
      app.listarCatalogo(),
    ]);
    if (!mounted) return;
    setState(() {
      _asignados = results[0] as Map<int, List<User>>;
      _catalogo = results[1] as List<TareaCatalogo>;
      _cargandoAsignados = false;
    });
  }

  Future<void> _recargar() async {
    setState(() => _cargandoAsignados = true);
    await Future.wait([widget.onRefresh(), _cargarAsignados()]);
  }

  @override
  Widget build(BuildContext context) {
    final enCatalogo = _tabController.index == 2;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tareas del hogar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Castigos automáticos',
            onPressed: () => _ajustesCastigos(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Semana', icon: Icon(Icons.calendar_view_week_outlined)),
            Tab(text: 'Tareas', icon: Icon(Icons.checklist)),
            Tab(text: 'Catálogo', icon: Icon(Icons.menu_book_outlined)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _cargandoAsignados
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _AdminSemanaTab(
                        tareas: widget.tareas,
                        asignados: _asignados,
                        onRefresh: _recargar,
                      ),
                      _AdminListaTab(
                        tareas: widget.tareas,
                        asignados: _asignados,
                        catalogo: _catalogo,
                        onRefresh: _recargar,
                      ),
                      _AdminCatalogoTab(
                        catalogo: _catalogo,
                        onChanged: _recargar,
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: DuoButton(
                label: enCatalogo ? 'Nueva en el catálogo' : 'Nueva tarea',
                icon: Icons.add,
                onPressed: () => enCatalogo
                    ? _nuevaEntradaCatalogo(context)
                    : _nuevaTarea(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _ajustesCastigos(BuildContext context) async {
    final app = context.read<AppProvider>();
    var auto = await app.getAutoCastigos();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Castigos automáticos'),
          content: SwitchListTile(
            title: const Text('Descontar por tareas vencidas'),
            subtitle: const Text(
                'Si está apagado, las tareas vencidas no quitan puntos '
                'automáticamente. Tú decides los castigos.'),
            value: auto,
            onChanged: (v) async {
              setLocal(() => auto = v);
              await app.setAutoCastigos(v);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Listo'),
            ),
          ],
        ),
      ),
    );
  }

  void _nuevaTarea(BuildContext context) async {
    final app = context.read<AppProvider>();
    await app.listarUsuarios();
    final usuarios = app.listaUsuarios;
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => _TaskFormDialog(
        onSaved: (data) => _crearTareaDesdePestana(context, data: data),
        usuarios: usuarios,
        catalogo: _catalogo,
      ),
    );
  }

  void _nuevaEntradaCatalogo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _CatalogoFormDialog(
        onSaved: (data) => _guardarCatalogo(context, data: data),
      ),
    );
  }

  Future<void> _guardarCatalogo(BuildContext context,
      {Map<String, Object?>? data, int? id}) async {
    final app = context.read<AppProvider>();
    if (data == null) return;
    final titulo = (data['titulo'] as String?) ?? '';
    final puntos = (data['puntos'] as int?) ?? 0;
    if (id == null) {
      await app.crearCatalogo(titulo: titulo, puntos: puntos);
    } else {
      await app.editarCatalogo(TareaCatalogo(id: id, titulo: titulo, puntos: puntos));
    }
    await _recargar();
  }

  Future<void> _crearTareaDesdePestana(BuildContext context,
      {Map<String, Object?>? data}) async {
    final app = context.read<AppProvider>();
    if (data == null) return;

    final List<int> integrantesIds = (data['integrantes'] as List? ?? [])
        .map((e) => e is Map ? (e['id'] as int?) ?? 0 : 0)
        .where((id) => id != 0)
        .toList();

    await app.crearTarea(
      titulo: data['titulo'] as String? ?? '',
      descripcion: data['descripcion'] as String? ?? '',
      puntos: (data['puntos'] as int?) ?? 0,
      dificultad: data['dificultad'] as String? ?? 'media',
      fechaLimite: data['fechaLimite'] as DateTime?,
      frecuencia: data['frecuencia'] as String? ?? 'unica',
      integrantesIds: integrantesIds,
      dia: data['dia'] as String? ?? '',
    );
    await _recargar();
  }
}

/// Vista semanal del admin: cada día con sus tareas y quién las tiene.
/// Permite filtrar por integrante para revisar la semana de cada niño y
/// evitar repeticiones.
class _AdminSemanaTab extends StatefulWidget {
  final List<Task> tareas;
  final Map<int, List<User>> asignados;
  final Future<void> Function() onRefresh;

  const _AdminSemanaTab({
    required this.tareas,
    required this.asignados,
    required this.onRefresh,
  });

  @override
  State<_AdminSemanaTab> createState() => _AdminSemanaTabState();
}

class _AdminSemanaTabState extends State<_AdminSemanaTab> {
  static const _diasOrden = [
    'lunes',
    'martes',
    'miercoles',
    'jueves',
    'viernes',
    'sabado',
    'domingo',
  ];

  int? _filtroUsuario; // null = todos

  List<User> get _integrantes {
    final seen = <int>{};
    final result = <User>[];
    for (final lista in widget.asignados.values) {
      for (final u in lista) {
        if (seen.add(u.id!)) result.add(u);
      }
    }
    return result;
  }

  List<User> _asignadosDe(Task t) =>
      widget.asignados[t.id] ?? const <User>[];

  /// Claves "dia|titulo" donde la misma tarea se repite para la misma persona
  /// el mismo día (duplicado real que conviene revisar).
  Set<String> _duplicadasEn(List<Task> tareas) {
    final porDiaTitulo = <String, Map<int, int>>{};
    for (final t in tareas) {
      if (t.dia.isEmpty) continue;
      final key = '${t.dia}|${t.titulo}';
      final mapa = porDiaTitulo.putIfAbsent(key, () => <int, int>{});
      for (final u in _asignadosDe(t)) {
        mapa[u.id ?? -1] = (mapa[u.id ?? -1] ?? 0) + 1;
      }
    }
    return {
      for (final e in porDiaTitulo.entries)
        if (e.value.values.any((c) => c > 1)) e.key,
    };
  }

  bool _cumpleFiltro(Task t) =>
      _filtroUsuario == null ||
      _asignadosDe(t).any((u) => u.id == _filtroUsuario);

  @override
  Widget build(BuildContext context) {
    final activas = widget.tareas.where((t) => t.activa).toList();
    final conDia =
        activas.where((t) => t.dia.isNotEmpty && _cumpleFiltro(t)).toList();
    final sinDia =
        activas.where((t) => t.dia.isEmpty && _cumpleFiltro(t)).toList();
    final integrantes = _integrantes;
    final duplicadas = _duplicadasEn(conDia);

    if (activas.isEmpty && integrantes.isEmpty) {
      return const EmptyState(
        icon: Icons.calendar_view_week_outlined,
        message: 'Aún no hay tareas activas.',
        hint: 'Crea una tarea con su día para planificar la semana.',
      );
    }

    final elegido = _filtroUsuario == null
        ? null
        : integrantes.where((u) => u.id == _filtroUsuario).firstOrNull;
    var totalTareas = 0;
    var totalXP = 0;
    if (elegido != null) {
      for (final t in activas) {
        if (!_cumpleFiltro(t)) continue;
        totalTareas++;
        totalXP += t.puntos;
      }
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (integrantes.isNotEmpty)
            _FiltroSemana(
              integrantes: integrantes,
              seleccionado: _filtroUsuario,
              onSeleccionar: (id) => setState(
                  () => _filtroUsuario = _filtroUsuario == id ? null : id),
            ),
          if (elegido != null)
            DuoCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: AppColors.verdeFondo,
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.person,
                      color: AppColors.verdeOscuro, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Semana de ${elegido.nombre}: $totalTareas tareas · $totalXP XP',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.verdeOscuro,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_filtroUsuario != null &&
              conDia.isEmpty &&
              sinDia.isEmpty) ...[
            EmptyState(
              icon: Icons.person_search,
              message: '${elegido?.nombre ?? 'Este'} no tiene tareas esta semana.',
              hint: 'Asígnale tareas desde la pestaña Tareas.',
            ),
          ],
          for (final dia in _diasOrden)
            if (conDia.any((t) => t.dia == dia)) ...[
              _DiaSemanaHeader(
                nombre: _nombreDia(dia),
                total: conDia.where((t) => t.dia == dia).length,
                esHoy: dia == _IntegranteTasksList._diaHoy,
              ),
              ...conDia
                  .where((t) => t.dia == dia)
                  .map((t) => _SemanaTaskCard(
                        tarea: t,
                        asignados: _asignadosDe(t),
                        duplicada: duplicadas.contains('${t.dia}|${t.titulo}'),
                      )),
              const SizedBox(height: 8),
            ],
          if (sinDia.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 12, 4, 6),
              child: Text(
                'Todos los días',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.grisMedio,
                ),
              ),
            ),
            ...sinDia.map((t) => _SemanaTaskCard(
                  tarea: t,
                  asignados: _asignadosDe(t),
                  duplicada: false,
                )),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// Píldoras para filtrar la semana por cada integrante.
class _FiltroSemana extends StatelessWidget {
  final List<User> integrantes;
  final int? seleccionado;
  final ValueChanged<int?> onSeleccionar;

  const _FiltroSemana({
    required this.integrantes,
    required this.seleccionado,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          _PillFiltro(
            nombre: 'Todos',
            usuarioId: null,
            activo: seleccionado == null,
            onTap: () => onSeleccionar(null),
          ),
          const SizedBox(width: 8),
          for (final u in integrantes)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _PillFiltro(
                nombre: u.nombre,
                usuarioId: u.id,
                avatar: u,
                activo: seleccionado == u.id,
                onTap: () => onSeleccionar(u.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _PillFiltro extends StatelessWidget {
  final String nombre;
  final User? avatar;
  final int? usuarioId;
  final bool activo;
  final VoidCallback onTap;

  const _PillFiltro({
    required this.nombre,
    required this.usuarioId,
    required this.activo,
    required this.onTap,
    this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    final color = avatar == null
        ? AppColors.azul
        : UserAvatar.colorDe(avatar!);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: activo ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              offset: Offset(0, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatar != null) ...[
              UserAvatar(user: avatar!, radius: 10),
              const SizedBox(width: 6),
            ],
            Text(
              nombre,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: activo ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiaSemanaHeader extends StatelessWidget {
  final String nombre;
  final int total;
  final bool esHoy;

  const _DiaSemanaHeader({
    required this.nombre,
    required this.total,
    this.esHoy = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = esHoy ? AppColors.verde : AppColors.azul;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 22,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            nombre,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          if (esHoy) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.verde,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'HOY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.linea,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$total tarea${total == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.grisMedio,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SemanaTaskCard extends StatelessWidget {
  final Task tarea;
  final List<User> asignados;
  final bool duplicada;

  const _SemanaTaskCard({
    required this.tarea,
    required this.asignados,
    required this.duplicada,
  });

  @override
  Widget build(BuildContext context) {
    return DuoCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DuoIconBadge(
                icon: Icons.checklist,
                color: _colorPorDificultad(tarea.dificultad),
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tarea.titulo,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tarea.puntos} pts • ${tarea.dificultad.toUpperCase()}'
                      '${tarea.frecuencia != 'unica' ? ' • ${_capitalizar(tarea.frecuencia)}' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.grisMedio,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (asignados.isEmpty)
            const Text(
              'Sin asignar',
              style: TextStyle(fontSize: 11, color: AppColors.grisMedio),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final u in asignados) _IntegrantePill(nombre: u.nombre),
              ],
            ),
          if (duplicada)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.amarillo.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: AppColors.grisOscuro),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'La misma tarea se repite para la misma persona el mismo día.',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.grisOscuro,
                      ),
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

class _IntegrantePill extends StatelessWidget {
  final String nombre;
  const _IntegrantePill({required this.nombre});

  @override
  Widget build(BuildContext context) {
    final color = UserAvatar.colorDe(
        User(nombre: nombre, password: '', rol: 'integrante'));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatar(
              user: User(
                  nombre: nombre, password: '', rol: 'integrante'),
              radius: 8),
          const SizedBox(width: 5),
          Text(
            nombre,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminListaTab extends StatelessWidget {
  final List<Task> tareas;
  final Map<int, List<User>> asignados;
  final List<TareaCatalogo> catalogo;
  final Future<void> Function() onRefresh;

  const _AdminListaTab({
    required this.tareas,
    required this.asignados,
    required this.catalogo,
    required this.onRefresh,
  });

  static const _diasOrden = [
    'lunes',
    'martes',
    'miercoles',
    'jueves',
    'viernes',
    'sabado',
    'domingo',
  ];

  @override
  Widget build(BuildContext context) {
    final activas = tareas.where((t) => t.activa).toList();
    final inactivas = tareas.where((t) => !t.activa).toList();
    final conDia = activas.where((t) => t.dia.isNotEmpty).toList();
    final sinDia = activas.where((t) => t.dia.isEmpty).toList();

    if (tareas.isEmpty) {
      return const EmptyState(
        icon: Icons.checklist,
        message: 'Aún no hay tareas registradas.',
        hint: 'Pulsa "Nueva tarea" para crear la primera.',
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final dia in _diasOrden)
            if (conDia.any((t) => t.dia == dia)) ...[
              _DiaSemanaHeader(
                nombre: _nombreDia(dia),
                total: conDia.where((t) => t.dia == dia).length,
                esHoy: dia == _IntegranteTasksList._diaHoy,
              ),
              ...conDia
                  .where((t) => t.dia == dia)
                  .map((t) => _AdminTaskCard(
                        tarea: t,
                        asignados: asignados[t.id] ?? const [],
                        catalogo: catalogo,
                        onRefresh: onRefresh,
                      )),
              const SizedBox(height: 8),
            ],
          if (sinDia.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 12, 4, 6),
              child: Text(
                'Todos los días',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.grisMedio,
                ),
              ),
            ),
            ...sinDia.map((t) => _AdminTaskCard(
                  tarea: t,
                  asignados: asignados[t.id] ?? const [],
                  catalogo: catalogo,
                  onRefresh: onRefresh,
                )),
            const SizedBox(height: 8),
          ],
          if (inactivas.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 12, 4, 6),
              child: Text(
                'Inactivas',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.grisMedio,
                ),
              ),
            ),
            ...inactivas.map((t) => _AdminTaskCard(
                  tarea: t,
                  asignados: asignados[t.id] ?? const [],
                  catalogo: catalogo,
                  onRefresh: onRefresh,
                )),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _AdminCatalogoTab extends StatelessWidget {
  final List<TareaCatalogo> catalogo;
  final Future<void> Function() onChanged;

  const _AdminCatalogoTab({required this.catalogo, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (catalogo.isEmpty) {
      return const EmptyState(
        icon: Icons.menu_book_outlined,
        message: 'Registra tus tareas con sus puntos.',
        hint: 'Pulsa "Nueva en el catálogo" para empezar. Al crear una tarea, '
            'los puntos se rellenarán solos según el título.',
      );
    }

    return RefreshIndicator(
      onRefresh: onChanged,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Text(
              'Puntos por defecto de cada tarea. Se prellenan al crear una '
              'tarea nueva y se pueden editar.',
              style: TextStyle(fontSize: 12, color: AppColors.grisMedio),
            ),
          ),
          for (final c in catalogo) _CatalogoCard(entrada: c, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _CatalogoCard extends StatelessWidget {
  final TareaCatalogo entrada;
  final Future<void> Function() onChanged;

  const _CatalogoCard({required this.entrada, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final color = _colorPorDificultad(_dificultadPara(entrada.puntos));
    return DuoCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          DuoIconBadge(icon: Icons.menu_book, color: color, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entrada.titulo,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entrada.puntos} pts · ${_capitalizar(_dificultadPara(entrada.puntos))}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.grisMedio),
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

  String _dificultadPara(int puntos) {
    if (puntos >= 10) return 'dificil';
    if (puntos >= 6) return 'media';
    return 'facil';
  }

  void _editar(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _CatalogoFormDialog(
        inicial: entrada,
        onSaved: (data) => _guardar(context, data: data, id: entrada.id),
      ),
    );
  }

  Future<void> _guardar(BuildContext context,
      {required Map<String, Object?> data, int? id}) async {
    final app = context.read<AppProvider>();
    final titulo = (data['titulo'] as String?) ?? '';
    final puntos = (data['puntos'] as int?) ?? 0;
    await app.editarCatalogo(
        TareaCatalogo(id: id, titulo: titulo, puntos: puntos));
    await onChanged();
  }

  void _eliminar(BuildContext context) async {
    final app = context.read<AppProvider>();
    await app.eliminarCatalogo(entrada.id!);
    await onChanged();
  }
}

class _CatalogoFormDialog extends StatefulWidget {
  final TareaCatalogo? inicial;
  final Function(Map<String, Object?>)? onSaved;

  const _CatalogoFormDialog({this.inicial, this.onSaved});

  @override
  State<_CatalogoFormDialog> createState() => _CatalogoFormDialogState();
}

class _CatalogoFormDialogState extends State<_CatalogoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tituloController;
  late final TextEditingController _puntosController;

  @override
  void initState() {
    super.initState();
    _tituloController =
        TextEditingController(text: widget.inicial?.titulo ?? '');
    _puntosController =
        TextEditingController(text: (widget.inicial?.puntos ?? 0).toString());
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _puntosController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.inicial == null ? 'Nueva entrada' : 'Editar entrada'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _tituloController,
              decoration: const InputDecoration(labelText: 'Título'),
              validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _puntosController,
              decoration: const InputDecoration(labelText: 'Puntos'),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  (v == null || int.tryParse(v) == null) ? 'Número válido' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            widget.onSaved?.call({
              'titulo': _tituloController.text,
              'puntos': int.tryParse(_puntosController.text) ?? 0,
            });
            Navigator.pop(context);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _AdminTaskCard extends StatelessWidget {
  final Task tarea;
  final List<User> asignados;
  final List<TareaCatalogo> catalogo;
  final Future<void> Function()? onRefresh;

  const _AdminTaskCard({
    required this.tarea,
    this.asignados = const [],
    this.catalogo = const [],
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return DuoCard(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: DuoIconBadge(icon: Icons.task_alt, color: AppColors.azul, size: 40),
        title: Text(tarea.titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${tarea.puntos} pts • ${tarea.dificultad.toUpperCase()}'
              '${tarea.dia.isNotEmpty ? ' • ${_nombreDia(tarea.dia)}' : ''}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            if (tarea.fechaLimite != null)
              Text(
                'Límite: ${tarea.fechaLimite!.toLocal().toString().split(" ").first}',
                style: const TextStyle(fontSize: 12, color: AppColors.grisMedio),
              ),
            const SizedBox(height: 8),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.azul),
              onPressed: () => _editarTarea(context, tarea),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: AppColors.rojo),
              onPressed: () => _eliminarTarea(context, tarea.id!),
            ),
          ],
        ),
        children: [
          const Divider(),
          _CardActionsAdmin(tarea: tarea, asignados: asignados),
        ],
      ),
    );
  }

  void _editarTarea(BuildContext context, Task tarea) async {
    final app = context.read<AppProvider>();
    await app.listarUsuarios();
    final usuarios = app.listaUsuarios;
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => _TaskFormDialog(
        initialData: {
          'titulo': tarea.titulo,
          'descripcion': tarea.descripcion,
          'puntos': tarea.puntos,
          'dificultad': tarea.dificultad,
          'fechaLimite': tarea.fechaLimite,
          'frecuencia': tarea.frecuencia,
          'dia': tarea.dia,
          'integrantes': [],
        },
        onSaved: (data) => _crearEditarTarea(context, data: data, id: tarea.id),
        usuarios: usuarios,
        catalogo: catalogo,
      ),
    );
  }

  Future<void> _crearEditarTarea(BuildContext context,
      {required Map<String, Object?> data, int? id}) async {
    final app = context.read<AppProvider>();
    final List<int> integrantesIds = (data['integrantes'] as List? ?? [])
        .map((e) => e is Map ? (e['id'] as int?) ?? 0 : 0)
        .where((id) => id != 0)
        .toList();

    if (id != null) {
      final tareaEditada = tarea.copyWith(
        titulo: data['titulo'] as String? ?? tarea.titulo,
        descripcion: data['descripcion'] as String? ?? tarea.descripcion,
        puntos: (data['puntos'] as int?) ?? tarea.puntos,
        dificultad: data['dificultad'] as String? ?? tarea.dificultad,
        fechaLimite: data['fechaLimite'] as DateTime? ?? tarea.fechaLimite,
        frecuencia: data['frecuencia'] as String? ?? tarea.frecuencia,
        dia: data['dia'] as String? ?? tarea.dia,
      );
      await app.editarTarea(tareaEditada, integrantesIds: integrantesIds);
    }
    if (context.mounted) Navigator.pop(context);
    await onRefresh?.call();
  }

  Future<void> _eliminarTarea(BuildContext context, int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar tarea?'),
        content: const Text(
            'Se eliminará la tarea y sus asignaciones. Si había castigos por '
            'esa tarea, se devolverán los puntos a los integrantes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final app = context.read<AppProvider>();
    await app.eliminarTarea(id);
    if (context.mounted) await onRefresh?.call();
  }
}

class _CardActionsAdmin extends StatelessWidget {
  final Task tarea;
  final List<User> asignados;
  const _CardActionsAdmin({required this.tarea, this.asignados = const []});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Estado: ', style: TextStyle(fontSize: 13)),
            Chip(
              label: Text(tarea.estado.toUpperCase()),
              backgroundColor: tarea.estado == 'activa'
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.15),
              labelStyle: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Asignaciones:',
            style: TextStyle(fontSize: 12, color: AppColors.grisMedio)),
        const SizedBox(height: 4),
        _AsignadosList(asignados: asignados),
      ],
    );
  }
}

class _AsignadosList extends StatelessWidget {
  final List<User> asignados;
  const _AsignadosList({this.asignados = const []});

  @override
  Widget build(BuildContext context) {
    if (asignados.isEmpty) {
      return const Text(
        'Sin asignar',
        style: TextStyle(fontSize: 11, color: AppColors.grisMedio),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final u in asignados) _IntegrantePill(nombre: u.nombre),
      ],
    );
  }
}

class _IntegranteTasksList extends StatelessWidget {
  final List<(Task, Assignment)> misTareas;
  const _IntegranteTasksList({required this.misTareas});

  static const _diasOrden = [
    'lunes',
    'martes',
    'miercoles',
    'jueves',
    'viernes',
    'sabado',
    'domingo',
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();

    final pendientes = misTareas.where((t) => !t.$2.completada).toList();
    final enRevision =
        misTareas.where((t) => t.$2.completada && !t.$2.aprobada).toList();

    if (pendientes.isEmpty && enRevision.isEmpty) {
      return const EmptyState(
        icon: Icons.task_alt,
        message: 'No tienes tareas asignadas aún.',
        hint: 'Contacta al administrador para recibir tareas.',
      );
    }

    final conDia = pendientes.where((t) => t.$1.dia.isNotEmpty).toList();
    final sinDia = pendientes.where((t) => t.$1.dia.isEmpty).toList();

    conDia.sort((a, b) =>
        _diasOrden.indexOf(a.$1.dia).compareTo(_diasOrden.indexOf(b.$1.dia)));

    return RefreshIndicator(
      onRefresh: () async => app.tareasConAsignacionDe(app.usuarioActual!.id!),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _ProgresoHoy(misTareas: misTareas),
          if (enRevision.isNotEmpty) ...[
            const _DiaHeader(nombre: 'En revisión', color: AppColors.amarillo),
            ...enRevision.map((t) => _MiniTaskCard(
                  task: t.$1,
                  assignment: t.$2,
                  onCompletada: null,
                )),
            const SizedBox(height: 8),
          ],
          for (final dia in _diasOrden)
            if (conDia.any((t) => t.$1.dia == dia)) ...[
              _DiaHeader(
                nombre: _nombreDia(dia),
                color: dia == _diaHoy ? AppColors.verde : AppColors.azul,
                esHoy: dia == _diaHoy,
                bloqueado: dia != _diaHoy,
              ),
              ...conDia
                  .where((t) => t.$1.dia == dia)
                  .map((t) => _MiniTaskCard(
                        task: t.$1,
                        assignment: t.$2,
                        bloqueada: dia != _diaHoy,
                        onCompletada: () {
                          lanzarConfeti(context);
                          app.completarTarea(t.$1.id!);
                        },
                      )),
              const SizedBox(height: 8),
            ],
          if (sinDia.isNotEmpty) ...[
            const _DiaHeader(nombre: 'Otros', color: AppColors.grisMedio),
            ...sinDia.map((t) => _MiniTaskCard(
                  task: t.$1,
                  assignment: t.$2,
                  onCompletada: () {
                    lanzarConfeti(context);
                    app.completarTarea(t.$1.id!);
                  },
                )),
          ],
        ],
      ),
    );
  }

  /// Día de hoy en minúsculas según la semana (mismo formato que `Task.dia`).
  static String get _diaHoy {
    const nombres = [
      'lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo',
    ];
    return nombres[DateTime.now().weekday - 1];
  }
}

class _ProgresoHoy extends StatelessWidget {
  final List<(Task, Assignment)> misTareas;
  const _ProgresoHoy({required this.misTareas});

  @override
  Widget build(BuildContext context) {
    final completadas =
        misTareas.where((t) => t.$2.completada && t.$2.aprobada).length;
    final total = misTareas.length;
    final progreso = total == 0 ? 0.0 : completadas / total;

    return DuoCard(
      padding: const EdgeInsets.all(16),
      color: AppColors.verdeFondo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏆',
                  style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                'Mi progreso',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.verdeOscuro,
                ),
              ),
              const Spacer(),
              Text(
                '$completadas/$total',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.verdeOscuro,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 10,
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation(AppColors.verde),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiaHeader extends StatelessWidget {
  final String nombre;
  final Color color;
  final bool esHoy;
  final bool bloqueado;

  const _DiaHeader({
    required this.nombre,
    required this.color,
    this.esHoy = false,
    this.bloqueado = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 22,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            nombre,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          if (bloqueado) ...[
            const SizedBox(width: 6),
            const Icon(Icons.lock_outline, size: 15, color: AppColors.grisMedio),
          ],
          if (esHoy) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.verde,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'HOY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniTaskCard extends StatelessWidget {
  final Task task;
  final Assignment assignment;
  final VoidCallback? onCompletada;
  final bool bloqueada;

  const _MiniTaskCard({
    required this.task,
    required this.assignment,
    this.onCompletada,
    this.bloqueada = false,
  });

  @override
  Widget build(BuildContext context) {
    final opacidad = bloqueada ? 0.45 : 1.0;
    return DuoCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Opacity(
        opacity: opacidad,
        child: Row(
          children: [
            DuoIconBadge(
                icon: Icons.checklist, color: _colorPorDificultad(task.dificultad), size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.titulo,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    '${task.dificultad.toUpperCase()}'
                    '${task.fechaLimite != null ? " · ${task.fechaLimite!.toLocal().toString().split(" ").first}" : ""}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.grisMedio),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: bloqueada
                  ? Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.grisMedio.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.grisMedio),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline,
                              size: 15, color: AppColors.grisMedio),
                          SizedBox(width: 4),
                          Text(
                            'Bloqueada',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.grisMedio),
                          ),
                        ],
                      ),
                    )
                  : DuoButton(
                      label: assignment.completada
                          ? (assignment.aprobada ? 'Completada' : 'En revisión')
                          : 'Completar',
                      color: assignment.completada
                          ? (assignment.aprobada ? AppColors.grisMedio : AppColors.amarillo)
                          : AppColors.verde,
                      borderColor: assignment.completada
                          ? (assignment.aprobada ? AppColors.grisOscuro : AppColors.verdeOscuro)
                          : AppColors.verdeOscuro,
                      onPressed: assignment.completada ? null : onCompletada,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _colorPorDificultad(String d) {
  switch (d) {
    case 'facil':
      return AppColors.verde;
    case 'media':
      return AppColors.amarillo;
    case 'dificil':
      return AppColors.rojo;
    default:
      return AppColors.azul;
  }
}

String _capitalizar(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _HistorialCard extends StatelessWidget {
  final Task task;
  final Assignment assignment;

  const _HistorialCard({required this.task, required this.assignment});

  @override
  Widget build(BuildContext context) {
    return DuoCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const DuoIconBadge(icon: Icons.check_circle, color: AppColors.verde, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.titulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                  assignment.fechaCompletada != null
                      ? 'Completada el: ${assignment.fechaCompletada!.toLocal().toString().split(" ").first}'
                      : 'Asignada el: ${assignment.fechaAsignada!.toLocal().toString().split(" ").first}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.grisMedio),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.amarillo.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '+${task.puntos} pts',
              style: const TextStyle(
                  color: AppColors.grisOscuro, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskFormDialog extends StatefulWidget {
  final Map<String, Object?>? initialData;
  final Function(Map<String, Object?>)? onSaved;
  final List<User> usuarios;
  final List<TareaCatalogo> catalogo;

  const _TaskFormDialog({
    this.initialData,
    this.onSaved,
    this.usuarios = const [],
    this.catalogo = const [],
  });

  @override
  State<_TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<_TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _puntosController = TextEditingController();
  String _dificultad = 'media';
  DateTime? _fechaLimite;
  String _frecuencia = 'unica';
  String _dia = '';
  final Set<int> _integrantesIds = {};
  bool _puntosManual = false;

  /// Si el título coincide con el catálogo y el admin no tocó los puntos,
  /// rellena los puntos por defecto (y la dificultad se sugiere sola).
  void _autofillDesdeCatalogo() {
    if (_puntosManual || widget.catalogo.isEmpty) return;
    final t = _tituloController.text.trim().toLowerCase();
    if (t.isEmpty) return;
    for (final c in widget.catalogo) {
      if (c.titulo.trim().toLowerCase() == t) {
        if (_puntosController.text != c.puntos.toString()) {
          _puntosController.text = c.puntos.toString();
        }
        return;
      }
    }
  }

  /// La dificultad se sugiere sola según los puntos: entre más vale la tarea,
  /// más difícil es (10+ difícil, 6-9 media, 1-5 fácil). El admin puede
  /// cambiarla después.
  void _sugerirDificultad() {
    final pts = int.tryParse(_puntosController.text);
    if (pts == null) return;
    final sugerida = pts >= 10
        ? 'dificil'
        : (pts >= 6 ? 'media' : 'facil');
    if (_dificultad != sugerida) setState(() => _dificultad = sugerida);
  }

  @override
  void initState() {
    super.initState();
    _puntosController.addListener(_sugerirDificultad);
    _tituloController.addListener(_autofillDesdeCatalogo);
    if (widget.initialData != null) {
      final d = widget.initialData!;
      _tituloController.text = d['titulo'] as String? ?? '';
      _descripcionController.text = d['descripcion'] as String? ?? '';
      _puntosController.text = (d['puntos'] as int?)?.toString() ?? '0';
      _dificultad = d['dificultad'] as String? ?? 'media';
      _fechaLimite = d['fechaLimite'] as DateTime?;
      _frecuencia = d['frecuencia'] as String? ?? 'unica';
      _dia = d['dia'] as String? ?? '';
      final iniciales = d['integrantes'] as List? ?? [];
      for (final e in iniciales) {
        if (e is Map) {
          final id = e['id'] as int?;
          if (id != null && id != 0) _integrantesIds.add(id);
        }
      }
    }
    _sugerirDificultad();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva tarea'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _puntosController,
                      decoration: const InputDecoration(labelText: 'Puntos'),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _puntosManual = true,
                      validator: (v) =>
                          (v == null || int.tryParse(v) == null)
                              ? 'Número válido'
                              : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _dificultad,
                      decoration:
                          const InputDecoration(labelText: 'Dificultad'),
                      items: const [
                        DropdownMenuItem(value: 'facil', child: Text('Fácil')),
                        DropdownMenuItem(
                            value: 'media', child: Text('Media')),
                        DropdownMenuItem(
                            value: 'dificil', child: Text('Difícil')),
                      ],
                      onChanged: (v) => setState(() => _dificultad = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                title: Text(
                  _fechaLimite == null
                      ? 'Sin fecha límite'
                      : 'Límite: ${_fechaLimite!.toLocal().toString().split(" ").first}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _fechaLimite ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _fechaLimite = picked);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _frecuencia,
                decoration: const InputDecoration(labelText: 'Frecuencia'),
                items: const [
                  DropdownMenuItem(value: 'unica', child: Text('Única')),
                  DropdownMenuItem(value: 'diaria', child: Text('Diaria')),
                  DropdownMenuItem(
                      value: 'semanal', child: Text('Semanal')),
                  DropdownMenuItem(
                      value: 'mensual', child: Text('Mensual')),
                ],
                onChanged: (v) => setState(() => _frecuencia = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _dia.isEmpty ? null : _dia,
                hint: const Text('Día de la semana'),
                decoration: const InputDecoration(labelText: 'Día'),
                items: const [
                  DropdownMenuItem(value: 'lunes', child: Text('Lunes')),
                  DropdownMenuItem(value: 'martes', child: Text('Martes')),
                  DropdownMenuItem(value: 'miercoles', child: Text('Miércoles')),
                  DropdownMenuItem(value: 'jueves', child: Text('Jueves')),
                  DropdownMenuItem(value: 'viernes', child: Text('Viernes')),
                  DropdownMenuItem(value: 'sabado', child: Text('Sábado')),
                  DropdownMenuItem(value: 'domingo', child: Text('Domingo')),
                ],
                onChanged: (v) => setState(() => _dia = v ?? ''),
              ),
              if (widget.usuarios.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Asignar a:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...widget.usuarios.map((u) => CheckboxListTile(
                  title: Text(u.nombre),
                  value: _integrantesIds.contains(u.id),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _integrantesIds.add(u.id!);
                      } else {
                        _integrantesIds.remove(u.id);
                      }
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                )),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final data = {
              'titulo': _tituloController.text,
              'descripcion': _descripcionController.text,
              'puntos': int.tryParse(_puntosController.text) ?? 0,
              'dificultad': _dificultad,
              'fechaLimite': _fechaLimite,
              'frecuencia': _frecuencia,
              'dia': _dia,
              'integrantes': _integrantesIds.map((id) => {'id': id}).toList(),
            };
            widget.onSaved?.call(data);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _puntosController.dispose();
    super.dispose();
  }
}

class _HistorialTasksList extends StatelessWidget {
  final List<(Task, Assignment)> historial;
  const _HistorialTasksList({required this.historial});

  @override
  Widget build(BuildContext context) {
    if (historial.isEmpty) {
      return const EmptyState(
        icon: Icons.history_toggle_off,
        message: 'Sin historial de tareas completadas.',
        hint: 'Completa tareas para ver tu historial aquí.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: historial.length,
      itemBuilder: (context, i) {
        final (t, a) = historial[i];
        return _HistorialCard(task: t, assignment: a);
      },
    );
  }
}

String _nombreDia(String dia) {
  switch (dia) {
    case 'lunes':
      return 'Lunes';
    case 'martes':
      return 'Martes';
    case 'miercoles':
      return 'Miércoles';
    case 'jueves':
      return 'Jueves';
    case 'viernes':
      return 'Viernes';
    case 'sabado':
      return 'Sábado';
    case 'domingo':
      return 'Domingo';
    default:
      return dia;
  }
}