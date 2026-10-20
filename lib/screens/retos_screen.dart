import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reto.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../providers/app_provider.dart';
import '../services/celebration_service.dart';
import '../theme/app_theme.dart';
import '../widgets/confetti.dart';
import '../widgets/contadores.dart';
import '../widgets/duo_widgets.dart';
import '../widgets/hq_design.dart';
import '../widgets/icono3d.dart';
import '../widgets/icons3d.dart';

String _formatoFecha(DateTime f) {
  final d = f.day.toString().padLeft(2, '0');
  final m = f.month.toString().padLeft(2, '0');
  final h = f.hour.toString().padLeft(2, '0');
  final min = f.minute.toString().padLeft(2, '0');
  return '$d/$m/${f.year} $h:$min';
}

const _diasSemana = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

String _nombreDia(DateTime d) => _diasSemana[(d.weekday - 1) % 7];

/// Nombre de un integrante por id (para mostrar ganadores y robos).
String _nombreDe(BuildContext context, int uid) {
  for (final u in context.read<AppProvider>().listaUsuarios) {
    if (u.id == uid) return u.nombre;
  }
  return 'Alguien';
}

class RetosScreen extends StatefulWidget {
  const RetosScreen({super.key});

  @override
  State<RetosScreen> createState() => _RetosScreenState();
}

class _RetosScreenState extends State<RetosScreen> {
  List<Reto> _retos = const [];
  List<User> _integrantes = const [];
  final Map<int, List<Task>> _pozosLluvia = {};
  bool _cargando = true;
  late AppProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<AppProvider>();
    _provider.addListener(_onChange);
    _cargar();
  }

  @override
  void dispose() {
    _provider.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cargar();
    });
  }

  Future<void> _cargar() async {
    final app = context.read<AppProvider>();
    final results = await Future.wait([
      app.retosDeLaSemana(),
      app.listarIntegrantes(),
    ]);
    final retos = results[0] as List<Reto>;
    // El pozo de tareas de cada lluvia (solo para el niño: lo usa al tomar).
    final pozos = <int, List<Task>>{};
    for (final r in retos) {
      if (r.esLluvia && r.id != null) {
        pozos[r.id!] = await app.tareasPozoLluvia(r);
      }
    }
    if (!mounted) return;
    setState(() {
      _retos = retos;
      _integrantes = results[1] as List<User>;
      _pozosLluvia
        ..clear()
        ..addAll(pozos);
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();
    final user = app.usuarioActual;
    if (user == null) return const SizedBox.shrink();
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final retos = _retos;
    final esAdmin = user.esAdmin;
    final total = _integrantes.length;

    final contenido = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: RefreshIndicator(
          onRefresh: () async => _cargar(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (esAdmin)
                const PageTitle(
                  'Retos',
                  subtitle: 'Retos de la semana en familia',
                )
              else
                const ReferenciaTitulo('RETOS FAMILIARES', 'Mis retos', icono: Icono3DTipo.bandera),
              if (esAdmin) ...[
                const _RetoDestacado(),
                const SizedBox(height: 16),
              ],
              if (retos.isEmpty)
                _SinRetoCard(esAdmin: esAdmin)
              else ...[
                for (final reto in retos)
                  esAdmin
                      ? _RetoCardAdmin(reto: reto, total: total)
                      : _RetoCardChild(
                          reto: reto,
                          total: total,
                          user: user,
                          pozo: _pozosLluvia[reto.id] ?? const [],
                        ),
                const SizedBox(height: 8),
                if (esAdmin)
                  DuoButton(
                    label: 'Agregar otro reto',
                    icon: Icons.add_circle_outline,
                    onPressed: () => _abrirRetoDialog(context),
                  ),
              ],
              const SizedBox(height: 16),
              _RetosPasados(esAdmin: esAdmin),
            ],
          ),
        ),
      ),
    );

    return contenido;
  }

  void _abrirRetoDialog(BuildContext context, {Reto? inicial}) {
    showDialog(
      context: context,
      builder: (_) => _NuevoRetoDialog(inicial: inicial),
    );
  }
}

/// Contenido de la pestaña Retos para el admin, incrustado como segmento
/// dentro de la pantalla Tareas (navegación de referencia: 5 pestañas).
class RetosAdminInline extends StatefulWidget {
  const RetosAdminInline({super.key});

  @override
  State<RetosAdminInline> createState() => _RetosAdminInlineState();
}

