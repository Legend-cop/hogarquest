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
    if (mounted) _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final app = context.read<AppProvider>();
    final lista = await app.listarIntegrantes();
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
    await app.crearUsuario(
      nombre: datos['nombre'] as String,
      avatar: datos['avatar'] as String? ?? '😊',
      edad: (datos['edad'] as int?) ?? 0,
      colorTema: datos['colorTema'] as String? ?? '',
      password: (datos['password'] as String?) ?? '1234',
      rol: 'integrante',
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
    await app.editarUsuario(u.copyWith(
      nombre: datos['nombre'] as String,
      avatar: datos['avatar'] as String? ?? u.avatar,
      edad: (datos['edad'] as int?) ?? u.edad,
      colorTema: datos['colorTema'] as String? ?? u.colorTema,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar integrantes')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _integrantes.isEmpty
              ? const EmptyState(
                  icon: Icons.group_add,
                  message: 'Aún no hay integrantes',
                  hint: 'Toca el botón + para agregar el primero.',
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
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    u.activo
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: AppColors.grisMedio,
                                  ),
                                  tooltip: u.activo
                                      ? 'Inactivar'
                                      : 'Activar',
                                  onPressed: () => _toggleActivo(u),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.gavel,
                                      color: AppColors.rojo),
                                  tooltip: 'Aplicar castigo',
                                  onPressed: () => _castigarUsuario(u),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: AppColors.azul),
                                  onPressed: () => _editarUsuario(u),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: AppColors.rojo),
                                  onPressed: () => _eliminarUsuario(u),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _nuevoUsuario,
        backgroundColor: AppColors.verde,
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add_alt),
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
  late final TextEditingController _edad;
  late final TextEditingController _colorTema;

  @override
  void initState() {
    super.initState();
    final u = widget.usuario;
    _nombre = TextEditingController(text: u?.nombre ?? '');
    _edad = TextEditingController(text: u?.edad.toString() ?? '');
    _colorTema = TextEditingController(text: u?.colorTema ?? '');
  }

  @override
  void dispose() {
    _nombre.dispose();
    _edad.dispose();
    _colorTema.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              TextFormField(
                controller: _edad,
                decoration: const InputDecoration(labelText: 'Edad'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _colorTema,
                decoration: const InputDecoration(labelText: 'Tema favorito'),
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
              'edad': int.tryParse(_edad.text) ?? 0,
              'colorTema': _colorTema.text.trim(),
            });
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
