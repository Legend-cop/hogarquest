import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user.dart';
import '../theme/app_theme.dart';

/// Las mascotas de HogarQuest. Son el avatar interactivo de cada
/// integrante: se dibujan con CustomPainter (estilo trazo grueso redondeado),
/// reaccionan al tocarlas con salto, chispas y frases, y el niño puede
/// elegir la suya desde su perfil. Las 16 primeras son las clásicas; las
/// siguientes 5 (aurón, fénix, dori, cósmo y rex) son las EXCLUSIVAS de los
/// integrantes: se desbloquean con requisitos difíciles. Las 4 últimas
/// (búho-mago, rey, robot guardián y dino dorado) son SOLO del admin.
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
  auron,
  fenix,
  dori,
  cosmo,
  rex,
  // Exclusivas del administrador: no las puede elegir ningún integrante.
  buhomago,
  rey,
  robotguardian,
  dinodoro,
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
    MascotType.auron => 'Aurón',
    MascotType.fenix => 'Fénix',
    MascotType.dori => 'Dori',
    MascotType.cosmo => 'Cosmo',
    MascotType.rex => 'Rex',
    MascotType.buhomago => 'Merlín',
    MascotType.rey => 'Rey Hogar',
    MascotType.robotguardian => 'Centinela',
    MascotType.dinodoro => 'Áureo',
  };

  /// Color representativo de cada mascota. Sincronizado con el color con el
  /// que se pinta su cuerpo (globo, borde de celda y selección usan este).
  Color get color => switch (this) {
    MascotType.escobin => const Color(0xFF10B981),
    MascotType.gotita => const Color(0xFF3B82F6),
    MascotType.burbu => const Color(0xFF8B5CF6),
    MascotType.chispita => const Color(0xFFF59E0B),
    MascotType.esponjita => const Color(0xFFEF4444),
    MascotType.peludito => const Color(0xFFEAB308),
    MascotType.lunardo => const Color(0xFF93C5FD),
    MascotType.pepita => const Color(0xFF4ADE80),
    MascotType.robito => const Color(0xFF60A5FA),
    MascotType.flamina => const Color(0xFFF472B6),
    MascotType.sushito => const Color(0xFFFB923C),
    MascotType.nubecita => const Color(0xFF94A3B8),
    MascotType.meloncito => const Color(0xFF22C55E),
    MascotType.piquito => const Color(0xFFEA580C),
    MascotType.gatito => const Color(0xFFA78BFA),
    MascotType.dragito => const Color(0xFF34D399),
    MascotType.auron => const Color(0xFFC4B5FD),
    MascotType.fenix => const Color(0xFFF97316),
    MascotType.dori => const Color(0xFF38BDF8),
    MascotType.cosmo => const Color(0xFF94A3B8),
    MascotType.rex => const Color(0xFF22C55E),
    MascotType.buhomago => const Color(0xFF8B5CF6),
    MascotType.rey => const Color(0xFFF59E0B),
    MascotType.robotguardian => const Color(0xFF06B6D4),
    MascotType.dinodoro => const Color(0xFFFACC15),
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
    MascotType.auron => [
      '¡Mágico y valiente! 🦄',
      '¡Brillo con mi cuerno! ✨',
      '¡Arcoíris de victoria! 🌈',
      '¡Puro amor y magia! 💜',
      '¡Volamos alto! 🪽',
      '¡Eres única! 🌟',
    ],
    MascotType.fenix => [
      '¡Renaceré más fuerte! 🔥',
      '¡Alas de fuego! 🦅',
      '¡Siempre me levanto! 💪',
      '¡Luz que nunca se apaga! ✨',
      '¡Vuelo del fénix! 🌅',
      '¡Imparable! 🏆',
    ],
    MascotType.dori => [
      '¡Nadando a la victoria! 🐬',
      '¡Salta conmigo! 🌊',
      '¡El mar es tuyo! 🌊',
      '¡Agua y diversión! 💧',
      '¡Rápido como el mar! ⚡',
      '¡Sigue la corriente! 🌀',
    ],
    MascotType.cosmo => [
      '¡Rumbo a las estrellas! 🚀',
      '¡Misión cumplida! 🌍',
      '¡Explorador espacial! 👨‍🚀',
      '¡Gravedad cero! 🪐',
      '¡Ad astra! ⭐',
      '¡El espacio te espera! 🌌',
    ],
    MascotType.rex => [
      '¡Grrr de campeón! 🦕',
      '¡Pisotón de victoria! 👣',
      '¡Dinosaurio gigante! 🌿',
      '¡Rugido épico! 🔊',
      '¡Fuerza prehistórica! 💥',
      '¡Rey del jurásico! 👑',
    ],
    MascotType.buhomago => [
      '¡La sabios guía el hogar! 🦉',
      '¡Un hechizo de orden! ✨',
      '¡Con sabiduría y calma! 🧙',
      '¡El saber es poder! 📚',
      '¡Mi sabiduría es tuya! 🔮',
      '¡Todo lo veo! 👀',
    ],
    MascotType.rey => [
      '¡Por el reino del hogar! 👑',
      '¡Decreto orden total! 🏰',
      '¡La corona manda! ✨',
      '¡Viva la familia! 🎉',
      '¡Reinar es servir! ⚜️',
      '¡Nobleza obliga! 🛡️',
    ],
    MascotType.robotguardian => [
      '¡Guardián activado! 🤖',
      '¡Escudos en línea! 🛡️',
      '¡Protección total! ⚡',
      '¡Análisis completado! 📡',
      '¡Cuidando la misión! 🚀',
      '¡Modo guardián! 🔒',
    ],
    MascotType.dinodoro => [
      '¡El jefe dorado llegó! 🦖',
      '¡Pisotón de oro! ✨',
      '¡Corona de dinosaurio! 👑',
      '¡Rugido dorado! 🏆',
      '¡El rey prehistórico! 🌟',
      '¡Poder dorado total! 💛',
    ],
  };

  /// Primera frase (la que se muestra por defecto).
  String get frase => frases.first;
}

