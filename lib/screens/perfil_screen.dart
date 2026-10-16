import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/photo_picker.dart';
import '../db/photo_store.dart';
import '../db/upload_client.dart';
import '../providers/app_provider.dart';
import 'ajustes_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/duo_widgets.dart';
import '../widgets/hq_design.dart';
import '../widgets/icono3d.dart';
import '../widgets/icons3d.dart';
import '../widgets/insignia_parche.dart';
import '../widgets/mascots.dart';
import '../widgets/user_avatar.dart';
import '../models/user.dart';
import '../models/badge.dart' as badge_model;
import '../models/assignment.dart';
import '../models/castigo.dart';
import '../models/task.dart';
import '../services/gamification_service.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
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

  /// Liga del usuario: depende de sus puntos acumulados (escalera de 20).
  void _cargarLiga() {
    final user = context.read<AppProvider>().usuarioActual;
    if (user == null) return;
    setState(() => _liga = GamificationService.ligaDe(user.puntos));
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
    // El admin elige entre sus 4 mascotas exclusivas (todas disponibles y
    // sin requisitos); los integrantes usan el sistema de desbloqueo.
    if (user.esAdmin) {
      if (!mounted) return;
      final nueva = await elegirMascotaSheet(
        context,
        actual,
        desbloqueadas: mascotasSoloAdmin,
        visibles: mascotasSoloAdmin,
        nivel: 0,
        puntos: 0,
        tareas: 0,
        insignias: 0,
      );
      if (nueva == null || nueva == actual || !mounted) return;
      await app.editarUsuario(user.copyWith(mascota: nueva.name));
      return;
    }
    final nivel = GamificationService.nivelPara(user.puntos);
    final historial = await app.historialDe(user.id!);
    final insignias = await app.insigniasDe(user.id!);
    if (!mounted) return;
    final tareas = historial.length;
    final nInsignias = insignias.length;
    final desbloqueadas = mascotasDesbloqueadas(
      nivel: nivel,
      puntos: user.puntos,
      tareas: tareas,
      insignias: nInsignias,
    );
    final nueva = await elegirMascotaSheet(
      context,
      actual,
      desbloqueadas: desbloqueadas,
      nivel: nivel,
      puntos: user.puntos,
      tareas: tareas,
      insignias: nInsignias,
    );
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReferenciaTitulo(
                user.esAdmin
                    ? 'TU CUARTEL GENERAL'
                    : 'PERFIL DE ${user.nombre.toUpperCase()}',
                'Mi perfil',
                icono: Icono3DTipo.persona,
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: azulFondoTema(context),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _AvatarCard(
                  user: user,
                  onCambiarFoto: user.esAdmin ? _cambiarFoto : null,
                  editando: _editando,
                  onEditar: () => setState(() => _editando = true),
                  onAjustes: _irAjustes,
                  onCerrarSesion: () => _cerrarSesion(context),
                  onMascota: _elegirMascota,
                ),
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
              if (!user.esAdmin && !_editando) ...[
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
      MaterialPageRoute(builder: (_) => const AjustesScreen()),
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
          DialogActions(
            onCancel: () => Navigator.pop(ctx, false),
            primary: DuoButton(
              fullWidth: false,
              color: AppColors.rojo,
              borderColor: AppColors.rojoOscuro,
              onPressed: () => Navigator.pop(ctx, true),
              label: 'Salir',
            ),
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
        ? 'Administrador del Hogar'
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
                : MascotWidget(mascota: mascota, size: 112, flotante: true),
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
  const _BotonIcono({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? textoTema(context);
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        foregroundColor: c,
        backgroundColor: superficieTema(context),
        side: BorderSide(
          color: color ??
              (esOscuro(context) ? Colors.white24 : AppColors.linea),
          width: 1.5,
        ),
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
              verdeFondoTema(context),
              Bolt3D(size: 34),
            ),
            (
              'Liga',
              liga,
              Icons.military_tech,
              amarilloFondoTema(context),
              Medal3D(size: 34, tono: medalTonoDe(liga)),
            ),
            (
              'Racha',
              '${user.racha}',
              Icons.local_fire_department,
              rojoFondoTema(context),
              Flame3D(size: 34, racha: user.racha),
            ),
          ]
        : <(String, String, IconData, Color, Widget)>[
            (
              'XP',
              '${user.puntos}',
              Icons.bolt,
              verdeFondoTema(context),
              Bolt3D(size: 34),
            ),
            (
              'Racha',
              '${user.racha}',
              Icons.local_fire_department,
              rojoFondoTema(context),
              Flame3D(size: 34, racha: user.racha),
            ),
            (
              'Liga',
              liga,
              Icons.military_tech,
              amarilloFondoTema(context),
              Medal3D(size: 34, tono: medalTonoDe(liga)),
            ),
          ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: MetricCard(
              items[i].$1,
              items[i].$2,
              items[i].$3,
              items[i].$4,
              iconoWidget: items[i].$5,
            ),
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
    final logradas = _detalle.where((d) => d.$4).toList();
    final faltantes = _detalle.where((d) => !d.$4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Insignias (${logradas.length} de ${_detalle.length})',
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
        const SizedBox(height: 10),
        // Dos carruseles horizontales: arriba las logradas, abajo las que
        // faltan por completar (así el perfil no queda eterno de scroll).
        _filaCarrusel(
          titulo: 'Logradas',
          items: logradas,
          vacio: 'Aún no has ganado insignias. ¡Sigue así!',
        ),
        const SizedBox(height: 16),
        _filaCarrusel(
          titulo: 'Por conseguir',
          items: faltantes,
          vacio: '¡Ya las tienes todas! 🏆',
        ),
      ],
    );
  }

  /// Fila horizontal con scroll de parches de insignia (carrusel).
  Widget _filaCarrusel({
    required String titulo,
    required List<(badge_model.Badge, int, int, bool)> items,
    required String vacio,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            '$titulo (${items.length})',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              vacio,
              style: TextStyle(fontSize: 12, color: textoSuaveTema(context)),
            ),
          )
        else
          SizedBox(
            height: 122,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final d = items[i];
                return SizedBox(
                  width: 92,
                  child: CardBox(
                    margin: EdgeInsets.zero,
                    color: d.$4
                        ? amarilloFondoTema(context)
                        : superficieTema(context),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    child: Center(
                      child: InsigniaParche(
                        icono: d.$1.icono,
                        nombre: d.$1.nombre,
                        lograda: d.$4,
                        actual: d.$2,
                        meta: d.$3,
                        size: 66,
                      ),
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

  /// Filtro por días: 7, 30 o 0 = todo el historial.
  int _dias = 7;
  bool _expandido = false;

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
        _castigos = castigos;
        _puntosSemana = puntos;
        _cargando = false;
      });
    }
  }

  /// Castigos del periodo seleccionado, del más reciente al más antiguo.
  List<Castigo> get _filtrados {
    final corte = _dias <= 0
        ? null
        : DateTime.now().subtract(Duration(days: _dias));
    final lista = _castigos
        .where((c) => corte == null || !c.fecha.isBefore(corte))
        .toList();
    lista.sort((a, b) => b.fecha.compareTo(a.fecha));
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_castigos.isEmpty) {
      return CardBox(
        color: rojoFondoTema(context),
        child: Text(
          'Sin castigos activos. ¡Sigue así, lo estás haciendo genial!',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: textoTema(context),
          ),
        ),
      );
    }

    final lista = _filtrados;
    final visibles = _expandido ? lista : lista.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filtro por días: evita que la lista alargue demasiado el perfil.
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final (valor, etiqueta) in const [
              (7, '7 días'),
              (30, '30 días'),
              (0, 'Todo'),
            ])
              ChoiceChip(
                label: Text(etiqueta),
                selected: _dias == valor,
                onSelected: (_) => setState(() {
                  _dias = valor;
                  _expandido = false;
                }),
                selectedColor: rojoFondoTema(context),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _dias == valor
                      ? (esOscuro(context)
                          ? Colors.redAccent
                          : AppColors.rojo)
                      : textoSuaveTema(context),
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
        if (_puntosSemana > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Chip(
              label: Text('-$_puntosSemana pts esta semana'),
              backgroundColor: rojoFondoTema(context),
              labelStyle: TextStyle(
                color: esOscuro(context) ? Colors.redAccent : AppColors.rojo,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          )
        else
          const SizedBox(height: 8),
        if (lista.isEmpty)
          CardBox(
            color: rojoFondoTema(context),
            child: Text(
              'Sin castigos en este periodo. 🎉',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: textoTema(context),
              ),
            ),
          )
        else ...[
          for (final c in visibles)
            CardBox(
              color: rojoFondoTema(context),
              child: Text(
                '${c.motivo} · ${c.fecha.day}/${c.fecha.month} · '
                '−${c.puntos} pts',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: textoTema(context),
                ),
              ),
            ),
          if (lista.length > 6)
            TextButton(
              onPressed: () => setState(() => _expandido = !_expandido),
              child: Text(
                _expandido
                    ? 'Ver menos'
                    : 'Ver los ${lista.length} castigos',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ],
    );
  }
}
