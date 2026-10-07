import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user.dart';
import '../theme/app_theme.dart';

/// Las 16 mascotas de HogarQuest. Son el avatar interactivo de cada
/// integrante: se dibujan con CustomPainter (estilo trazo grueso redondeado),
/// reaccionan al tocarlas con salto, chispas y frases, y el niño puede
/// elegir la suya desde su perfil.
enum MascotType {
  escobin,
  gotita,
  burbu,
  chispita,
  esponjita,
  peludito,
  lunardo,
  pepita,
  robito,
  flamina,
  sushito,
  nubecita,
  meloncito,
  piquito,
  gatito,
  dragito,
}

/// Frases sociales compartidas: la mascota conversa más allá de su temática.
const List<String> _frasesSociales = [
  '¡Me encanta ser tu amiguito! 🐾',
  '¡Tú y yo somos un equipo! 🤝',
  '¡Hoy vamos a ganar juntos! 🏆',
  '¡Gracias por cuidarme! 🥰',
  '¿Jugamos cuando termines? 🎮',
  '¡Eres mi persona favorita! 💛',
  '¡Eres increíble, en serio! 🌟',
  '¡Nunca te rindas! 💪',
];

extension MascotTypeX on MascotType {
  String get nombre => switch (this) {
    MascotType.escobin => 'Escobín',
    MascotType.gotita => 'Gotita',
    MascotType.burbu => 'Burbu',
    MascotType.chispita => 'Chispita',
    MascotType.esponjita => 'Esponjita',
    MascotType.peludito => 'Peludito',
    MascotType.lunardo => 'Lunardo',
    MascotType.pepita => 'Pepita',
    MascotType.robito => 'Robito',
    MascotType.flamina => 'Flamina',
    MascotType.sushito => 'Sushito',
    MascotType.nubecita => 'Nubecita',
    MascotType.meloncito => 'Meloncito',
    MascotType.piquito => 'Piquito',
    MascotType.gatito => 'Gatito',
    MascotType.dragito => 'Dragito',
  };

  Color get color => switch (this) {
    MascotType.escobin => const Color(0xFF10B981),
    MascotType.gotita => const Color(0xFF3B82F6),
    MascotType.burbu => const Color(0xFF8B5CF6),
    MascotType.chispita => const Color(0xFFF59E0B),
    MascotType.esponjita => const Color(0xFFEF4444),
    MascotType.peludito => const Color(0xFFEAB308),
    MascotType.lunardo => const Color(0xFF60A5FA),
    MascotType.pepita => const Color(0xFF22C55E),
    MascotType.robito => const Color(0xFF0EA5E9),
    MascotType.flamina => const Color(0xFFF472B6),
    MascotType.sushito => const Color(0xFFFB923C),
    MascotType.nubecita => const Color(0xFF64748B),
    MascotType.meloncito => const Color(0xFF16A34A),
    MascotType.piquito => const Color(0xFFF97316),
    MascotType.gatito => const Color(0xFFA78BFA),
    MascotType.dragito => const Color(0xFF10B981),
  };