/// Mascotas reservadas al administrador: ningún integrante puede verlas ni
/// elegirlas.
const Set<MascotType> mascotasSoloAdmin = {
  MascotType.buhomago,
  MascotType.rey,
  MascotType.robotguardian,
  MascotType.dinodoro,
};

/// Mascota del usuario. El admin siempre tiene una de las suyas (Merlín por
/// defecto); los integrantes jamás caen en una mascota de admin.
MascotType mascotaDeUser(User u) {
  for (final m in MascotType.values) {
    if (m.name == u.mascota) {
      if (u.esAdmin) return mascotasSoloAdmin.contains(m) ? m : MascotType.buhomago;
      return mascotasSoloAdmin.contains(m) ? _inicialDe(u) : m;
    }
  }
  return u.esAdmin ? MascotType.buhomago : _inicialDe(u);
}

/// Mascota inicial (siempre desbloqueada) de un integrante.
MascotType _inicialDe(User u) {
  const iniciales = [MascotType.escobin, MascotType.gotita, MascotType.pepita];
  final seed = u.id ?? u.nombre.hashCode;
  return iniciales[seed % iniciales.length];
}

/// Requisitos de desbloqueo de una mascota (combinación de nivel, puntos,
/// tareas aprobadas e insignias). 0 = sin requisito en esa categoría.
class RequisitosMascota {
  final int nivel;
  final int puntos;
  final int tareas;
  final int insignias;
  const RequisitosMascota({
    this.nivel = 0,
    this.puntos = 0,
    this.tareas = 0,
    this.insignias = 0,
  });

  bool seCumple({
    required int nivelActual,
    required int puntosActuales,
    required int tareasActuales,
    required int insigniasActuales,
  }) =>
      nivelActual >= nivel &&
      puntosActuales >= puntos &&
      tareasActuales >= tareas &&
      insigniasActuales >= insignias;

  /// Descripción de lo que falta (para el candado de las bloqueadas).
  String faltante({
    required int nivelActual,
    required int puntosActuales,
    required int tareasActuales,
    required int insigniasActuales,
  }) {
    final faltan = <String>[];
    if (nivelActual < nivel) faltan.add('Nivel $nivel');
    if (puntosActuales < puntos) faltan.add('$puntos pts');
    if (tareasActuales < tareas) faltan.add('$tareas tareas');
    if (insigniasActuales < insignias) faltan.add('$insignias insignias');
    return faltan.join(' · ');
  }
}

/// Requisitos por mascota. Tres arrancan desde el inicio; trece se
/// desbloquean progresivamente; cinco (aurón, fénix, dori, cósmo y rex) son
/// las EXCLUSIVAS, con los requisitos más exigentes de todas.
const Map<MascotType, RequisitosMascota> requisitosMascotas = {
  // Iniciales (sin requisitos).
  MascotType.escobin: RequisitosMascota(),
  MascotType.gotita: RequisitosMascota(),
  MascotType.pepita: RequisitosMascota(),
  // Progresivas.
  MascotType.gatito: RequisitosMascota(nivel: 2, tareas: 5),
  MascotType.burbu: RequisitosMascota(nivel: 2, puntos: 100),
  MascotType.chispita: RequisitosMascota(nivel: 3, tareas: 10),
  MascotType.esponjita: RequisitosMascota(tareas: 15),
  MascotType.peludito: RequisitosMascota(nivel: 3, puntos: 250),
  MascotType.lunardo: RequisitosMascota(nivel: 4, tareas: 20),
  MascotType.nubecita: RequisitosMascota(nivel: 4, puntos: 500),
  MascotType.robito: RequisitosMascota(tareas: 25, insignias: 2),
  MascotType.flamina: RequisitosMascota(nivel: 4, puntos: 400, tareas: 20),
  MascotType.sushito: RequisitosMascota(nivel: 4, puntos: 450, insignias: 3),
  MascotType.meloncito: RequisitosMascota(tareas: 30, insignias: 3),
  MascotType.piquito: RequisitosMascota(nivel: 4, puntos: 500, tareas: 25),
  MascotType.dragito:
      RequisitosMascota(nivel: 5, puntos: 800, tareas: 40, insignias: 4),
  // Exclusivas (5): los diseños nuevos, las más difíciles.
  MascotType.auron: RequisitosMascota(nivel: 5, puntos: 700, tareas: 30, insignias: 4),
  MascotType.fenix: RequisitosMascota(nivel: 5, puntos: 850, tareas: 35, insignias: 5),
  MascotType.dori: RequisitosMascota(nivel: 5, puntos: 900, tareas: 40, insignias: 5),
  MascotType.cosmo: RequisitosMascota(nivel: 5, puntos: 1000, tareas: 45, insignias: 6),
  MascotType.rex:
      RequisitosMascota(nivel: 5, puntos: 1200, tareas: 55, insignias: 7),
};

/// Requisitos de una mascota (por defecto, sin requisitos).
RequisitosMascota requisitosDe(MascotType m) =>
    requisitosMascotas[m] ?? const RequisitosMascota();

