import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/tarea_catalogo.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import 'empty_state.dart';
import 'user_avatar.dart';

/// Planificador semanal unificado (sustituye las pestañas Semana/Tareas/Catálogo).
///
/// * Barra superior fija: carrusel de avatares arrastrables + paginador de
///   semanas reales con fechas del calendario.
/// * Cuerpo: 7 columnas en pantallas anchas (≥700px) o 7 bloques verticales
///   en móvil. El día de HOY se marca con contorno verde neón.
/// * Tarjetas con editar/eliminar inline (hover en web) y etiqueta "Vencida".
/// * Creación rápida con catálogo predictivo al pie de cada día.
class WeeklyPlanner extends StatefulWidget {
  final List<Task> tareas;
  final Map<int, List<User>> asignados;
  final List<User> integrantes;
  final List<TareaCatalogo> catalogo;
  final Set<int> pendientes;
  final int semanaOffset;
  final ValueChanged<int> onSemanaChanged;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Task tarea, User responsable) onReasignar;
  final void Function(Task tarea) onEditar;
  final void Function(Task tarea) onEliminar;
  final Future<void> Function(String titulo, DateTime fecha,
      {TareaCatalogo? plantilla}) onCrearRapida;
  final void Function(String titulo, DateTime fecha) onCrearLibre;
  /// Secciones extra ("Todos los días", "Inactivas") al pie del scroll.
  final List<Widget> extra;

  const WeeklyPlanner({
    super.key,
    required this.tareas,
    required this.asignados,
    required this.integrantes,
    required this.catalogo,
    required this.pendientes,
    required this.semanaOffset,
    required this.onSemanaChanged,
    required this.onRefresh,
    required this.onReasignar,
    required this.onEditar,
    required this.onEliminar,
    required this.onCrearRapida,
    required this.onCrearLibre,
    this.extra = const [],
  });

  @override
  State<WeeklyPlanner> createState() => _WeeklyPlannerState();
}

class _WeeklyPlannerState extends State<WeeklyPlanner> {
  static const _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  final Map<String, GlobalKey> _dayKeys = {};
  bool _scrollInicial = false;

  /// Domingo de la semana visible según el offset.
  DateTime get _inicioSemana {
    final hoy = DateTime.now();
    final domingoActual = DateTime(hoy.year, hoy.month, hoy.day)
        .subtract(Duration(days: hoy.weekday % 7));
    return domingoActual.add(Duration(days: widget.semanaOffset * 7));
  }

  List<DateTime> get _fechas =>
      [for (var i = 0; i < 7; i++) _inicioSemana.add(Duration(days: i))];

  String get _tituloSemana {
    final f = _fechas;
    if (f.first.month == f.last.month && f.first.year == f.last.year) {
      return 'Semana del ${f.first.day} al ${f.last.day} de ${_meses[f.first.month - 1]}';
    }
    return 'Semana del ${f.first.day} de ${_meses[f.first.month - 1]}'
        ' al ${f.last.day} de ${_meses[f.last.month - 1]}';
  }

  static String nombreDiaLargo(int weekday) => const [
        'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
      ][weekday - 1];

  static String claveDia(DateTime f) => const [
        'domingo', 'lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado',
      ][f.weekday % 7];

  bool _esHoy(DateTime f) {
    final hoy = DateTime.now();
    return f.year == hoy.year && f.month == hoy.month && f.day == hoy.day;
  }

  List<User> _asignadosDe(Task t) => widget.asignados[t.id] ?? const [];

  /// Tareas visibles en la columna de una fecha concreta.
  List<Task> _tareasDelDia(DateTime fecha) {
    final clave = claveDia(fecha);
    return widget.tareas.where((t) {
      if (!t.activa) return false;
      // Con día de la semana recurrente: solo aparece en su día.
      if (t.dia.isNotEmpty) return t.dia == clave;
      // Sin día: aparece en la fecha exacta de su límite si cae en la semana.
      final fl = t.fechaLimite;
      return fl != null &&
          fl.year == fecha.year &&
          fl.month == fecha.month &&
          fl.day == fecha.day;
    }).toList();
  }

