import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/celebration_service.dart';
import '../services/haptics_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/confetti.dart';
import '../widgets/duo_widgets.dart';
import '../widgets/empty_state.dart';
import '../widgets/hq_design.dart';
import '../widgets/icono3d.dart';
import '../widgets/icons3d.dart';
import '../widgets/mascots.dart';
import '../widgets/playful_motion.dart';
import '../widgets/user_avatar.dart';
import '../models/tarea_catalogo.dart';
import '../models/task.dart';
import '../models/assignment.dart';
import '../models/user.dart';
import 'retos_screen.dart' show RetosAdminInline;

class TareasScreen extends StatefulWidget {
  const TareasScreen({super.key});

  @override
  State<TareasScreen> createState() => _TareasScreenState();
}

class _TareasScreenState extends State<TareasScreen> {
  bool _cargando = true;
  int _pestana = 0;
  List<(Task, Assignment)> _misTareas = [];
  List<(Task, Assignment)> _historial = [];
  List<(Task, Assignment, User)> _robables = [];
  List<Task> _todasLasTareas = [];
  User? _usuarioActual;
  late AppProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<AppProvider>();
    _provider.addListener(_onChange);
    _cargarDatos();
  }

  @override
  void dispose() {
    _provider.removeListener(_onChange);
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
        final rob = await app.tareasRobables();
        if (!mounted) return;
        setState(() {
          _misTareas = mis;
          _historial = hist;
          _robables = rob;
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: const ReferenciaTitulo(
            'SOLO TUS ENCARGOS',
            'Mis tareas',
            icono: Icono3DTipo.check,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: PillSegment(
            index: _pestana,
            onChanged: (i) => setState(() => _pestana = i),
            items: const [
              (icon: Icons.check_circle_outline, label: 'Pendientes'),
              (icon: Icons.history, label: 'Historial'),
            ],
          ),
        ),
        Expanded(
          child: PlayfulIndexedStack(
            index: _pestana,
            children: [
              _IntegranteTasksList(
                misTareas: _misTareas,
                robables: _robables,
              ),
              _HistorialTasksList(historial: _historial),
            ],
          ),
        ),
      ],
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
  Map<int, DateTime> _porAprobar = {};
  Set<int> _sinCompletar = {};
  List<User> _integrantes = [];
  int _semanaOffset = 0;
  int? _diaSel;
  int? _miembroId;
  int _segmento = 0;
  bool _cargando = true;

  /// Panel lateral del Libro de Tareas abierto (pantallas >= 700). Sin
  /// barrera modal para poder arrastrar tarjetas del libro a los días.
  bool _libroAbierto = false;

  /// true cuando el sheet móvil del libro se cerró solo al iniciar un
  /// arrastre (para dejar ver los chips de día); se reabre al soltar.
  bool _libroCerradoPorArrastre = false;

  /// Tween fijo: si se recreara en cada build, el panel re-animaría su
  /// entrada en cada rebuild (poll de 20 s, recargas, etc.).
  final Tween<double> _panelTween = Tween(begin: 1, end: 0);

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
      app.pendientesDeAprobacion(),
      app.listarIntegrantes(),
      app.idsTareasPendientes(),
    ]);
    if (!mounted) return;
    final porAprobar = results[2] as List<(Task, Assignment, User)>;
    setState(() {
      _asignados = results[0] as Map<int, List<User>>;
      _catalogo = results[1] as List<TareaCatalogo>;
      _porAprobar = {
        for (final (_, a, _) in porAprobar)
          a.tareaId: a.fechaCompletada ?? a.fechaAsignada ?? DateTime.now(),
      };
      _integrantes = results[3] as List<User>;
      _sinCompletar = results[4] as Set<int>;
      _cargando = false;
    });
  }

  /// Ids de tareas con una asignación completada pero sin aprobar, acotadas
  /// a la semana visible (evita que semanas futuras marquen "pendiente").
  Set<int> get _pendientes {
    final inicio = _inicioSemana;
    final fin = inicio.add(const Duration(days: 7));
    return _porAprobar.entries
        .where((e) => !e.value.isBefore(inicio) && e.value.isBefore(fin))
        .map((e) => e.key)
        .toSet();
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
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  static const _mesesLargos = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  static const _letrasDia = ['D', 'L', 'M', 'X', 'J', 'V', 'S'];
  static const _nombresDia = [
    'Domingo',
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
  ];

  /// Domingo de la semana visible según el offset.
  DateTime get _inicioSemana {
    final hoy = DateTime.now();
    final domingoActual = DateTime(
      hoy.year,
      hoy.month,
      hoy.day,
    ).subtract(Duration(days: hoy.weekday % 7));
    return domingoActual.add(Duration(days: _semanaOffset * 7));
  }

  List<DateTime> get _fechas => [
    for (var i = 0; i < 7; i++) _inicioSemana.add(Duration(days: i)),
  ];

  int get _indiceHoy {
    final hoy = DateTime.now();
    final fechas = _fechas;
    for (var i = 0; i < 7; i++) {
      final f = fechas[i];
      if (f.year == hoy.year && f.month == hoy.month && f.day == hoy.day) {
        return i;
      }
    }
    return 0;
  }

  int get _indiceSel => _diaSel ?? _indiceHoy;

  /// Número de semana ISO (jueves de la semana visible) para el paginador.
  int get _semanaIso {
    final jueves = _inicioSemana.add(const Duration(days: 4));
    final inicioAnio = DateTime(jueves.year, 1, 1);
    final doy = jueves.difference(inicioAnio).inDays + 1;
    final semana = (doy - jueves.weekday + 10) ~/ 7;
    return semana < 1 ? 1 : semana;
  }

  String get _rangoFechas {
    final a = _fechas.first;
    final b = _fechas.last;
    if (a.month == b.month && a.year == b.year) {
      return '${a.day} – ${b.day} ${_mesesLargos[a.month - 1]}';
    }
    return '${a.day} ${_mesesLargos[a.month - 1]} –'
        ' ${b.day} ${_mesesLargos[b.month - 1]}';
  }

  String _tituloDia(DateTime f) {
    final nombre = _nombresDia[f.weekday % 7];
    final hoy = DateTime.now();
    final esHoy =
        f.year == hoy.year && f.month == hoy.month && f.day == hoy.day;
    return esHoy ? 'Hoy, ${nombre.toLowerCase()}' : nombre;
  }

  /// Primera palabra del nombre, truncada para chips compactos.
  String _nombreCorto(String nombre) {
    final primera = nombre.trim().split(RegExp(r'\s+')).first;
    return primera.length > 10 ? '${primera.substring(0, 10)}…' : primera;
  }

  /// Tareas visibles para la fecha seleccionada.
  List<Task> _tareasDelDia(DateTime fecha) {
    final clave = _claveDeFecha(fecha);
    return widget.tareas.where((t) {
      if (!t.activa) return false;
      if (t.dia.isNotEmpty) return t.dia == clave;
      final fl = t.fechaLimite;
      return fl != null &&
          fl.year == fecha.year &&
          fl.month == fecha.month &&
          fl.day == fecha.day;
    }).toList();
  }

  bool _vencida(Task t, DateTime fecha) {
    if (!_sinCompletar.contains(t.id)) return false;
    final fl = t.fechaLimite;
    final limite =
        fl != null &&
            fl.year == fecha.year &&
            fl.month == fecha.month &&
            fl.day == fecha.day
        ? fl
        : DateTime(fecha.year, fecha.month, fecha.day, 23, 59);
    return DateTime.now().isAfter(limite);
  }

  /// Reasignación mediante diálogo de checkboxes (sustituye al drag).
  Future<void> _asignarDialogo(Task tarea) async {
    final actuales = (_asignados[tarea.id] ?? const <User>[])
        .map((u) => u.id!)
        .toSet();
    final elegidos = <int>{...actuales};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Asignar "${tarea.titulo}"'),
          content: SizedBox(
            width: 320,
            child: _integrantes.isEmpty
                ? const Text('No hay integrantes todavía.')
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final u in _integrantes)
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(u.nombre),
                            value: elegidos.contains(u.id),
                            onChanged: (v) => setLocal(() {
                              if (v == true) {
                                elegidos.add(u.id!);
                              } else {
                                elegidos.remove(u.id);
                              }
                            }),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                      ],
                    ),
                  ),
          ),
          actions: [
            DialogActions(
              onCancel: () => Navigator.pop(ctx, false),
              primary: DuoButton(
                fullWidth: false,
                label: 'Guardar',
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AppProvider>().editarTarea(
      tarea,
      integrantesIds: elegidos.toList(),
    );
    HapticsService.seleccion();
    _snack('Asignación actualizada');
    await _recargar();
  }

  Future<void> _editarTarea(Task tarea) async {
    final app = context.read<AppProvider>();
    final usuarios = await app.listarIntegrantes();
    if (!mounted) return;
    final integrantesData = (_asignados[tarea.id] ?? const <User>[])
        .map((u) => {'id': u.id})
        .toList();
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
          'icono': tarea.icono,
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
      icono: data['icono'] as String? ?? tarea.icono,
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
          'esa tarea, se devolverán los puntos a los integrantes.',
        ),
        actions: [
          DialogActions(
            onCancel: () => Navigator.pop(ctx, false),
            primary: DuoButton(
              fullWidth: false,
              color: AppColors.rojo,
              borderColor: AppColors.rojoOscuro,
              label: 'Eliminar',
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AppProvider>().eliminarTarea(tarea.id!);
    await _recargar();
  }

  /// Creación rápida desde el pie de un día (con plantilla del catálogo).
  Future<void> _crearRapida(
    String titulo,
    DateTime fecha, {
    TareaCatalogo? plantilla,
  }) async {
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
      icono: c?.icono ?? '',
      dia: _claveDeFecha(fecha),
      frecuencia: 'semanal',
      integrantesIds: [],
    );
    HapticsService.seleccion();
    _snack(
      c != null
          ? '"${c.titulo}" creada para el ${_nombreDia(_claveDeFecha(fecha))}'
          : '"$titulo" creada para el ${_nombreDia(_claveDeFecha(fecha))}',
    );
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
      icono: data['icono'] as String? ?? '',
    );
    if (mounted) Navigator.pop(context);
    await _recargar();
  }

  void _nuevaEntradaCatalogo() {
    showDialog(
      context: context,
      builder: (_) =>
          _CatalogoFormDialog(onSaved: (data) => _guardarCatalogo(data: data)),
    );
  }

  Future<void> _guardarCatalogo({Map<String, Object?>? data, int? id}) async {
    final app = context.read<AppProvider>();
    if (data == null) return;
    final titulo = (data['titulo'] as String?) ?? '';
    final puntos = (data['puntos'] as int?) ?? 0;
    final categoria = (data['categoria'] as String?) ?? 'General';
    final dificultad = (data['dificultad'] as String?) ?? 'media';
    final icono = (data['icono'] as String?) ?? '';
    if (id == null) {
      await app.crearCatalogo(
        titulo: titulo,
        puntos: puntos,
        categoria: categoria,
        dificultad: dificultad,
        icono: icono,
      );
    } else {
      await app.editarCatalogo(
        TareaCatalogo(
          id: id,
          titulo: titulo,
          puntos: puntos,
          categoria: categoria,
          dificultad: dificultad,
          icono: icono,
        ),
      );
    }
    await _recargar();
  }

  /// Libro de tareas: catálogo CRUD en panel lateral sin modal (web, para
  /// poder arrastrar) o bottom sheet (móvil).
  void _abrirLibro() {
    final ancho = MediaQuery.sizeOf(context).width;
    if (ancho >= 700) {
      setState(() => _libroAbierto = !_libroAbierto);
      return;
    }
    _mostrarLibroMovil();
  }

  /// Bottom sheet del libro (pantallas <700 px).
  void _mostrarLibroMovil() {
    _libroCerradoPorArrastre = false;
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
          onUsar: (c) =>
              _usarEntradaCatalogo(c, dia: _claveDeFecha(_fechas[_indiceSel])),
          onDragIniciado: _cerrarLibroParaArrastre,
          onDragCancelado: _reabrirLibroSiCerrado,
        ),
      ),
    );
  }

  /// Al iniciar un arrastre desde el sheet: lo cerramos para dejar ver los
  /// chips de día (Flutter mantiene el drag vivo aunque se desmonte el
  /// Draggable: drag_target.dart conserva el reconocedor con drag activo).
  void _cerrarLibroParaArrastre() {
    if (_libroCerradoPorArrastre) return;
    _libroCerradoPorArrastre = true;
    Navigator.of(context).pop();
  }

  /// Si el libro se cerró para un arrastre, lo vuelve a abrir (al soltar en
  /// zona vacía, o antes del formulario al acertar un día).
  void _reabrirLibroSiCerrado() {
    if (!_libroCerradoPorArrastre) return;
    _mostrarLibroMovil();
  }

  /// Añadir una entrada del catálogo como tarea: abre el formulario
  /// prellenado con los datos del libro (puntos, categoría, dificultad,
  /// icono) y el día elegido — con el botón "Añadir" o al soltar la
  /// tarjeta sobre un día.
  void _usarEntradaCatalogo(TareaCatalogo entrada, {String dia = ''}) {
    showDialog(
      context: context,
      builder: (_) => _TaskFormDialog(
        initialData: {
          'titulo': entrada.titulo,
          'puntos': entrada.puntos,
          'dificultad': entrada.dificultad,
          'categoria': entrada.categoria,
          'icono': entrada.icono,
          'dia': dia,
          'frecuencia': 'semanal',
        },
        onSaved: _crearDesdeDialog,
        usuarios: _integrantes,
        catalogo: _catalogo,
      ),
    );
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
              'automáticamente. Tú decides los castigos.',
            ),
            value: auto,
            onChanged: (v) async {
              setLocal(() => auto = v);
              await app.setAutoCastigos(v);
            },
          ),
          actions: [
            DuoButton(
              fullWidth: false,
              label: 'Listo',
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccion(String titulo) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
    child: Text(
      titulo,
      style: TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 18,
        color: textoTema(context),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final activas = widget.tareas.where((t) => t.activa).toList();
    final sinDia = activas.where((t) => t.dia.isEmpty).toList();
    final inactivas = widget.tareas.where((t) => !t.activa).toList();

    final fechas = _fechas;
    final fechaSel = fechas[_indiceSel];
    var delDia = _tareasDelDia(fechaSel);
    if (_miembroId != null) {
      delDia = delDia
          .where(
            (t) => (_asignados[t.id] ?? const <User>[]).any(
              (u) => u.id == _miembroId,
            ),
          )
          .toList();
    }

    final anchoPanel = MediaQuery.sizeOf(context).width;
    final libroLateral = _libroAbierto && anchoPanel >= 700;

    return Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(right: libroLateral ? 380 : 0),
            child: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _recargar,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: ReferenciaTitulo(
                      'ORGANIZA Y CONQUISTA',
                      'Mis tareas',
                      icono: Icono3DTipo.check,
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.menu_book_outlined),
                          tooltip: 'Libro de Tareas',
                          onPressed: _abrirLibro,
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined),
                          tooltip: 'Castigos automáticos',
                          onPressed: _ajustesCastigos,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.verde,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.add,
                              color: Colors.white,
                            ),
                            tooltip: 'Nueva tarea',
                            onPressed: _nuevaTarea,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: PillSegment(
                      index: _segmento,
                      onChanged: (i) => setState(() => _segmento = i),
                      items: const [
                        (icon: Icons.calendar_today, label: 'Tareas'),
                        (icon: Icons.flag_outlined, label: 'Retos'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _segmento == 1
                        ? const RetosAdminInline()
                        : ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                            children: [
                  // Paginador de semanas estilo referencia.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        tooltip: 'Semana anterior',
                        onPressed: () => setState(() => _semanaOffset -= 1),
                      ),
                      Flexible(
                        child: Text(
                          'Semana $_semanaIso · $_rangoFechas',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'Semana siguiente',
                        onPressed: () => setState(() => _semanaOffset += 1),
                      ),
                    ],
                  ),
                  // Filtro por integrante (carrusel horizontal).
                  if (_integrantes.isNotEmpty)
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ChoiceChip(
                            label: const Text('Todos'),
                            selected: _miembroId == null,
                            onSelected: (_) =>
                                setState(() => _miembroId = null),
                          ),
                          for (final u in _integrantes) ...[
                            const SizedBox(width: 8),
                            ChoiceChip(
                              avatar: UserAvatar(user: u, radius: 10),
                              label: Text(_nombreCorto(u.nombre)),
                              selected: _miembroId == u.id,
                              onSelected: (_) =>
                                  setState(() => _miembroId = u.id),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Rejilla de 7 días (letras) estilo referencia. Cada chip
                  // acepta tarjetas arrastradas desde el Libro de Tareas.
                  Row(
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: DragTarget<TareaCatalogo>(
                              onWillAcceptWithDetails: (_) => true,
                              onAcceptWithDetails: (d) {
                                // Móvil: el sheet se cerró al arrastrar;
                                // reabrirlo ANTES del formulario para que el
                                // diálogo quede encima del libro.
                                _reabrirLibroSiCerrado();
                                _usarEntradaCatalogo(
                                  d.data,
                                  dia: _claveDeFecha(_fechas[i]),
                                );
                              },
                              builder: (context, candidatos, rechazados) {
                                final sobre = candidatos.isNotEmpty;
                                return ChoiceChip(
                                  label: Text(_letrasDia[i]),
                                  selected: i == _indiceSel,
                                  side: BorderSide(
                                    color: sobre
                                        ? AppColors.verde
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                  onSelected: (_) =>
                                      setState(() => _diaSel = i),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Sección del día seleccionado.
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _tituloDia(fechaSel),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '${delDia.length} ${delDia.length == 1 ? 'tarea' : 'tareas'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: textoSuaveTema(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (activas.isEmpty)
                    const EmptyState(
                      mascota: MascotType.robito,
                      icon: Icons.calendar_view_week_outlined,
                      message: 'Aún no hay tareas activas.',
                      hint:
                          'Crea una tarea con su día para planificar la '
                          'semana.',
                    )
                  else if (delDia.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Sin tareas para este día.',
                        style: TextStyle(
                          fontSize: 12,
                          color: textoSuaveTema(context),
                        ),
                      ),
                    )
                  else
                    for (final (i, t) in delDia.indexed)
                      PlayfulEntrance(
                        delayMs: (i * 70).clamp(0, 560),
                        child: _AdminTareaFila(
                          tarea: t,
                          asignados: _asignados[t.id] ?? const [],
                          vencida: _vencida(t, fechaSel),
                          pendiente: _pendientes.contains(t.id),
                          onAsignar: () => _asignarDialogo(t),
                          onEditar: () => _editarTarea(t),
                          onEliminar: () => _eliminarTarea(t),
                        ),
                      ),
                  const SizedBox(height: 6),
                  // Creación rápida del día seleccionado.
                  _QuickAddDia(
                    fecha: fechaSel,
                    catalogo: _catalogo,
                    onCrear: _crearRapida,
                    onCrearLibre: _crearLibre,
                  ),
                  if (sinDia.isNotEmpty) ...[
                    _seccion('Todos los días'),
                    for (final (i, t) in sinDia.indexed)
                      PlayfulEntrance(
                        delayMs: (i * 70).clamp(0, 560),
                        child: _AdminTaskCard(
                          tarea: t,
                          asignados: _asignados[t.id] ?? const [],
                          catalogo: _catalogo,
                          onRefresh: _recargar,
                        ),
                      ),
                  ],
                  if (inactivas.isNotEmpty) ...[
                    _seccion('Inactivas'),
                    for (final (i, t) in inactivas.indexed)
                      PlayfulEntrance(
                        delayMs: (i * 70).clamp(0, 560),
                        child: _AdminTaskCard(
                          tarea: t,
                          asignados: _asignados[t.id] ?? const [],
                          catalogo: _catalogo,
                          onRefresh: _recargar,
                        ),
                      ),
                  ],
                  const SizedBox(height: 72),
                ],
              ),
            ),
          ],
        ),
      ),
          ),
          // Panel lateral del Libro de Tareas (>= 700 px): sin barrera
          // modal para que el arrastre de tarjetas a los días funcione.
          if (libroLateral)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 380,
              child: TweenAnimationBuilder<double>(
                tween: _panelTween,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (context, v, child) => Transform.translate(
                  offset: Offset(v * 380, 0),
                  child: child,
                ),
                child: Material(
                  elevation: 10,
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: _LibroTareas(
                    catalogo: _catalogo,
                    onChanged: _recargar,
                    onNuevo: _nuevaEntradaCatalogo,
                    onUsar: (c) => _usarEntradaCatalogo(
                      c,
                      dia: _claveDeFecha(_fechas[_indiceSel]),
                    ),
                    onCerrar: () => setState(() => _libroAbierto = false),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PIEZAS DEL ADMIN ESTILO REFERENCIA (filas · quick add)
// ---------------------------------------------------------------------------

/// Fila de tarea del día seleccionado estilo referencia: título + chip de
/// dificultad + XP + menú de acciones (asignar/editar/eliminar).
class _AdminTareaFila extends StatelessWidget {
  final Task tarea;
  final List<User> asignados;
  final bool vencida;
  final bool pendiente;
  final VoidCallback onAsignar;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _AdminTareaFila({
    required this.tarea,
    required this.asignados,
    required this.vencida,
    required this.pendiente,
    required this.onAsignar,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return CardBox(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (context) {
              final color = Color(CategoriaTarea.colorDe(tarea.categoria));
              return Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(color, Colors.white, 0.82)!,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icono3D(
                  tipo: tarea.icono3d,
                  size: 26,
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tarea.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    difChip(context, tarea.dificultad),
                    Text(
                      '${tarea.puntos} pts',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: textoTema(context),
                      ),
                    ),
                    if (vencida)
                      Chip(
                        label: const Text('Vencida'),
                        backgroundColor: rojoFondoTema(context),
                        labelStyle: const TextStyle(
                          color: AppColors.rojo,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (pendiente) const _IndicadorAprobacion(),
                  ],
                ),
                if (asignados.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final u in asignados.take(4))
                        UserAvatar(user: u, radius: 9),
                      if (asignados.length > 4)
                        Text(
                          '+${asignados.length - 4}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: textoSuaveTema(context),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Acciones',
            icon: Icon(Icons.more_horiz, color: textoSuaveTema(context)),
            onSelected: (v) {
              switch (v) {
                case 'asignar':
                  onAsignar();
                case 'editar':
                  onEditar();
                case 'eliminar':
                  onEliminar();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'asignar',
                child: Row(
                  children: [
                    Icon(Icons.person_add_alt_1, size: 17),
                    SizedBox(width: 10),
                    Text('Asignar a…'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'editar',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 17),
                    SizedBox(width: 10),
                    Text('Editar'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'eliminar',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 17),
                    SizedBox(width: 10),
                    Text('Eliminar'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Indicador compacto "pendiente de aprobación": reloj animado + icono de
/// reloj de arena, sin texto grande que estrangule el título en móvil.
class _IndicadorAprobacion extends StatelessWidget {
  const _IndicadorAprobacion();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Pendiente de aprobación',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: amarilloFondoTema(context),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              size: 13,
              color: AppColors.amarilloOscuro,
            ),
            SizedBox(width: 3),
            _RelojAprobacion(size: 16),
          ],
        ),
      ),
    );
  }
}

/// Reloj de arena con manecilla que gira, para alertar que algo está pendiente.
class _RelojAprobacion extends StatefulWidget {
  final double size;
  const _RelojAprobacion({this.size = 16});

  @override
  State<_RelojAprobacion> createState() => _RelojAprobacionState();
}

class _RelojAprobacionState extends State<_RelojAprobacion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _RelojPintor(
          _ctrl.value,
          amarilloFondoTema(context),
          textoTema(context),
        ),
      ),
    );
  }
}

class _RelojPintor extends CustomPainter {
  final double t;
  final Color fondo;
  final Color tinta;
  _RelojPintor(this.t, this.fondo, this.tinta);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = fondo);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = AppColors.amarilloOscuro
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.14,
    );
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final dir = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(
        c + dir * (r * 0.72),
        c + dir * (r * 0.86),
        Paint()
          ..color = tinta
          ..strokeWidth = r * 0.06
          ..strokeCap = StrokeCap.round,
      );
    }
    // Manecilla de las horas (lenta): 1 vuelta por cada 12 de minutos.
    _mano(canvas, c, t * 2 * math.pi / 12, r * 0.45, r * 0.11);
    // Manecilla de los minutos (rápida): 1 vuelta por ciclo.
    _mano(canvas, c, t * 2 * math.pi, r * 0.66, r * 0.07);
    canvas.drawCircle(c, r * 0.1, Paint()..color = AppColors.amarilloOscuro);
  }

  void _mano(Canvas canvas, Offset c, double ang, double largo, double ancho) {
    final dir = Offset(math.sin(ang), -math.cos(ang));
    canvas.drawLine(
      c,
      c + dir * largo,
      Paint()
        ..color = tinta
        ..strokeWidth = ancho
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RelojPintor old) =>
      old.t != t || old.fondo != fondo || old.tinta != tinta;
}

/// Campo de creación rápida para el día seleccionado.
class _QuickAddDia extends StatefulWidget {
  final DateTime fecha;
  final List<TareaCatalogo> catalogo;
  final Future<void> Function(
    String titulo,
    DateTime fecha, {
    TareaCatalogo? plantilla,
  })
  onCrear;
  final void Function(String titulo, DateTime fecha) onCrearLibre;

  const _QuickAddDia({
    required this.fecha,
    required this.catalogo,
    required this.onCrear,
    required this.onCrearLibre,
  });

  @override
  State<_QuickAddDia> createState() => _QuickAddDiaState();
}

class _QuickAddDiaState extends State<_QuickAddDia> {
  final _focus = FocusNode();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _enviar(String texto) async {
    final t = texto.trim();
    if (t.isEmpty) return;
    TareaCatalogo? match;
    for (final c in widget.catalogo) {
      final ct = c.titulo.trim().toLowerCase();
      if (ct == t.toLowerCase() || ct.startsWith(t.toLowerCase())) {
        match = c;
        break;
      }
    }
    _focus.unfocus();
    if (match != null) {
      await widget.onCrear(match.titulo, widget.fecha, plantilla: match);
    } else {
      widget.onCrearLibre(t, widget.fecha);
    }
    if (mounted) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: _controller,
      focusNode: _focus,
      style: const TextStyle(fontSize: 13),
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        isDense: true,
        hintText: '+ Añadir tarea este día…',
        hintStyle: const TextStyle(fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        suffixIconConstraints: const BoxConstraints(
          maxWidth: 34,
          maxHeight: 34,
        ),
        suffixIcon: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 20,
          icon: const Icon(Icons.add_circle),
          color: AppColors.verde,
          tooltip: 'Crear tarea',
          onPressed: () => _enviar(_controller.text),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? Colors.white24 : AppColors.linea,
          ),
        ),
      ),
      onSubmitted: _enviar,
    );
  }
}