class _RetosAdminInlineState extends State<RetosAdminInline> {
  List<Reto> _retos = const [];
  List<User> _integrantes = const [];
  bool _cargando = true;
  late AppProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<AppProvider>();
    _provider.addListener(_onChange);
    _cargar();
  }

  @override
  void dispose() {
    _provider.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cargar();
    });
  }

  Future<void> _cargar() async {
    final app = context.read<AppProvider>();
    final results = await Future.wait([
      app.retosDeLaSemana(),
      app.listarIntegrantes(),
    ]);
    if (!mounted) return;
    setState(() {
      _retos = results[0] as List<Reto>;
      _integrantes = results[1] as List<User>;
      _cargando = false;
    });
  }

  void _nuevoReto() {
    showDialog(context: context, builder: (_) => const _NuevoRetoDialog());
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    final retos = _retos;
    final total = _integrantes.length;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            const _RetoDestacado(),
            if (retos.isEmpty)
              _SinRetoCard(esAdmin: true)
            else ...[
              for (final reto in retos)
                _RetoCardAdmin(reto: reto, total: total),
              const SizedBox(height: 8),
              DuoButton(
                label: 'Agregar otro reto',
                icon: Icons.add_circle_outline,
                onPressed: _nuevoReto,
              ),
            ],
            const SizedBox(height: 16),
            _RetosPasados(esAdmin: true),
          ],
        ),
      ),
    );
  }
}

/// Crea o edita un reto semanal (solo admin).
class _NuevoRetoDialog extends StatefulWidget {
  final Reto? inicial;
  const _NuevoRetoDialog({this.inicial});

  @override
  State<_NuevoRetoDialog> createState() => _NuevoRetoDialogState();
}

class _NuevoRetoDialogState extends State<_NuevoRetoDialog> {
  late final TextEditingController _titulo = TextEditingController(
    text: widget.inicial?.titulo ?? '',
  );
  late final TextEditingController _descripcion = TextEditingController(
    text: widget.inicial?.descripcion ?? '',
  );
  late final TextEditingController _puntos = TextEditingController(
    text: (widget.inicial?.puntos ?? 30).toString(),
  );
  String _categoria = 'limpieza';
  DateTime? _fechaFin;
  String _modo = Reto.modoNormal;
  DateTime? _diaLluvia;
  DateTime? _plazoIndividual;
  DateTime? _ventanaInicio;
  DateTime? _ventanaFin;
  int _multiplicador = 2;

  @override
  void initState() {
    super.initState();
    _fechaFin = widget.inicial?.fechaFin;
    _modo = widget.inicial?.modo ?? Reto.modoNormal;
    _diaLluvia = widget.inicial?.fechaLluvia;
    _plazoIndividual = widget.inicial?.plazoIndividual;
    _ventanaInicio = widget.inicial?.ventanaInicio;
    _ventanaFin = widget.inicial?.ventanaFin ?? widget.inicial?.plazoIndividual;
    _multiplicador = widget.inicial?.multiplicador ?? 2;
  }

