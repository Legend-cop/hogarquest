import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/confetti.dart';
import '../widgets/duo_widgets.dart';
import '../widgets/empty_state.dart';
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

class _AdminTasksList extends StatelessWidget {
  final List<Task> tareas;
  final Future<void> Function() onRefresh;

  const _AdminTasksList({required this.tareas, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tareas del hogar'),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: tareas.length,
                itemBuilder: (context, i) => _AdminTaskCard(tarea: tareas[i]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: DuoButton(
                label: 'Nueva tarea',
                icon: Icons.add,
                onPressed: () => _nuevaTarea(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _nuevaTarea(BuildContext context) async {
    final app = context.read<AppProvider>();
    await app.listarUsuarios();
    final usuarios = app.listaUsuarios;
    showDialog(
      context: context,
      builder: (_) => _TaskFormDialog(
        onSaved: (data) => _crearEditarTarea(context, data: data),
        usuarios: usuarios,
      ),
    );
  }

  Future<void> _crearEditarTarea(BuildContext context,
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
    if (context.mounted) Navigator.pop(context);
    await app.listarTareas();
  }
}

class _AdminTaskCard extends StatelessWidget {
  final Task tarea;
  const _AdminTaskCard({required this.tarea});

  @override
  Widget build(BuildContext context) {
    return DuoCard(
      padding: EdgeInsets.zero,
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
          _CardActionsAdmin(tarea: tarea),
        ],
      ),
    );
  }

  void _editarTarea(BuildContext context, Task tarea) async {
    final app = context.read<AppProvider>();
    await app.listarUsuarios();
    final usuarios = app.listaUsuarios;
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
    await app.listarTareas();
  }

  Future<void> _eliminarTarea(BuildContext context, int id) async {
    final app = context.read<AppProvider>();
    await app.eliminarTarea(id);
    if (context.mounted) Navigator.pop(context);
    await app.listarTareas();
  }
}

class _CardActionsAdmin extends StatelessWidget {
  final Task tarea;
  const _CardActionsAdmin({required this.tarea});

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
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        _AsignadosList(tareaId: tarea.id!),
      ],
    );
  }
}

class _AsignadosList extends StatelessWidget {
  final int tareaId;
  const _AsignadosList({required this.tareaId});

  @override
  Widget build(BuildContext context) {
    return const Text('(Detalle de asignaciones)', style: TextStyle(fontSize: 11));
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
}

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

  const _TaskFormDialog({this.initialData, this.onSaved, this.usuarios = const []});

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

  @override
  void initState() {
    super.initState();
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