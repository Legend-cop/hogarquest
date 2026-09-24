import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/photo_picker.dart';
import '../db/photo_store.dart';
import '../db/upload_client.dart';
import '../providers/app_provider.dart';
import 'settings_screen.dart';
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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nombreController = TextEditingController();
  final _colorTemaController = TextEditingController();
  bool _editando = false;
  User? _ultimoUsuario;
  AppProvider? _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _provider = context.read<AppProvider>();
      _provider!.addListener(_onChange);
      final user = _provider!.usuarioActual;
      if (user != null) {
        _nombreController.text = user.nombre;
        _colorTemaController.text = user.colorTema;
        _ultimoUsuario = user;
      }
    });
  }

  @override
  void dispose() {
    _provider?.removeListener(_onChange);
    _nombreController.dispose();
    _colorTemaController.dispose();
    super.dispose();
  }

  void _onChange() {
    final app = context.read<AppProvider>();
    final u = app.usuarioActual;
    if (u != null && _ultimoUsuario != null) {
      final m = _ultimoUsuario!;
      if (m.nombre == u.nombre &&
          m.foto == u.foto &&
          m.fotoLocal == u.fotoLocal &&
          m.puntos == u.puntos &&
          m.nivel == u.nivel &&
          m.racha == u.racha) {
        return;
      }
    }
    _ultimoUsuario = u;
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
        title: const Text('Perfil del integrante'),
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A3B1D),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    offset: Offset(0, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: _AvatarCard(user: user, onCambiarFoto: _cambiarFoto),
            ),
            const SizedBox(height: 20),
            if (_editando)
              _InfoCard(
                user: user,
                editando: _editando,
                nombreController: _nombreController,
                colorTemaController: _colorTemaController,
                onGuardado: () => setState(() => _editando = false),
              )
            else
              _StatsGrid(user: user),
            const SizedBox(height: 20),
            const Divider(),
            SectionHeader(title: 'Medallero de insignias'),
            _InsigniasSection(user: user),
            const SizedBox(height: 20),
            SectionHeader(title: 'Canjes recientes'),
            _RedemptionsSection(user: user),
            const SizedBox(height: 20),
            _CastigosSection(userId: user.id!),
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
              fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
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
              color: Colors.white70, fontWeight: FontWeight.w700),
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


/// Rejilla 2×2 de estadísticas del integrante (Nivel, Racha, XP, Edad).
class _StatsGrid extends StatelessWidget {
  final User user;
  const _StatsGrid({required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.military_tech,
                label: 'Nivel',
                valor: '${user.nivel}',
                color: AppColors.amarillo,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                icon: Icons.local_fire_department,
                label: 'Racha',
                valor: '${user.racha} días',
                color: AppColors.rojo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.star,
                label: 'Puntos XP',
                valor: '${user.puntos}',
                color: AppColors.azul,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                icon: Icons.cake,
                label: 'Edad',
                valor: '${user.edad} años',
                color: AppColors.morado,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valor;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.superficieOscura : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? AppColors.grisMedio.withValues(alpha: 0.3)
              : AppColors.linea,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000), offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            valor,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: textoTema(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textoSuaveTema(context),
            ),
          ),
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
    return const SizedBox.shrink();
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
      return Text('Completa tareas para ganar insignias.',
          style: TextStyle(color: textoSuaveTema(context)));
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logradas = _detalle.where((d) => d.$4).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '$logradas de ${_detalle.length} logradas',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: textoSuaveTema(context),
            ),
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (final d in _detalle)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: d.$4
                          ? AppColors.amarillo
                          : (isDark ? Colors.white10 : AppColors.linea),
                      boxShadow: d.$4
                          ? [
                              BoxShadow(
                                color:
                                    AppColors.amarillo.withValues(alpha: 0.45),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      _icono(d.$1.icono),
                      size: 26,
                      color: d.$4 ? Colors.white : textoSuaveTema(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 68,
                    child: Text(
                      d.$1.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),
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
                          style: TextStyle(
                              color: textoSuaveTema(context), fontSize: 12)),
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
                        style: TextStyle(
                            color: textoSuaveTema(context), fontSize: 12),
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
      return Text('Aún no se ha canjeado ninguna recompensa.',
          style: TextStyle(color: textoSuaveTema(context)));
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
            Text('Castigos y quitas',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textoTema(context))),
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
          Text('Sin castigos ni quitas. ¡Sigue así! 🎉',
              style: TextStyle(color: textoSuaveTema(context), fontSize: 13))
        else ...[
          if (tareas.isNotEmpty) ...[
            Text('Por tareas sin cumplir',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: textoSuaveTema(context))),
            ...tareas.map((c) => _fila(c, Icons.event_busy, Colors.orange)),
            const SizedBox(height: 8),
          ],
          if (disciplina.isNotEmpty) ...[
            Text('Castigos (disciplina)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: textoSuaveTema(context))),
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