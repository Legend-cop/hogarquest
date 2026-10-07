import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reto.dart';
import '../models/user.dart';
import '../providers/app_provider.dart';
import '../services/celebration_service.dart';
import '../theme/app_theme.dart';
import '../widgets/confetti.dart';
import '../widgets/duo_widgets.dart';
import '../widgets/hq_design.dart';
import '../widgets/icons3d.dart';

String _formatoFecha(DateTime f) {
  final d = f.day.toString().padLeft(2, '0');
  final m = f.month.toString().padLeft(2, '0');
  final h = f.hour.toString().padLeft(2, '0');
  final min = f.minute.toString().padLeft(2, '0');
  return '$d/$m/${f.year} $h:$min';
}

class RetosScreen extends StatefulWidget {
  /// `false` al incrustarse dentro de Tareas (ya su propia cabecera).
  final bool mostrarTitulo;

  const RetosScreen({super.key, this.mostrarTitulo = true});

  @override
  State<RetosScreen> createState() => _RetosScreenState();
}

class _RetosScreenState extends State<RetosScreen> {
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
    final results =
        await Future.wait([app.retosDeLaSemana(), app.listarIntegrantes()]);
    if (!mounted) return;
    setState(() {
      _retos = results[0] as List<Reto>;
      _integrantes = results[1] as List<User>;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();
    final user = app.usuarioActual;
    if (user == null) return const SizedBox.shrink();
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
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
              if (widget.mostrarTitulo)
                PageTitle(
                  esAdmin ? 'Retos' : 'Mis retos',
                  subtitle: esAdmin
                      ? 'Retos de la semana en familia'
                      : 'Metas en equipo de esta semana',
                  actions: [
                    if (esAdmin)
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'Nuevo reto',
                        onPressed: () => _abrirRetoDialog(context),
                      ),
                  ],
                ),
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
                      : _RetoCardChild(reto: reto, total: total, user: user),
                const SizedBox(height: 8),
                if (esAdmin)
                  DuoButton(
                    label: 'Agregar otro reto',
                    icon: Icons.add_circle_outline,
                    onPressed: () => _abrirRetoDialog(context),
                  ),
              ],
              if (!esAdmin && retos.isEmpty) ...[
                const SizedBox(height: 12),
                const _ComoFuncionan(),
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

/// Crea o edita un reto semanal (solo admin).
class _NuevoRetoDialog extends StatefulWidget {
  final Reto? inicial;
  const _NuevoRetoDialog({this.inicial});

  @override
  State<_NuevoRetoDialog> createState() => _NuevoRetoDialogState();
}

class _NuevoRetoDialogState extends State<_NuevoRetoDialog> {
  late final TextEditingController _titulo =
      TextEditingController(text: widget.inicial?.titulo ?? '');
  late final TextEditingController _descripcion =
      TextEditingController(text: widget.inicial?.descripcion ?? '');
  late final TextEditingController _puntos = TextEditingController(
      text: (widget.inicial?.puntos ?? 30).toString());
  String _categoria = 'limpieza';
  DateTime? _fechaFin;

  @override
  void initState() {
    super.initState();
    _fechaFin = widget.inicial?.fechaFin;
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
          editando ? 'Editar reto de la semana' : 'Nuevo reto de la semana'),
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
                hintText: 'Ej: cada integrante ordena su cuarto 3 veces en la semana',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categoria,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: _categorias.entries
                  .map((e) => DropdownMenuItem(
                      value: e.key, child: Text(e.value)))
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
            Text('Vencimiento (opcional)',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            _FechaFinPicker(
              fechaFin: _fechaFin,
              onChanged: (v) => setState(() => _fechaFin = v),
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
          onPressed: () async {
            final titulo = _titulo.text.trim();
            final descripcion = _descripcion.text.trim();
            final pts = int.tryParse(_puntos.text) ?? 0;
            if (titulo.isEmpty || descripcion.isEmpty || pts <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Completa título, descripción y puntos.')),
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
                  fechaFin: _fechaFin);
            } else {
              await app.editarReto(inicial.copyWith(
                titulo: titulo,
                descripcion: descripcion,
                puntos: pts,
                fechaFin: _fechaFin,
              ));
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(editando ? 'Guardar' : 'Crear reto'),
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
        DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute));
  }

  @override
  Widget build(BuildContext context) {
    final f = fechaFin;
    return DuoCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppColors.verdeFondo,
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
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
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

/// Tarjeta destacada verde estilo referencia (solo admin).
class _RetoDestacado extends StatelessWidget {
  const _RetoDestacado();

  @override
  Widget build(BuildContext context) {
    return CardBox(
      color: AppColors.verdeFondo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RETO FAMILIAR DESTACADO',
            style: TextStyle(
              color: AppColors.grisOscuro,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '¡Todos sumamos!',
            style: TextStyle(
              color: AppColors.grisOscuro,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Completen retos juntos y ganen XP extra.',
            style: TextStyle(
              color: AppColors.grisOscuro,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
      // Texto exacto del zip ( ChildChallenges ).
      return const CardBox(
        color: AppColors.azulFondo,
        child: Text(
          'Aún no hay reto esta semana. Pídele al administrador que cree '
          'un reto familiar.',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.grisOscuro,
          ),
        ),
      );
    }
    return CardBox(
      color: AppColors.azulFondo,
      child: Column(
        children: [
          const Text(
            'Aún no hay reto esta semana',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.grisOscuro),
          ),
          const SizedBox(height: 6),
          const Text(
            'Crea un reto familiar: todos lo cumplen y ganan puntos bonus.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.grisOscuro),
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

/// Tarjeta de ayuda "¿Cómo funcionan?" con el texto exacto del zip.
class _ComoFuncionan extends StatelessWidget {
  const _ComoFuncionan();

  @override
  Widget build(BuildContext context) {
    return const CardBox(
      child: Text(
        '¿Cómo funcionan? Los retos son metas en equipo: al cumplirlas, '
        'toda la familia gana XP extra.',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.grisOscuro,
        ),
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
            color: AppColors.amarilloFondo,
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
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
    final c = reto.cumplidos.length;
    final max = total > 0 ? total : (c >= 1 ? c : 1);
    final valor = max == 0 ? 0.0 : (c / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              'Progreso familiar',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: textoSuaveTema(context),
              ),
            ),
            const Spacer(),
            Text(
              '$c/$max',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: AppColors.grisOscuro,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ProgressLine(valor, color: AppColors.verde),
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
            'retos aprobados no se modifican.'),
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
    if (!context.mounted) return;
    final id = reto.id;
    if (id != null) {
      await context.read<AppProvider>().eliminarReto(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();
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
                    icon: const Icon(Icons.edit, color: AppColors.azul, size: 20),
                    tooltip: 'Editar reto',
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => _NuevoRetoDialog(inicial: reto),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.rojo, size: 20),
                    tooltip: 'Eliminar reto',
                    onPressed: () => _confirmarEliminar(context, reto),
                  ),
                ],
              ),
            ],
          ),
          _ProgresoReto(reto: reto, total: total),
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
  const _RetoCardChild({required this.reto, required this.total, required this.user});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();
    final loCumpli = reto.cumplidos.contains(user.id);
    final yaAprobado = reto.aprobados.contains(user.id);

    return DuoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RetoCabecera(reto: reto),
          _ProgresoReto(reto: reto, total: total),
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
          else if (loCumpli)
            const _MarcadoChip()
          else
            DuoButton(
              label: '¡Lo cumplí!',
              icon: Icons.verified,
              onPressed: () => app.marcarRetoCumplido(reto),
            ),
        ],
      ),
    );
  }
}

class _MarcadoChip extends StatelessWidget {
  const _MarcadoChip();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.verified, color: AppColors.verde, size: 22),
        const SizedBox(width: 8),
        const Text('¡Marcado! Espera la aprobación del admin.',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.verde)),
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
                const Icon(Icons.flag, color: AppColors.grisOscuro, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    r.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  '${r.cumplidos.length} cumplidos · +${r.puntos} pts',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: textoSuaveTema(context)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}