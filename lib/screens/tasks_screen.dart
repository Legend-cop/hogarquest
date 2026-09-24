import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/haptics_service.dart';
import '../widgets/weekly_planner.dart';
import '../services/notification_service.dart';
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
  late AppProvider _provider;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _provider = context.read<AppProvider>();
    _provider.addListener(_onChange);
    _cargarDatos();
  }

  @override
  void dispose() {
    _provider.removeListener(_onChange);
    _tabController.dispose();
    super.dispose();
  }

  void _onChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cargarDatos();
    });
  }

  Future<void> _cargarDatos() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    final app = context.read<AppProvider>();
    final user = app.usuarioActual;
    if (user == null) return;
    if (!mounted) return;
    setState(() => _usuarioActual = user);

    try {
      if (user.esAdmin) {
        final tareas = await app.listarTareas();
        if (!mounted) return;
        setState(() => _todasLasTareas = tareas);
      } else {
        final mis = await app.tareasConAsignacionDe(user.id!);
        final hist = await app.historialDe(user.id!);
        if (!mounted) return;
        setState(() {
          _misTareas = mis;
          _historial = hist;
        });
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
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

class _AdminTasksListState extends State<_AdminTasksList> {
  Map<int, List<User>> _asignados = {};
  List<TareaCatalogo> _catalogo = [];
  Set<int> _pendientes = {};
  List<User> _integrantes = [];
  int _semanaOffset = 0;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final app = context.read<AppProvider>();
    final results = await Future.wait([
      app.asignadosPorTarea(),
      app.listarCatalogo(),
      app.idsTareasPendientes(),
      app.listarIntegrantes(),
    ]);
    if (!mounted) return;
    setState(() {
      _asignados = results[0] as Map<int, List<User>>;
      _catalogo = results[1] as List<TareaCatalogo>;
      _pendientes = results[2] as Set<int>;
      _integrantes = results[3] as List<User>;
      _cargando = false;
    });
  }

  Future<void> _recargar() async {
    await Future.wait([widget.onRefresh(), _cargar()]);
  }

  /// Clave recurrente del modelo ("lunes"…"domingo") para una fecha.
  String _claveDeFecha(DateTime f) => const [
        'domingo',
        'lunes',
        'martes',
        'miercoles',
        'jueves',
        'viernes',
        'sabado',
      ][f.weekday % 7];

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }

  /// Arrastra un avatar sobre una tarea: añade a esa persona como responsable
  /// (sin quitar a quienes ya la tenían).
  Future<void> _reasignar(Task tarea, User responsable) async {
    final actuales =
        (_asignados[tarea.id] ?? const <User>[]).map((u) => u.id!).toSet();
    if (actuales.contains(responsable.id)) {
      HapticsService.seleccion();
      _snack('${responsable.nombre} ya tiene "${tarea.titulo}"');
      return;
    }
    final ids = [...actuales, responsable.id!];
    await context.read<AppProvider>().editarTarea(tarea, integrantesIds: ids);
    HapticsService.seleccion();
    _snack('Tarea asignada a ${responsable.nombre}');
    await _recargar();
  }

  Future<void> _editarTarea(Task tarea) async {
    final app = context.read<AppProvider>();
    final usuarios = await app.listarIntegrantes();
    if (!mounted) return;
    final integrantesData =
        (_asignados[tarea.id] ?? const <User>[]).map((u) => {'id': u.id}).toList();
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
          'categoria': tarea.categoria,
          'integrantes': integrantesData,
        },
        onSaved: (data) => _guardarEdicion(tarea, data),
        usuarios: usuarios,
        catalogo: _catalogo,
      ),
    );
  }

  Future<void> _guardarEdicion(Task tarea, Map<String, Object?> data) async {
    final app = context.read<AppProvider>();
    final integrantesIds = (data['integrantes'] as List? ?? [])
        .map((e) => e is Map ? (e['id'] as int?) ?? 0 : 0)
        .where((id) => id != 0)
        .toList();

    final editada = tarea.copyWith(
      titulo: data['titulo'] as String? ?? tarea.titulo,
      descripcion: data['descripcion'] as String? ?? tarea.descripcion,
      puntos: (data['puntos'] as int?) ?? tarea.puntos,
      dificultad: data['dificultad'] as String? ?? tarea.dificultad,
      fechaLimite: data['fechaLimite'] as DateTime? ?? tarea.fechaLimite,
      frecuencia: data['frecuencia'] as String? ?? tarea.frecuencia,
      dia: data['dia'] as String? ?? tarea.dia,
      categoria: data['categoria'] as String? ?? tarea.categoria,
    );
    await app.editarTarea(editada, integrantesIds: integrantesIds);

    final fl = data['fechaLimite'] as DateTime?;
    if (fl != null && fl.isAfter(DateTime.now())) {
      final nid = tarea.id! % 1000000;
      await NotificationService.instance.cancelarTarea(nid);
      await NotificationService.instance.programarTarea(
        id: nid,
        cuando: fl,
        titulo: 'Tarea por vencer',
        cuerpo: '${data['titulo']}',
      );
    }
    if (mounted) Navigator.pop(context);
    await _recargar();
  }

  Future<void> _eliminarTarea(Task tarea) async {
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
    if (ok != true || !mounted) return;
    await context.read<AppProvider>().eliminarTarea(tarea.id!);
    await _recargar();
  }

  /// Creación rápida desde el pie de un día (con plantilla del catálogo).
  Future<void> _crearRapida(String titulo, DateTime fecha,
      {TareaCatalogo? plantilla}) async {
    var c = plantilla;
    if (c == null) {
      final q = titulo.trim().toLowerCase();
      for (final e in _catalogo) {
        final t = e.titulo.trim().toLowerCase();
        if (t == q || t.startsWith(q)) {
          c = e;
          break;
        }
      }
    }
    await context.read<AppProvider>().crearTarea(
          titulo: c?.titulo ?? titulo,
          puntos: c?.puntos ?? 0,
          dificultad: c?.dificultad ?? 'media',
          categoria: c?.categoria ?? 'General',
          dia: _claveDeFecha(fecha),
          frecuencia: 'semanal',
          integrantesIds: [],
        );
    HapticsService.seleccion();
    _snack(c != null
        ? '"${c.titulo}" creada para el ${_nombreDia(_claveDeFecha(fecha))}'
        : '"$titulo" creada para el ${_nombreDia(_claveDeFecha(fecha))}');
    await _recargar();
  }

  /// Texto libre sin match en el catálogo: abre el formulario completo
  /// prellenado con el día elegido.
  void _crearLibre(String titulo, DateTime fecha) {
    showDialog(
      context: context,
      builder: (_) => _TaskFormDialog(
        initialData: {
          'titulo': titulo,
          'dia': _claveDeFecha(fecha),
          'frecuencia': 'semanal',
          'fechaLimite': DateTime(fecha.year, fecha.month, fecha.day, 23, 59),
        },
        onSaved: _crearDesdeDialog,
        usuarios: _integrantes,
        catalogo: _catalogo,
      ),
    );
  }

  void _nuevaTarea() {
    showDialog(
      context: context,
      builder: (_) => _TaskFormDialog(
        onSaved: _crearDesdeDialog,
        usuarios: _integrantes,
        catalogo: _catalogo,
      ),
    );
  }

  Future<void> _crearDesdeDialog(Map<String, Object?> data) async {
    final app = context.read<AppProvider>();
    final integrantesIds = (data['integrantes'] as List? ?? [])
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
      categoria: data['categoria'] as String? ?? 'General',
    );
    if (mounted) Navigator.pop(context);
    await _recargar();
  }

  void _nuevaEntradaCatalogo() {
    showDialog(
      context: context,
      builder: (_) => _CatalogoFormDialog(
        onSaved: (data) => _guardarCatalogo(data: data),
      ),
    );
  }

  Future<void> _guardarCatalogo(
      {Map<String, Object?>? data, int? id}) async {
    final app = context.read<AppProvider>();
    if (data == null) return;
    final titulo = (data['titulo'] as String?) ?? '';
    final puntos = (data['puntos'] as int?) ?? 0;
    final categoria = (data['categoria'] as String?) ?? 'General';
    final dificultad = (data['dificultad'] as String?) ?? 'media';
    if (id == null) {
      await app.crearCatalogo(
          titulo: titulo,
          puntos: puntos,
          categoria: categoria,
          dificultad: dificultad);
    } else {
      await app.editarCatalogo(TareaCatalogo(
        id: id,
        titulo: titulo,
        puntos: puntos,
        categoria: categoria,
        dificultad: dificultad,
      ));
    }
    await _recargar();
  }

  /// Libro de tareas: catálogo CRUD en panel lateral (web) o bottom sheet.
  void _abrirLibro() {
    final ancho = MediaQuery.sizeOf(context).width;
    if (ancho >= 700) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          alignment: Alignment.centerRight,
          insetPadding: EdgeInsets.zero,
          child: SizedBox(
            width: 380,
            height: MediaQuery.sizeOf(ctx).height,
            child: _LibroTareas(
              catalogo: _catalogo,
              onChanged: _recargar,
              onNuevo: _nuevaEntradaCatalogo,
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.75,
          child: _LibroTareas(
            catalogo: _catalogo,
            onChanged: _recargar,
            onNuevo: _nuevaEntradaCatalogo,
          ),
        ),
      );
    }
  }

  void _ajustesCastigos() async {
    final app = context.read<AppProvider>();
    var auto = await app.getAutoCastigos();
    if (!mounted) return;
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

  Widget _seccion(String titulo) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(
          titulo,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: textoSuaveTema(context),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final activas = widget.tareas.where((t) => t.activa).toList();
    final sinDia = activas.where((t) => t.dia.isEmpty).toList();
    final inactivas = widget.tareas.where((t) => !t.activa).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tareas del hogar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task),
            tooltip: 'Nueva tarea',
            onPressed: _nuevaTarea,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Castigos automáticos',
            onPressed: _ajustesCastigos,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.menu_book_outlined),
        label: const Text('Libro de Tareas'),
        onPressed: _abrirLibro,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : WeeklyPlanner(
              tareas: widget.tareas,
              asignados: _asignados,
              integrantes: _integrantes,
              catalogo: _catalogo,
              pendientes: _pendientes,
              semanaOffset: _semanaOffset,
              onSemanaChanged: (o) => setState(() => _semanaOffset = o),
              onRefresh: _recargar,
              onReasignar: _reasignar,
              onEditar: _editarTarea,
              onEliminar: _eliminarTarea,
              onCrearRapida: _crearRapida,
              onCrearLibre: _crearLibre,
              extra: [
                if (sinDia.isNotEmpty) ...[
                  _seccion('Todos los días'),
                  ...sinDia.map((t) => _AdminTaskCard(
                        tarea: t,
                        asignados: _asignados[t.id] ?? const [],
                        catalogo: _catalogo,
                        onRefresh: _recargar,
                      )),
                ],
                if (inactivas.isNotEmpty) ...[
                  _seccion('Inactivas'),
                  ...inactivas.map((t) => _AdminTaskCard(
                        tarea: t,
                        asignados: _asignados[t.id] ?? const [],
                        catalogo: _catalogo,
                        onRefresh: _recargar,
                      )),
                ],
                const SizedBox(height: 72),
              ],
            ),
    );
  }
}