  /// Ventana por defecto del frenesí: hoy de 16:00 a 18:00.
  DateTime get _hoy16 =>
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 16);

  DateTime get _hoy18 =>
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 18);

  /// Elige día + hora de la ventana del frenesí (inicio o fin).
  Future<void> _elegirVentana({required bool esInicio}) async {
    final base = (esInicio ? _ventanaInicio : _ventanaFin) ?? _hoy16;
    final fecha = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (fecha == null || !mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (hora == null || !mounted) return;
    final completo = DateTime(
      fecha.year,
      fecha.month,
      fecha.day,
      hora.hour,
      hora.minute,
    );
    setState(() {
      if (esInicio) {
        _ventanaInicio = completo;
        if (_ventanaFin == null || !_ventanaFin!.isAfter(completo)) {
          _ventanaFin = completo.add(const Duration(hours: 2));
        }
      } else {
        _ventanaFin = completo;
      }
      // En lluvia el día elegido en la ventana ES el día sorteado.
      if (_modo == Reto.modoLluvia) {
        final ref = esInicio ? _ventanaInicio! : _ventanaFin!;
        _diaLluvia = DateTime(ref.year, ref.month, ref.day);
      }
    });
  }

  /// El modo/día solo se pueden cambiar si el reto aún no tiene marcas,
  /// robos ni ganador (para no pisar una carrera en curso).
  bool get _editableModo {
    final inicial = widget.inicial;
    if (inicial == null) return true;
    return inicial.cumplidos.isEmpty &&
        inicial.robados.isEmpty &&
        inicial.marcas.isEmpty &&
        inicial.ganador == null;
  }

  static const _categorias = {
    'limpieza': 'Limpieza en equipo',
    'convivencia': 'Convivencia',
    'orden': 'Orden',
    'otro': 'Otro',
  };

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    _puntos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.inicial != null;
    return AlertDialog(
      title: Text(
        editando ? 'Editar reto de la semana' : 'Nuevo reto de la semana',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titulo,
              decoration: const InputDecoration(
                labelText: 'Título',
                hintText: 'Ej: Todos ordenan su cuarto',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descripcion,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText:
                    'Ej: cada integrante ordena su cuarto 3 veces en la semana',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categoria,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: _categorias.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _categoria = v ?? 'otro'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _puntos,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Puntos bonus por integrante',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Modo del reto',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (editando && !_editableModo)
              Text(
                _modo == Reto.modoLluvia
                    ? '🌪 Lluvia (ya hay actividad: no se puede cambiar)'
                    : _modo == Reto.modoFrenesi
                        ? '🔥 Frenesí (ya hay actividad: no se puede cambiar)'
                        : 'Normal (clásico: aprueba el admin)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: textoSuaveTema(context),
                ),
              )
            else ...[
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ChoiceChip(
                      label: const Text('Normal'),
                      selected: _modo == Reto.modoNormal,
                      onSelected: (_) =>
                          setState(() => _modo = Reto.modoNormal),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('🌪 Lluvia'),
                      selected: _modo == Reto.modoLluvia,
                      onSelected: (_) {
                        setState(() {
                          _modo = Reto.modoLluvia;
                          _diaLluvia ??= AppProvider.sortearDiaLluvia();
                          // Ventana por defecto sobre el día sorteado.
                          final d = _diaLluvia!;
                          _ventanaInicio ??= DateTime(
                            d.year,
                            d.month,
                            d.day,
                            16,
                          );
                          _ventanaFin ??= DateTime(
                            d.year,
                            d.month,
                            d.day,
                            18,
                          );
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('🔥 Frenesí'),
                      selected: _modo == Reto.modoFrenesi,
                      onSelected: (_) =>
                          setState(() => _modo = Reto.modoFrenesi),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _modo == Reto.modoLluvia
                    ? 'Día aleatorio de la semana: el primero en cumplirlo ese día gana al instante.'
                    : _modo == Reto.modoFrenesi
                        ? 'Todos tienen un "su tiempo"; el que lo pierda pierde su slot y otro hijo se lo puede robar.'
                        : 'Todos lo cumplen y el admin aprueba y da los puntos.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: textoSuaveTema(context),
                ),
              ),
            ],
            if (_modo == Reto.modoLluvia) ...[
              const SizedBox(height: 10),
              DuoCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: azulFondoTema(context),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.casino_rounded,
                          size: 20,
                          color: AppColors.azul,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lluvia el ${_nombreDia(_diaLluvia ?? DateTime.now())}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (_editableModo)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _diaLluvia = AppProvider.sortearDiaLluvia();
                                final d = _diaLluvia!;
                                _ventanaInicio = DateTime(
                                  d.year,
                                  d.month,
                                  d.day,
                                  _ventanaInicio?.hour ?? 16,
                                );
                                _ventanaFin = DateTime(
                                  d.year,
                                  d.month,
                                  d.day,
                                  _ventanaFin?.hour ?? 18,
                                );
                              });
                            },
                            child: const Text('Re-sortear'),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          size: 18,
                          color: AppColors.azul,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Abre: ${_formatoFecha(_ventanaInicio ?? _hoy16)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _elegirVentana(esInicio: true),
                          child: const Text('Cambiar'),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.stop_rounded,
                          size: 18,
                          color: AppColors.rojo,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Cierra: ${_formatoFecha(_ventanaFin ?? _hoy18)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _elegirVentana(esInicio: false),
                          child: const Text('Cambiar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'El pozo abre en la ventana: los hijos toman tareas sin '
                'asignar y cobran al instante. El mayor acumulado gana el bonus.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: textoSuaveTema(context),
                ),
              ),
            ] else if (_modo == Reto.modoFrenesi) ...[
              const SizedBox(height: 12),
              const Text(
                '🔥 Ventana de la batalla',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              DuoCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: AppColors.coralFondo,
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          size: 18,
                          color: AppColors.coral,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Empieza: ${_formatoFecha(_ventanaInicio ?? _hoy16)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _elegirVentana(esInicio: true),
                          child: const Text('Cambiar'),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.stop_rounded,
                          size: 18,
                          color: AppColors.rojo,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Termina: ${_formatoFecha(_ventanaFin ?? _hoy18)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _elegirVentana(esInicio: false),
                          child: const Text('Cambiar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Multiplicador de puntos',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final m in const [2, 3, 4, 5])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text('x$m'),
                          selected: _multiplicador == m,
                          selectedColor: AppColors.coralFondo,
                          onSelected: (_) => setState(() => _multiplicador = m),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Dentro de la ventana, las tareas aprobadas o robadas pagan '
                'x$_multiplicador. El que pierda su slot, otro hijo lo roba.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: textoSuaveTema(context),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Text(
                'Vencimiento (opcional)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              _FechaFinPicker(
                fechaFin: _fechaFin,
                onChanged: (v) => setState(() => _fechaFin = v),
              ),
            ],
          ],
        ),
      ),
      actions: [
        DialogActions(
          onCancel: () => Navigator.pop(context),
          primary: DuoButton(
            fullWidth: false,
            label: editando ? 'Guardar' : 'Crear reto',
            onPressed: () async {
              final titulo = _titulo.text.trim();
              final descripcion = _descripcion.text.trim();
              final pts = int.tryParse(_puntos.text) ?? 0;
              if (titulo.isEmpty || descripcion.isEmpty || pts <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Completa título, descripción y puntos.'),
                  ),
                );
                return;
              }
              final app = context.read<AppProvider>();
              final inicial = widget.inicial;
              if (inicial == null) {
                await app.crearReto(
                  titulo: titulo,
                  descripcion: descripcion,
                  puntos: pts,
                  // En lluvia el vencimiento es automático: el cierre de la
                  // ventana.
                  fechaFin: _modo == Reto.modoLluvia ? null : _fechaFin,
                  modo: _modo,
                  fechaLluvia: _diaLluvia,
                  plazoIndividual: _modo == Reto.modoFrenesi
                      ? _ventanaFin
                      : null,
                  ventanaInicio: _modo == Reto.modoLluvia
                      ? (_ventanaInicio ?? _hoy16)
                      : _modo == Reto.modoFrenesi
                          ? (_ventanaInicio ?? _hoy16)
                          : null,
                  ventanaFin: _modo == Reto.modoLluvia
                      ? (_ventanaFin ?? _hoy18)
                      : _modo == Reto.modoFrenesi
                          ? (_ventanaFin ?? _hoy18)
                          : null,
                  multiplicador: _multiplicador,
                );
              } else {
                var finEdicion = _fechaFin;
                if (_modo == Reto.modoLluvia) {
                  finEdicion = _ventanaFin ??
                      inicial.ventanaFin ??
                      DateTime.now();
                }
                await app.editarReto(
                  inicial.copyWith(
                    titulo: titulo,
                    descripcion: descripcion,
                    puntos: pts,
                    fechaFin: finEdicion,
                    modo: _modo,
                    fechaLluvia: _diaLluvia,
                    plazoIndividual: _modo == Reto.modoFrenesi
                        ? (_ventanaFin ?? _plazoIndividual)
                        : null,
                    ventanaInicio: _modo == Reto.modoNormal
                        ? null
                        : (_ventanaInicio ?? _hoy16),
                    ventanaFin: _modo == Reto.modoNormal
                        ? null
                        : (_ventanaFin ?? _hoy18),
                    multiplicador:
                        _modo == Reto.modoFrenesi ? _multiplicador : 1,
                  ),
                );
              }
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }
}

/// Selector de fecha y hora límite para el reto (opcional).
class _FechaFinPicker extends StatelessWidget {
  final DateTime? fechaFin;
  final ValueChanged<DateTime?> onChanged;

  const _FechaFinPicker({required this.fechaFin, required this.onChanged});

  String _formato(DateTime f) => _formatoFecha(f);

  Future<void> _elegir(BuildContext context) async {
    final ahora = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: fechaFin ?? ahora,
      firstDate: ahora.subtract(const Duration(days: 1)),
      lastDate: DateTime(ahora.year + 1),
    );
    if (fecha == null || !context.mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(fechaFin ?? ahora),
    );
    if (hora == null) return;
    onChanged(
      DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = fechaFin;
    return DuoCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: verdeFondoTema(context),
      child: Row(
        children: [
          Icon(
            f == null ? Icons.schedule : Icons.event_available,
            size: 20,
            color: f == null ? AppColors.grisMedio : AppColors.verdeOscuro,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              f == null
                  ? 'Sin límite (vence al terminar la semana)'
                  : 'Vence el ${_formato(f)}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _elegir(context),
            child: const Text('Elegir'),
          ),
          if (f != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Quitar fecha límite',
              onPressed: () => onChanged(null),
            ),
        ],
      ),
    );
  }
}

/// Tarjeta destacada verde oscuro idéntica al segmento Retos de la referencia.
class _RetoDestacado extends StatelessWidget {
  const _RetoDestacado();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.verdeProfundo,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        '¡Todos sumamos! Completen retos juntos y ganen XP extra.',
        style: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SinRetoCard extends StatelessWidget {
  final bool esAdmin;
  const _SinRetoCard({required this.esAdmin});

  @override
  Widget build(BuildContext context) {
    if (!esAdmin) {
      // Tarjeta vacía idéntica a ChildChallengesScreen de la referencia.
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: isDark ? AppColors.superficieOscura : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? AppColors.grisMedio.withValues(alpha: 0.3)
                : const Color(0xFFD1D5DB),
          ),
        ),
        child: Column(
          children: [
            // Icono 3D animado en vez de la escoba estática: el rayo
            // transmite energía de reto.
            const SizedBox(
              width: 60,
              height: 60,
              child: Center(child: Bolt3D(size: 52, animar: true)),
            ),
            const SizedBox(height: 16),
            Text(
              'Aún no hay reto esta semana',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textoTema(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pídele al administrador que cree un reto familiar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textoSuaveTema(context)),
            ),
          ],
        ),
      );
    }
    return CardBox(
      color: azulFondoTema(context),
      child: Column(
        children: [
          Text(
            'Aún no hay reto esta semana',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: textoTema(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Crea un reto familiar: todos lo cumplen y ganan puntos bonus.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textoSuaveTema(context),
            ),
          ),
          const SizedBox(height: 16),
          DuoButton(
            label: 'Crear reto',
            icon: Icons.add_circle_outline,
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const _NuevoRetoDialog(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cabecera común de las tarjetas de reto: caja icono + título/descripción + pts.
class _RetoCabecera extends StatelessWidget {
  final Reto reto;
  const _RetoCabecera({required this.reto});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: amarilloFondoTema(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.flag_rounded,
            size: 26,
            color: AppColors.amarilloOscuro,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reto.titulo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                reto.descripcion,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: textoSuaveTema(context),
                ),
              ),
              if (reto.esLluvia || reto.esFrenesi) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: reto.esLluvia
                        ? azulFondoTema(context)
                        : amarilloFondoTema(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        reto.esLluvia
                            ? Icons.casino_rounded
                            : Icons.local_fire_department,
                        size: 12,
                        color: textoTema(context),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          reto.esLluvia
                              ? (reto.fechaLluvia != null &&
                                      reto.lluviaActiva(DateTime.now())
                                  ? '¡Lluvia HOY! Sé el primero'
                                  : reto.fechaLluvia != null
                                      ? 'Lluvia el ${_nombreDia(reto.fechaLluvia!)}'
                                      : 'Lluvia: día aleatorio')
                              : 'Frenesí · su tiempo: ${_formatoFecha(reto.plazoEfectivo)}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: textoTema(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Bolt3D(size: 16, animar: false),
            const SizedBox(width: 3),
            Text(
              '+${reto.puntos} pts',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.azul,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Barra de progreso familiar + contador y límite de la tarjeta de reto.
class _ProgresoReto extends StatelessWidget {
  final Reto reto;
  final int total;

  const _ProgresoReto({required this.reto, required this.total});

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final c = reto.cumplidos.length;
    final max = reto.esLluvia
        ? 1
        : (total > 0 ? total : (c >= 1 ? c : 1));
    final valor = reto.ganador != null
        ? 1.0
        : (max == 0 ? 0.0 : (c / max).clamp(0.0, 1.0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                reto.esLluvia
                    ? '¡Carrera! Solo 1 ganador'
                    : 'Progreso familiar',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: textoSuaveTema(context),
                ),
              ),
            ),
            Text(
              reto.esLluvia
                  ? (reto.ganador != null
                      ? '🏆 ${_nombreDe(context, reto.ganador!)}'
                      : 'En carrera')
                  : '$c/$max',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: textoTema(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ProgressLine(valor, color: AppColors.verde),
        if (reto.esFrenesi && reto.robados.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.local_fire_department,
                size: 14,
                color: AppColors.coral,
              ),
              const SizedBox(width: 4),
              Text(
                'Robos: ${reto.robados.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.coral,
                ),
              ),
            ],
          ),
        ],
        if (reto.esLluvia && reto.fechaLluvia != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.casino_rounded, size: 14, color: textoSuaveTema(context)),
              const SizedBox(width: 4),
              Text(
                reto.lluviaActiva(ahora)
                    ? 'La lluvia es hoy'
                    : 'La lluvia es el ${_nombreDia(reto.fechaLluvia!)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textoSuaveTema(context),
                ),
              ),
            ],
          ),
        ],
        if (reto.esFrenesi) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 14, color: textoSuaveTema(context)),
              const SizedBox(width: 4),
              Text(
                'Su tiempo vence el ${_formatoFecha(reto.plazoEfectivo)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textoSuaveTema(context),
                ),
              ),
            ],
          ),
        ],
        if (reto.fechaFin != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: textoSuaveTema(context)),
              const SizedBox(width: 4),
              Text(
                'Vence el ${_formatoFecha(reto.fechaFin!)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textoSuaveTema(context),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Barra INDIVIDUAL del frenesí: tus puntos acumulados contra el mayor
/// acumulado de la familia. El admin sí ve el reporte de todos en su
/// tarjeta (chips por hijo).
class _ProgresoIndividual extends StatelessWidget {
  final Reto reto;
  final int uid;
  const _ProgresoIndividual({required this.reto, required this.uid});

  @override
  Widget build(BuildContext context) {
    final mios = reto.acumulados[uid] ?? 0;
    var lider = 0;
    for (final v in reto.acumulados.values) {
      if (v > lider) lider = v;
    }
    final max = lider > 0 ? lider : (mios > 0 ? mios : 1);
    final valor = (mios / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                'Tus puntos acumulados',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: textoSuaveTema(context),
                ),
              ),
            ),
            Text(
              lider > mios
                  ? '$mios pts · líder $lider'
                  : (lider > 0 ? '$mios pts · ¡vas líder!' : '0 pts'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: textoTema(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ProgressLine(valor, color: AppColors.coral),
      ],
    );
  }
}