/// Panel lateral/bottom-sheet con el catálogo CRUD ("Libro de Tareas").
class _LibroTareas extends StatelessWidget {
  final List<TareaCatalogo> catalogo;
  final Future<void> Function() onChanged;
  final VoidCallback onNuevo;

  /// Usa una entrada como tarea (formulario prellenado).
  final void Function(TareaCatalogo entrada)? onUsar;

  /// Cierra el panel lateral (cuando no vive en una ruta con Navigator).
  final VoidCallback? onCerrar;

  /// Sheet móvil: al iniciar un arrastre se cierra el libro para dejar ver
  /// los chips de día (Flutter conserva el drag al desmontar el Draggable).
  final VoidCallback? onDragIniciado;

  /// Sheet móvil: el arrastre se soltó sin acertar ningún día → reabrir.
  final VoidCallback? onDragCancelado;

  const _LibroTareas({
    required this.catalogo,
    required this.onChanged,
    required this.onNuevo,
    this.onUsar,
    this.onCerrar,
    this.onDragIniciado,
    this.onDragCancelado,
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
                onPressed: onCerrar ?? () => Navigator.pop(context),
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
                        mascota: MascotType.escobin,
                        icon: Icons.menu_book_outlined,
                        message: 'Registra tus tareas con sus puntos.',
                        hint:
                            'Pulsa "Nueva en el catálogo" para empezar. Al '
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
                            fontSize: 12,
                            color: textoSuaveTema(context),
                          ),
                        ),
                      ),
                      for (final c in lista)
                        _CatalogoCard(
                          entrada: c,
                          onChanged: onChanged,
                          onUsar: onUsar,
                          onDragIniciado: onDragIniciado,
                          onDragCancelado: onDragCancelado,
                        ),
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
      User(nombre: nombre, password: '', rol: 'integrante'),
    );
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
            user: User(nombre: nombre, password: '', rol: 'integrante'),
            radius: 8,
          ),
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
  final void Function(TareaCatalogo entrada)? onUsar;

  /// Sheet móvil: cerrar el libro al empezar el arrastre…
  final VoidCallback? onDragIniciado;

  /// …y reabrirlo si el arrastre se cancela sin soltar sobre un día.
  final VoidCallback? onDragCancelado;

  const _CatalogoCard({
    required this.entrada,
    required this.onChanged,
    this.onUsar,
    this.onDragIniciado,
    this.onDragCancelado,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorPorDificultad(_dificultadPara(entrada.puntos));
    final card = DuoCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icono3D(
              tipo: entrada.icono.isEmpty
                  ? CategoriaTarea.icono3dDe(entrada.categoria)
                  : Icono3DTipo.porNombre(entrada.icono),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entrada.titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entrada.puntos} pts · ${_capitalizar(_dificultadPara(entrada.puntos))}',
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
            icon: const Icon(Icons.add_circle, color: AppColors.verde),
            tooltip: 'Añadir a la semana',
            onPressed: onUsar == null ? null : () => onUsar!(entrada),
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

    // Arrastrar la tarjeta del libro sobre un día para abrir el formulario
    // prellenado de ese día. En el sheet móvil, al iniciar el arrastre el
    // libro se cierra solo (los chips de día quedan libres) y se reabre
    // al soltar si no se acertó ningún día.
    return LongPressDraggable<TareaCatalogo>(
      data: entrada,
      hapticFeedbackOnStart: true,
      onDragStarted: onDragIniciado,
      onDraggableCanceled: (_, _) => onDragCancelado?.call(),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.6)),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 8),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icono3D(
                tipo: entrada.icono.isEmpty
                    ? CategoriaTarea.icono3dDe(entrada.categoria)
                    : Icono3DTipo.porNombre(entrada.icono),
                size: 18,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  entrada.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
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
          await app.editarCatalogo(
            TareaCatalogo(
              id: entrada.id,
              titulo: titulo,
              puntos: puntos,
              categoria: (data['categoria'] as String?) ?? entrada.categoria,
              dificultad: (data['dificultad'] as String?) ?? entrada.dificultad,
              icono: (data['icono'] as String?) ?? entrada.icono,
            ),
          );
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
  late String _icono;

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(
      text: widget.inicial?.titulo ?? '',
    );
    _puntosController = TextEditingController(
      text: (widget.inicial?.puntos ?? 0).toString(),
    );
    _categoria = widget.inicial?.categoria ?? 'General';
    _dificultad =
        widget.inicial?.dificultad ??
        _dificultadPara(widget.inicial?.puntos ?? 0);
    _icono = widget.inicial?.icono ?? '';
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
              validator: (v) => (v == null || int.tryParse(v) == null)
                  ? 'Número válido'
                  : null,
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
                  color: verdeFondoTema(context),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icono3D(
                  tipo: _icono.isEmpty
                      ? CategoriaTarea.icono3dDe(_categoria)
                      : Icono3DTipo.porNombre(_icono),
                  size: 38,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 148),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _IconoOpcion(
                      tipo: CategoriaTarea.icono3dDe(_categoria),
                      etiqueta: 'Auto',
                      seleccionado: _icono.isEmpty,
                      onTap: () => setState(() => _icono = ''),
                    ),
                    for (final t in Icono3DTipo.values)
                      _IconoOpcion(
                        tipo: t,
                        seleccionado: _icono == t.name,
                        onTap: () => setState(() => _icono = t.name),
                      ),
                  ],
                ),
              ),
            ),
          ],
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
                widget.onSaved?.call({
                  'titulo': _tituloController.text,
                  'puntos': int.tryParse(_puntosController.text) ?? 0,
                  'categoria': _categoria,
                  'dificultad': _dificultad,
                  'icono': _icono,
                });
                Navigator.pop(context);
              },
            ),
          ),
        ],
    );
  }
}

