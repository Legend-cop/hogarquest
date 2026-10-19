/// Aviso de que alguien robó una tarea o un slot de reto del usuario.
/// Se muestra en un diálogo animado al abrir la app.
class AvisoRobo {
  /// Nombre del hijo que robó.
  final String ladron;

  /// Título de la tarea o el reto robado.
  final String titulo;

  /// Puntos que ganó el ladrón.
  final int puntos;

  /// True si el robo fue de un reto (frenesí), false si fue una tarea.
  final bool esReto;

  const AvisoRobo({
    required this.ladron,
    required this.titulo,
    required this.puntos,
    this.esReto = false,
  });
}