class _RetoCardAdmin extends StatelessWidget {
  final Reto reto;
  final int total;
  const _RetoCardAdmin({required this.reto, required this.total});

  Future<void> _confirmarEliminar(BuildContext context, Reto reto) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar reto?'),
        content: Text(
          'Se eliminará "${reto.titulo}". Los puntos ya otorgados por '
          'retos aprobados no se modifican.',
        ),
        actions: [
          DialogActions(
            onCancel: () => Navigator.pop(ctx, false),
            primary: DuoButton(
              fullWidth: false,
              color: AppColors.rojo,
              borderColor: AppColors.rojoOscuro,
              onPressed: () => Navigator.pop(ctx, true),
              label: 'Eliminar',
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    final id = reto.id;
    if (id != null) {
      await context.read<AppProvider>().eliminarReto(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();
    // Verde = falta para empezar la ventana; rojo = falta para cerrarla.
    final fenIni = reto.ventanaInicio;
    final sinEmpezar = fenIni != null && DateTime.now().isBefore(fenIni);
    return DuoCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _RetoCabecera(reto: reto)),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      color: AppColors.azul,
                      size: 20,
                    ),
                    tooltip: 'Editar reto',
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => _NuevoRetoDialog(inicial: reto),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.rojo,
                      size: 20,
                    ),
                    tooltip: 'Eliminar reto',
                    onPressed: () => _confirmarEliminar(context, reto),
                  ),
                ],
              ),
            ],
          ),
          _ProgresoReto(reto: reto, total: total),
          if (reto.esFrenesi && reto.ventanaFin != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                ContadorRegresivo(
                  hasta: sinEmpezar ? fenIni : reto.plazoEfectivo,
                  compacto: true,
                  color: sinEmpezar ? AppColors.verde : AppColors.rojo,
                  fondo: sinEmpezar
                      ? verdeFondoTema(context)
                      : rojoFondoTema(context),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.coralFondo,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '🔥 x${reto.multiplicador}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.coralOscuro,
                    ),
                  ),
                ),
              ],
            ),
            if (reto.acumulados.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Acumulado de la ventana:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: textoSuaveTema(context),
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final e in reto.acumulados.entries)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(
                        Icons.local_fire_department,
                        size: 14,
                        color: AppColors.coral,
                      ),
                      label: Text(
                        '${_nombreDe(context, e.key)}: ${e.value} pts',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
          if (reto.esLluvia && reto.ganador != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Trophy3D(size: 16, animar: false),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_nombreDe(context, reto.ganador!)} ganó la lluvia '
                    'al instante (+${reto.puntos} pts)',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.verdeOscuro,
                    ),
                  ),
                ),
              ],
            ),
          ],
          for (final e in reto.robados.entries) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department,
                  size: 16,
                  color: AppColors.coral,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_nombreDe(context, e.value)} robó el slot de '
                    '${_nombreDe(context, e.key)} (+${reto.puntos} pts)',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.coralOscuro,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          if (reto.finalizado)
            Center(
              child: Text(
                'Reto finalizado',
                style: TextStyle(color: textoSuaveTema(context), fontSize: 12),
              ),
            )
          else
            Center(
              child: TextButton.icon(
                onPressed: () {
                  lanzarConfeti(context);
                  unawaited(CelebrationService.instance.success());
                  app.aprobarReto(reto);
                },
                icon: const Icon(Icons.check_circle, color: AppColors.verde),
                label: Text(
                  reto.cumplidos.isEmpty
                      ? 'Finalizar reto'
                      : 'Finalizar y dar puntos',
                  style: const TextStyle(color: AppColors.verde),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RetoCardChild extends StatelessWidget {
  final Reto reto;
  final int total;
  final User user;
  final List<Task> pozo;
  const _RetoCardChild({
    required this.reto,
    required this.total,
    required this.user,
    this.pozo = const [],
  });

  Future<void> _robarSlot(
    BuildContext context,
    AppProvider app,
    User victima,
  ) async {
    final ok = await app.robarReto(reto, victima.id!);
    if (!ok || !context.mounted) return;
    lanzarConfeti(context);
    unawaited(CelebrationService.instance.success());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '¡Robaste el reto de ${victima.nombre}! +${reto.puntos} pts',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();
    final ahora = DateTime.now();
    final loCumpli = reto.cumplidos.contains(user.id);
    final yaAprobado = reto.aprobados.contains(user.id);

    // ¿Todavía no abre el pozo? El contador de "empieza en" es VERDE
    // (verde = falta para empezar, rojo = falta para cerrar). Antes se
    // mostraba "ya pasó" durante todo el día de la lluvia.
    final lluviaAntes =
        reto.esLluvia && (reto.inicioLluvia?.isAfter(ahora) ?? false);

    // Slots vencidos sin cumplir de otros hijos (frenesí): se pueden robar
    // cuando YA pasó "su tiempo" (el vencido = sin info de ventana).
    final robables = <User>[];
    if (reto.esFrenesi &&
        reto.vigente &&
        ahora.isAfter(reto.plazoEfectivo)) {
      for (final u in app.listaUsuarios) {
        if (u.id == null ||
            u.id == user.id ||
            u.esAdmin ||
            !u.activo ||
            !reto.slotRobable(u.id!)) {
          continue;
        }
        robables.add(u);
      }
    }

    return DuoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RetoCabecera(reto: reto),
          // En frenesí cada hijo ve SU barra (acumulado vs líder); el
          // "Progreso familiar" es para los demás modos y el admin.
          reto.esFrenesi
              ? _ProgresoIndividual(reto: reto, uid: user.id ?? 0)
              : _ProgresoReto(reto: reto, total: total),
          if (reto.esFrenesi &&
              (reto.ventanaFin != null || reto.plazoIndividual != null)) ...[
            if (reto.ventanaInicio != null &&
                ahora.isBefore(reto.ventanaInicio!)) ...[
              // Sin empezar: SOLO el contador al inicio, en VERDE
              // (verde = falta para empezar), sin info de vencimiento.
              const SizedBox(height: 10),
              ContadorRegresivo(
                hasta: reto.ventanaInicio!,
                color: AppColors.verde,
                fondo: verdeFondoTema(context),
              ),
              const SizedBox(height: 6),
              Text(
                'La ventana de la batalla empieza en… ¡prepárate!',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textoSuaveTema(context),
                ),
              ),
            ] else if (reto.ventanaFrenesiActiva(ahora)) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  // Rojo = falta para que cierre la ventana.
                  ContadorRegresivo(
                    hasta: reto.ventanaFin ?? reto.plazoEfectivo,
                    compacto: true,
                    color: AppColors.rojo,
                    fondo: rojoFondoTema(context),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.coralFondo,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '🔥 x${reto.multiplicador}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.coralOscuro,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '¡La ventana está corriendo! Tus tareas pagan '
                'x${reto.multiplicador}. Acumulado: '
                '${reto.acumulados[user.id] ?? 0} pts.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textoSuaveTema(context),
                ),
              ),
            ],
          ],
          const SizedBox(height: 14),
          if (yaAprobado)
            Row(
              children: [
                Trophy3D(size: 18, animar: false),
                const SizedBox(width: 6),
                Text(
                  'Ganaste +${reto.puntos} pts por este reto',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: textoTema(context),
                  ),
                ),
              ],
            )
          else if (reto.esLluvia && reto.ganador != null)
            Row(
              children: [
                Trophy3D(size: 18, animar: false),
                const SizedBox(width: 6),
                Text(
                  '🏆 Ganó ${_nombreDe(context, reto.ganador!)} '
                  '+${reto.puntos} pts',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: textoTema(context),
                  ),
                ),
              ],
            )
          else if (reto.esLluvia && reto.lluviaEnVentana(ahora))
            _PozoLluvia(reto: reto, pozo: pozo, user: user)
          else if (reto.esLluvia && !reto.lluviaEnVentana(ahora))
            Row(
              children: [
                const Icon(
                  Icons.water_drop_outlined,
                  size: 18,
                  color: AppColors.azul,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    lluviaAntes
                        ? (reto.lluviaActiva(ahora)
                              ? 'La lluvia empieza hoy: el pozo abre en…'
                              : 'La lluvia es el '
                                    '${_nombreDia(reto.fechaLluvia ?? ahora)}: '
                                    'el pozo abre en…')
                        : 'La lluvia de hoy ya pasó — mira quién ganó.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: textoSuaveTema(context),
                    ),
                  ),
                ),
                // Verde = falta para que empiece la lluvia.
                if (lluviaAntes)
                  ContadorRegresivo(
                    hasta: reto.inicioLluvia!,
                    compacto: true,
                    color: AppColors.verde,
                    fondo: verdeFondoTema(context),
                  ),
              ],
            )
          else if (loCumpli)
            _MarcadoChip(
              texto: reto.esFrenesi
                  ? '¡Marcado a tiempo! Cobras al finalizar el reto.'
                  : '¡Marcado! Espera la aprobación del admin.',
            )
          else if (reto.esFrenesi && !reto.puedeMarcarFrenesi(ahora))
            Row(
              children: [
                const Icon(
                  Icons.hourglass_bottom,
                  size: 18,
                  color: AppColors.rojo,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '⏰ Pasó tu tiempo: tu slot puede ser robado.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.rojo,
                    ),
                  ),
                ),
              ],
            )
          else if (!reto.esLluvia)
            DuoButton(
              label: '¡Lo cumplí!',
              icon: Icons.verified,
              onPressed: () => app.marcarRetoCumplido(reto),
            ),
          for (final e in reto.robados.entries) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department,
                  size: 16,
                  color: AppColors.coral,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_nombreDe(context, e.value)} robó el slot de '
                    '${_nombreDe(context, e.key)} (+${reto.puntos} pts)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.coralOscuro,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (robables.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '🔥 Slots para robar',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: textoTema(context),
                    ),
                  ),
                ),
                // Robo solo de 18:00 a 21:30: fuera de ventana, contador
                // verde al próximo opening y botón apagado.
                if (!AppProvider.enVentanaRobo(ahora))
                  ContadorRegresivo(
                    hasta: AppProvider.proximaVentanaRobo(ahora),
                    compacto: true,
                    color: AppColors.verde,
                    fondo: verdeFondoTema(context),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (final v in robables)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${v.nombre} pasó su tiempo',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: textoSuaveTema(context),
                        ),
                      ),
                    ),
                    DuoButton(
                      fullWidth: false,
                      label: AppProvider.enVentanaRobo(ahora)
                          ? '¡Robarla! +${reto.puntos}'
                          : 'Abre 18:00',
                      onPressed: AppProvider.enVentanaRobo(ahora)
                          ? () => _robarSlot(context, app, v)
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MarcadoChip extends StatelessWidget {
  final String texto;
  const _MarcadoChip({
    this.texto = '¡Marcado! Espera la aprobación del admin.',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.verified, color: AppColors.verde, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.verde,
            ),
          ),
        ),
      ],
    );
  }
}