/// Panel lateral/bottom-sheet con el catálogo CRUD ("Libro de Tareas").
class _LibroTareas extends StatelessWidget {
  final List<TareaCatalogo> catalogo;
  final Future<void> Function() onChanged;
  final VoidCallback onNuevo;

  const _LibroTareas({
    required this.catalogo,
    required this.onChanged,
    required this.onNuevo,
  });

  @override
  Widget build(BuildContext context) {
    int ordenD(int p) => p >= 10 ? 2 : (p >= 6 ? 1 : 0);
    final lista = List<TareaCatalogo>.from(catalogo)
      ..sort((a, b) {
        final oa = ordenD(a.puntos);
        final ob = ordenD(b.puntos);
        if (oa != ob) return oa.compareTo(ob);
        return a.puntos.compareTo(b.puntos);
      });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              const Icon(Icons.menu_book_outlined, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Libro de Tareas',
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
          child: RefreshIndicator(
            onRefresh: onChanged,
            child: lista.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 48),
                      EmptyState(
                        icon: Icons.menu_book_outlined,
                        message: 'Registra tus tareas con sus puntos.',
                        hint: 'Pulsa "Nueva en el catálogo" para empezar. Al '
                            'crear una tarea, los puntos se rellenarán solos '
                            'según el título.',
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                        child: Text(
                          'Puntos por defecto de cada tarea. Se prellenan al '
                          'crear una tarea nueva y se pueden editar. '
                          'Ordenadas por dificultad.',
                          style: TextStyle(
                              fontSize: 12, color: textoSuaveTema(context)),
                        ),
                      ),
                      for (final c in lista)
                        _CatalogoCard(entrada: c, onChanged: onChanged),
                    ],
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: DuoButton(
              label: 'Nueva en el catálogo',
              icon: Icons.add,
              onPressed: onNuevo,
            ),
          ),
        ),
      ],
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
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: textoSuaveTema(context)),
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
    final app = context.read<AppProvider>();
    showDialog(
      context: context,
      builder: (_) => _CatalogoFormDialog(
        inicial: entrada,
        onSaved: (data) async {
          final titulo = (data['titulo'] as String?) ?? '';
          final puntos = (data['puntos'] as int?) ?? 0;
          await app.editarCatalogo(TareaCatalogo(
            id: entrada.id,
            titulo: titulo,
            puntos: puntos,
            categoria: (data['categoria'] as String?) ?? entrada.categoria,
            dificultad: (data['dificultad'] as String?) ?? entrada.dificultad,
          ));
          await onChanged();
        },
      ),
    );
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
  late String _categoria;
  late String _dificultad;

  @override
  void initState() {
    super.initState();
    _tituloController =
        TextEditingController(text: widget.inicial?.titulo ?? '');
    _puntosController =
        TextEditingController(text: (widget.inicial?.puntos ?? 0).toString());
    _categoria = widget.inicial?.categoria ?? 'General';
    _dificultad = widget.inicial?.dificultad ?? _dificultadPara(widget.inicial?.puntos ?? 0);
  }

  String _dificultadPara(int puntos) {
    if (puntos >= 10) return 'dificil';
    if (puntos >= 6) return 'media';
    return 'facil';
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
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categoria,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: [
                for (final c in CategoriaTarea.nombres)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _categoria = v ?? 'General'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _dificultad,
              decoration: const InputDecoration(labelText: 'Dificultad'),
              items: const [
                DropdownMenuItem(value: 'facil', child: Text('Fácil')),
                DropdownMenuItem(value: 'media', child: Text('Media')),
                DropdownMenuItem(value: 'dificil', child: Text('Difícil')),
              ],
              onChanged: (v) => setState(() => _dificultad = v ?? 'media'),
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
              'categoria': _categoria,
              'dificultad': _dificultad,
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
                'Límite: ${_fmtLimite(tarea.fechaLimite!)}',
                style: TextStyle(fontSize: 12, color: textoSuaveTema(context)),
              ),
            const SizedBox(height: 6),
            Chip(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              avatar: Icon(CategoriaTarea.iconoDe(tarea.categoria),
                  size: 14, color: Colors.white),
              label: Text(tarea.categoria),
              labelStyle: const TextStyle(
                  fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
              backgroundColor: Color(CategoriaTarea.colorDe(tarea.categoria)),
              padding: EdgeInsets.zero,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: _CardActionsAdmin(tarea: tarea, asignados: asignados),
          ),
        ],
      ),
    );
  }

  void _editarTarea(BuildContext context, Task tarea) async {
    final app = context.read<AppProvider>();
    final usuarios = await app.listarIntegrantes();
    if (!context.mounted) return;
    final asignadosAEstaTarea = asignados;
    final integrantesData = asignadosAEstaTarea.map((u) => {'id': u.id}).toList();
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
          'categoria': tarea.categoria,
          'integrantes': integrantesData,
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
        categoria: data['categoria'] as String? ?? tarea.categoria,
      );
      await app.editarTarea(tareaEditada, integrantesIds: integrantesIds);
    }
    final fl = data['fechaLimite'] as DateTime?;
    if (fl != null && fl.isAfter(DateTime.now())) {
      final nid = (id ?? data['titulo'].hashCode).abs() % 1000000;
      await NotificationService.instance.cancelarTarea(nid);
      await NotificationService.instance.programarTarea(
        id: nid,
        cuando: fl,
        titulo: 'Tarea por vencer',
        cuerpo: '${data['titulo']}',
      );
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
        Text('Asignaciones:',
            style: TextStyle(fontSize: 12, color: textoSuaveTema(context))),
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
      return Text(
        'Sin asignar',
        style: TextStyle(fontSize: 11, color: textoSuaveTema(context)),
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
    'domingo',
    'lunes',
    'martes',
    'miercoles',
    'jueves',
    'viernes',
    'sabado',
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
      onRefresh: () async {
        final app2 = context.read<AppProvider>();
        final u = app2.usuarioActual;
        if (u != null) await app2.tareasConAsignacionDe(u.id!);
      },
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
            _DiaHeader(
                nombre: 'Otros', color: textoSuaveTema(context).withValues(alpha: 0.45)),
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
    // Semana que empieza en domingo (índice 0).
    const nombres = [
      'domingo', 'lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado',
    ];
    return nombres[DateTime.now().weekday % 7];
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
            Icon(Icons.lock_outline, size: 15, color: textoSuaveTema(context)),
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
                    '${task.fechaLimite != null ? " · ${_fmtLimite(task.fechaLimite!)}" : ""}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: textoSuaveTema(context)),
                  ),
                  const SizedBox(height: 4),
                  Chip(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(CategoriaTarea.iconoDe(task.categoria),
                        size: 13, color: Colors.white),
                    label: Text(task.categoria),
                    labelStyle: const TextStyle(
                        fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
                    backgroundColor: Color(CategoriaTarea.colorDe(task.categoria)),
                    padding: EdgeInsets.zero,
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
                        color: textoSuaveTema(context).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: textoSuaveTema(context)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline,
                              size: 15, color: textoSuaveTema(context)),
                          SizedBox(width: 4),
                          Text(
                            'Bloqueada',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: textoSuaveTema(context)),
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
                  style: TextStyle(
                      fontSize: 11, color: textoSuaveTema(context)),
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
              style: TextStyle(
                  color: textoTema(context), fontWeight: FontWeight.w800),
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
  String _categoria = 'General';
  final Set<int> _integrantesIds = {};
  bool _puntosManual = false;

  /// Si el título coincide con el catálogo y el admin no tocó los campos,
  /// rellena puntos/categoría/dificultad por defecto.
  void _autofillDesdeCatalogo() {
    if (_puntosManual || widget.catalogo.isEmpty) return;
    final t = _tituloController.text.trim().toLowerCase();
    if (t.isEmpty) return;
    for (final c in widget.catalogo) {
      if (c.titulo.trim().toLowerCase() == t) {
        if (_puntosController.text != c.puntos.toString()) {
          _puntosController.text = c.puntos.toString();
        }
        var cambia = false;
        if (_categoria != c.categoria) {
          _categoria = c.categoria;
          cambia = true;
        }
        if (_dificultad != c.dificultad) {
          _dificultad = c.dificultad;
          cambia = true;
        }
        if (cambia) setState(() {});
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
      _categoria = d['categoria'] as String? ?? 'General';
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
              DropdownButtonFormField<String>(
                value: _categoria,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: [
                  for (final c in CategoriaTarea.nombres)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _categoria = v!),
              ),
              ListTile(
                title: Text(
                  _fechaLimite == null
                      ? 'Sin fecha límite'
                      : 'Límite: ${_fmtLimite(_fechaLimite!)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _fechaLimite ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked == null) return;
                  final prev = _fechaLimite;
                  final hora = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(prev ?? picked),
                  );
                  final t = hora ??
                      (prev != null
                          ? TimeOfDay(hour: prev.hour, minute: prev.minute)
                          : const TimeOfDay(hour: 0, minute: 0));
                  setState(() => _fechaLimite = DateTime(
                      picked.year, picked.month, picked.day, t.hour, t.minute));
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
                  DropdownMenuItem(value: 'domingo', child: Text('Domingo')),
                  DropdownMenuItem(value: 'lunes', child: Text('Lunes')),
                  DropdownMenuItem(value: 'martes', child: Text('Martes')),
                  DropdownMenuItem(value: 'miercoles', child: Text('Miércoles')),
                  DropdownMenuItem(value: 'jueves', child: Text('Jueves')),
                  DropdownMenuItem(value: 'viernes', child: Text('Viernes')),
                  DropdownMenuItem(value: 'sabado', child: Text('Sábado')),
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
              'categoria': _categoria,
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

/// Formatea la fecha límite con hora (solo muestra la hora si no es 00:00).
String _fmtLimite(DateTime d) {
  final fecha = d.toLocal().toString().split(' ').first;
  if (d.hour == 0 && d.minute == 0) return fecha;
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$fecha $h:$m';
}