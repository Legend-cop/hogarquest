import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import 'local_sync_screen.dart';

import '../db/photo_picker.dart';
import '../db/photo_store.dart';
import '../db/upload_client.dart';
import '../providers/app_provider.dart';
import '../screens/bluetooth_sync_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/duo_widgets.dart';
import '../widgets/section_header.dart';
import '../widgets/user_avatar.dart';
import '../models/user.dart';
import '../models/badge.dart' as badge_model;
import '../models/assignment.dart';
import '../models/castigo.dart';
import '../models/redemption.dart';
import '../models/reward.dart';
import '../models/task.dart';
import '../services/gamification_service.dart';
import '../services/notification_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nombreController = TextEditingController();
  final _colorTemaController = TextEditingController();
  bool _editando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().addListener(_onChange);
    });
  }

  @override
  void dispose() {
    context.read<AppProvider>().removeListener(_onChange);
    _nombreController.dispose();
    _colorTemaController.dispose();
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
    if (_nombreController.text.isEmpty) {
      _nombreController.text = user.nombre;
      _colorTemaController.text = user.colorTema;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del integrante'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout, color: AppColors.rojo),
            onPressed: () => _cerrarSesion(context),
          ),
          IconButton(
            icon: Icon(_editando ? Icons.done : Icons.edit),
            onPressed: () => setState(() => _editando = !_editando),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _AvatarCard(user: user, onCambiarFoto: _cambiarFoto),
            const SizedBox(height: 24),
            _InfoCard(
              user: user,
              editando: _editando,
              nombreController: _nombreController,
              colorTemaController: _colorTemaController,
              onGuardado: () => setState(() => _editando = false),
            ),
            const SizedBox(height: 20),
            _RecordatorioCard(userId: user.id!),
            const SizedBox(height: 20),
            const Divider(),
            SectionHeader(title: 'Mis insignias'),
            _InsigniasSection(user: user),
            const SizedBox(height: 20),
            SectionHeader(title: 'Canjes recientes'),
            _RedemptionsSection(user: user),
            const SizedBox(height: 20),
            _CastigosSection(userId: user.id!),
            if (user.esAdmin) ...[
              const SizedBox(height: 20),
              const Divider(),
              SectionHeader(title: 'Administración'),
              DuoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.pin, color: AppColors.azul),
                      title: const Text('PIN de administrador'),
                      subtitle: const Text(
                          'Protege el acceso al panel de administración.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _configurarPin(context),
                    ),
                    const Divider(),
                    ListTile(
                      leading:
                          const Icon(Icons.download, color: AppColors.verdeOscuro),
                      title: const Text('Exportar respaldo'),
                      subtitle: const Text(
                          'Descarga una copia completa de la base de datos.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _exportarRespaldo(context),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.restore, color: AppColors.azul),
                      title: const Text('Restaurar respaldo'),
                      subtitle: const Text(
                          'Carga un respaldo previamente descargado.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _restaurarRespaldo(context),
                    ),
                    const Divider(),
                    ListTile(
                      leading:
                          const Icon(Icons.wifi_tethering, color: AppColors.azul),
                      title: const Text('Sincronización local'),
                      subtitle: const Text(
                          'Sincroniza con otros dispositivos sin internet (misma Wi-Fi).'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LocalSyncScreen()),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.bluetooth, color: AppColors.azul),
                      title: const Text('Sincronización por Bluetooth'),
                      subtitle: const Text(
                          'Sincroniza con otros dispositivos sin internet (Bluetooth/Wi-Fi directo).'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const BluetoothSyncScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            DuoButton(
              label: 'Cerrar sesión',
              icon: Icons.logout,
              color: AppColors.rojo,
              borderColor: const Color(0xFFC62828),
              fullWidth: false,
              onPressed: () => _cerrarSesion(context),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _configurarPin(BuildContext context) async {
    final pin = TextEditingController();
    final confirmar = TextEditingController();
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PIN de administrador'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Crea un PIN de 4 a 6 dígitos. Se pedirá cada vez que '
              'inicies sesión como administrador.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pin,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nuevo PIN'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmar,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirmar PIN'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (pin.text.length < 4 || pin.text != confirmar.text) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Los PIN no coinciden o son muy cortos.'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, pin.text);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (nuevo == null) return;
    final app = context.read<AppProvider>();
    await app.fijarPin(nuevo);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN de administrador configurado.')),
      );
    }
  }

  Future<void> _exportarRespaldo(BuildContext context) async {
    try {
      final app = context.read<AppProvider>();
      final json = await app.exportarRespaldo();
      final bytes = Uint8List.fromList(utf8.encode(json));
      final nombre =
          'hogarquest_respaldo_${DateTime.now().toIso8601String().substring(0, 10)}';
      await FileSaver.instance.saveFile(
        name: nombre,
        bytes: bytes,
        fileExtension: 'json',
        mimeType: MimeType.other,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Respaldo descargado.')),
        );
      }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo exportar: $e')),
          );
        }
      }
    }

  Future<void> _restaurarRespaldo(BuildContext context) async {
    try {
      final app = context.read<AppProvider>();
      final resultado = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (resultado.isEmpty) return;
      final bytes = await resultado.single.readAsBytes();
      final contenido = utf8.decode(bytes);
      final data = jsonDecode(contenido);
      if (data is! Map<String, dynamic>) {
        throw Exception('El archivo no es un respaldo válido.');
      }
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restaurar respaldo'),
          content: const Text(
            'Esto reemplazará los datos actuales por el contenido del '
            'respaldo en este y otros dispositivos. ¿Continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restaurar'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
      await app.importarRespaldo(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Respaldo restaurado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo restaurar: $e')),
        );
      }
    }
  }

  Future<void> _cambiarFoto() async {
    try {
      final resultado = await elegirFoto();
      if (resultado == null) return;
      final (bytes, mime) = resultado;
      if (!mounted) return;
      final app = context.read<AppProvider>();
      final user = app.usuarioActual;
      if (user == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subiendo foto…')),
      );
      final local = await PhotoStore.guardarBytes(bytes);
      final url = await UploadClient().subirFoto(bytes, mime: mime);
      if (!mounted) return;
      if (url == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto guardada en este dispositivo. Se subirá al tener internet.'),
          ),
        );
      }
      await app.editarUsuario(user.copyWith(foto: url ?? user.foto, fotoLocal: local));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Foto actualizada!')),
        );
      }
    } catch (e) {
      debugPrint('Error al elegir foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo elegir la foto: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    final app = context.read<AppProvider>();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres salir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (ok == true) {
      app.logout();
    }
  }
}