/// "🌧 Pozo de tareas": durante la ventana de la lluvia, las tareas del día
/// sin asignar están aquí. El primero en tomarla cobra al instante y la
/// tarea desaparece del pozo.
class _PozoLluvia extends StatelessWidget {
  final Reto reto;
  final List<Task> pozo;
  final User user;
  const _PozoLluvia({
    required this.reto,
    required this.pozo,
    required this.user,
  });

  Future<void> _tomar(BuildContext context, Task tarea) async {
    final app = context.read<AppProvider>();
    final ok = await app.tomarDelPozo(reto, tarea.id!);
    if (!ok || !context.mounted) return;
    lanzarConfeti(context);
    unawaited(CelebrationService.instance.success());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.azul,
          content: Text(
            '¡Tomaste "${tarea.titulo}"! +${tarea.puntos} pts',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fin = reto.finLluvia ?? reto.plazoEfectivo;
    final restante = fin.difference(DateTime.now());
    final urgente = !restante.isNegative && restante.inMinutes <= 5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🌧', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              'Pozo de tareas',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: textoTema(context),
              ),
            ),
            const SizedBox(width: 8),
            // Rojo = falta para que cierre la ventana.
            ContadorRegresivo(
              hasta: fin,
              compacto: true,
              color: urgente ? Colors.white : AppColors.rojo,
              fondo: urgente ? AppColors.rojo : rojoFondoTema(context),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Toma una tarea y cobra sus puntos al instante. ¡El mayor '
          'acumulado gana +${reto.puntos} pts al cerrar!',
          style: TextStyle(
            fontSize: 11.5,
            height: 1.35,
            color: textoSuaveTema(context),
          ),
        ),
        const SizedBox(height: 8),
        if (pozo.isEmpty)
          Text(
            'El pozo está vacío: no quedan tareas sin tomar. 🌵',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: textoSuaveTema(context),
            ),
          )
        else
          for (final t in pozo)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icono3D(
                    tipo: Icono3DTipo.porNombre(t.icono),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.titulo,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: textoTema(context),
                      ),
                    ),
                  ),
                  DuoButton(
                    fullWidth: false,
                    label: '¡La hago! +${t.puntos}',
                    onPressed: () => _tomar(context, t),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _RetosPasados extends StatefulWidget {
  final bool esAdmin;
  const _RetosPasados({required this.esAdmin});

  @override
  State<_RetosPasados> createState() => _RetosPasadosState();
}

class _RetosPasadosState extends State<_RetosPasados> {
  List<Reto> _todos = const [];
  bool _cargando = true;
  late AppProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<AppProvider>();
    _provider.addListener(_onChange);
    _cargar();
  }

  @override
  void dispose() {
    _provider.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cargar();
    });
  }

  Future<void> _cargar() async {
    final todos = await _provider.listarRetos();
    if (!mounted) return;
    setState(() {
      _todos = todos;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const SizedBox.shrink();
    final pasados = _todos.where((r) => !r.vigente).toList();
    if (pasados.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            'Retos anteriores',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        for (final r in pasados)
          CardBox(
            child: Row(
              children: [
                Icon(Icons.flag, color: textoTema(context), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    r.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  r.ganador != null
                      ? '🏆 ${_nombreDe(context, r.ganador!)} · +${r.puntos} pts'
                      : '${r.cumplidos.length} cumplidos · +${r.puntos} pts',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: textoSuaveTema(context),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
