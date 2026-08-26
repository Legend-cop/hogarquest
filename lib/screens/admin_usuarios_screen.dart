import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/duo_widgets.dart';
import '../widgets/empty_state.dart';
import '../widgets/user_avatar.dart';
import 'usuario_detail_screen.dart';

class AdminUsuariosScreen extends StatefulWidget {
  const AdminUsuariosScreen({super.key});

  @override
  State<AdminUsuariosScreen> createState() => _AdminUsuariosScreenState();
}

class _AdminUsuariosScreenState extends State<AdminUsuariosScreen> {
  bool _cargando = true;
  List<User> _integrantes = [];

  @override
  void initState() {
    super.initState();
    context.read<AppProvider>().addListener(_onChange);
    _cargar();
  }

  void _onChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cargar();
    });
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final app = context.read<AppProvider>();
    final lista = await app.listarUsuarios();
    if (mounted) {
      setState(() {
        _integrantes = lista;
        _cargando = false;
      });
    }
  }

  @override
  void dispose() {
    context.read<AppProvider>().removeListener(_onChange);
    super.dispose();
  }

  Future<void> _nuevoUsuario() async {
    final app = context.read<AppProvider>();
    final datos = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => const _UsuarioFormDialog(),
    );
    if (datos == null || !mounted) return;
    final passNuevo = (datos['password'] as String? ?? '').trim();
    await app.crearUsuario(
      nombre: datos['nombre'] as String,
      avatar: datos['avatar'] as String? ?? '😊',
      edad: (datos['edad'] as int?) ?? 0,
      fechaNacimiento: datos['fechaNacimiento'] as DateTime?,
      colorTema: datos['colorTema'] as String? ?? '',
      password: passNuevo.isNotEmpty ? passNuevo : '1234',
      rol: (datos['rol'] as String?) ?? 'integrante',
    );
    await _cargar();
  }

  Future<void> _editarUsuario(User u) async {
    final app = context.read<AppProvider>();
    final datos = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _UsuarioFormDialog(usuario: u),
    );
    if (datos == null || !mounted) return;
    final passEdit = (datos['password'] as String? ?? '').trim();
    await app.editarUsuario(u.copyWith(
      nombre: datos['nombre'] as String,
      avatar: datos['avatar'] as String? ?? u.avatar,
      edad: (datos['edad'] as int?) ?? u.edad,
      fechaNacimiento: datos['fechaNacimiento'] as DateTime?,
      colorTema: datos['colorTema'] as String? ?? u.colorTema,
      rol: (datos['rol'] as String?) ?? u.rol,
      password: passEdit.isNotEmpty ? passEdit : u.password,
    ));
    await _cargar();
  }

  Future<void> _eliminarUsuario(User u) async {
    final app = context.read<AppProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar integrante'),
        content: Text('¿Eliminar a "${u.nombre}"? Se borrarán sus tareas y canjes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.rojo)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await app.eliminarUsuario(u.id!);
    await _cargar();
  }

  Future<void> _toggleActivo(User u) async {
    final app = context.read<AppProvider>();
    await app.setUsuarioActivo(u.id!, !u.activo);
    await _cargar();
  }

  Future<void> _castigarUsuario(User u) async {
    final app = context.read<AppProvider>();
    final motivo = TextEditingController();
    final puntos = TextEditingController(text: '10');
    var tipo = 'disciplina';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Aplicar castigo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Castigo a ${u.nombre}. Los castigos son por portarse mal '
                'o desobediencia; la quita de puntos por no cumplir tareas se '
                'genera sola al vencer.',
                style: const TextStyle(fontSize: 13, color: AppColors.grisMedio),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: motivo,
                decoration: const InputDecoration(
                  labelText: 'Motivo',
                  hintText: 'Ej: desobedeció, se portó mal',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: puntos,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Puntos a quitar'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'disciplina', child: Text('Castigo (portarse mal)')),
                  DropdownMenuItem(value: 'tarea', child: Text('Quita por tarea sin cumplir')),
                ],
                onChanged: (v) => setLocal(() => tipo = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                final pts = int.tryParse(puntos.text) ?? 0;
                final m = motivo.text.trim();
                if (pts <= 0 || m.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Escribe un motivo y puntos válidos.')),
                  );
                  return;
                }
                await app.castigarManual(
                  u.id!,
                  m,
                  pts,
                  tipo: tipo == 'tarea' ? 'tarea' : 'disciplina',
                );
                if (ctx.mounted) Navigator.pop(ctx);
                await _cargar();
              },
              child: const Text('Aplicar', style: TextStyle(color: AppColors.rojo)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetPassword(User u) async {
    final app = context.read<AppProvider>();
    final pass = TextEditingController(text: '1234');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restablecer contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nueva contraseña para ${u.nombre}:',
                style: const TextStyle(fontSize: 13, color: AppColors.grisMedio)),
            const SizedBox(height: 12),
            TextField(
              controller: pass,
              decoration: const InputDecoration(labelText: 'Contraseña'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (pass.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Restablecer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await app.cambiarPassword(u.id!, pass.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Contraseña de ${u.nombre} actualizada')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar integrantes')),
      body: Column(
        children: [
          Expanded(
            child: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _integrantes.isEmpty
              ? const EmptyState(
                  icon: Icons.group_add,
                  message: 'Aún no hay integrantes',
                  hint: 'Toca "Nuevo integrante" para agregar el primero.',
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _integrantes.length,
                    itemBuilder: (context, i) {
                      final u = _integrantes[i];
                      return DuoCard(
                        padding: EdgeInsets.zero,
                        child: Opacity(
                          opacity: u.activo ? 1 : 0.55,
                          child: ListTile(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DetailUsuarioScreen(
                                    usuarioId: u.id!),
                              ),
                            ),
                            leading: UserAvatar(user: u, radius: 22),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(u.nombre,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                ),
                                if (!u.activo) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.grisMedio
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('Inactivo',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.grisMedio)),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                                '${u.edad} años · Nivel ${u.nivel} · ${u.puntos} pts'),
                            trailing: PopupMenuButton<String>(
                              tooltip: 'Opciones',
                              onSelected: (opcion) {
                                switch (opcion) {
                                  case 'activo':
                                    _toggleActivo(u);
                                    break;
                                  case 'castigo':
                                    _castigarUsuario(u);
                                    break;
                                  case 'editar':
                                    _editarUsuario(u);
                                    break;
                                  case 'password':
                                    _resetPassword(u);
                                    break;
                                  case 'eliminar':
                                    _eliminarUsuario(u);
                                    break;
                                }
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'activo',
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    leading: Icon(
                                      u.activo
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: AppColors.grisMedio,
                                    ),
                                    title: Text(u.activo
                                        ? 'Inactivar'
                                        : 'Activar'),
                                    trailing: u.activo
                                        ? null
                                        : const Text('Inactivo',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.grisMedio)),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'castigo',
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    leading: const Icon(Icons.gavel,
                                        color: AppColors.rojo),
                                    title: const Text('Aplicar castigo'),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'editar',
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    leading: const Icon(Icons.edit,
                                        color: AppColors.azul),
                                    title: const Text('Editar'),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'password',
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    leading: const Icon(Icons.lock_reset,
                                        color: AppColors.morado),
                                    title: const Text('Restablecer contraseña'),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'eliminar',
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    leading: const Icon(Icons.delete,
                                        color: AppColors.rojo),
                                    title: const Text('Eliminar'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: DuoButton(
                label: 'Nuevo integrante',
                icon: Icons.person_add_alt,
                onPressed: _nuevoUsuario,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsuarioFormDialog extends StatefulWidget {
  final User? usuario;

  const _UsuarioFormDialog({this.usuario});

  @override
  State<_UsuarioFormDialog> createState() => _UsuarioFormDialogState();
}

class _UsuarioFormDialogState extends State<_UsuarioFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _colorTema;
  late final TextEditingController _password;
  String _rol = 'integrante';
  DateTime? _fechaNacimiento;

  @override
  void initState() {
    super.initState();
    final u = widget.usuario;
    _nombre = TextEditingController(text: u?.nombre ?? '');
    _colorTema = TextEditingController(text: u?.colorTema ?? '');
    _password = TextEditingController();
    _rol = u?.rol ?? 'integrante';
    _fechaNacimiento = u?.fechaNacimiento;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _colorTema.dispose();
    _password.dispose();
    super.dispose();
  }

  int _edadDe(DateTime? fn) {
    if (fn == null) return 0;
    final a = DateTime.now().difference(fn).inDays ~/ 365.25;
    return a < 0 ? 0 : a;
  }

  Future<void> _elegirFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _fechaNacimiento ?? DateTime.now().subtract(const Duration(days: 365 * 10)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _fechaNacimiento = picked);
  }

  @override
  Widget build(BuildContext context) {
    final edad = _edadDe(_fechaNacimiento);
    return AlertDialog(
      title: Text(widget.usuario == null ? 'Nuevo integrante' : 'Editar integrante'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              Text(
                'El avatar se genera con las iniciales y un color según el nombre.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.grisMedio),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nombre,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cake, color: AppColors.azul),
                title: Text(_fechaNacimiento == null
                    ? 'Fecha de nacimiento'
                    : 'Edad: $edad años'),
                subtitle: _fechaNacimiento == null
                    ? const Text('Toca para seleccionar')
                    : Text(
                        '${_fechaNacimiento!.day}/${_fechaNacimiento!.month}/${_fechaNacimiento!.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _elegirFecha,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _colorTema,
                decoration: const InputDecoration(labelText: 'Tema favorito'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _rol,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: const [
                  DropdownMenuItem(
                      value: 'integrante', child: Text('Hijo / Integrante')),
                  DropdownMenuItem(
                      value: 'admin', child: Text('Padre / Copadre')),
                ],
                onChanged: (v) => setState(() => _rol = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                decoration: const InputDecoration(
                    labelText: 'Contraseña (dejar vacía = 1234)'),
                obscureText: true,
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
            Navigator.pop(context, {
              'nombre': _nombre.text.trim(),
              'avatar': '',
              'edad': _edadDe(_fechaNacimiento),
              'fechaNacimiento': _fechaNacimiento,
              'colorTema': _colorTema.text.trim(),
              'rol': _rol,
              'password': _password.text.trim(),
            });
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
