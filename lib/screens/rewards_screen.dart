import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../db/photo_picker.dart';
import '../db/photo_store.dart';
import '../db/server_config.dart';
import '../db/upload_client.dart';
import '../widgets/foto_widget.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/duo_widgets.dart';
import '../widgets/empty_state.dart';
import '../models/reward.dart';
import '../models/redemption.dart';
import '../models/user.dart';

/// Resuelve una ruta de foto (relativa o absoluta) a una URL mostrable.
String _resolverFoto(String foto) {
  if (foto.isEmpty) return '';
  if (foto.startsWith('http')) return foto;
  return '${ServerConfig.baseUrl}$foto';
}

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
    if (!mounted) return;
    setState(() => _cargando = true);
    try {
      _recompensas = await widget.app.listarRecompensas();
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
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
      foto: data['foto'] as String? ?? '',
      fotoLocal: data['fotoLocal'] as String? ?? '',
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
            'foto': reward.foto,
            'fotoLocal': reward.fotoLocal,
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
      foto: data['foto'] as String? ?? reward.foto,
      fotoLocal: data['fotoLocal'] as String? ?? reward.fotoLocal,
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
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
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
              DuoButton(
                label: '📋 Historial',
                fullWidth: false,
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => _EntregaCanjesDialog(app: widget.app),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _recompensas.isEmpty
              ? const EmptyState(
                  icon: Icons.card_giftcard,
                  message: 'No hay recompensas disponibles',
                  hint: 'Crea una recompensa para incentivar a los integrantes.',
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 260,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: _recompensas.length,
                      itemBuilder: (context, i) {
                        final r = _recompensas[i];
                        return _RewardGridCard(
                          reward: r,
                          onEditar: () => _editarRecompensa(context, r),
                          onEliminar: () => _eliminarRecompensa(context, r),
                        );
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Chip dorado con los puntos de una recompensa.
class _OroChip extends StatelessWidget {
  final int pts;
  const _OroChip({required this.pts});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.amarillo.withValues(alpha: 0.18)
            : const Color(0xFFFFF3C4),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on, size: 14, color: AppColors.amarillo),
          const SizedBox(width: 4),
          Text(
            '$pts pts',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.amarillo : const Color(0xFF8A6D00),
            ),
          ),
        ],
      ),
    );
  }
}

/// Acción mini (editar/eliminar) con hover en escritorio.
class _MiniAccionGrid extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _MiniAccionGrid({
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
          padding: const EdgeInsets.all(4),
          child: Icon(icono, size: 17, color: color),
        ),
      ),
    );
  }
}