  /// Frases cortas al interactuar. Se rotan (y se intercalan con las
  /// frases sociales) para que la conversación nunca se sienta repetitiva.
  List<String> get frases => switch (this) {
    MascotType.escobin => [
      '¡A barrer se dijo! 🧹',
      '¡Un polvito más y brillamos! ✨',
      '¡Con paso firme! 💪',
      '¡El orden es tuyo! 🏠',
      '¡Deja la habitación reluciente! 🌟',
      '¡Escoba en mano, ánimo! 😄',
    ],
    MascotType.gotita => [
      '¡Limpio como el agua! 💧',
      '¡Chapuzón de jabón! 🫧',
      '¡Brilla con todo! ✨',
      '¡Ni una manchita! 💙',
      '¡Cuchi-cuchi con la esponja! 🛁',
      '¡A enjuagar y a brillar! 🌈',
    ],
    MascotType.burbu => [
      '¡Hazlo burbujear! ✨',
      '¡Festín de pompas! 🫧',
      '¡A brillar se ha dicho! 💜',
      '¡Tú puedes, campeón! 🙌',
      '¡Mil pompas de alegría! 🎈',
      '¡A revez, que es más divertido! 😜',
    ],
    MascotType.chispita => [
      '¡Falta una chispa! ⚡',
      '¡Enciéndete! 🔥',
      '¡Vamos con todo! 💛',
      '¡Eres imparable! 🚀',
      '¡Zas! ¡Otra tarea lista! 💥',
      '¡Energía a tope! ⚡',
    ],
    MascotType.esponjita => [
      '¡Friega con ganas! 🧽',
      '¡Un chapuzón más! 🫧',
      '¡A relucir! ✨',
      '¡Tú contra la mugre! 💪',
      '¡Ni el más difícil me resisto! 🫠',
      '¡Seca y a brillar! 🌞',
    ],
    MascotType.peludito => [
      '¡Abrazo de oso! 🧸',
      '¡Mimos y tareas! 💛',
      '¡Te cuido yo! 🐻',
      '¡A listo y sin prisa! 🐾',
      '¡Dormilón a la carga! 😴',
      '¡Contigo estoy siempre! 🤗',
    ],
    MascotType.lunardo => [
      '¡Buenas noches y a brillar! 🌙',
      '¡Luna llena de ganas! 🌕',
      '¡A descansar mañana! 😴',
      '¡Sueña con tareas hechas! 💫',
      '¡La noche es nuestra! 🌌',
      '¡Susurro de luna! 🌜',
    ],
    MascotType.pepita => [
      '¡Crece como yo! 🌱',
      '¡Riega tus sueños! 💦',
      '¡Un día a la vez! 🌿',
      '¡Brote de campeón! 🌻',
      '¡Raíces fuertes, corazón verde! 💚',
      '¡Florecerás hoy! 🌸',
    ],
    MascotType.robito => [
      '¡Procesando... ¡listo! 🤖',
      '¡Cálculo: tú puedes! 🧮',
      '¡Bip bip, a por ello! 🔋',
      '¡Modo campeón activado! 🚀',
      '¡Mi circuito te quiere! 💛',
      '¡Datos de éxito cargados! 📊',
    ],
    MascotType.flamina => [
      '¡Florece con alegría! 🌸',
      '¡Pétalos de energía! 🌺',
      '¡Huele a victoria! 🌷',
      '¡Brilla como una flor! 🌼',
      '¡Miércoles de flores! 💐',
      '¡Semilla de grandeza! 🌻',
    ],
    MascotType.sushito => [
      '¡Rollo de ganas! 🍣',
      '¡Algo rico y a estudiar! 🍱',
      '¡Bocado de energía! 🥢',
      '¡Wasabi de ánimo! 🌶️',
      '¡Delicado y fuerte! 😋',
      '¡Un bocado más! 🍚',
    ],
    MascotType.nubecita => [
      '¡Nubecita de alegría! ☁️',
      '¡Pensamiento esponjoso! 💭',
      '¡Lluvia de ideas! 🌦️',
      '¡Sueños en volumen! 🌈',
      '¡Flotando de feliz! 😊',
      '¡Tormenta de aplausos! ⛈️',
    ],
    MascotType.meloncito => [
      '¡Refresca y adelante! 🍉',
      '¡Dulce como tú! 🍬',
      '¡Verano de ganas! 😎',
      '¡Semillas de éxito! ✨',
      '¡Un cachito de felicidad! 😄',
      '¡Pa pa pa, qué rico! 🎶',
    ],
    MascotType.piquito => [
      '¡Pío pío, a por todas! 🐦',
      '¡Canta tu victoria! 🎵',
      '¡Pico afilado y a volar! 🪶',
      '¡Nido de campeones! 🥚',
      '¡Migajas de gloria! 🌾',
      '¡Volando alto! 🦅',
    ],
    MascotType.gatito => [
      '¡Miau, tú puedes! 🐱',
      '¡Ronroneo de éxito! 😺',
      '¡Bola de peluche! 🧶',
      '¡Toca la tecla ganadora! 🎹',
      '¡Mimos y deberes! 🐾',
      '¡A roncar y a ganar! 😽',
    ],
    MascotType.dragito => [
      '¡Fuego de dragón! 🐉',
      '¡Ardiente de ganas! 🔥',
      '¡Escamas de campeón! 🛡️',
      '¡Vuela, pequeño dragón! 🌋',
      '¡Roar de victoria! 😤',
      '¡Corazón de fuego! ❤️‍🔥',
    ],
  };

  /// Primera frase (la que se muestra por defecto).
  String get frase => frases.first;
}

/// Mascota elegida por el usuario; si no ha elegido, una estable según su id.
MascotType mascotaDeUser(User u) {
  for (final m in MascotType.values) {
    if (m.name == u.mascota) return m;
  }
  final seed = u.id ?? u.nombre.hashCode;
  return MascotType.values[seed % MascotType.values.length];
}

/// Avatar de mascota interactivo: CustomPaint + salto con estiramiento,
/// chispas de color y frase en globo. El globo vive DENTRO de un Stack de
/// tamaño fijo, así que nunca desplaza la pantalla al aparecer.
class MascotWidget extends StatefulWidget {
  final MascotType mascota;
  final double size;
  final bool interactivo;

  /// Animación de flote continuo (para la mascota flotante que acompaña
  /// al usuario entre vistas).
  final bool flotante;

  /// Se invoca en cada toque con la frase que acaba de decir.
  final ValueChanged<String>? onInteract;

  /// Mensaje persistente del globo (asistente contextual). Mientras esté
  /// activo se muestra todo el tiempo; al tocar la mascota aparece una
  /// frase temporal y después vuelve este mensaje.
  final String? globo;

  const MascotWidget({
    super.key,
    required this.mascota,
    this.size = 140,
    this.interactivo = true,
    this.flotante = false,
    this.onInteract,
    this.globo,
  });

  @override
  State<MascotWidget> createState() => _MascotWidgetState();
}

