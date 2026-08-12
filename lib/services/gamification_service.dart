import '../models/assignment.dart';
import '../models/task.dart';

/// Reglas de gamificación de HogarQuest.
class GamificationService {
  GamificationService._();
  static const niveles = <int, String>{
    1: 'Aprendiz del hogar',
    2: 'Ayudante',
    3: 'Trabajador',
    4: 'Super estrella',
    5: 'Experto del hogar',
  };

  static const limites = <int, int>{
    1: 0,
    2: 100,
    3: 250,
    4: 500,
    5: 800,
  };

  /// Nivel según los puntos acumulados (hasta 5, y una fórmula para niveles 6+).
  static int nivelPara(int puntos) {
    if (puntos >= 800) {
      // Nivel 5+ : cada 400 puntos adicionales un nivel más.
      return 5 + ((puntos - 800) ~/ 400);
    }
    for (var l = limites.length; l >= 1; l--) {
      if (puntos >= limites[l]!) return l;
    }
    return 1;
  }

  /// Nombre visible del nivel.
  static String nombreNivel(int nivel) {
    if (nivel <= 5) return niveles[nivel]!;
    return 'Maestro nivel $nivel';
  }

  /// Puntos mínimos y máximos del nivel actual.
  static (int, int) rangoNivel(int nivel) {
    if (nivel <= 5) {
      final max = nivel < 5 ? limites[nivel + 1]! - 1 : 800;
      return (limites[nivel]!, max);
    }
    final base = 800 + (nivel - 5) * 400;
    return (base, base + 399);
  }

  /// Progreso (0.0 - 1.0) hacia el siguiente nivel.
  static double progresoNivel(int puntos, int nivel) {
    final (min, max) = rangoNivel(nivel);
    final span = max - min;
    if (span <= 0) return 1.0;
    return ((puntos - min) / span).clamp(0.0, 1.0);
  }

  /// Puntos restantes para subir de nivel.
  static int puntosParaSiguiente(int puntos, int nivel) {
    final (_, max) = rangoNivel(nivel);
    return max - puntos < 0 ? 0 : max - puntos;
  }

  /// Recompensa por racha (días).
  static int bonusRacha(int diasRacha) {
    if (diasRacha >= 30) return 50;
    if (diasRacha >= 7) return 30;
    if (diasRacha >= 3) return 10;
    return 0;
  }

  /// Actualiza la racha contando días consecutivos con tareas aprobadas.
  static int calcularRacha(List<DateTime> fechasAprobadas) {
    if (fechasAprobadas.isEmpty) return 0;
    final fechas = fechasAprobadas
        .map((f) => DateTime(f.year, f.month, f.day))
        .toSet()
        .toList()
      ..sort();
    var racha = 1;
    final hoy = DateTime.now();
    final ultima = fechas.last;
    final diasDesdeUltima = hoy.difference(ultima).inDays;
    if (diasDesdeUltima > 1) return 0;
    for (var i = fechas.length - 1; i > 0; i--) {
      if (fechas[i].difference(fechas[i - 1]).inDays == 1) {
        racha++;
      } else {
        break;
      }
    }
    return racha;
  }

  /// Determina qué insignias merece un integrante.
  /// Devuelve lista de índices de insignias (1..6 según el catálogo fijo).
  static List<int> insigniasGanadas({
    required int puntos,
    required int racha,
    required List<Assignment> aprobadas,
    required List<Task> tareas,
  }) {
    final ganadas = <int>{};
    final tareasPorId = {for (final t in tareas) t.id: t};

    var limpieza = 0, cocina = 0, orden = 0, puntual = 0;
    for (final a in aprobadas) {
      final t = tareasPorId[a.tareaId];
      if (t == null) continue;
      final d = t.descripcion.toLowerCase();
      if (d.contains('limpiar') || d.contains('limpieza') ||
          d.contains('barrer') || d.contains('trapear')) {
        limpieza++;
      }
      if (d.contains('cocina') || d.contains('cocinar') || d.contains('platos')) {
        cocina++;
      }
      if (d.contains('orden') || d.contains('ordenar') ||
          d.contains('organizar')) {
        orden++;
      }
      final limite = t.fechaLimite;
      if (limite != null && a.fechaAprobada != null &&
          a.fechaAprobada!.isBefore(limite)) {
        puntual++;
      }
    }

    if (limpieza >= 10) ganadas.add(1);
    if (cocina >= 10) ganadas.add(2);
    if (orden >= 10) ganadas.add(3);
    if (puntual >= 5) ganadas.add(4);
    if (racha >= 7) ganadas.add(5);
    if (nivelPara(puntos) >= 5) ganadas.add(6);
    return ganadas.toList()..sort();
  }
}
