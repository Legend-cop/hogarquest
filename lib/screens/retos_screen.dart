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
import '../widgets/section_header.dart';

String _formatoFecha(DateTime f) {
  final d = f.day.toString().padLeft(2, '0');
  final m = f.month.toString().padLeft(2, '0');
  final h = f.hour.toString().padLeft(2, '0');
  final min = f.minute.toString().padLeft(2, '0');
  return '$d/$m/${f.year} $h:$min';
}

class RetosScreen extends StatefulWidget {
  const RetosScreen({super.key});

  @override
  State<RetosScreen> createState() => _RetosScreenState();
}

class _RetosScreenState extends State<RetosScreen> {
  late Future<List<Reto>> _futureRetos;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppProvider>();
    app.addListener(_onChange);
    _futureRetos = app.retosDeLaSemana();
  }

  @override
  void dispose() {
    context.read<AppProvider>().removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();
    final user = app.usuarioActual;
    if (user == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Retos de la semana'),
        actions: [
          if (user.esAdmin)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Nuevo reto',
              onPressed: () => _abrirRetoDialog(context),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _futureRetos = context.read<AppProvider>().retosDeLaSemana();
          });
        },
        child: FutureBuilder<List<Reto>>(
          future: _futureRetos,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final retos = snap.data ?? const <Reto>[];
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (retos.isEmpty)
                      _SinRetoCard(esAdmin: user.esAdmin)
                    else ...[
                      for (final reto in retos)
                        _RetoCard(reto: reto, user: user),
                      if (user.esAdmin) ...[
                        const SizedBox(height: 8),
                        DuoButton(
                          label: 'Agregar otro reto',
                          icon: Icons.add_circle_outline,
                          onPressed: () => _abrirRetoDialog(context),
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                    _RetosPasados(esAdmin: user.esAdmin),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
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
                  : 'Vence el ${_formato(f!)}',
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

class _SinRetoCard extends StatelessWidget {
  final bool esAdmin;
  const _SinRetoCard({required this.esAdmin});

  @override
  Widget build(BuildContext context) {
    return DuoCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.flag_circle, size: 48, color: AppColors.amarillo),
          const SizedBox(height: 12),
          const Text('Aún no hay reto esta semana',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            esAdmin
                ? 'Crea un reto familiar: todos lo cumplen y ganan puntos bonus.'
                : 'Pídele al administrador que cree un reto familiar.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.grisMedio),
          ),
          if (esAdmin) ...[
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
        ],
      ),
    );
  }
}

class _RetoCard extends StatelessWidget {
  final Reto reto;
  final User user;
  const _RetoCard({required this.reto, required this.user});

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
    final esAdmin = user.esAdmin;
    final loCumpli = reto.cumplidos.contains(user.id);
    final yaAprobado = reto.aprobados.contains(user.id);

    return DuoCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: AppColors.amarillo, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(reto.titulo,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              if (esAdmin) ...[
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
              Chip(
                avatar: const Icon(Icons.stars, size: 16),
                label: Text('+${reto.puntos} pts',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                backgroundColor: AppColors.amarillo.withValues(alpha: 0.15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(reto.descripcion,
              style: const TextStyle(fontSize: 14, height: 1.4)),
          if (reto.fechaFin != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.schedule, size: 14, color: AppColors.grisMedio),
                const SizedBox(width: 4),
                Text('Vence el ${_formatoFecha(reto.fechaFin!)}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grisMedio)),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Cumplido por ${reto.cumplidos.length} integrante${reto.cumplidos.length == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 12, color: AppColors.grisMedio),
          ),
          const SizedBox(height: 8),
          if (!esAdmin)
            loCumpli
                ? const _MarcadoChip()
                : DuoButton(
                    label: '¡Lo cumplí!',
                    icon: Icons.verified,
                    onPressed: () => app.marcarRetoCumplido(reto),
                  )
          else ...[
            if (!reto.finalizado)
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
              )
            else
              const Text('Reto finalizado',
                  style: TextStyle(color: AppColors.grisMedio, fontSize: 12)),
          ],
          if (yaAprobado)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, color: AppColors.amarillo, size: 16),
                  const SizedBox(width: 6),
                  Text('Ganaste +${reto.puntos} pts por este reto',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.grisOscuro)),
                ],
              ),
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
  late Future<List<Reto>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppProvider>().listarRetos();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Reto>>(
      future: _future,
      builder: (context, snap) {
        final retos = snap.data ?? const <Reto>[];
        final pasados = retos.where((r) => !r.vigente).toList();
        if (pasados.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Retos anteriores'),
            for (final r in pasados)
              ListTile(
                dense: true,
                leading: const Icon(Icons.flag, color: AppColors.grisMedio),
                title: Text(r.titulo),
                subtitle: Text(
                    '${r.cumplidos.length} cumplidos · +${r.puntos} pts'),
              ),
          ],
        );
      },
    );
  }
}