/// Tarjeta de recompensa en el grid del admin: foto, chip dorado y
/// editar/eliminar al hacer hover (siempre visibles en táctil).
class _RewardGridCard extends StatefulWidget {
  final Reward reward;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _RewardGridCard({
    required this.reward,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  State<_RewardGridCard> createState() => _RewardGridCardState();
}

class _RewardGridCardState extends State<_RewardGridCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.reward;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final siempreVisible = kIsWeb
        ? (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)
        : true;
    final mostrar = siempreVisible || _hover;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.superficieOscura : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hover
                ? AppColors.verde
                : (isDark
                    ? AppColors.grisMedio.withValues(alpha: 0.3)
                    : AppColors.linea),
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
                color: Color(0x14000000), offset: Offset(0, 4), blurRadius: 0),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 86,
              decoration: BoxDecoration(
                color: AppColors.amarillo.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: (r.foto.isNotEmpty || r.fotoLocal.isNotEmpty)
                  ? Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: FotoWidget(
                          url: _resolverFoto(r.foto),
                          local: r.fotoLocal,
                          size: 78,
                          placeholder: const Icon(Icons.card_giftcard,
                              color: AppColors.azul, size: 34),
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.card_giftcard,
                          color: AppColors.azul, size: 36),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              r.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Text(
                r.descripcion,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontSize: 11, color: textoSuaveTema(context)),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _OroChip(pts: r.costoPuntos),
                const Spacer(),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: mostrar ? 1 : 0,
                  child: mostrar
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _MiniAccionGrid(
                              icono: Icons.edit,
                              color: AppColors.azul,
                              tooltip: 'Editar',
                              onPressed: widget.onEditar,
                            ),
                            _MiniAccionGrid(
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
          ],
        ),
      ),
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
            ? Text('No hay recompensas pendientes de entregar.',
                style: TextStyle(color: textoSuaveTema(context)))
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
  String _foto = '';
  String _fotoLocal = '';
  bool _subiendo = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final d = widget.initialData!;
      _nombreController.text = d['nombre'] as String? ?? '';
      _descripcionController.text = d['descripcion'] as String? ?? '';
      _costoPuntosController.text = (d['costoPuntos'] as int?)?.toString() ?? '0';
      _foto = d['foto'] as String? ?? '';
      _fotoLocal = d['fotoLocal'] as String? ?? '';
    }
  }

  Future<void> _elegirFoto() async {
    try {
      final resultado = await elegirFoto();
      if (resultado == null) return;
      final (bytes, mime) = resultado;
      if (!mounted) return;
      setState(() => _subiendo = true);
      // Se guarda una copia local SIEMPRE (funciona sin internet).
      final local = await PhotoStore.guardarBytes(bytes);
      // Se sube al servidor solo si hay conexion; si no, queda pendiente.
      final url = await UploadClient().subirFoto(bytes, mime: mime);
      if (!mounted) return;
      setState(() {
        _fotoLocal = local;
        if (url != null) _foto = url;
      });
      if (url == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto guardada en este dispositivo. Se subirá al tener internet.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialData == null
          ? 'Nueva recompensa'
          : 'Editar recompensa'),
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
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_foto.isNotEmpty || _fotoLocal.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: FotoWidget(
                        url: _resolverFoto(_foto),
                        local: _fotoLocal,
                        size: 56,
                        placeholder: const Icon(Icons.image),
                      ),
                    ),
                  DuoButton(
                    label: _foto.isEmpty && _fotoLocal.isEmpty
                        ? 'Añadir foto'
                        : 'Cambiar foto',
                    icon: Icons.photo_camera,
                    fullWidth: false,
                    loading: _subiendo,
                    onPressed: _subiendo ? null : _elegirFoto,
                  ),
                  if (_foto.isNotEmpty || _fotoLocal.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.rojo),
                      tooltip: 'Quitar foto',
                      onPressed: () => setState(() {
                            _foto = '';
                            _fotoLocal = '';
                          }),
                    ),
                ],
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
              'foto': _foto,
              'fotoLocal': _fotoLocal,
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
    if (!mounted) return;
    setState(() => _cargando = true);
    try {
      _recompensas = await widget.app.listarRecompensas();
      _canjes = await widget.app.canjesDe(widget.user.id!);
      _bloqueado = await widget.app.tieneTareasVencidas(widget.user.id!);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
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
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = constraints.maxWidth >= 700 ? 3 : 2;
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            if (_canjes.isNotEmpty) ...[
                              _MisCanjes(entre: _canjes, user: widget.user),
                              const SizedBox(height: 4),
                            ],
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: cols,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.66,
                              children: [
                                for (final r in _recompensas)
                                  _UserRewardCard(
                                    reward: r,
                                    jaCanjeado: _canjes
                                        .any((c) => c.$2.id == r.id),
                                    onCanjear: () => _canjearRecompensa(r),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Tarjeta de recompensa para el integrante: foto, chip dorado y botón
/// "Canjear" compacto estilo Duolingo.
class _UserRewardCard extends StatelessWidget {
  final Reward reward;
  final bool jaCanjeado;
  final VoidCallback onCanjear;

  const _UserRewardCard({
    required this.reward,
    required this.jaCanjeado,
    required this.onCanjear,
  });

  @override
  Widget build(BuildContext context) {
    final r = reward;
    return DuoCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.amarillo.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: (r.foto.isNotEmpty || r.fotoLocal.isNotEmpty)
                ? Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: FotoWidget(
                        url: _resolverFoto(r.foto),
                        local: r.fotoLocal,
                        size: 64,
                        placeholder: Icon(
                            jaCanjeado ? Icons.check : Icons.card_giftcard,
                            color: jaCanjeado
                                ? AppColors.grisMedio
                                : AppColors.verde,
                            size: 30),
                      ),
                    ),
                  )
                : Center(
                    child: Icon(
                        jaCanjeado ? Icons.check : Icons.card_giftcard,
                        color:
                            jaCanjeado ? AppColors.grisMedio : AppColors.verde,
                        size: 32),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            r.nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Text(
              r.descripcion,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: textoSuaveTema(context)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _OroChip(pts: r.costoPuntos),
              if (jaCanjeado) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.verdeFondo,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Canjeado',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.verdeOscuro,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const Spacer(),
          const SizedBox(height: 8),
          _MiniBoton(
            label: jaCanjeado ? 'Canjeado' : 'Canjear',
            color: jaCanjeado ? AppColors.grisOscuro : AppColors.azul,
            borderColor:
                jaCanjeado ? AppColors.grisOscuro : const Color(0xFF1290C9),
            onPressed: jaCanjeado ? null : onCanjear,
          ),
        ],
      ),
    );
  }
}

/// Botón Duolingo compacto (altura 40) para las tarjetas del grid.
class _MiniBoton extends StatelessWidget {
  final String label;
  final Color color;
  final Color borderColor;
  final VoidCallback? onPressed;

  const _MiniBoton({
    required this.label,
    required this.color,
    required this.borderColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final bg = enabled ? color : AppColors.linea;
    final bd = enabled ? borderColor : AppColors.grisMedio;
    return SizedBox(
      height: 40,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border(bottom: BorderSide(color: bd, width: 4)),
            ),
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
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
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textoTema(context)),
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