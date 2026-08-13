import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/duo_widgets.dart';
import '../widgets/empty_state.dart';
import '../models/reward.dart';
import '../models/redemption.dart';
import '../models/user.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final user = app.usuarioActual;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Recompensas')),
      body: user.esAdmin
          ? _AdminRewardsView(app: app)
          : _UserRewardsView(user: user, app: app),
    );
  }
}

class _AdminRewardsView extends StatefulWidget {
  final AppProvider app;
  const _AdminRewardsView({required this.app});

  @override
  State<_AdminRewardsView> createState() => _AdminRewardsViewState();
}

class _AdminRewardsViewState extends State<_AdminRewardsView> {
  List<Reward> _recompensas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    widget.app.addListener(_onChange);
    _cargarDatos();
  }

  void _onChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cargarDatos();
    });
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    _recompensas = await widget.app.listarRecompensas();
    setState(() => _cargando = false);
  }

  @override
  void dispose() {
    widget.app.removeListener(_onChange);
    super.dispose();
  }

  void _nuevaRecompensa(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _RewardFormDialog(
        onSaved: (data) => _crearRecompensa(context, data),
      ),
    );
  }

  Future<void> _crearRecompensa(BuildContext context, Map<String, Object?> data) async {
    await widget.app.crearRecompensa(
      nombre: data['nombre'] as String? ?? '',
      descripcion: data['descripcion'] as String? ?? '',
      costoPuntos: (data['costoPuntos'] as int?) ?? 0,
    );
    if (context.mounted) Navigator.pop(context);
    _cargarDatos();
  }

  void _editarRecompensa(BuildContext context, Reward reward) {
    showDialog(
      context: context,
      builder: (_) => _RewardFormDialog(
        initialData: {
          'nombre': reward.nombre,
          'descripcion': reward.descripcion,
          'costoPuntos': reward.costoPuntos,
        },
        onSaved: (data) => _editarRecompensaGuardado(context, reward, data),
      ),
    );
  }

  Future<void> _editarRecompensaGuardado(BuildContext context, Reward reward, Map<String, Object?> data) async {
    final recompensasEditada = Reward(
      id: reward.id,
      nombre: data['nombre'] as String? ?? reward.nombre,
      descripcion: data['descripcion'] as String? ?? reward.descripcion,
      costoPuntos: (data['costoPuntos'] as int?) ?? reward.costoPuntos,
    );
    await widget.app.editarRecompensa(recompensasEditada);
    if (context.mounted) Navigator.pop(context);
    _cargarDatos();
  }

  void _eliminarRecompensa(BuildContext context, Reward reward) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar recompensa'),
        content: Text('¿Estás seguro que deseas eliminar "${reward.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await widget.app.eliminarRecompensa(reward.id!);
              if (context.mounted) Navigator.pop(context);
              _cargarDatos();
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Expanded(
          child: _recompensas.isEmpty
              ? const EmptyState(
                  icon: Icons.card_giftcard,
                  message: 'No hay recompensas disponibles',
                  hint: 'Crea una recompensa para incentivar a los integrantes.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _recompensas.length,
                  itemBuilder: (context, i) {
                    final r = _recompensas[i];
                    return DuoCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        leading: DuoIconBadge(
                            icon: Icons.card_giftcard,
                            color: AppColors.azul,
                            size: 42),
                        title: Text(r.nombre,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${r.descripcion}\n• ${r.costoPuntos} pts'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: AppColors.azul),
                              onPressed: () => _editarRecompensa(context, r),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: AppColors.rojo),
                              onPressed: () => _eliminarRecompensa(context, r),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: DuoButton(
                  label: 'Nueva recompensa',
                  icon: Icons.add,
                  onPressed: () => _nuevaRecompensa(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DuoButton(
                  label: 'Entregas',
                  icon: Icons.redeem,
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => _EntregaCanjesDialog(app: widget.app),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Diálogo donde el admin entrega las recompensas canjeadas por los integrantes.
class _EntregaCanjesDialog extends StatefulWidget {
  final AppProvider app;
  const _EntregaCanjesDialog({required this.app});

  @override
  State<_EntregaCanjesDialog> createState() => _EntregaCanjesDialogState();
}

class _EntregaCanjesDialogState extends State<_EntregaCanjesDialog> {
  List<(Redemption, Reward, User)> _canjes = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final canjes = await widget.app.canjesFamilia();
    if (mounted) setState(() => _canjes = canjes);
  }

  @override
  Widget build(BuildContext context) {
    final pendientes =
        _canjes.where((c) => c.$1.estado == 'pendiente').toList();
    return AlertDialog(
      title: const Text('Entregar recompensas'),
      content: SizedBox(
        width: 420,
        child: pendientes.isEmpty
            ? const Text('No hay recompensas pendientes de entregar.',
                style: TextStyle(color: AppColors.grisMedio))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: pendientes.length,
                itemBuilder: (context, i) {
                  final c = pendientes[i];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.card_giftcard,
                        color: AppColors.azul),
                    title: Text(c.$2.nombre,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                        '${c.$3.nombre} · ${c.$1.fecha.day}/${c.$1.fecha.month}'),
                    trailing: DuoButton(
                      label: 'Entregar',
                      color: AppColors.verde,
                      onPressed: () async {
                        await widget.app.marcarCanjeEntregado(c.$1.id!);
                        await _cargar();
                      },
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _RewardFormDialog extends StatefulWidget {
  final Map<String, Object?>? initialData;
  final Function(Map<String, Object?>)? onSaved;

  const _RewardFormDialog({this.initialData, this.onSaved});

  @override
  State<_RewardFormDialog> createState() => _RewardFormDialogState();
}

class _RewardFormDialogState extends State<_RewardFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _costoPuntosController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final d = widget.initialData!;
      _nombreController.text = d['nombre'] as String? ?? '';
      _descripcionController.text = d['descripcion'] as String? ?? '';
      _costoPuntosController.text = (d['costoPuntos'] as int?)?.toString() ?? '0';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva recompensa'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _costoPuntosController,
                decoration: const InputDecoration(labelText: 'Puntos'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || int.tryParse(v) == null)
                    ? 'Número válido requerido'
                    : null,
              ),
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
              'nombre': _nombreController.text,
              'descripcion': _descripcionController.text,
              'costoPuntos': int.tryParse(_costoPuntosController.text) ?? 0,
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
    _nombreController.dispose();
    _descripcionController.dispose();
    _costoPuntosController.dispose();
    super.dispose();
  }
}

class _UserRewardsView extends StatefulWidget {
  final User user;
  final AppProvider app;
  const _UserRewardsView({required this.user, required this.app});

  @override
  State<_UserRewardsView> createState() => _UserRewardsViewState();
}

class _UserRewardsViewState extends State<_UserRewardsView> {
  List<Reward> _recompensas = [];
  List<(Redemption, Reward)> _canjes = [];
  bool _cargando = true;
  bool _bloqueado = false;

  @override
  void initState() {
    super.initState();
    widget.app.addListener(_onChange);
    _cargarDatos();
  }

  void _onChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cargarDatos();
    });
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    _recompensas = await widget.app.listarRecompensas();
    _canjes = await widget.app.canjesDe(widget.user.id!);
    _bloqueado = await widget.app.tieneTareasVencidas(widget.user.id!);
    setState(() => _cargando = false);
  }

  @override
  void dispose() {
    widget.app.removeListener(_onChange);
    super.dispose();
  }

  Future<void> _canjearRecompensa(Reward recompensa) async {
    final success = await widget.app.canjearRecompensa(recompensa);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Has canjeado "${recompensa.nombre}" exitosamente!'),
        ),
      );
      await _cargarDatos();
    } else {
      final msg = widget.app.error ?? 'No puedes canjear esta recompensa.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      await _cargarDatos();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        if (_bloqueado)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.rojo.withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_clock, color: AppColors.rojo),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tienes tareas vencidas. Complétalas para poder canjear recompensas.',
                    style: TextStyle(fontSize: 13, color: AppColors.rojo, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _recompensas.isEmpty
              ? const EmptyState(
                  icon: Icons.card_giftcard,
                  message: 'No hay recompensas disponibles para canjear',
                  hint: 'Contacta al administrador para agregar recompensas.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _recompensas.length + (_canjes.isEmpty ? 0 : 1),
                  itemBuilder: (context, i) {
                    if (_canjes.isNotEmpty && i == 0) {
                      return _MisCanjes(entre: _canjes, user: widget.user);
                    }
                    final r = _recompensas[i - (_canjes.isEmpty ? 0 : 1)];
                    final jaCambiado = _canjes.any((c) => c.$2.id == r.id);
                    return DuoCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          DuoIconBadge(
                            icon: jaCambiado ? Icons.check : Icons.card_giftcard,
                            color: jaCambiado ? AppColors.grisMedio : AppColors.verde,
                            size: 42,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.nombre,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                                Text(r.descripcion,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.grisMedio)),
                                const SizedBox(height: 4),
                                Text('Coste: ${r.costoPuntos} pts',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.grisOscuro)),
                                if (jaCambiado)
                                  Text(
                                    'Canjeado el: ${_canjes.firstWhere((c) => c.$2.id == r.id).$1.fecha}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.grisMedio),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 118,
                            child: jaCambiado
                                ? DuoButton(
                                    label: 'Canjeado',
                                    color: AppColors.grisMedio,
                                    borderColor: AppColors.grisOscuro,
                                    onPressed: null,
                                  )
                                : DuoButton(
                                    label: 'Canjear',
                                    color: AppColors.azul,
                                    borderColor: Color(0xFF1290C9),
                                    onPressed: () => _canjearRecompensa(r),
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Historial de canjes del integrante, con su estado (pendiente / entregada).
class _MisCanjes extends StatelessWidget {
  final List<(Redemption, Reward)> entre;
  final User user;
  const _MisCanjes({required this.entre, required this.user});

  @override
  Widget build(BuildContext context) {
    final pendientes = entre.where((c) => c.$1.estado == 'pendiente').length;
    final entregadas = entre.where((c) => c.$1.estado == 'entregada').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.redeem, color: AppColors.azul, size: 20),
            const SizedBox(width: 6),
            Text(
              'Mis canjes (${entre.length})',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.grisOscuro),
            ),
            const Spacer(),
            Chip(
              label: Text('$pendientes pend. · $entregadas entr.',
                  style: const TextStyle(
                      color: AppColors.grisOscuro, fontSize: 11)),
              visualDensity: VisualDensity.compact,
              backgroundColor: AppColors.verdeFondo,
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final c in entre)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.amarillo.withValues(alpha: 0.2),
              child: const Icon(Icons.card_giftcard,
                  color: AppColors.amarillo, size: 18),
            ),
            title: Text(c.$2.nombre,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
            subtitle: Text(
              '${c.$1.fecha.day}/${c.$1.fecha.month} · ${c.$1.estado == 'entregada' ? 'Entregada' : 'Pendiente'}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Chip(
              label: Text(c.$1.estado == 'entregada'
                  ? 'ENTREGADA'
                  : 'PENDIENTE',
                  style: TextStyle(
                      color: c.$1.estado == 'entregada'
                          ? AppColors.verdeOscuro
                          : AppColors.rojo,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
              backgroundColor: (c.$1.estado == 'entregada'
                      ? AppColors.verdeFondo
                      : Colors.red)
                  .withValues(alpha: 0.12),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}