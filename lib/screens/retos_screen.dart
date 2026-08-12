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

class RetosScreen extends StatelessWidget {
  const RetosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();
    final user = app.usuarioActual!;
    return Scaffold(
      appBar: AppBar(title: const Text('Retos de la semana')),
      body: RefreshIndicator(
        onRefresh: () async => setState(context),
        child: FutureBuilder<Reto?>(
          future: app.retoDeLaSemana(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final reto = snap.data;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (reto == null)
                      _SinRetoCard(esAdmin: user.esAdmin)
                    else
                      _RetoCard(reto: reto, user: user),
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

  void setState(BuildContext context) {
    // no-op: la tarjeta es stateless y se re-arma al hacer pull-to-refresh
  }
}

/// Crea un reto semanal (solo admin).
class _NuevoRetoDialog extends StatefulWidget {
  const _NuevoRetoDialog();

  @override
  State<_NuevoRetoDialog> createState() => _NuevoRetoDialogState();
}

class _NuevoRetoDialogState extends State<_NuevoRetoDialog> {
  final _titulo = TextEditingController();
  final _descripcion = TextEditingController();
  final _puntos = TextEditingController(text: '30');
  String _categoria = 'limpieza';

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
    return AlertDialog(
      title: const Text('Nuevo reto de la semana'),
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
            await context
                .read<AppProvider>()
                .crearReto(titulo: titulo, descripcion: descripcion, puntos: pts);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Crear reto'),
        ),
      ],
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
            if (reto.cumplidos.isNotEmpty && !reto.finalizado)
Center(
                  child: TextButton.icon(
                    onPressed: () {
                      lanzarConfeti(context);
                      unawaited(CelebrationService.instance.success());
                      app.aprobarReto(reto);
                    },
                    icon: const Icon(Icons.check_circle, color: AppColors.verde),
                    label: const Text('Aprobar y dar puntos',
                        style: TextStyle(color: AppColors.verde)),
                  ),
                )
            else if (reto.finalizado)
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

class _RetosPasados extends StatelessWidget {
  final bool esAdmin;
  const _RetosPasados({required this.esAdmin});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Reto>>(
      future: context.read<AppProvider>().listarRetos(),
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