class _AvatarCard extends StatelessWidget {
  final User user;
  final VoidCallback? onCambiarFoto;
  const _AvatarCard({required this.user, this.onCambiarFoto});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            UserAvatar(user: user, radius: 56),
            if (onCambiarFoto != null)
              Positioned(
                bottom: -2,
                right: -2,
                child: GestureDetector(
                  onTap: onCambiarFoto,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.verde,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_camera,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          user.nombre,
          style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.grisOscuro),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Pill(icon: Icons.military_tech, text: 'Nivel ${user.nivel}', color: AppColors.amarillo),
            const SizedBox(width: 8),
            _Pill(icon: Icons.local_fire_department, text: '${user.racha} días', color: AppColors.rojo),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${user.puntos} pts XP acumulados',
          style: const TextStyle(
              color: AppColors.grisMedio, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _Pill({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: color, fontSize: 13)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatefulWidget {
  final User user;
  final bool editando;
  final TextEditingController nombreController;
  final TextEditingController colorTemaController;
  final VoidCallback? onGuardado;

  const _InfoCard({
    required this.user,
    required this.editando,
    required this.nombreController,
    required this.colorTemaController,
    this.onGuardado,
  });

  @override
  State<_InfoCard> createState() => _InfoCardState();
}

class _InfoCardState extends State<_InfoCard> {
  late DateTime? _fechaNacimiento;

  @override
  void initState() {
    super.initState();
    _fechaNacimiento = widget.user.fechaNacimiento;
  }

  int _edadDe(DateTime? fn) {
    if (fn == null) return widget.user.edad;
    final a = DateTime.now().difference(fn).inDays ~/ 365.25;
    return a < 0 ? 0 : a;
  }

  Future<void> _elegirFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ??
          DateTime.now().subtract(const Duration(days: 365 * 10)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _fechaNacimiento = picked);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();

    if (widget.editando) {
      return DuoCard(
        child: Column(
          children: [
            TextField(
              controller: widget.nombreController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cake, color: AppColors.azul),
              title: Text(_fechaNacimiento == null
                  ? 'Fecha de nacimiento'
                  : 'Edad: ${_edadDe(_fechaNacimiento)} años'),
              subtitle: _fechaNacimiento == null
                  ? const Text('Toca para seleccionar')
                  : Text(
                      '${_fechaNacimiento!.day}/${_fechaNacimiento!.month}/${_fechaNacimiento!.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _elegirFecha,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.colorTemaController,
              decoration: const InputDecoration(labelText: 'Tema favorito'),
            ),
            const SizedBox(height: 16),
            DuoButton(
              label: 'Guardar',
              icon: Icons.save,
              onPressed: () async {
                final userEditado = widget.user.copyWith(
                  nombre: widget.nombreController.text,
                  edad: _edadDe(_fechaNacimiento),
                  fechaNacimiento: _fechaNacimiento,
                  colorTema: widget.colorTemaController.text,
                );
                await app.editarUsuario(userEditado);
                widget.onGuardado?.call();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Perfil actualizado')),
                  );
                }
              },
            ),
          ],
        ),
      );
    }

    return DuoCard(
      child: Column(
        children: [
          _InfoRow(icon: Icons.person, label: 'Nombre', value: widget.user.nombre),
          const Divider(),
          _InfoRow(icon: Icons.cake, label: 'Edad', value: '${widget.user.edad} años'),
          const Divider(),
          _InfoRow(
            icon: Icons.palette,
            label: 'Tema favorito',
            value: widget.user.colorTema,
          ),
          const Divider(),
          _InfoRow(icon: Icons.star, label: 'Nivel', value: 'Nivel ${widget.user.nivel}'),
          const Divider(),
          _InfoRow(
            icon: Icons.local_fire_department,
            label: 'Racha',
            value: '${widget.user.racha} días',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.azul, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _InsigniasSection extends StatefulWidget {
  final User user;
  const _InsigniasSection({required this.user});

  @override
  State<_InsigniasSection> createState() => _InsigniasSectionState();
}

class _InsigniasSectionState extends State<_InsigniasSection> {
  List<(badge_model.Badge, int, int, bool)> _detalle = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final app = context.read<AppProvider>();
    final catalogo = await app.listarInsignias();
    final historial = widget.user.id != null
        ? await app.historialDe(widget.user.id!)
        : <(Task, Assignment)>[];
    final tareas = await app.listarTareas();
    final asignaciones = historial.map((h) => h.$2).toList();
    final detalle = GamificationService.detalleInsignias(
      catalogo: catalogo,
      puntos: widget.user.puntos,
      racha: widget.user.racha,
      aprobadas: asignaciones,
      tareas: tareas,
    );
    if (mounted) {
      setState(() {
        _detalle = detalle;
        _cargando = false;
      });
    }
  }

  IconData _icono(String nombre) {
    const mapa = {
      'cleaning_services': Icons.cleaning_services,
      'restaurant': Icons.restaurant,
      'inventory_2': Icons.inventory_2,
      'schedule': Icons.schedule,
      'local_fire_department': Icons.local_fire_department,
      'emoji_events': Icons.emoji_events,
      'flash_on': Icons.flash_on,
    };
    return mapa[nombre] ?? Icons.emoji_events;
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_detalle.isEmpty) {
      return const Text('Completa tareas para ganar insignias.',
          style: TextStyle(color: Colors.grey));
    }
    return Column(
      children: [
        for (final d in _detalle)
          DuoCard(
            margin: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _icono(d.$1.icono),
                  size: 30,
                  color: d.$4 ? AppColors.amarillo : AppColors.grisMedio,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(d.$1.nombre,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 15)),
                          ),
                          if (d.$4)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.verdeFondo,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('¡Lograda!',
                                  style: TextStyle(
                                      color: AppColors.verdeOscuro,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(d.$1.descripcion,
                          style: const TextStyle(
                              color: AppColors.grisMedio, fontSize: 12)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: d.$3 == 0 ? 0 : d.$2 / d.$3,
                        backgroundColor: AppColors.linea,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            d.$4 ? AppColors.verde : AppColors.azul),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        d.$4 ? 'Completada' : '${d.$2}/${d.$3}',
                        style: const TextStyle(
                            color: AppColors.grisMedio, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RedemptionsSection extends StatefulWidget {
  final User user;
  const _RedemptionsSection({required this.user});

  @override
  State<_RedemptionsSection> createState() => _RedemptionsSectionState();
}

class _RedemptionsSectionState extends State<_RedemptionsSection> {
  List<(Redemption, Reward)> _canjes = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final app = context.read<AppProvider>();
    final canjes = widget.user.id != null ? await app.canjesDe(widget.user.id!) : <(Redemption, Reward)>[];
    if (mounted) {
      setState(() {
        _canjes = canjes;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_canjes.isEmpty) {
      return const Text('Aún no se ha canjeado ninguna recompensa.',
          style: TextStyle(color: Colors.grey));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _canjes.length,
      itemBuilder: (context, i) {
        final (canje, recompensa) = _canjes[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.verde.withValues(alpha: 0.15),
            child: const Icon(Icons.card_giftcard, color: AppColors.verde),
          ),
          title: Text(recompensa.nombre),
          subtitle: Text(canje.fecha.toString()),
          trailing: Chip(
            label: Text('-${recompensa.costoPuntos} pts'),
            backgroundColor: Colors.red.withValues(alpha: 0.15),
            labelStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }
}

class _RecordatorioCard extends StatefulWidget {
  final int userId;
  const _RecordatorioCard({required this.userId});

  @override
  State<_RecordatorioCard> createState() => _RecordatorioCardState();
}

class _RecordatorioCardState extends State<_RecordatorioCard> {
  int? _minutos;
  bool _cargando = true;
  bool _permisoConcedido = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final minutos =
        await NotificationService.instance.horaConfigurada(widget.userId);
    final permiso =
        await NotificationService.instance.permisoConcedido();
    if (mounted) {
      setState(() {
        _minutos = minutos;
        _permisoConcedido = permiso;
        _cargando = false;
      });
    }
  }

  Future<void> _elegirHora() async {
    final actual = _minutos ?? 8 * 60;
    final app = context.read<AppProvider>();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: actual ~/ 60,
        minute: actual % 60,
      ),
      helpText: 'Hora del recordatorio diario',
    );
    if (picked == null) return;
    final minutos = picked.hour * 60 + picked.minute;
    await NotificationService.instance.guardarHora(
      app: app,
      userId: widget.userId,
      minutos: minutos,
    );
    if (mounted) {
      setState(() => _minutos = minutos);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recordatorio actualizado')),
      );
    }
  }

  Future<void> _solicitarPermiso() async {
    final concedido =
        await NotificationService.instance.solicitarPermiso();
    if (!concedido) return;
    if (mounted) {
      setState(() => _permisoConcedido = true);
    }
  }

  Future<void> _abrirAjustes() async {
    await NotificationService.instance.abrirAjustes();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    final minutos = _minutos ?? 8 * 60;
    final hora = minutos ~/ 60;
    final minuto = minutos % 60;
    final horaTexto = '${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}';
    final colores = Theme.of(context).colorScheme;
    return Column(
      children: [
        DuoCard(
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: AppColors.amarillo.withValues(alpha: 0.2),
              child: const Icon(Icons.alarm, color: AppColors.amarillo),
            ),
            title: const Text('Recordatorio diario',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
                'Notificación a las $horaTexto para tus tareas del día'),
            trailing: TextButton(
              onPressed: _elegirHora,
              child: const Text('Cambiar hora'),
            ),
          ),
        ),
        if (!_permisoConcedido)
          DuoCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.notifications_off,
                      color: colores.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Notificaciones bloqueadas. Para recibir los recordatorios, actívalas desde los Ajustes del sistema.',
                      style: TextStyle(fontSize: 12, color: colores.onSurface),
                    ),
                  ),
                  TextButton(
                    onPressed: _abrirAjustes,
                    child: const Text('Abrir Ajustes'),
                  ),
                  TextButton(
                    onPressed: _solicitarPermiso,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CastigosSection extends StatefulWidget {
  final int userId;
  const _CastigosSection({required this.userId});

  @override
  State<_CastigosSection> createState() => _CastigosSectionState();
}

class _CastigosSectionState extends State<_CastigosSection> {
  List<Castigo> _castigos = [];
  int _puntosSemana = 0;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final app = context.read<AppProvider>();
    final castigos = await app.castigosDe(widget.userId);
    final puntos = await app.puntosCastigadosRecientes(widget.userId);
    if (mounted) {
      setState(() {
        _castigos = castigos.reversed.toList();
        _puntosSemana = puntos;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final disciplina = _castigos.where((c) => c.esDisciplina).take(5).toList();
    final tareas = _castigos.where((c) => c.esTarea).take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.gavel, color: AppColors.rojo, size: 20),
            const SizedBox(width: 6),
            const Text('Castigos y quitas',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.grisOscuro)),
            const Spacer(),
            if (_puntosSemana > 0)
              Chip(
                label: Text('-$_puntosSemana pts esta semana'),
                backgroundColor: Colors.red.withValues(alpha: 0.15),
                labelStyle: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.w700, fontSize: 11),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_castigos.isEmpty)
          const Text('Sin castigos ni quitas. ¡Sigue así! 🎉',
              style: TextStyle(color: AppColors.grisMedio, fontSize: 13))
        else ...[
          if (tareas.isNotEmpty) ...[
            const Text('Por tareas sin cumplir',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.grisMedio)),
            ...tareas.map((c) => _fila(c, Icons.event_busy, Colors.orange)),
            const SizedBox(height: 8),
          ],
          if (disciplina.isNotEmpty) ...[
            const Text('Castigos (disciplina)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.grisMedio)),
            ...disciplina.map((c) => _fila(c, Icons.error_outline, AppColors.rojo)),
          ],
        ],
      ],
    );
  }

  Widget _fila(Castigo c, IconData icono, Color color) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icono, color: color, size: 20),
      ),
      title: Text(c.motivo,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(
          '${c.fecha.day}/${c.fecha.month} · ${c.esTarea ? 'Tarea sin cumplir' : 'Disciplina'}',
          style: const TextStyle(fontSize: 11)),
      trailing: Text('-${c.puntos} pts',
          style: const TextStyle(
              color: AppColors.rojo,
              fontWeight: FontWeight.w800,
              fontSize: 13)),
    );
  }
}