/// Conjunto de mascotas desbloqueadas dadas las estadísticas del usuario.
Set<MascotType> mascotasDesbloqueadas({
  required int nivel,
  required int puntos,
  required int tareas,
  required int insignias,
}) {
  return {
    for (final m in MascotType.values)
      if (requisitosDe(m).seCumple(
        nivelActual: nivel,
        puntosActuales: puntos,
        tareasActuales: tareas,
        insigniasActuales: insignias,
      ))
        m,
  };
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

  /// Etiqueta del botón de acción del globo (ej. "Ir a Tareas"). Requiere
  /// [onGloboAccion] para que el toque navegue a la vista sugerida.
  final String? globoAccion;

  /// Se invoca al pulsar el botón de acción del globo (el padre debe
  /// ocultar el globo tras navegar).
  final VoidCallback? onGloboAccion;

  const MascotWidget({
    super.key,
    required this.mascota,
    this.size = 140,
    this.interactivo = true,
    this.flotante = false,
    this.onInteract,
    this.globo,
    this.globoAccion,
    this.onGloboAccion,
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
    // El globo nunca desborda el ancho de la mascota: se limita a su
    // tamaño para no tapar texto o tarjetas vecinas.
    final anchoGlobo = size;
    // Zona reservada ARRIBA de la mascota para el globo con botón: solo el
    // compañero de navegación (con consejo/botón) la necesita. En Flutter
    // un RenderBox no reparte toques a sus hijos fuera de su tamaño, así
    // que sin esta zona el botón "Ir →" jamás recibiría el toque; el
    // picker/perfil/empty_state (sin globo) no cambian de layout.
    final tieneCompanero = widget.globo != null || widget.onGloboAccion != null;
    final zonaGlobo = tieneCompanero ? (size * 0.9).clamp(56.0, 88.0) : 0.0;
    return SizedBox(
      width: size,
      height: size + zonaGlobo,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Mascota: su propio GestureDetector (toque = saludar/saltar).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: size,
            child: GestureDetector(
              onTap: _interactuar,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedBuilder(
                    animation: Listenable.merge([_ctrl, _bob]),
                    builder: (context, _) {
                      final flote = widget.flotante
                          ? (_bob.value * 8 - 4)
                          : 0.0;
                      final lift = _salto.value * size + flote;
                      final sy = _escalaY.value;
                      final sx = 2 - sy;
                      return Transform.translate(
                        offset: Offset(0, lift),
                        child: Transform.scale(
                          scaleX: sx,
                          scaleY: sy,
                          alignment: Alignment.bottomCenter,
                          // ClipRect: el pintor nunca pinta fuera de su caja (bigotes,
                          // hocicos o el salto no invaden tarjetas vecinas).
                          child: ClipRect(
                            child: CustomPaint(
                              size: Size(size, size),
                              painter: _MascotPainter(widget.mascota),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (_chispas)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ChispasPainter(
                          _ctrl.value,
                          widget.mascota.color,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Globo: hermano del área de la mascota (nadie lo envuelve por
          // fuera), así su botón sí recibe toques. Entra y sale con fade.
          Positioned(
            bottom: size + 6,
            left: (size - anchoGlobo) / 2,
            right: (size - anchoGlobo) / 2,
            child: IgnorePointer(
              ignoring: !mostrarGlobo,
              child: AnimatedOpacity(
                opacity: mostrarGlobo ? 1 : 0,
                duration: Duration(
                  milliseconds:
                      MediaQuery.disableAnimationsOf(context) ? 0 : 260,
                ),
                curve: Curves.easeOutCubic,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _Globo(
                    mascota: widget.mascota,
                    frase: textoGlobo,
                    tooltip: '${widget.mascota.nombre}: $textoGlobo',
                    // El botón de acción solo acompaña al consejo
                    // contextual, no a la frase del toque.
                    accion: _hablando ? null : widget.globoAccion,
                    onAccion: _hablando ? null : widget.onGloboAccion,
                  ),
                ),
              ),
            ),
          ),
        ],
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
          ..quadraticBezierTo(
            p.dx + r * 0.3,
            p.dy - r * 0.3,
            p.dx + r * 2.4,
            p.dy,
          )
          ..quadraticBezierTo(
            p.dx + r * 0.3,
            p.dy + r * 0.3,
            p.dx,
            p.dy + r * 2.4,
          )
          ..quadraticBezierTo(
            p.dx - r * 0.3,
            p.dy + r * 0.3,
            p.dx - r * 2.4,
            p.dy,
          )
          ..quadraticBezierTo(
            p.dx - r * 0.3,
            p.dy - r * 0.3,
            p.dx,
            p.dy - r * 2.4,
          )
          ..close();
        canvas.drawPath(star, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ChispasPainter old) => old.t != t || old.color != color;
}

/// Globo de diálogo: fijo dentro del Stack de la mascota. Puede llevar un
/// botón de acción ("Ir a Tareas") que el padre convierte en navegación.
class _Globo extends StatelessWidget {
  final MascotType mascota;
  final String frase;
  final String tooltip;
  final String? accion;
  final VoidCallback? onAccion;

  const _Globo({
    required this.mascota,
    required this.frase,
    required this.tooltip,
    this.accion,
    this.onAccion,
  });

  @override
  Widget build(BuildContext context) {
    final tieneAccion = accion != null && onAccion != null;
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              frase,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: mascota.color,
              ),
            ),
            if (tieneAccion) ...[
              const SizedBox(height: 4),
              // El GestureDetector interno gana el toque: no dispara el
              // salto/habla de la mascota, solo navega.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAccion,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: mascota.color,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          accion!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 11,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Selector de mascota: bottom sheet con la galería completa.
/// Devuelve la mascota elegida (o null si se cancela).
Future<MascotType?> elegirMascotaSheet(
  BuildContext context,
  MascotType actual, {
  required Set<MascotType> desbloqueadas,
  required int nivel,
  required int puntos,
  required int tareas,
  required int insignias,
  Set<MascotType>? visibles,
}) {
  // Sin lista explícita: las de los integrantes (nunca las del admin).
  final lista =
      visibles ??
      MascotType.values
          .where((m) => !mascotasSoloAdmin.contains(m))
          .toSet();
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
                      for (final m in lista)
                        _CeldaMascota(
                          tipo: m,
                          seleccionada: m == actual,
                          desbloqueada: desbloqueadas.contains(m),
                          nivelActual: nivel,
                          puntosActuales: puntos,
                          tareasActuales: tareas,
                          insigniasActuales: insignias,
                          onTap: desbloqueadas.contains(m)
                              ? () => Navigator.of(sheetContext).pop(m)
                              : null,
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
  final bool desbloqueada;
  final int nivelActual;
  final int puntosActuales;
  final int tareasActuales;
  final int insigniasActuales;
  final VoidCallback? onTap;
  const _CeldaMascota({
    required this.tipo,
    required this.seleccionada,
    required this.desbloqueada,
    required this.nivelActual,
    required this.puntosActuales,
    required this.tareasActuales,
    required this.insigniasActuales,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final req = requisitosDe(tipo);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: seleccionada
              ? amarilloFondoTema(context)
              : (esOscuro(context)
                    ? AppColors.superficieOscura
                    : const Color(0xFFF7F7F7)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: seleccionada
                ? AppColors.amarillo
                : (desbloqueada ? AppColors.linea : AppColors.grisMedio),
            width: seleccionada ? 2.5 : 1.5,
          ),
        ),
        child: Opacity(
          opacity: desbloqueada ? 1 : 0.55,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  MascotWidget(mascota: tipo, size: 54, interactivo: false),
                  if (!desbloqueada)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock,
                          size: 15,
                          color: AppColors.grisMedio,
                        ),
                      ),
                    ),
                ],
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
              if (!desbloqueada)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    req.faltante(
                      nivelActual: nivelActual,
                      puntosActuales: puntosActuales,
                      tareasActuales: tareasActuales,
                      insigniasActuales: insigniasActuales,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 8,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: AppColors.grisMedio,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dibuja cada mascota con estilo "fake-3D": sombra proyectada, cuerpo con
/// gradiente de luz (arriba-izquierda claro → base → oscuro abajo-derecha),
/// trazo grueso redondeado y cara kawaii (ojos ovalados con brillo doble y
/// mejillas rosas).
class _MascotPainter extends CustomPainter {
  final MascotType mascota;

  _MascotPainter(this.mascota);

  /// Escala actual (lienzo de referencia 220x220); se fija en [paint].
  double _s = 1;

  /// En modo sombra todos los paints se vuelven negros y borrosos, para
  /// dibujar la silueta de la sombra proyectada con el mismo código.
  bool _sombra = false;

  @override
  void paint(Canvas canvas, Size size) {
    _s = size.width / 220;

    // Sombra proyectada: la misma silueta en negro borroso, desplazada
    // abajo-derecha; encima la mascota nítida.
    canvas.save();
    canvas.translate(5 * _s, 10 * _s);
    _sombra = true;
    _pintar(canvas);
    _sombra = false;
    canvas.restore();

    _pintar(canvas);
  }

  void _pintar(Canvas canvas) {
    final s = _s;
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
      case MascotType.auron:
        _pintarAuron(canvas, s);
      case MascotType.fenix:
        _pintarFenix(canvas, s);
      case MascotType.dori:
        _pintarDori(canvas, s);
      case MascotType.cosmo:
        _pintarCosmo(canvas, s);
      case MascotType.rex:
        _pintarRex(canvas, s);
      case MascotType.buhomago:
        _pintarBuhomago(canvas, s);
      case MascotType.rey:
        _pintarRey(canvas, s);
      case MascotType.robotguardian:
        _pintarRobotGuardian(canvas, s);
      case MascotType.dinodoro:
        _pintarDinoDoro(canvas, s);
    }
  }

  Paint _trazo() => _trazoCon(const Color(0xFF0F172A), 4.5);

  /// Trazo con color y grosor; en modo sombra se vuelve negro y borroso.
  Paint _trazoCon(Color color, double ancho) {
    if (_sombra) {
      return Paint()
        ..color = const Color(0x4D000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ancho
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * _s);
    }
    return Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = ancho
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
  }

  /// Relleno fake-3D: gradiente diagonal con luz arriba-izquierda. Los
  /// colores translúcidos (brillos, poros, cráteres) quedan sólidos tal cual.
  /// En modo sombra: negro borroso.
  Paint _relleno(Color color) {
    if (_sombra) {
      return Paint()
        ..color = const Color(0x4D000000)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * _s);
    }
    if (color.a * 255.0 < 0x80) {
      return Paint()
        ..color = color
        ..style = PaintingStyle.fill;
    }
    final claro = Color.lerp(color, Colors.white, 0.34)!;
    final oscuro = Color.lerp(color, const Color(0xFF000000), 0.26)!;
    return Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [claro, color, oscuro],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, 220 * _s, 220 * _s));
  }

  /// Dos ojos ovalados con brillo doble, centrados en [c] con escala [e].
  void _ojos(Canvas canvas, double s, Offset c, double e) {
    final ink = _relleno(const Color(0xFF0F172A));
    for (final dx in const [-18.0, 18.0]) {
      final o = c + Offset(dx * s * e, -8 * s * e);
      canvas.drawOval(
        Rect.fromCenter(center: o, width: 13 * s * e, height: 17 * s * e),
        ink,
      );
      canvas.drawCircle(
        o + Offset(-2.4 * s * e, -3.6 * s * e),
        2.8 * s * e,
        _relleno(const Color(0xFFFFFFFF)),
      );
      canvas.drawCircle(
        o + Offset(2.6 * s * e, 3.2 * s * e),
        1.4 * s * e,
        _relleno(const Color(0xA6FFFFFF)),
      );
    }
  }

  /// Cara común: mejillas rosas, dos ojos ovalados y una sonrisa,
  /// centrada en [c] con escala [e].
  void _cara(Canvas canvas, double s, Offset c, double e) {
    // Mejillas kawaii debajo de los ojos.
    final mejilla = _relleno(const Color(0xB3F9A8D4));
    for (final dx in const [-31.0, 31.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c + Offset(dx * s * e, 7 * s * e),
          width: 17 * s * e,
          height: 9 * s * e,
        ),
        mejilla,
      );
    }
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
    final madera = _relleno(const Color(0xFFB45309));
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
    // Gota simétrica clásica: ápice arriba + flancos con cúbicas espejo +
    // semicírculo inferior exacto (la cuerda del arco = 2×radio, así que
    // nunca se deforma).
    final gota = Path()
      ..moveTo(110 * s, 32 * s)
      ..cubicTo(140 * s, 80 * s, 174 * s, 108 * s, 174 * s, 152 * s)
      ..arcToPoint(
        Offset(46 * s, 152 * s),
        radius: Radius.circular(64 * s),
        clockwise: true,
      )
      ..cubicTo(46 * s, 108 * s, 80 * s, 80 * s, 110 * s, 32 * s)
      ..close();
    canvas.drawPath(gota, azul);
    canvas.drawPath(gota, stroke);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(78 * s, 108 * s),
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
    // Estrella clásica de 5 puntas (ápice arriba): radios alternos
    // exterior/interior con paso pi/5.
    final estrella = Path();
    const n = 5;
    for (var i = 0; i < n * 2; i++) {
      final radio = i.isEven ? 88 * s : 36 * s;
      final angulo = -math.pi / 2 + i * math.pi / n;
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
      final p =
          Offset(110 * s, 128 * s) +
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
    // Cráteres de la cara visible del creciente.
    final crater = _relleno(const Color(0x332563EB));
    canvas.drawCircle(Offset(74 * s, 96 * s), 9 * s, crater);
    canvas.drawCircle(Offset(72 * s, 168 * s), 7 * s, crater);
    canvas.drawCircle(Offset(54 * s, 138 * s), 5 * s, crater);
    canvas.drawCircle(Offset(62 * s, 192 * s), 4 * s, crater);
    // Destellos de estrella en el hueco del creciente (lado derecho).
    final destello = _relleno(const Color(0xFF60A5FA));
    void estrella(Offset c, double r) {
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - r)
          ..quadraticBezierTo(
            c.dx + r * 0.18,
            c.dy - r * 0.18,
            c.dx + r,
            c.dy,
          )
          ..quadraticBezierTo(
            c.dx + r * 0.18,
            c.dy + r * 0.18,
            c.dx,
            c.dy + r,
          )
          ..quadraticBezierTo(
            c.dx - r * 0.18,
            c.dy + r * 0.18,
            c.dx - r,
            c.dy,
          )
          ..quadraticBezierTo(
            c.dx - r * 0.18,
            c.dy - r * 0.18,
            c.dx,
            c.dy - r,
          )
          ..close(),
        destello,
      );
    }

    estrella(Offset(176 * s, 70 * s), 9 * s);
    estrella(Offset(188 * s, 140 * s), 6 * s);
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
      _trazoCon(const Color(0xFF15803D), 10 * s),
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
      _trazoCon(const Color(0xFF0F172A), 5 * s),
    );
    canvas.drawCircle(
      Offset(110 * s, 30 * s),
      12 * s,
      _relleno(const Color(0xFFFACC15)),
    );
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
      final p = centro + Offset(math.cos(ang) * 60 * s, math.sin(ang) * 60 * s);
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
    final veta = _trazoCon(const Color(0xFFFFE4C7), 6 * s);
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
    final plumon = _trazoCon(const Color(0xFFEA580C), 6 * s);
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
        ..quadraticBezierTo(106 * s, 144 * s, 118 * s, 136 * s),
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
    final bigote = _trazoCon(const Color(0xFF0F172A), 3 * s);
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

  void _pintarAuron(Canvas canvas, double s) {
    // Melena arcoíris (atrás, costado izquierdo).
    final melena = const [
      Color(0xFFF472B6),
      Color(0xFFFBBF24),
      Color(0xFF22C55E),
      Color(0xFF60A5FA),
    ];
    for (var i = 0; i < melena.length; i++) {
      final tira = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset((42 - i * 3) * s, (102 + i * 22) * s),
          width: 34 * s,
          height: 22 * s,
        ),
        Radius.circular(11 * s),
      );
      canvas.drawRRect(tira, _relleno(melena[i]));
      canvas.drawRRect(tira, _trazoCon(const Color(0xFF0F172A), 3.5));
    }
    // Orejas.
    for (final dx in const [-38.0, 38.0]) {
      final oreja = Path()
        ..moveTo((110 + dx) * s, 96 * s)
        ..lineTo((110 + dx + (dx < 0 ? -14 : 14)) * s, 60 * s)
        ..lineTo((110 + dx + (dx < 0 ? 6 : -6)) * s, 100 * s)
        ..close();
      canvas.drawPath(oreja, _relleno(const Color(0xFFE9D5FF)));
      canvas.drawPath(oreja, _trazo());
    }
    // Cuerno dorado.
    final cuerno = Path()
      ..moveTo(110 * s, 28 * s)
      ..lineTo(126 * s, 78 * s)
      ..lineTo(94 * s, 78 * s)
      ..close();
    canvas.drawPath(cuerno, _relleno(const Color(0xFFFBBF24)));
    canvas.drawPath(cuerno, _trazo());
    // Cabeza.
    final cabeza = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(110 * s, 140 * s),
        width: 118 * s,
        height: 108 * s,
      ),
      Radius.circular(52 * s),
    );
    canvas.drawRRect(cabeza, _relleno(const Color(0xFFF5F3FF)));
    canvas.drawRRect(cabeza, _trazo());
    _cara(canvas, s, Offset(110 * s, 142 * s), 1);
  }

  void _pintarFenix(Canvas canvas, double s) {
    // Cresta de llama.
    final llama = Path()
      ..moveTo(66 * s, 76 * s)
      ..quadraticBezierTo(62 * s, 34 * s, 86 * s, 54 * s)
      ..quadraticBezierTo(92 * s, 18 * s, 110 * s, 44 * s)
      ..quadraticBezierTo(126 * s, 16 * s, 134 * s, 52 * s)
      ..quadraticBezierTo(158 * s, 36 * s, 152 * s, 76 * s)
      ..close();
    canvas.drawPath(llama, _relleno(const Color(0xFFF97316)));
    final interna = Path()
      ..moveTo(88 * s, 74 * s)
      ..quadraticBezierTo(90 * s, 46 * s, 108 * s, 60 * s)
      ..quadraticBezierTo(126 * s, 42 * s, 132 * s, 74 * s)
      ..close();
    canvas.drawPath(interna, _relleno(const Color(0xFFFDE047)));
    canvas.drawPath(llama, _trazo());
    // Ala lateral.
    final ala = Path()
      ..moveTo(58 * s, 126 * s)
      ..quadraticBezierTo(18 * s, 150 * s, 44 * s, 186 * s)
      ..quadraticBezierTo(72 * s, 166 * s, 76 * s, 140 * s)
      ..close();
    canvas.drawPath(ala, _relleno(const Color(0xFFF97316)));
    canvas.drawPath(ala, _trazo());
    // Cuerpo.
    final cuerpo = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(112 * s, 142 * s),
        width: 120 * s,
        height: 108 * s,
      ),
      Radius.circular(52 * s),
    );
    canvas.drawRRect(cuerpo, _relleno(const Color(0xFFFB923C)));
    canvas.drawRRect(cuerpo, _trazo());
    _cara(canvas, s, Offset(116 * s, 142 * s), 1);
  }

  void _pintarDori(Canvas canvas, double s) {
    final stroke = _trazo();
    // Cola.
    final cola = Path()
      ..moveTo(74 * s, 168 * s)
      ..lineTo(28 * s, 146 * s)
      ..lineTo(40 * s, 174 * s)
      ..lineTo(20 * s, 198 * s)
      ..lineTo(76 * s, 190 * s)
      ..close();
    canvas.drawPath(cola, _relleno(const Color(0xFF0EA5E9)));
    canvas.drawPath(cola, stroke);
    // Aleta dorsal.
    final dorsal = Path()
      ..moveTo(118 * s, 74 * s)
      ..quadraticBezierTo(152 * s, 40 * s, 150 * s, 84 * s)
      ..close();
    canvas.drawPath(dorsal, _relleno(const Color(0xFF0EA5E9)));
    canvas.drawPath(dorsal, stroke);
    // Cuerpo.
    final cuerpo = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(114 * s, 132 * s),
        width: 132 * s,
        height: 96 * s,
      ),
      Radius.circular(48 * s),
    );
    canvas.drawRRect(cuerpo, _relleno(const Color(0xFF38BDF8)));
    canvas.drawRRect(cuerpo, stroke);
    // Panza clara.
    final panza = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(118 * s, 154 * s),
        width: 92 * s,
        height: 44 * s,
      ),
      Radius.circular(22 * s),
    );
    canvas.drawRRect(panza, _relleno(const Color(0xFFBAE6FD)));
    _cara(canvas, s, Offset(120 * s, 126 * s), 1);
  }

  void _pintarCosmo(Canvas canvas, double s) {
    final stroke = _trazo();
    // Antena.
    canvas.drawLine(
      Offset(110 * s, 46 * s),
      Offset(110 * s, 24 * s),
      stroke,
    );
    canvas.drawCircle(
      Offset(110 * s, 20 * s),
      8 * s,
      _relleno(const Color(0xFFF472B6)),
    );
    // Casco.
    final casco = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(110 * s, 122 * s),
        width: 132 * s,
        height: 132 * s,
      ),
      Radius.circular(62 * s),
    );
    canvas.drawRRect(casco, _relleno(const Color(0xFFF1F5F9)));
    canvas.drawRRect(casco, stroke);
    // Visor.
    final visor = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(110 * s, 118 * s),
        width: 94 * s,
        height: 76 * s,
      ),
      Radius.circular(34 * s),
    );
    canvas.drawRRect(visor, _relleno(const Color(0xFF0F172A)));
    canvas.drawRRect(visor, stroke);
    if (!_sombra) {
      final brillo = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(92 * s, 102 * s),
          width: 34 * s,
          height: 20 * s,
        ),
        Radius.circular(10 * s),
      );
      canvas.drawRRect(brillo, _relleno(const Color(0x66FFFFFF)));
    }
    _cara(canvas, s, Offset(110 * s, 120 * s), 0.82);
    // Collar del traje.
    final collar = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(110 * s, 182 * s),
        width: 72 * s,
        height: 22 * s,
      ),
      Radius.circular(11 * s),
    );
    canvas.drawRRect(collar, _relleno(const Color(0xFF94A3B8)));
    canvas.drawRRect(collar, stroke);
  }

  void _pintarRex(Canvas canvas, double s) {
    final stroke = _trazo();
    // Cola.
    final cola = Path()
      ..moveTo(62 * s, 158 * s)
      ..quadraticBezierTo(10 * s, 168 * s, 16 * s, 196 * s)
      ..quadraticBezierTo(52 * s, 196 * s, 76 * s, 180 * s)
      ..close();
    canvas.drawPath(cola, _relleno(const Color(0xFF16A34A)));
    canvas.drawPath(cola, stroke);
    // Espinas.
    for (final p in [
      Path()
        ..moveTo(76 * s, 70 * s)
        ..lineTo(92 * s, 38 * s)
        ..lineTo(108 * s, 70 * s)
        ..close(),
      Path()
        ..moveTo(108 * s, 64 * s)
        ..lineTo(126 * s, 32 * s)
        ..lineTo(142 * s, 66 * s)
        ..close(),
    ]) {
      canvas.drawPath(p, _relleno(const Color(0xFFEF4444)));
      canvas.drawPath(p, stroke);
    }
    // Hocico.
    final hocico = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(152 * s, 152 * s),
        width: 62 * s,
        height: 48 * s,
      ),
      Radius.circular(22 * s),
    );
    canvas.drawRRect(hocico, _relleno(const Color(0xFF22C55E)));
    canvas.drawRRect(hocico, stroke);
    // Cuerpo.
    final cuerpo = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(108 * s, 136 * s),
        width: 122 * s,
        height: 112 * s,
      ),
      Radius.circular(52 * s),
    );
    canvas.drawRRect(cuerpo, _relleno(const Color(0xFF22C55E)));
    canvas.drawRRect(cuerpo, stroke);
    _cara(canvas, s, Offset(104 * s, 132 * s), 0.92);
  }

  /// Merlín: búho sabio con túnica, gorro de mago estrellado y penachos.
  void _pintarBuhomago(Canvas canvas, double s) {
    final stroke = _trazo();
    // Alas a los costados.
    for (final dx in const [-66.0, 66.0]) {
      final ala = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset((110 + dx) * s, 152 * s),
          width: 40 * s,
          height: 74 * s,
        ),
        Radius.circular(20 * s),
      );
      canvas.drawRRect(ala, _relleno(const Color(0xFF7C3AED)));
      canvas.drawRRect(ala, stroke);
    }
    // Penachos (orejas del búho).
    for (final dx in const [-46.0, 46.0]) {
      final penacho = Path()
        ..moveTo((110 + dx) * s, 100 * s)
        ..lineTo((110 + dx + (dx < 0 ? -12 : 12)) * s, 66 * s)
        ..lineTo((110 + dx + (dx < 0 ? 8 : -8)) * s, 104 * s)
        ..close();
      canvas.drawPath(penacho, _relleno(const Color(0xFF8B5CF6)));
      canvas.drawPath(penacho, stroke);
    }
    // Cuerpo.
    final cuerpo = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(110 * s, 142 * s),
        width: 116 * s,
        height: 120 * s,
      ),
      Radius.circular(56 * s),
    );
    canvas.drawRRect(cuerpo, _relleno(const Color(0xFF8B5CF6)));
    canvas.drawRRect(cuerpo, stroke);
    // Panza.
    final panza = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(110 * s, 166 * s),
        width: 72 * s,
        height: 58 * s,
      ),
      Radius.circular(29 * s),
    );
    canvas.drawRRect(panza, _relleno(const Color(0xFFC4B5FD)));
    // Gorro de mago (cono).
    final gorro = Path()
      ..moveTo(62 * s, 88 * s)
      ..lineTo(158 * s, 88 * s)
      ..lineTo(110 * s, 20 * s)
      ..close();
    canvas.drawPath(gorro, _relleno(const Color(0xFF6D28D9)));
    canvas.drawPath(gorro, stroke);
    // Ala doblada del gorro.
    final punta = Path()
      ..moveTo(110 * s, 20 * s)
      ..quadraticBezierTo(150 * s, 26 * s, 156 * s, 54 * s)
      ..quadraticBezierTo(132 * s, 44 * s, 118 * s, 50 * s)
      ..close();
    canvas.drawPath(punta, _relleno(const Color(0xFF6D28D9)));
    canvas.drawPath(punta, stroke);
    // Borde del gorro.
    final brim = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(110 * s, 90 * s),
        width: 116 * s,
        height: 20 * s,
      ),
      Radius.circular(10 * s),
    );
    canvas.drawRRect(brim, _relleno(const Color(0xFF5B21B6)));
    canvas.drawRRect(brim, stroke);
    // Destello mágico en el gorro.
    final est = Path()
      ..moveTo(96 * s, 58 * s)
      ..quadraticBezierTo(100 * s, 68 * s, 110 * s, 72 * s)
      ..quadraticBezierTo(100 * s, 76 * s, 96 * s, 86 * s)
      ..quadraticBezierTo(92 * s, 76 * s, 82 * s, 72 * s)
      ..quadraticBezierTo(92 * s, 68 * s, 96 * s, 58 * s)
      ..close();
    canvas.drawPath(est, _relleno(const Color(0xFFFDE68A)));
    canvas.drawPath(est, stroke);
    _cara(canvas, s, Offset(110 * s, 136 * s), 1);
  }

  /// Rey Hogar: corona dorada con joyas, capa real y túnica.
  void _pintarRey(Canvas canvas, double s) {
    final stroke = _trazo();
    // Capa roja (detrás del cuerpo).
    final capa = Path()
      ..moveTo(54 * s, 116 * s)
      ..quadraticBezierTo(26 * s, 172 * s, 50 * s, 206 * s)
      ..lineTo(170 * s, 206 * s)
      ..quadraticBezierTo(194 * s, 172 * s, 166 * s, 116 * s)
      ..close();
    canvas.drawPath(capa, _relleno(const Color(0xFFDC2626)));
    canvas.drawPath(capa, stroke);
    // Túnica real.
    final cuerpo = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(110 * s, 142 * s),
        width: 116 * s,
        height: 114 * s,
      ),
      Radius.circular(52 * s),
    );
    canvas.drawRRect(cuerpo, _relleno(const Color(0xFF7C3AED)));
    canvas.drawRRect(cuerpo, stroke);
    // Gargantilla / joya del cuello.
    canvas.drawCircle(
      Offset(110 * s, 104 * s),
      9 * s,
      _relleno(const Color(0xFFEF4444)),
    );
    // Corona (3 picos).
    final corona = Path()
      ..moveTo(54 * s, 88 * s)
      ..lineTo(54 * s, 50 * s)
      ..lineTo(82 * s, 72 * s)
      ..lineTo(110 * s, 40 * s)
      ..lineTo(138 * s, 72 * s)
      ..lineTo(166 * s, 50 * s)
      ..lineTo(166 * s, 88 * s)
      ..close();
    canvas.drawPath(corona, _relleno(const Color(0xFFFBBF24)));
    canvas.drawPath(corona, stroke);
    // Base de la corona.
    final base = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(110 * s, 90 * s),
        width: 116 * s,
        height: 18 * s,
      ),
      Radius.circular(9 * s),
    );
    canvas.drawRRect(base, _relleno(const Color(0xFFF59E0B)));
    canvas.drawRRect(base, stroke);
    // Joyas.
    for (final dx in const [-36.0, 0.0, 36.0]) {
      canvas.drawCircle(
        Offset((110 + dx) * s, 90 * s),
        5 * s,
        _relleno(dx == 0 ? const Color(0xFF3B82F6) : const Color(0xFFEF4444)),
      );
    }
    _cara(canvas, s, Offset(110 * s, 144 * s), 1);
  }

  /// Centinela: robot guardián deluxe con visor luminoso y escudo.
  void _pintarRobotGuardian(Canvas canvas, double s) {
    final stroke = _trazo();
    // Antena con luz.
    canvas.drawLine(
      Offset(110 * s, 52 * s),
      Offset(110 * s, 26 * s),
      stroke,
    );
    canvas.drawCircle(
      Offset(110 * s, 22 * s),
      9 * s,
      _relleno(const Color(0xFF22D3EE)),
    );
    // Brazos.
    for (final dx in const [-74.0, 74.0]) {
      final brazo = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset((110 + dx) * s, 156 * s),
          width: 34 * s,
          height: 60 * s,
        ),
        Radius.circular(16 * s),
      );
      canvas.drawRRect(brazo, _relleno(const Color(0xFF94A3B8)));
      canvas.drawRRect(brazo, stroke);
    }
    // Pechera.
    final cuerpo = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(110 * s, 154 * s),
        width: 110 * s,
        height: 98 * s,
      ),
      Radius.circular(26 * s),
    );
    canvas.drawRRect(cuerpo, _relleno(const Color(0xFFCBD5E1)));
    canvas.drawRRect(cuerpo, stroke);
    // Escudo en el pecho.
    final escudo = Path()
      ..moveTo(110 * s, 130 * s)
      ..lineTo(142 * s, 142 * s)
      ..lineTo(142 * s, 172 * s)
      ..quadraticBezierTo(142 * s, 194 * s, 110 * s, 202 * s)
      ..quadraticBezierTo(78 * s, 194 * s, 78 * s, 172 * s)
      ..lineTo(78 * s, 142 * s)
      ..close();
    canvas.drawPath(escudo, _relleno(const Color(0xFF06B6D4)));
    canvas.drawPath(escudo, stroke);
    // Palomita dentro del escudo.
    final chk = Path()
      ..moveTo(94 * s, 164 * s)
      ..lineTo(105 * s, 175 * s)
      ..lineTo(128 * s, 150 * s);
    canvas.drawPath(chk, _trazoCon(const Color(0xFFFFFFFF), 6));
    // Cabeza.
    final cabeza = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(110 * s, 74 * s),
        width: 106 * s,
        height: 80 * s,
      ),
      Radius.circular(28 * s),
    );
    canvas.drawRRect(cabeza, _relleno(const Color(0xFFE2E8F0)));
    canvas.drawRRect(cabeza, stroke);
    // Visor.
    final visor = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(110 * s, 76 * s),
        width: 78 * s,
        height: 36 * s,
      ),
      Radius.circular(17 * s),
    );
    canvas.drawRRect(visor, _relleno(const Color(0xFF0F172A)));
    canvas.drawRRect(visor, stroke);
    // Ojos luminosos.
    for (final dx in const [-19.0, 19.0]) {
      canvas.drawCircle(
        Offset((110 + dx) * s, 76 * s),
        7 * s,
        _relleno(const Color(0xFF22D3EE)),
      );
    }
  }

  /// Áureo: el dinosaurio jefe, dorado y con corona.
  void _pintarDinoDoro(Canvas canvas, double s) {
    final stroke = _trazo();
    // Cola.
    final cola = Path()
      ..moveTo(64 * s, 162 * s)
      ..quadraticBezierTo(8 * s, 170 * s, 14 * s, 200 * s)
      ..quadraticBezierTo(54 * s, 200 * s, 80 * s, 184 * s)
      ..close();
    canvas.drawPath(cola, _relleno(const Color(0xFFEAB308)));
    canvas.drawPath(cola, stroke);
    // Brazo corto.
    final brazo = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(66 * s, 152 * s),
        width: 32 * s,
        height: 24 * s,
      ),
      Radius.circular(12 * s),
    );
    canvas.drawRRect(brazo, _relleno(const Color(0xFFEAB308)));
    canvas.drawRRect(brazo, stroke);
    // Hocico.
    final hocico = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(158 * s, 154 * s),
        width: 68 * s,
        height: 54 * s,
      ),
      Radius.circular(26 * s),
    );
    canvas.drawRRect(hocico, _relleno(const Color(0xFFFACC15)));
    canvas.drawRRect(hocico, stroke);
    // Cuerpo.
    final cuerpo = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(104 * s, 142 * s),
        width: 126 * s,
        height: 118 * s,
      ),
      Radius.circular(56 * s),
    );
    canvas.drawRRect(cuerpo, _relleno(const Color(0xFFFACC15)));
    canvas.drawRRect(cuerpo, stroke);
    // Corona de jefe (se sienta sobre la cabeza).
    final corona = Path()
      ..moveTo(58 * s, 96 * s)
      ..lineTo(58 * s, 54 * s)
      ..lineTo(86 * s, 78 * s)
      ..lineTo(118 * s, 46 * s)
      ..lineTo(150 * s, 78 * s)
      ..lineTo(178 * s, 54 * s)
      ..lineTo(178 * s, 96 * s)
      ..close();
    canvas.drawPath(corona, _relleno(const Color(0xFFFDE68A)));
    canvas.drawPath(corona, stroke);
    // Joya de la corona.
    canvas.drawCircle(
      Offset(118 * s, 84 * s),
      7 * s,
      _relleno(const Color(0xFFEF4444)),
    );
    // Fosas nasales.
    canvas.drawCircle(
      Offset(182 * s, 146 * s),
      4 * s,
      _relleno(const Color(0xFF92400E)),
    );
    canvas.drawCircle(
      Offset(194 * s, 160 * s),
      4 * s,
      _relleno(const Color(0xFF92400E)),
    );
    _cara(canvas, s, Offset(96 * s, 138 * s), 0.92);
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) =>
      oldDelegate.mascota != mascota;
}