class _MascotWidgetState extends State<MascotWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _salto;
  late final Animation<double> _escalaY;
  late final AnimationController _bob;
  bool _hablando = false;
  bool _chispas = false;
  int _i = 0;
  bool _social = false;

  String get _fraseActual => _social
      ? _frasesSociales[_i % _frasesSociales.length]
      : widget.mascota.frases[_i % widget.mascota.frases.length];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    // Salto con estiramiento: sube, se estira, aterriza aplastando y
    // rebota un pelín. Todo dentro de su caja: no mueve la pantalla.
    _salto = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -0.14), weight: 40),
      TweenSequenceItem(tween: Tween(begin: -0.14, end: 0), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 0, end: -0.03), weight: 15),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _escalaY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 0.90), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.90, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    if (widget.flotante) _bob.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _bob.dispose();
    super.dispose();
  }

  void _interactuar() {
    if (!widget.interactivo) return;
    HapticFeedback.lightImpact();
    _ctrl.forward(from: 0);
    final rnd = math.Random();
    // Frase aleatoria distinta de la anterior; alterna entre su temática y
    // una frase social, para que la mascota se sienta más conversadora.
    final lista = widget.mascota.frases;
    var n = _i;
    while (n == _i && lista.length > 1) {
      n = rnd.nextInt(lista.length);
    }
    final social = rnd.nextBool();
    setState(() {
      _i = social ? rnd.nextInt(_frasesSociales.length) : n;
      _social = social;
      _hablando = true;
      _chispas = true;
    });
    widget.onInteract?.call(_fraseActual);
    Future<void>.delayed(const Duration(milliseconds: 750), () {
      if (mounted) setState(() => _chispas = false);
    });
    Future<void>.delayed(const Duration(seconds: 1, milliseconds: 800), () {
      if (mounted) setState(() => _hablando = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final mostrarGlobo = _hablando || widget.globo != null;
    final textoGlobo = _hablando ? _fraseActual : (widget.globo ?? '');
    // Ancho fijo del globo: siempre centrado sobre la mascota y creciendo
    // HACIA ARRIBA desde su borde inferior (sin alterar el layout).
    final anchoGlobo = math.max(176.0, size + 40.0);
    return GestureDetector(
      onTap: _interactuar,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([_ctrl, _bob]),
              builder: (context, _) {
                final flote = widget.flotante ? (_bob.value * 8 - 4) : 0.0;
                final lift = _salto.value * size + flote;
                final sy = _escalaY.value;
                final sx = 2 - sy;
                return Transform.translate(
                  offset: Offset(0, lift),
                  child: Transform.scale(
                    scaleX: sx,
                    scaleY: sy,
                    alignment: Alignment.bottomCenter,
                    child: CustomPaint(
                      size: Size(size, size),
                      painter: _MascotPainter(widget.mascota),
                    ),
                  ),
                );
              },
            ),
            if (_chispas)
              Positioned.fill(
                child: CustomPaint(
                  painter: _ChispasPainter(_ctrl.value, widget.mascota.color),
                ),
              ),
            if (mostrarGlobo)
              Positioned(
                bottom: size + 6,
                left: (size - anchoGlobo) / 2,
                right: (size - anchoGlobo) / 2,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _Globo(
                    mascota: widget.mascota,
                    frase: textoGlobo,
                    tooltip: '${widget.mascota.nombre}: $textoGlobo',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Chispas/corazones que brotan al tocar la mascota, con el color de ella.
class _ChispasPainter extends CustomPainter {
  final double t;
  final Color color;
  _ChispasPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final w = size.width;
    final h = size.height;
    final rnd = math.Random(7);
    final paint = Paint();
    for (var i = 0; i < 8; i++) {
      final ang = -math.pi / 2 + (rnd.nextDouble() - 0.5) * 2.4;
      final dist = (0.18 + 0.40 * t) * w;
      final p = Offset(
        w / 2 + math.cos(ang) * dist,
        h * 0.55 + math.sin(ang) * dist - t * h * 0.16,
      );
      final alpha = ((1 - t) * 255).clamp(0, 255).toInt();
      final esCorazon = i % 3 == 0;
      if (esCorazon) {
        paint.color = Color.fromARGB(alpha, 0xF8, 0x71, 0x71);
        final r = w * 0.035 * (1 - t * 0.4);
        canvas.drawCircle(p + Offset(-r * 0.55, -r * 0.3), r, paint);
        canvas.drawCircle(p + Offset(r * 0.55, -r * 0.3), r, paint);
        final tri = Path()
          ..moveTo(p.dx - r * 1.1, p.dy - r * 0.1)
          ..lineTo(p.dx + r * 1.1, p.dy - r * 0.1)
          ..lineTo(p.dx, p.dy + r * 1.3)
          ..close();
        canvas.drawPath(tri, paint);
      } else {
        paint.color = color.withAlpha(alpha);
        final r = w * (0.020 + 0.014 * (1 - t));
        canvas.drawCircle(p, r, paint);
        // Destello de4 puntas.
        final star = Path()
          ..moveTo(p.dx, p.dy - r * 2.4)
          ..quadraticBezierTo(p.dx + r * 0.3, p.dy - r * 0.3,
              p.dx + r * 2.4, p.dy)
          ..quadraticBezierTo(p.dx + r * 0.3, p.dy + r * 0.3,
              p.dx, p.dy + r * 2.4)
          ..quadraticBezierTo(p.dx - r * 0.3, p.dy + r * 0.3,
              p.dx - r * 2.4, p.dy)
          ..quadraticBezierTo(p.dx - r * 0.3, p.dy - r * 0.3,
              p.dx, p.dy - r * 2.4)
          ..close();
        canvas.drawPath(star, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ChispasPainter old) => old.t != t || old.color != color;
}

/// Globo de diálogo: fijo dentro del Stack de la mascota.
class _Globo extends StatelessWidget {
  final MascotType mascota;
  final String frase;
  final String tooltip;

  const _Globo({
    required this.mascota,
    required this.frase,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: mascota.color, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x22000000), offset: Offset(0, 2)),
          ],
        ),
        child: Text(
          frase,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: mascota.color,
          ),
        ),
      ),
    );
  }
}

/// Selector de mascota: bottom sheet con la galería completa.
/// Devuelve la mascota elegida (o null si se cancela).
Future<MascotType?> elegirMascotaSheet(
  BuildContext context,
  MascotType actual,
) {
  return showModalBottomSheet<MascotType>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(sheetContext).size.height * 0.78,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.linea,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Elige tu mascota',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              'Toca una para hacerla tu compañero',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.grisMedio,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth > 560 ? 5 : 4;
                  final ancho = constraints.maxWidth / cols;
                  return GridView.count(
                    crossAxisCount: cols,
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: ancho / 118,
                    children: [
                      for (final m in MascotType.values)
                        _CeldaMascota(
                          tipo: m,
                          seleccionada: m == actual,
                          onTap: () => Navigator.of(sheetContext).pop(m),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CeldaMascota extends StatelessWidget {
  final MascotType tipo;
  final bool seleccionada;
  final VoidCallback onTap;
  const _CeldaMascota({
    required this.tipo,
    required this.seleccionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: seleccionada
              ? AppColors.amarilloFondo
              : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: seleccionada ? AppColors.amarillo : AppColors.linea,
            width: seleccionada ? 2.5 : 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MascotWidget(
              mascota: tipo,
              size: 58,
              interactivo: false,
            ),
            const SizedBox(height: 2),
            Text(
              tipo.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dibuja cada mascota con trazo grueso redondeado y cara común.
class _MascotPainter extends CustomPainter {
  final MascotType mascota;

  _MascotPainter(this.mascota);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 220;
    switch (mascota) {
      case MascotType.escobin:
        _pintarEscobin(canvas, s);
      case MascotType.gotita:
        _pintarGotita(canvas, s);
      case MascotType.burbu:
        _pintarBurbu(canvas, s);
      case MascotType.chispita:
        _pintarChispita(canvas, s);
      case MascotType.esponjita:
        _pintarEsponjita(canvas, s);
      case MascotType.peludito:
        _pintarPeludito(canvas, s);
      case MascotType.lunardo:
        _pintarLunardo(canvas, s);
      case MascotType.pepita:
        _pintarPepita(canvas, s);
      case MascotType.robito:
        _pintarRobito(canvas, s);
      case MascotType.flamina:
        _pintarFlamina(canvas, s);
      case MascotType.sushito:
        _pintarSushito(canvas, s);
      case MascotType.nubecita:
        _pintarNubecita(canvas, s);
      case MascotType.meloncito:
        _pintarMeloncito(canvas, s);
      case MascotType.piquito:
        _pintarPiquito(canvas, s);
      case MascotType.gatito:
        _pintarGatito(canvas, s);
      case MascotType.dragito:
        _pintarDragito(canvas, s);
    }
  }

  Paint _trazo() => Paint()
    ..color = const Color(0xFF0F172A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint _relleno(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  /// Dos ojos grandes, centrados en [c] con escala [e].
  void _ojos(Canvas canvas, double s, Offset c, double e) {
    canvas.drawCircle(
      c + Offset(-18 * s * e, -8 * s * e),
      5 * s * e,
      _relleno(const Color(0xFF0F172A)),
    );
    canvas.drawCircle(
      c + Offset(18 * s * e, -8 * s * e),
      5 * s * e,
      _relleno(const Color(0xFF0F172A)),
    );
  }

  /// Cara común: dos ojos y una sonrisa, centrada en [c] con escala [e].
  void _cara(Canvas canvas, double s, Offset c, double e) {
    _ojos(canvas, s, c, e);
    final smile = Path()
      ..moveTo(c.dx - 14 * s * e, c.dy + 6 * s * e)
      ..quadraticBezierTo(
        c.dx,
        c.dy + 16 * s * e,
        c.dx + 14 * s * e,
        c.dy + 6 * s * e,
      );
    canvas.drawPath(smile, _trazo());
  }

  void _pintarEscobin(Canvas canvas, double s) {
    final madera = Paint()..color = const Color(0xFFB45309);
    final cerda = _relleno(const Color(0xFF10B981));
    final stroke = _trazo();

    final paloRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(110 * s, 52 * s),
        width: 12 * s,
        height: 80 * s,
      ),
      Radius.circular(6 * s),
    );
    canvas.drawRRect(paloRect, madera);
    canvas.drawRRect(paloRect, stroke);

    final headPath = Path()
      ..moveTo(58 * s, 108 * s)
      ..cubicTo(88 * s, 94 * s, 132 * s, 94 * s, 162 * s, 108 * s)
      ..lineTo(178 * s, 186 * s)
      ..cubicTo(142 * s, 202 * s, 78 * s, 202 * s, 42 * s, 186 * s)
      ..close();
    canvas.drawPath(headPath, cerda);
    canvas.drawPath(headPath, stroke);

    _cara(canvas, s, Offset(110 * s, 148 * s), 1);

    for (double x in [58, 88, 110, 132, 162]) {
      canvas.drawLine(
        Offset(x * s, 192 * s),
        Offset(x * s + (x < 110 ? -3 * s : (x > 110 ? 3 * s : 0)), 212 * s),
        stroke,
      );
    }
  }

  void _pintarGotita(Canvas canvas, double s) {
    final azul = _relleno(const Color(0xFF3B82F6));
    final stroke = _trazo();
    final gota = Path()
      ..moveTo(110 * s, 34 * s)
      ..cubicTo(160 * s, 92 * s, 172 * s, 122 * s, 172 * s, 150 * s)
      ..arcToPoint(
        Offset(48 * s, 150 * s),
        radius: Radius.circular(62 * s),
        clockwise: true,
      )
      ..arcToPoint(
        Offset(110 * s, 34 * s),
        radius: Radius.circular(62 * s),
        clockwise: true,
      )
      ..close();
    canvas.drawPath(gota, azul);
    canvas.drawPath(gota, stroke);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(78 * s, 104 * s),
        width: 22 * s,
        height: 30 * s,
      ),
      _relleno(const Color(0x22FFFFFF)),
    );
    _cara(canvas, s, Offset(110 * s, 156 * s), 0.9);
  }

  void _pintarBurbu(Canvas canvas, double s) {
    final violeta = _relleno(const Color(0xFF8B5CF6));
    final stroke = _trazo();
    canvas.drawCircle(Offset(110 * s, 120 * s), 88 * s, violeta);
    canvas.drawCircle(Offset(110 * s, 120 * s), 88 * s, stroke);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(70 * s, 68 * s),
        width: 34 * s,
        height: 20 * s,
      ),
      _relleno(const Color(0x44FFFFFF)),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(158 * s, 92 * s),
        width: 16 * s,
        height: 10 * s,
      ),
      _relleno(const Color(0x2FFFFFFF)),
    );
    _cara(canvas, s, Offset(110 * s, 130 * s), 1);
  }

  void _pintarChispita(Canvas canvas, double s) {
    final amarillo = _relleno(const Color(0xFFF59E0B));
    final stroke = _trazo();
    final centro = Offset(110 * s, 120 * s);
    final estrella = Path();
    const n = 8;
    for (var i = 0; i < n * 2; i++) {
      final radio = i.isEven ? 90 * s : 42 * s;
      final angulo = (i * math.pi / (n / 2));
      final p =
          centro + Offset(math.cos(angulo) * radio, math.sin(angulo) * radio);
      if (i == 0) {
        estrella.moveTo(p.dx, p.dy);
      } else {
        estrella.lineTo(p.dx, p.dy);
      }
    }
    estrella.close();
    canvas.drawPath(estrella, amarillo);
    canvas.drawPath(estrella, stroke);
    _cara(canvas, s, centro, 0.9);
  }

  void _pintarEsponjita(Canvas canvas, double s) {
    final rosa = _relleno(const Color(0xFFEF4444));
    final poro = _relleno(const Color(0x33FFFFFF));
    final stroke = _trazo();
    final cuerpo = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(110 * s, 128 * s),
        width: 128 * s,
        height: 100 * s,
      ),
      Radius.circular(18 * s),
    );
    canvas.drawRRect(cuerpo, rosa);
    canvas.drawRRect(cuerpo, stroke);
    canvas.drawCircle(Offset(76 * s, 84 * s), 8 * s, poro);
    canvas.drawCircle(Offset(110 * s, 72 * s), 7 * s, poro);
    canvas.drawCircle(Offset(144 * s, 84 * s), 8 * s, poro);
    canvas.drawCircle(Offset(82 * s, 160 * s), 7 * s, poro);
    canvas.drawCircle(Offset(138 * s, 160 * s), 7 * s, poro);
    _cara(canvas, s, Offset(110 * s, 120 * s), 1);
  }

  void _pintarPeludito(Canvas canvas, double s) {
    final oso = _relleno(const Color(0xFFEAB308));
    final orejaInt = _relleno(const Color(0xFFFDE68A));
    final stroke = _trazo();

    // Orejas.
    for (final c in [Offset(56 * s, 56 * s), Offset(164 * s, 56 * s)]) {
      canvas.drawCircle(c, 30 * s, oso);
      canvas.drawCircle(c, 30 * s, stroke);
      canvas.drawCircle(c, 15 * s, orejaInt);
    }

    // Cabeza peluda.
    final cabeza = Path();
    const n = 14;
    for (var i = 0; i < n * 2; i++) {
      final radio = i.isEven ? 86 * s : 78 * s;
      final angulo = -math.pi / 2 + i * math.pi / n;
      final p = Offset(110 * s, 128 * s) +
          Offset(math.cos(angulo) * radio, math.sin(angulo) * radio);
      if (i == 0) {
        cabeza.moveTo(p.dx, p.dy);
      } else {
        cabeza.lineTo(p.dx, p.dy);
      }
    }
    cabeza.close();
    canvas.drawPath(cabeza, oso);
    canvas.drawPath(cabeza, stroke);

    _cara(canvas, s, Offset(110 * s, 126 * s), 1);
    // Nariz.
    canvas.drawCircle(
      Offset(110 * s, 146 * s),
      6 * s,
      _relleno(const Color(0xFF0F172A)),
    );
  }

  void _pintarLunardo(Canvas canvas, double s) {
    final luna = _relleno(const Color(0xFF93C5FD));
    final stroke = _trazo();
    final path = Path()
      ..moveTo(160 * s, 34 * s)
      ..quadraticBezierTo(62 * s, 44 * s, 42 * s, 132 * s)
      ..quadraticBezierTo(24 * s, 214 * s, 130 * s, 204 * s)
      ..quadraticBezierTo(84 * s, 158 * s, 96 * s, 104 * s)
      ..quadraticBezierTo(118 * s, 58 * s, 160 * s, 34 * s)
      ..close();
    canvas.drawPath(path, luna);
    canvas.drawPath(path, stroke);
    // Cráteres.
    canvas.drawCircle(
      Offset(74 * s, 96 * s),
      9 * s,
      _relleno(const Color(0x332563EB)),
    );
    canvas.drawCircle(
      Offset(72 * s, 168 * s),
      7 * s,
      _relleno(const Color(0x332563EB)),
    );
    _cara(canvas, s, Offset(92 * s, 132 * s), 0.85);
  }

  void _pintarPepita(Canvas canvas, double s) {
    final hoja = _relleno(const Color(0xFF10B981));
    final hojaClara = _relleno(const Color(0xFF4ADE80));
    final tierra = _relleno(const Color(0xFF92400E));
    final stroke = _trazo();

    // Tallo.
    canvas.drawLine(
      Offset(110 * s, 160 * s),
      Offset(110 * s, 74 * s),
      Paint()
        ..color = const Color(0xFF15803D)
        ..strokeWidth = 10 * s
        ..strokeCap = StrokeCap.round,
    );

    // Hojas.
    canvas.save();
    canvas.translate(74 * s, 84 * s);
    canvas.rotate(-0.55);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 74 * s, height: 40 * s),
      hoja,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 74 * s, height: 40 * s),
      stroke,
    );
    canvas.restore();
    canvas.save();
    canvas.translate(150 * s, 68 * s);
    canvas.rotate(0.5);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 78 * s, height: 42 * s),
      hojaClara,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 78 * s, height: 42 * s),
      stroke,
    );
    canvas.restore();

    // Bulbo de tierra.
    final bulbo = Path()
      ..moveTo(44 * s, 166 * s)
      ..quadraticBezierTo(46 * s, 208 * s, 110 * s, 208 * s)
      ..quadraticBezierTo(174 * s, 208 * s, 176 * s, 166 * s)
      ..close();
    canvas.drawPath(bulbo, tierra);
    canvas.drawPath(bulbo, stroke);
    // Briznas de tierra.
    canvas.drawCircle(
      Offset(76 * s, 184 * s),
      5 * s,
      _relleno(const Color(0xFFB45309)),
    );
    canvas.drawCircle(
      Offset(146 * s, 182 * s),
      5 * s,
      _relleno(const Color(0xFFB45309)),
    );
    _cara(canvas, s, Offset(110 * s, 178 * s), 0.8);
  }

  void _pintarRobito(Canvas canvas, double s) {
    final azul = _relleno(const Color(0xFF60A5FA));
    final azulOsc = _relleno(const Color(0xFF0369A1));
    final gris = _relleno(const Color(0xFF94A3B8));
    final stroke = _trazo();

    // Antena.
    canvas.drawLine(
      Offset(110 * s, 64 * s),
      Offset(110 * s, 38 * s),
      Paint()
        ..color = const Color(0xFF0F172A)
        ..strokeWidth = 5 * s
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(110 * s, 30 * s), 12 * s, _relleno(const Color(0xFFFACC15)));
    canvas.drawCircle(Offset(110 * s, 30 * s), 12 * s, stroke);

    // Orejas laterales.
    for (final r in [
      RRect.fromRectAndRadius(
        Rect.fromLTWH(22 * s, 96 * s, 24 * s, 56 * s),
        Radius.circular(8 * s),
      ),
      RRect.fromRectAndRadius(
        Rect.fromLTWH(174 * s, 96 * s, 24 * s, 56 * s),
        Radius.circular(8 * s),
      ),
    ]) {
      canvas.drawRRect(r, azulOsc);
      canvas.drawRRect(r, stroke);
    }

    // Cuerpo/base.
    final base = RRect.fromRectAndRadius(
      Rect.fromLTWH(70 * s, 186 * s, 80 * s, 26 * s),
      Radius.circular(10 * s),
    );
    canvas.drawRRect(base, gris);
    canvas.drawRRect(base, stroke);

    // Cabeza.
    final cabeza = RRect.fromRectAndRadius(
      Rect.fromLTWH(36 * s, 62 * s, 148 * s, 128 * s),
      Radius.circular(30 * s),
    );
    canvas.drawRRect(cabeza, azul);
    canvas.drawRRect(cabeza, stroke);
    // Brillo de pantalla.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(48 * s, 74 * s, 34 * s, 20 * s),
        Radius.circular(10 * s),
      ),
      _relleno(const Color(0x55FFFFFF)),
    );

    _cara(canvas, s, Offset(110 * s, 124 * s), 1);
  }

  void _pintarFlamina(Canvas canvas, double s) {
    final petalo = _relleno(const Color(0xFFF472B6));
    final stroke = _trazo();
    final centro = Offset(110 * s, 116 * s);

    // Pétalos.
    for (var i = 0; i < 6; i++) {
      final ang = -math.pi / 2 + i * math.pi / 3;
      final p =
          centro + Offset(math.cos(ang) * 60 * s, math.sin(ang) * 60 * s);
      canvas.drawCircle(p, 38 * s, petalo);
      canvas.drawCircle(p, 38 * s, stroke);
    }

    // Centro.
    canvas.drawCircle(centro, 42 * s, _relleno(const Color(0xFFFACC15)));
    canvas.drawCircle(centro, 42 * s, stroke);
    // Polen.
    for (var i = 0; i < 5; i++) {
      final ang = i * math.pi * 2 / 5 + 0.4;
      canvas.drawCircle(
        centro + Offset(math.cos(ang) * 24 * s, math.sin(ang) * 24 * s),
        4 * s,
        _relleno(const Color(0xFFD97706)),
      );
    }

    _cara(canvas, s, centro, 0.85);
  }

  void _pintarSushito(Canvas canvas, double s) {
    final stroke = _trazo();

    // Arroz.
    final arroz = RRect.fromRectAndRadius(
      Rect.fromLTWH(34 * s, 138 * s, 152 * s, 62 * s),
      Radius.circular(28 * s),
    );
    canvas.drawRRect(arroz, _relleno(const Color(0xFFFFFBF2)));
    canvas.drawRRect(arroz, stroke);

    // Salmón.
    final salmon = RRect.fromRectAndRadius(
      Rect.fromLTWH(38 * s, 92 * s, 144 * s, 60 * s),
      Radius.circular(26 * s),
    );
    canvas.drawRRect(salmon, _relleno(const Color(0xFFFB923C)));
    canvas.drawRRect(salmon, stroke);
    // Vetas.
    final veta = Paint()
      ..color = const Color(0xFFFFE4C7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(56 * s, 132 * s), Offset(164 * s, 132 * s), veta);
    canvas.drawLine(Offset(70 * s, 110 * s), Offset(154 * s, 110 * s), veta);

    _cara(canvas, s, Offset(110 * s, 166 * s), 0.85);
  }

  void _pintarNubecita(Canvas canvas, double s) {
    final stroke = _trazo();
    final nube = Path()
      ..moveTo(46 * s, 172 * s)
      ..quadraticBezierTo(20 * s, 168 * s, 28 * s, 142 * s)
      ..quadraticBezierTo(32 * s, 116 * s, 62 * s, 120 * s)
      ..quadraticBezierTo(70 * s, 82 * s, 108 * s, 88 * s)
      ..quadraticBezierTo(142 * s, 72 * s, 158 * s, 106 * s)
      ..quadraticBezierTo(192 * s, 110 * s, 186 * s, 140 * s)
      ..quadraticBezierTo(200 * s, 166 * s, 170 * s, 172 * s)
      ..close();
    canvas.drawPath(nube, _relleno(const Color(0xFFF1F5F9)));
    canvas.drawPath(nube, stroke);
    _cara(canvas, s, Offset(110 * s, 136 * s), 1);
    // Colita de nube.
    canvas.drawLine(
      Offset(150 * s, 172 * s),
      Offset(158 * s, 196 * s),
      Paint()
        ..color = const Color(0xFF0F172A)
        ..strokeWidth = 5 * s
        ..strokeCap = StrokeCap.round,
    );
  }

  void _pintarMeloncito(Canvas canvas, double s) {
    final stroke = _trazo();

    // Corteza.
    final corteza = Path()
      ..moveTo(32 * s, 158 * s)
      ..arcToPoint(
        Offset(188 * s, 158 * s),
        radius: Radius.circular(78 * s),
        clockwise: false,
      )
      ..close();
    canvas.drawPath(corteza, _relleno(const Color(0xFF22C55E)));
    canvas.drawPath(corteza, stroke);

    // Pulpa.
    final pulpa = Path()
      ..moveTo(50 * s, 156 * s)
      ..arcToPoint(
        Offset(170 * s, 156 * s),
        radius: Radius.circular(60 * s),
        clockwise: false,
      )
      ..close();
    canvas.drawPath(pulpa, _relleno(const Color(0xFFEF4444)));
    canvas.drawPath(pulpa, stroke);

    // Semillas.
    for (final o in [
      Offset(76 * s, 128 * s),
      Offset(142 * s, 126 * s),
      Offset(110 * s, 96 * s),
      Offset(64 * s, 148 * s),
      Offset(156 * s, 148 * s),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(center: o, width: 6 * s, height: 10 * s),
        _relleno(const Color(0xFF0F172A)),
      );
    }
    _cara(canvas, s, Offset(110 * s, 134 * s), 0.8);
  }

  void _pintarPiquito(Canvas canvas, double s) {
    final stroke = _trazo();

    // Plumas de la cabeza.
    final plumon = Paint()
      ..color = const Color(0xFFEA580C)
      ..strokeWidth = 6 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(104 * s, 44 * s), Offset(94 * s, 20 * s), plumon);
    canvas.drawLine(Offset(118 * s, 42 * s), Offset(126 * s, 16 * s), plumon);

    // Cuerpo.
    final cuerpo = Rect.fromCenter(
      center: Offset(110 * s, 138 * s),
      width: 144 * s,
      height: 116 * s,
    );
    canvas.drawOval(cuerpo, _relleno(const Color(0xFFFB923C)));
    canvas.drawOval(cuerpo, stroke);

    // Ala.
    canvas.save();
    canvas.translate(84 * s, 152 * s);
    canvas.rotate(-0.35);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 64 * s, height: 44 * s),
      _relleno(const Color(0xFFEA580C)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 64 * s, height: 44 * s),
      stroke,
    );
    canvas.restore();

    // Pico.
    final pico = Path()
      ..moveTo(176 * s, 120 * s)
      ..lineTo(210 * s, 138 * s)
      ..lineTo(176 * s, 156 * s)
      ..close();
    canvas.drawPath(pico, _relleno(const Color(0xFFFACC15)));
    canvas.drawPath(pico, stroke);

    _ojos(canvas, s, Offset(104 * s, 116 * s), 0.95);
    // Sonrisa pequeña tras el pico.
    canvas.drawPath(
      Path()
        ..moveTo(96 * s, 134 * s)
        ..quadraticBezierTo(
            106 * s, 144 * s, 118 * s, 136 * s),
      _trazo(),
    );
  }

  void _pintarGatito(Canvas canvas, double s) {
    final gato = _relleno(const Color(0xFFA78BFA));
    final stroke = _trazo();

    // Orejas.
    final orejaIzq = Path()
      ..moveTo(42 * s, 44 * s)
      ..lineTo(94 * s, 66 * s)
      ..lineTo(46 * s, 104 * s)
      ..close();
    final orejaDer = Path()
      ..moveTo(178 * s, 44 * s)
      ..lineTo(126 * s, 66 * s)
      ..lineTo(174 * s, 104 * s)
      ..close();
    canvas.drawPath(orejaIzq, gato);
    canvas.drawPath(orejaIzq, stroke);
    canvas.drawPath(orejaDer, gato);
    canvas.drawPath(orejaDer, stroke);
    canvas.drawPath(
      Path()
        ..moveTo(56 * s, 60 * s)
        ..lineTo(82 * s, 72 * s)
        ..lineTo(60 * s, 90 * s)
        ..close(),
      _relleno(const Color(0xFFF9A8D4)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(164 * s, 60 * s)
        ..lineTo(138 * s, 72 * s)
        ..lineTo(160 * s, 90 * s)
        ..close(),
      _relleno(const Color(0xFFF9A8D4)),
    );

    // Cabeza.
    canvas.drawCircle(Offset(110 * s, 126 * s), 80 * s, gato);
    canvas.drawCircle(Offset(110 * s, 126 * s), 80 * s, stroke);

    // Bigotes.
    final bigote = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 3 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(34 * s, 122 * s), Offset(4 * s, 112 * s), bigote);
    canvas.drawLine(Offset(34 * s, 138 * s), Offset(4 * s, 148 * s), bigote);
    canvas.drawLine(Offset(186 * s, 122 * s), Offset(216 * s, 112 * s), bigote);
    canvas.drawLine(Offset(186 * s, 138 * s), Offset(216 * s, 148 * s), bigote);

    _cara(canvas, s, Offset(110 * s, 122 * s), 1);
    // Nariz.
    canvas.drawPath(
      Path()
        ..moveTo(103 * s, 138 * s)
        ..lineTo(117 * s, 138 * s)
        ..lineTo(110 * s, 147 * s)
        ..close(),
      _relleno(const Color(0xFFEC4899)),
    );
  }

  void _pintarDragito(Canvas canvas, double s) {
    final drag = _relleno(const Color(0xFF34D399));
    final cuerno = _relleno(const Color(0xFFFDE68A));
    final stroke = _trazo();

    // Cuernos.
    for (final p in [
      Path()
        ..moveTo(62 * s, 66 * s)
        ..lineTo(84 * s, 24 * s)
        ..lineTo(100 * s, 64 * s)
        ..close(),
      Path()
        ..moveTo(110 * s, 52 * s)
        ..lineTo(142 * s, 22 * s)
        ..lineTo(148 * s, 60 * s)
        ..close(),
    ]) {
      canvas.drawPath(p, cuerno);
      canvas.drawPath(p, stroke);
    }

    // Hocico.
    final hocico = Rect.fromCenter(
      center: Offset(168 * s, 146 * s),
      width: 84 * s,
      height: 62 * s,
    );
    canvas.drawOval(hocico, drag);
    canvas.drawOval(hocico, stroke);

    // Cabeza.
    canvas.drawCircle(Offset(94 * s, 122 * s), 72 * s, drag);
    canvas.drawCircle(Offset(94 * s, 122 * s), 72 * s, stroke);

    // Fosas nasales.
    canvas.drawCircle(
      Offset(184 * s, 136 * s),
      4 * s,
      _relleno(const Color(0xFF065F46)),
    );
    canvas.drawCircle(
      Offset(196 * s, 150 * s),
      4 * s,
      _relleno(const Color(0xFF065F46)),
    );

    _cara(canvas, s, Offset(116 * s, 116 * s), 0.9);
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) =>
      oldDelegate.mascota != mascota;
}