  bool _vencida(Task t, DateTime fecha) {
    if (!widget.pendientes.contains(t.id)) return false;
    final fl = t.fechaLimite;
    final limite = fl != null &&
            fl.year == fecha.year &&
            fl.month == fecha.month &&
            fl.day == fecha.day
        ? fl
        : DateTime(fecha.year, fecha.month, fecha.day, 23, 59);
    return DateTime.now().isAfter(limite);
  }

  /// Lleva el scroll al bloque de HOY la primera vez (solo en vista de lista).
  void _irAHoy() {
    if (_scrollInicial || widget.semanaOffset != 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollInicial = true;
      for (final f in _fechas) {
        if (!_esHoy(f)) continue;
        final ctx = _dayKeys[f.toIso8601String()]?.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.05,
            duration: const Duration(milliseconds: 350),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _irAHoy();
    final activas = widget.tareas.where((t) => t.activa).toList();
    final vacio = activas.isEmpty && widget.integrantes.isEmpty;

    return Column(
      children: [
        _barraSuperior(context),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: vacio
                ? LayoutBuilder(
                    builder: (context, c) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: c.maxHeight,
                        child: const EmptyState(
                          icon: Icons.calendar_view_week_outlined,
                          message: 'Aún no hay tareas activas.',
                          hint: 'Crea una tarea con su día para planificar '
                              'la semana.',
                        ),
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final grid = constraints.maxWidth >= 700;
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 800),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (grid)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (final fecha in _fechas)
                                        Expanded(
                                          child: _diaBloque(
                                            fecha,
                                            compacto: true,
                                          ),
                                        ),
                                    ],
                                  )
                                else
                                  for (final fecha in _fechas)
                                    _diaBloque(fecha, compacto: false),
                                ...widget.extra,
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  /// Barra superior fija: avatares arrastrables + paginador de semanas.
  Widget _barraSuperior(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.superficieOscura : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white24 : AppColors.linea,
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Semana anterior',
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    widget.onSemanaChanged(widget.semanaOffset - 1),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _tituloSemana,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    if (widget.semanaOffset != 0)
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () => widget.onSemanaChanged(0),
                        child: const Text('Volver a hoy',
                            style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Semana siguiente',
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    widget.onSemanaChanged(widget.semanaOffset + 1),
              ),
            ],
          ),
          if (widget.integrantes.isNotEmpty)
            SizedBox(
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final u in widget.integrantes)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: LongPressDraggable<User>(
                        data: u,
                        hapticFeedbackOnStart: true,
                        feedback: Material(
                          color: Colors.transparent,
                          child: _AvatarBurbuja(u: u, radius: 24),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.35,
                          child: _AvatarBurbuja(u: u, radius: 18),
                        ),
                        child: _AvatarBurbuja(u: u, radius: 18),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.drag_indicator,
                            size: 16, color: textoSuaveTema(context)),
                        const SizedBox(width: 4),
                        Text(
                          'Mantén pulsado un avatar y arrástralo a una tarea',
                          style: TextStyle(
                            fontSize: 11,
                            color: textoSuaveTema(context),
                          ),
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

  /// Bloque de un día (cabecera + tareas + creación rápida).
  Widget _diaBloque(DateTime fecha, {required bool compacto}) {
    final tareas = _tareasDelDia(fecha);
    final hoy = _esHoy(fecha);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final key = GlobalKey(debugLabel: fecha.toIso8601String());
    _dayKeys[fecha.toIso8601String()] = key;

    return Container(
      key: key,
      margin: EdgeInsets.only(bottom: compacto ? 0 : 10, right: compacto ? 6 : 0),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : (hoy ? AppColors.verdeFondo : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hoy ? AppColors.verde : (isDark ? Colors.white24 : AppColors.linea),
          width: hoy ? 2.5 : 1.5,
        ),
        boxShadow: hoy
            ? [
                BoxShadow(
                  color: AppColors.verde.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x14000000),
                  offset: Offset(0, 3),
                  blurRadius: 0,
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cabeceraDia(fecha, tareas.length, hoy: hoy, compacto: compacto),
          const SizedBox(height: 6),
          if (tareas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Sin tareas',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: textoSuaveTema(context),
                ),
              ),
            )
          else
            for (final t in tareas) ...[
              _TaskCardPlanner(
                tarea: t,
                fecha: fecha,
                asignados: _asignadosDe(t),
                vencida: _vencida(t, fecha),
                onEditar: () => widget.onEditar(t),
                onEliminar: () => widget.onEliminar(t),
                onReasignar: (u) => widget.onReasignar(t, u),
              ),
              const SizedBox(height: 6),
            ],
          const SizedBox(height: 2),
          _QuickAdd(
            fecha: fecha,
            catalogo: widget.catalogo,
            compacto: compacto,
            onCrear: widget.onCrearRapida,
            onCrearLibre: widget.onCrearLibre,
          ),
        ],
      ),
    );
  }