/// Opción de la librería de iconos del catálogo (con etiqueta opcional).
class _IconoOpcion extends StatelessWidget {
  final Icono3DTipo tipo;
  final bool seleccionado;
  final VoidCallback onTap;
  final String? etiqueta;

  const _IconoOpcion({
    required this.tipo,
    required this.seleccionado,
    required this.onTap,
    this.etiqueta,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: seleccionado ? verdeFondoTema(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado
                ? AppColors.verde
                : (esOscuro(context) ? Colors.white24 : AppColors.linea),
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icono3D(tipo: tipo, size: etiqueta == null ? 26 : 20),
            if (etiqueta != null)
              Text(
                etiqueta!,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: textoTema(context),
                ),
              ),
          ],
        ),
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DuoCard(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Container(
          width: 48,
          height: 48,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : AppColors.linea,
              borderRadius: BorderRadius.circular(12),
            ),
            child: tarea.icono.isEmpty
                ? Icon(
                    CategoriaTarea.iconoDe(tarea.categoria),
                    size: 24,
                    color: Color(CategoriaTarea.colorDe(tarea.categoria)),
                  )
                : Icono3D(tipo: tarea.icono3d, size: 24),
          ),
        title: Text(
          tarea.titulo,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Row(
              children: [
                difChip(context, tarea.dificultad),
                const Spacer(),
                if (tarea.dia.isNotEmpty) ...[
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: textoSuaveTema(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _nombreDia(tarea.dia),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: textoSuaveTema(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Bolt3D(size: 16, animar: false),
                const SizedBox(width: 3),
                Text(
                  '+${tarea.puntos} pts',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: textoSuaveTema(context),
                  ),
                ),
              ],
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
              avatar: Icon(
                CategoriaTarea.iconoDe(tarea.categoria),
                size: 14,
                color: Colors.white,
              ),
              label: Text(tarea.categoria),
              labelStyle: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
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
    final integrantesData = asignadosAEstaTarea
        .map((u) => {'id': u.id})
        .toList();
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

  Future<void> _crearEditarTarea(
    BuildContext context, {
    required Map<String, Object?> data,
    int? id,
  }) async {
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
          'esa tarea, se devolverán los puntos a los integrantes.',
        ),
        actions: [
          DialogActions(
            onCancel: () => Navigator.pop(ctx, false),
            primary: DuoButton(
              fullWidth: false,
              color: AppColors.rojo,
              borderColor: AppColors.rojoOscuro,
              label: 'Eliminar',
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
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
        Text(
          'Asignaciones:',
          style: TextStyle(fontSize: 12, color: textoSuaveTema(context)),
        ),
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
      children: [for (final u in asignados) _IntegrantePill(nombre: u.nombre)],
    );
  }
}

class _IntegranteTasksList extends StatelessWidget {
  final List<(Task, Assignment)> misTareas;
  final List<(Task, Assignment, User)> robables;
  const _IntegranteTasksList({
    required this.misTareas,
    this.robables = const [],
  });

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

    // Solo lo que sigue sin aprobar Y es del día actual: día de hoy o
    // con fecha límite que vence hoy.
    final items = misTareas
        .where((t) => !t.$2.aprobada && _esDeHoy(t.$1))
        .toList();

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          final app = context.read<AppProvider>();
          final u = app.usuarioActual;
          if (u != null) {
            await app.tareasConAsignacionDe(u.id!);
            await app.tareasRobables();
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const EmptyState(
              mascota: MascotType.chispita,
              icon: Icons.task_alt,
              message: 'No tienes tareas para hoy.',
              hint: 'Vuelve mañana o pídele al administrador nuevas tareas.',
            ),
            if (robables.isNotEmpty) ...[
              ..._seccionRobables(context, app),
            ],
          ],
        ),
      );
    }

    final conDia = items.where((t) => t.$1.dia.isNotEmpty).toList()
      ..sort(
        (a, b) => _diasOrden
            .indexOf(a.$1.dia)
            .compareTo(_diasOrden.indexOf(b.$1.dia)),
      );
    final sinDia = items.where((t) => t.$1.dia.isEmpty).toList();

    return RefreshIndicator(
      onRefresh: () async {
        final app2 = context.read<AppProvider>();
        final u = app2.usuarioActual;
        if (u != null) {
          await app2.tareasConAsignacionDe(u.id!);
          await app2.tareasRobables();
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          for (final (i, t) in [...conDia, ...sinDia].indexed)
            PlayfulEntrance(
              delayMs: (i * 70).clamp(0, 560),
              child: _MiniTaskCard(
                task: t.$1,
                assignment: t.$2,
                bloqueada: t.$1.dia.isNotEmpty && t.$1.dia != _diaHoy,
                vencida: _vencida(t.$1),
                onCompletada: () {
                  lanzarConfeti(context);
                  app.completarTarea(t.$1.id!);
                },
              ),
            ),
          if (robables.isNotEmpty) ...[
            ..._seccionRobables(context, app),
          ],
        ],
      ),
    );
  }

  /// Sección "🔥 Para robar": tareas que otros dejaron vencidas. Primero
  /// en pulsar se las queda (pago al instante, sin aprobación).
  List<Widget> _seccionRobables(BuildContext context, AppProvider app) {
    return [
      const SizedBox(height: 18),
      Row(
        children: [
          const Icon(Icons.local_fire_department, size: 20, color: AppColors.coral),
          const SizedBox(width: 6),
          Text(
            'Para robar',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: textoTema(context),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${robables.length}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.coral,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        'Tareas que alguien dejó vencidas: llévatelas y gana sus puntos.',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textoSuaveTema(context),
        ),
      ),
      const SizedBox(height: 10),
      for (final r in robables)
        _TareaRobableCard(
          task: r.$1,
          dueno: r.$3,
          onRobar: () async {
            final ok = await app.robarTarea(r.$2.id!);
            if (!ok || !context.mounted) return;
            lanzarConfeti(context);
            unawaited(CelebrationService.instance.success());
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '¡Robaste "${r.$1.titulo}" de ${r.$3.nombre}! '
                    '+${r.$1.puntos} pts',
                  ),
                ),
              );
            }
          },
        ),
    ];
  }

  /// Día de hoy en minúsculas según la semana (mismo formato que `Task.dia`).
  static String get _diaHoy {
    const nombres = [
      'domingo',
      'lunes',
      'martes',
      'miercoles',
      'jueves',
      'viernes',
      'sabado',
    ];
    return nombres[DateTime.now().weekday % 7];
  }

  /// ¿La tarea de hoy ya pasó su hora límite (y por tanto puede ser
  /// robada)? Solo aplica a tareas con fecha/hora explícita: las de día de
  /// la semana vencen a medianoche, cuando ya no aparecen en esta lista.
  static bool _vencida(Task task) {
    final fl = task.fechaLimite;
    if (fl == null) return false;
    final f = fl.toLocal();
    if (f.hour == 0 && f.minute == 0 && f.second == 0) return false;
    return DateTime.now().isAfter(f);
  }

  /// ¿La tarea es del día actual? Día de la semana de hoy, o con fecha
  /// límite que cae hoy (las vencidas o de otros días no se muestran).
  static bool _esDeHoy(Task task) {
    if (task.dia.isNotEmpty) return task.dia == _diaHoy;
    final fl = task.fechaLimite;
    if (fl == null) return false;
    final f = fl.toLocal();
    final now = DateTime.now();
    return f.year == now.year && f.month == now.month && f.day == now.day;
  }
}

