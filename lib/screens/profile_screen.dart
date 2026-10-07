import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/photo_picker.dart';
import '../db/photo_store.dart';
import '../db/upload_client.dart';
import '../providers/app_provider.dart';
import 'settings_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/duo_widgets.dart';
import '../widgets/hq_design.dart';
import '../widgets/icons3d.dart';
import '../widgets/mascots.dart';
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
  String _liga = 'Bronce';

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
      _cargarLiga();
    });
  }

  Future<void> _cargarLiga() async {
    final app = context.read<AppProvider>();
    final user = app.usuarioActual;
    if (user == null) return;
    final ranking = await app.rankingSemanaAnterior();
    if (!mounted) return;
    final idx = ranking.indexWhere((e) => e.$1.id == user.id);
    setState(() {
      _liga = idx >= 0
          ? GamificationService.ligaDe(idx + 1, ranking.length)
          : 'Bronce';
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
          m.mascota == u.mascota &&
          m.racha == u.racha) {
        return;
      }
    }
    _ultimoUsuario = u;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  /// Abre la galería de mascotas y, si el niño elige una, la guarda en su
  /// perfil (se sincroniza al instante con la mascota flotante y la cabecera).
  Future<void> _elegirMascota() async {
    final app = context.read<AppProvider>();
    final user = app.usuarioActual;
    if (user == null) return;
    final actual = mascotaDeUser(user);
    final nueva = await elegirMascotaSheet(context, actual);
    if (nueva == null || nueva == actual || !mounted) return;
    await app.editarUsuario(user.copyWith(mascota: nueva.name));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();
    final user = app.usuarioActual;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AvatarCard(
                user: user,
                onCambiarFoto: user.esAdmin ? _cambiarFoto : null,
                editando: _editando,
                onEditar: () => setState(() => _editando = true),
                onAjustes: _irAjustes,
                onCerrarSesion: () => _cerrarSesion(context),
                onMascota: user.esAdmin ? null : _elegirMascota,
              ),
              const SizedBox(height: 16),
              if (_editando)
                _InfoCard(
                  user: user,
                  editando: _editando,
                  nombreController: _nombreController,
                  colorTemaController: _colorTemaController,
                  onGuardado: () => setState(() => _editando = false),
                )
              else
                _MetricasRow(user: user, liga: _liga),
              const SizedBox(height: 16),
              _MedalleroSection(user: user),
              if (user.esAdmin) ...[
                const SizedBox(height: 16),
                const Text(
                  'Canjes recientes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                _RedemptionsSection(user: user),
              ],
              if (!_editando) ...[
                const SizedBox(height: 16),
                const Text(
                  'Castigos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                _CastigosSection(userId: user.id!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _irAjustes() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Subiendo foto…')));
      final local = await PhotoStore.guardarBytes(bytes);
      final url = await UploadClient().subirFoto(bytes, mime: mime);
      if (!mounted) return;
      if (url == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Foto guardada en este dispositivo. Se subirá al tener internet.',
            ),
          ),
        );
      }
      await app.editarUsuario(
        user.copyWith(foto: url ?? user.foto, fotoLocal: local),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('¡Foto actualizada!')));
      }
    } catch (e) {
      debugPrint('Error al elegir foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo elegir la foto: ${e.toString()}')),
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

/// Cabecera de perfil: acciones solo con icono arriba a la derecha, y foto
/// centrada con el nombre y su título debajo.
class _AvatarCard extends StatelessWidget {
  final User user;
  final VoidCallback? onCambiarFoto;
  final bool editando;
  final VoidCallback onEditar;
  final VoidCallback onAjustes;
  final VoidCallback onCerrarSesion;
  final VoidCallback? onMascota;
  const _AvatarCard({
    required this.user,
    this.onCambiarFoto,
    required this.editando,
    required this.onEditar,
    required this.onAjustes,
    required this.onCerrarSesion,
    this.onMascota,
  });