  Widget _cabeceraDia(DateTime fecha, int total,
      {required bool hoy, required bool compacto}) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 18,
          decoration: BoxDecoration(
            color: hoy ? AppColors.verde : AppColors.azul,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            compacto
                ? '${nombreDiaLargo(fecha.weekday)} ${fecha.day}'
                : '${nombreDiaLargo(fecha.weekday)} ${fecha.day}/${fecha.month}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: compacto ? 12.5 : 15,
            ),
          ),
        ),
        if (hoy) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.verde,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AppColors.verde.withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
            child: const Text(
              'HOY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
        if (total > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.linea.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$total',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: textoSuaveTema(context),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Burbuja de avatar con nombre para el carrusel arrastrable.
class _AvatarBurbuja extends StatelessWidget {
  final User u;
  final double radius;
  const _AvatarBurbuja({required this.u, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        UserAvatar(user: u, radius: radius),
        if (radius >= 16) ...[
          const SizedBox(height: 2),
          SizedBox(
            width: radius * 3.4,
            child: Text(
              u.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }
}

/// Tarjeta de tarea dentro del planificador: drag-target para reasignar,
/// editar/eliminar inline (hover en escritorio) y etiqueta "Vencida".
class _TaskCardPlanner extends StatefulWidget {
  final Task tarea;
  final DateTime fecha;
  final List<User> asignados;
  final bool vencida;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final ValueChanged<User> onReasignar;

  const _TaskCardPlanner({
    required this.tarea,
    required this.fecha,
    required this.asignados,
    required this.vencida,
    required this.onEditar,
    required this.onEliminar,
    required this.onReasignar,
  });

  @override
  State<_TaskCardPlanner> createState() => _TaskCardPlannerState();
}

class _TaskCardPlannerState extends State<_TaskCardPlanner> {
  bool _hover = false;
  bool _sobre = false; // arrastre encima

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // En táctil los botones siempre visibles; en web/escritorio con hover.
    final siempreVisible = kIsWeb
        ? (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)
        : true;
    final mostrarAcciones = siempreVisible || _hover;
    final colorTexto = widget.vencida ? textoSuaveTema(context) : textoTema(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: DragTarget<User>(
        onAcceptWithDetails: (d) => widget.onReasignar(d.data),
        onWillAcceptWithDetails: (_) {
          if (!_sobre) setState(() => _sobre = true);
          return true;
        },
        onLeave: (_) => setState(() => _sobre = false),
        builder: (context, candidatos, rechazados) {
          final arrastrando = candidatos.isNotEmpty || _sobre;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.fromLTRB(8, 7, 6, 7),
            decoration: BoxDecoration(
              color: widget.vencida
                  ? AppColors.rojo.withValues(alpha: 0.08)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: arrastrando
                    ? AppColors.verde
                    : widget.vencida
                        ? AppColors.rojo.withValues(alpha: 0.45)
                        : (isDark ? Colors.white12 : AppColors.linea),
                width: arrastrando ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.tarea.titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: colorTexto,
                          decoration: widget.vencida
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 120),
                      opacity: mostrarAcciones ? 1 : 0,
                      child: mostrarAcciones
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _MiniAccion(
                                  icono: Icons.edit,
                                  color: AppColors.azul,
                                  tooltip: 'Editar',
                                  onPressed: widget.onEditar,
                                ),
                                _MiniAccion(
                                  icono: Icons.delete,
                                  color: AppColors.rojo,
                                  tooltip: 'Eliminar',
                                  onPressed: widget.onEliminar,
                                ),
                              ],
                            )
                          : const SizedBox(width: 8),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${widget.tarea.puntos} pts · ${widget.tarea.dificultad.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: textoSuaveTema(context),
                        ),
                      ),
                    ),
                    if (widget.vencida) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.rojo,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Text(
                          'Vencida',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (widget.asignados.isEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Sin asignar',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: textoSuaveTema(context),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 3,
                    runSpacing: 3,
                    children: [
                      for (final u in widget.asignados.take(3))
                        UserAvatar(user: u, radius: 7),
                      if (widget.asignados.length > 3)
                        Text(
                          '+${widget.asignados.length - 3}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: textoSuaveTema(context),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MiniAccion extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _MiniAccion({
    required this.icono,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(icono, size: 15, color: color),
        ),
      ),
    );
  }
}

/// Campo de creación rápida con catálogo predictivo (menú flotante).
class _QuickAdd extends StatefulWidget {
  final DateTime fecha;
  final List<TareaCatalogo> catalogo;
  final bool compacto;
  final Future<void> Function(String titulo, DateTime fecha,
      {TareaCatalogo? plantilla}) onCrear;
  final void Function(String titulo, DateTime fecha) onCrearLibre;

  const _QuickAdd({
    required this.fecha,
    required this.catalogo,
    required this.compacto,
    required this.onCrear,
    required this.onCrearLibre,
  });

  @override
  State<_QuickAdd> createState() => _QuickAddState();
}

class _QuickAddState extends State<_QuickAdd> {
  final _focus = FocusNode();
  late final TextEditingController _controller;

  void _limpiar() {
    if (_controller.text.isNotEmpty) _controller.clear();
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
    if (mounted) _limpiar();
  }

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

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<TareaCatalogo>(
      focusNode: _focus,
      textEditingController: _controller,
      optionsBuilder: (v) {
        final q = v.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<TareaCatalogo>.empty();
        return widget.catalogo
            .where((c) => c.titulo.toLowerCase().contains(q))
            .take(6);
      },
      displayStringForOption: (c) => c.titulo,
      onSelected: (c) async {
        _focus.unfocus();
        await widget.onCrear(c.titulo, widget.fecha, plantilla: c);
        if (mounted) _limpiar();
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return SizedBox(
          height: 32,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            style: const TextStyle(fontSize: 11.5),
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.compacto
                  ? '+ Añadir…'
                  : '+ Añadir tarea en este día…',
              hintStyle: const TextStyle(fontSize: 11),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              suffixIconConstraints:
                  const BoxConstraints(maxWidth: 26, maxHeight: 26),
              suffixIcon: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 17,
                icon: const Icon(Icons.add_circle),
                color: AppColors.verde,
                tooltip: 'Crear tarea',
                onPressed: () => _enviar(controller.text),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white24
                      : AppColors.linea,
                ),
              ),
            ),
            onSubmitted: _enviar,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final lista = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(10),
              color: Theme.of(context).colorScheme.surface,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 170, maxWidth: 240),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shrinkWrap: true,
                  itemCount: lista.length,
                  itemBuilder: (context, i) {
                    final c = lista[i];
                    return InkWell(
                      onTap: () => onSelected(c),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        child: Row(
                          children: [
                            Icon(
                              CategoriaTarea.iconoDe(c.categoria),
                              size: 14,
                              color: AppColors.verdeOscuro,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                c.titulo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(
                              '${c.puntos} pts',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: textoSuaveTema(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