class _TareaRobableCard extends StatelessWidget {
  final Task task;
  final User dueno;
  final VoidCallback onRobar;
  const _TareaRobableCard({
    required this.task,
    required this.dueno,
    required this.onRobar,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.superficieOscura : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isDark
            ? Border.all(color: AppColors.grisMedio.withValues(alpha: 0.3))
            : Border.all(
                color: AppColors.coral.withValues(alpha: 0.5),
                width: 1.5,
              ),
        boxShadow: isDark
            ? const []
            : [
                BoxShadow(
                  color: AppColors.coral.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: coralFondoTema(context),
            ),
            child: const Icon(
              Icons.local_fire_department,
              color: AppColors.coralOscuro,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: textoTema(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Vencida de ${dueno.nombre}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textoSuaveTema(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${task.puntos} pts',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.verde,
                ),
              ),
              const SizedBox(height: 6),
              DuoButton(
                fullWidth: false,
                label: '¡Robarla!',
                icon: Icons.local_fire_department,
                onPressed: onRobar,
              ),
            ],
          ),
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
  final bool vencida;

  const _MiniTaskCard({
    required this.task,
    required this.assignment,
    this.onCompletada,
    this.bloqueada = false,
    this.vencida = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Widget trailing;
    if (assignment.completada) {
      trailing = Chip(
        label: const Text('EN REVISIÓN'),
        backgroundColor: amarilloFondoTema(context),
        labelStyle: TextStyle(
          color: textoTema(context),
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      );
    } else if (bloqueada) {
      trailing = Chip(
        label: const Text('BLOQUEADA'),
        backgroundColor: isDark ? Colors.white10 : AppColors.linea,
        labelStyle: TextStyle(
          color: textoSuaveTema(context),
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      );
    } else if (vencida) {
      // Aviso: al estar vencida, otro hijo puede robársela.
      trailing = Chip(
        label: const Text('¡PUEDE SER ROBADA!'),
        backgroundColor: coralFondoTema(context),
        labelStyle: TextStyle(
          color: textoTema(context),
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      trailing = const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.superficieOscura : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isDark
            ? Border.all(color: AppColors.grisMedio.withValues(alpha: 0.3))
            : null,
        boxShadow: isDark
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar infantil de la categoría (círculo con gradiente).
          Builder(
            builder: (context) {
              final color = Color(CategoriaTarea.colorDe(task.categoria));
              return Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(color, Colors.white, 0.80)!,
                  border:
                      isDark ? null : Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icono3D(
                  tipo: task.icono3d,
                  size: 34,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textoTema(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _lineaVencimiento(task),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textoSuaveTema(context),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                if (!assignment.completada && !bloqueada)
                  DuoButton(
                    label: 'Marcar como hecha',
                    onPressed: onCompletada,
                  )
                else
                  trailing,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Segunda línea de la tarjeta de tareas: "8 pts · vence hoy · 17:00".
String _lineaVencimiento(Task task) {
  final fl = task.fechaLimite;
  if (fl != null) {
    final f = fl.toLocal();
    final hoy = DateTime.now();
    final diff = DateTime(
      f.year,
      f.month,
      f.day,
    ).difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
    final hora = (f.hour == 0 && f.minute == 0)
        ? ''
        : ' · ${f.hour.toString().padLeft(2, '0')}'
              ':${f.minute.toString().padLeft(2, '0')}';
    if (diff < 0) {
      return '${task.puntos} pts · vencida el ${f.day} ${_mesesCortos[f.month - 1]}';
    }
    if (diff == 0) {
      return '${task.puntos} pts · vence hoy$hora';
    }
    if (diff == 1) {
      return '${task.puntos} pts · vence mañana';
    }
    return '${task.puntos} pts · vence el ${f.day} ${_mesesCortos[f.month - 1]}';
  }
  if (task.dia.isNotEmpty) {
    return '${task.puntos} pts · vence ${_nombreDia(task.dia).toLowerCase()}';
  }
  return '${task.puntos} pts';
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

const _mesesCortos = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

class _HistorialCard extends StatelessWidget {
  final Task task;
  final Assignment assignment;

  const _HistorialCard({required this.task, required this.assignment});

  @override
  Widget build(BuildContext context) {
    final completada = assignment.fechaCompletada != null;
    final fecha = assignment.fechaCompletada ?? assignment.fechaAsignada;
    final fechaTxt = fecha == null
        ? ''
        : '${fecha.day} ${_mesesCortos[fecha.month - 1]}';
    final etiqueta = completada ? 'Completada · $fechaTxt' : 'Asignada · $fechaTxt';

    return CardBox(
      color: completada
          ? verdeFondoTema(context)
          : amarilloFondoTema(context),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: completada ? AppColors.verde : AppColors.amarilloOscuro,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              completada ? Icons.check_circle_rounded : Icons.schedule_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: textoTema(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textoSuaveTema(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '+${task.puntos} XP',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: textoTema(context),
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
  String _icono = '';
  final Set<int> _integrantesIds = {};
  bool _puntosManual = false;

  /// Si el título coincide con el catálogo y el admin no tocó los campos,
  /// rellena puntos/categoría/dificultad/icono por defecto.
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
        if (_icono != c.icono) {
          _icono = c.icono;
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
    final sugerida = pts >= 10 ? 'dificil' : (pts >= 6 ? 'media' : 'facil');
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
      _icono = d['icono'] as String? ?? '';
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
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
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
                      validator: (v) => (v == null || int.tryParse(v) == null)
                          ? 'Número válido'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _dificultad,
                      decoration: const InputDecoration(
                        labelText: 'Dificultad',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'facil', child: Text('Fácil')),
                        DropdownMenuItem(value: 'media', child: Text('Media')),
                        DropdownMenuItem(
                          value: 'dificil',
                          child: Text('Difícil'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _dificultad = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoria,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: [
                  for (final c in CategoriaTarea.nombres)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _categoria = v!),
              ),
              const SizedBox(height: 12),
              // Icono de la tarea: el del Libro de Tareas si tiene; si no,
              // el de la categoría. Vive en el formulario para que se vea
              // al prellenar y se guarde con la tarea.
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Color(
                        CategoriaTarea.colorDe(_categoria),
                      ).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icono3D(
                      tipo: _icono.isEmpty
                          ? CategoriaTarea.icono3dDe(_categoria)
                          : Icono3DTipo.porNombre(_icono),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _icono.isEmpty
                          ? 'Icono por defecto de la categoría'
                          : 'Icono del Libro de Tareas',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: textoSuaveTema(context),
                      ),
                    ),
                  ),
                ],
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
                  if (!context.mounted) return;
                  final prev = _fechaLimite;
                  final hora = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(prev ?? picked),
                  );
                  final t =
                      hora ??
                      (prev != null
                          ? TimeOfDay(hour: prev.hour, minute: prev.minute)
                          : const TimeOfDay(hour: 0, minute: 0));
                  setState(
                    () => _fechaLimite = DateTime(
                      picked.year,
                      picked.month,
                      picked.day,
                      t.hour,
                      t.minute,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _frecuencia,
                decoration: const InputDecoration(labelText: 'Frecuencia'),
                items: const [
                  DropdownMenuItem(value: 'unica', child: Text('Única')),
                  DropdownMenuItem(value: 'diaria', child: Text('Diaria')),
                  DropdownMenuItem(value: 'semanal', child: Text('Semanal')),
                  DropdownMenuItem(value: 'mensual', child: Text('Mensual')),
                ],
                onChanged: (v) => setState(() => _frecuencia = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _dia.isEmpty ? null : _dia,
                hint: const Text('Día de la semana'),
                decoration: const InputDecoration(labelText: 'Día'),
                items: const [
                  DropdownMenuItem(value: 'domingo', child: Text('Domingo')),
                  DropdownMenuItem(value: 'lunes', child: Text('Lunes')),
                  DropdownMenuItem(value: 'martes', child: Text('Martes')),
                  DropdownMenuItem(
                    value: 'miercoles',
                    child: Text('Miércoles'),
                  ),
                  DropdownMenuItem(value: 'jueves', child: Text('Jueves')),
                  DropdownMenuItem(value: 'viernes', child: Text('Viernes')),
                  DropdownMenuItem(value: 'sabado', child: Text('Sábado')),
                ],
                onChanged: (v) => setState(() => _dia = v ?? ''),
              ),
              if (widget.usuarios.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Asignar a:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...widget.usuarios.map(
                  (u) => CheckboxListTile(
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
                  ),
                ),
              ],
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
              final data = {
                'titulo': _tituloController.text,
                'descripcion': _descripcionController.text,
                'puntos': int.tryParse(_puntosController.text) ?? 0,
                'dificultad': _dificultad,
                'fechaLimite': _fechaLimite,
                'frecuencia': _frecuencia,
                'dia': _dia,
                'categoria': _categoria,
                'icono': _icono,
                'integrantes': _integrantesIds.map((id) => {'id': id}).toList(),
              };
              widget.onSaved?.call(data);
            },
          ),
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        if (historial.isEmpty)
          const EmptyState(
            mascota: MascotType.nubecita,
            icon: Icons.history_toggle_off,
            message: 'Sin historial de tareas completadas.',
            hint: 'Completa tareas para ver tu historial aquí.',
          )
        else
          for (final (i, (t, a)) in historial.indexed)
            PlayfulEntrance(
              delayMs: (i * 70).clamp(0, 560),
              child: _HistorialCard(task: t, assignment: a),
            ),
      ],
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