  @override
  Widget build(BuildContext context) {
    final subtitulo = user.esAdmin
        ? 'Guardián del hogar'
        : '${GamificationService.nombreNivel(user.nivel)} · ${user.edad} años';
    // Los niños llevan su mascota como avatar de perfil: es interactiva
    // (salta y habla al tocarla) y da más protagonismo a su compañero.
    final mascota = mascotaDeUser(user);
    final mascotaOnTap = onMascota;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Acciones superiores: solo icono, al lado derecho de la pantalla.
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!editando) ...[
              _BotonIcono(icon: Icons.edit_outlined, onTap: onEditar),
              const SizedBox(width: 8),
            ],
            if (mascotaOnTap != null) ...[
              _BotonIcono(icon: Icons.pets, onTap: mascotaOnTap),
              const SizedBox(width: 8),
            ],
            _BotonIcono(icon: Icons.settings, onTap: onAjustes),
            const SizedBox(width: 8),
            _BotonIcono(
              icon: Icons.logout,
              color: AppColors.rojo,
              onTap: onCerrarSesion,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Foto centrada (admin) o mascota centrada (niño).
        Center(
          child: GestureDetector(
            onTap: onCambiarFoto,
            child: user.esAdmin
                ? Stack(
                    clipBehavior: Clip.none,
                    children: [
                      UserAvatar(user: user, radius: 48),
                      if (onCambiarFoto != null)
                        Positioned(
                          bottom: 0,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.fromBorderSide(
                                BorderSide(color: AppColors.linea, width: 2),
                              ),
                            ),
                            child: const Icon(
                              Icons.photo_camera,
                              color: AppColors.azul,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  )
                : MascotWidget(mascota: mascota, size: 112),
          ),
        ),
        if (!user.esAdmin) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              'NIVEL ${user.nivel}',
              style: const TextStyle(
                color: AppColors.verde,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Center(
          child: Text(
            user.nombre,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: user.esAdmin ? 22 : 24,
              fontWeight: FontWeight.w900,
              color: textoTema(context),
            ),
          ),
        ),
        Center(
          child: Text(
            subtitulo,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textoSuaveTema(context),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        if (!user.esAdmin) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Toca a ${mascota.nombre} para saludar 👆',
              style: const TextStyle(
                color: AppColors.grisMedio,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Botón de icono (sin texto) de la cabecera de perfil, con estilo
/// outlined redondeado; "Cerrar sesión" en rojo.
class _BotonIcono extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _BotonIcono({
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.grisOscuro;
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        foregroundColor: c,
        backgroundColor: Colors.white,
        side: BorderSide(color: color ?? AppColors.linea, width: 1.5),
        padding: EdgeInsets.zero,
        minimumSize: const Size(42, 42),
        maximumSize: const Size(42, 42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Fila de métricas estilo referencia: 3 MetricCard con fondo pastel
/// (XP, Racha y Liga para el niño; XP, Liga y Racha para el admin).
class _MetricasRow extends StatelessWidget {
  final User user;
  final String liga;

  const _MetricasRow({required this.user, required this.liga});

  @override
  Widget build(BuildContext context) {
    final items = user.esAdmin
        ? <(String, String, IconData, Color, Widget)>[
            (
              'XP',
              '${user.puntos}',
              Icons.bolt,
              AppColors.verdeFondo,
              Bolt3D(size: 34)
            ),
            (
              'Liga',
              liga,
              Icons.military_tech,
              AppColors.amarilloFondo,
              Medal3D(size: 34, tono: medalTonoDe(liga))
            ),
            (
              'Racha',
              '${user.racha}',
              Icons.local_fire_department,
              AppColors.rojoFondo,
              Flame3D(size: 34)
            ),
          ]
        : <(String, String, IconData, Color, Widget)>[
            (
              'XP',
              '${user.puntos}',
              Icons.bolt,
              AppColors.verdeFondo,
              Bolt3D(size: 34)
            ),
            (
              'Racha',
              '${user.racha}',
              Icons.local_fire_department,
              AppColors.rojoFondo,
              Flame3D(size: 34)
            ),
            (
              'Liga',
              liga,
              Icons.military_tech,
              AppColors.amarilloFondo,
              Medal3D(size: 34, tono: medalTonoDe(liga))
            ),
          ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: MetricCard(items[i].$1, items[i].$2, items[i].$3,
                items[i].$4,
                iconoWidget: items[i].$5),
          ),
        ],
      ],
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
      initialDate:
          _fechaNacimiento ??
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
              title: Text(
                _fechaNacimiento == null
                    ? 'Fecha de nacimiento'
                    : 'Edad: ${_edadDe(_fechaNacimiento)} años',
              ),
              subtitle: _fechaNacimiento == null
                  ? const Text('Toca para seleccionar')
                  : Text(
                      '${_fechaNacimiento!.day}/${_fechaNacimiento!.month}/${_fechaNacimiento!.year}',
                    ),
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

/// Medallero estilo referencia: título + "X de Y insignias" + rejilla de
/// tarjetas (las no logradas quedan atenuadas con candado).
class _MedalleroSection extends StatefulWidget {
  final User user;
  const _MedalleroSection({required this.user});

  @override
  State<_MedalleroSection> createState() => _MedalleroSectionState();
}

class _MedalleroSectionState extends State<_MedalleroSection> {
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

  /// Icono 3D de la insignia por su nombre de icono (sin animación en el
  /// grid para no saturar).
  Widget _iconoInsignia(String nombre, {double size = 28}) =>
      insignia3D(nombre, size: size, animar: false);

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_detalle.isEmpty) {
      return Text(
        'Completa tareas para ganar insignias.',
        style: TextStyle(color: textoSuaveTema(context)),
      );
    }
    final logradas = _detalle.where((d) => d.$4).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Insignias ($logradas de ${_detalle.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Medal3D(size: 26, tono: MedalTono.oro),
            const SizedBox(width: 4),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final d in _detalle)
              Opacity(
                opacity: d.$4 ? 1 : 0.4,
                child: CardBox(
                  margin: EdgeInsets.zero,
                  color: d.$4 ? AppColors.amarilloFondo : AppColors.fondo,
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _iconoInsignia(d.$1.icono, size: 28),
                      const SizedBox(height: 4),
                      Text(
                        d.$1.nombre,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
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
    final canjes = widget.user.id != null
        ? await app.canjesDe(widget.user.id!)
        : <(Redemption, Reward)>[];
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
      return Text(
        'Aún no se ha canjeado ninguna recompensa.',
        style: TextStyle(color: textoSuaveTema(context)),
      );
    }

    return Column(
      children: [
        for (final (canje, recompensa) in _canjes)
          CardBox(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.verdeFondo,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.card_giftcard,
                    color: AppColors.verdeOscuro,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recompensa.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${canje.fecha.day}/${canje.fecha.month}/${canje.fecha.year}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: textoSuaveTema(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '-${recompensa.costoPuntos} pts',
                  style: const TextStyle(
                    color: AppColors.rojo,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ],
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

    if (_castigos.isEmpty) {
      return const CardBox(
        color: AppColors.rojoFondo,
        child: Text(
          'Sin castigos activos. ¡Sigue así, lo estás haciendo genial!',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.grisOscuro,
          ),
        ),
      );
    }

    final disciplina = _castigos.where((c) => c.esDisciplina).take(5).toList();
    final tareas = _castigos.where((c) => c.esTarea).take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_puntosSemana > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Chip(
              label: Text('-$_puntosSemana pts esta semana'),
              backgroundColor: AppColors.rojoFondo,
              labelStyle: const TextStyle(
                color: AppColors.rojo,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        for (final c in [...tareas, ...disciplina])
          CardBox(
            color: AppColors.rojoFondo,
            child: Text(
              '${c.motivo} · ${c.fecha.day}/${c.fecha.month} · '
              '−${c.puntos} pts',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.grisOscuro,
              ),
            ),
          ),
      ],
    );
  }
}

