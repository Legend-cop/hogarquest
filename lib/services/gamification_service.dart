import '../models/assignment.dart';
import '../models/badge.dart';
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
  /// Devuelve lista de índices de insignias (1..7 según el catálogo fijo).
  static List<int> insigniasGanadas({
    required int puntos,
    required int racha,
    required List<Assignment> aprobadas,
    required List<Task> tareas,
  }) {
    final c = _contarCategorias(aprobadas: aprobadas, tareas: tareas);
    final diarias = _maxPorDia(aprobadas);
    final ganadas = <int>{};
    if (c['limpieza']! >= 10) ganadas.add(1);
    if (c['cocina']! >= 10) ganadas.add(2);
    if (c['orden']! >= 10) ganadas.add(3);
    if (c['puntual']! >= 5) ganadas.add(4);
    if (racha >= 7) ganadas.add(5);
    if (nivelPara(puntos) >= 5) ganadas.add(6);
    if (diarias >= 5) ganadas.add(7);
    return ganadas.toList()..sort();
  }

  /// Cuenta tareas aprobadas por categoría según la descripción.
  static Map<String, int> _contarCategorias({
    required List<Assignment> aprobadas,
    required List<Task> tareas,
  }) {
    final tareasPorId = {for (final t in tareas) t.id: t};
    var limpieza = 0, cocina = 0, orden = 0, puntual = 0;
    for (final a in aprobadas) {
      final t = tareasPorId[a.tareaId];
      if (t == null) continue;
      final d = t.descripcion.toLowerCase();
      if (d.contains('limpiar') ||
          d.contains('limpieza') ||
          d.contains('barrer') ||
          d.contains('trapear')) {
        limpieza++;
      }
      if (d.contains('cocina') ||
          d.contains('cocinar') ||
          d.contains('platos')) {
        cocina++;
      }
      if (d.contains('orden') ||
          d.contains('ordenar') ||
          d.contains('organizar')) {
        orden++;
      }
      final limite = t.fechaLimite;
      if (limite != null &&
          a.fechaAprobada != null &&
          a.fechaAprobada!.isBefore(limite)) {
        puntual++;
      }
    }
    return {
      'limpieza': limpieza,
      'cocina': cocina,
      'orden': orden,
      'puntual': puntual,
    };
  }

  /// Máximo de tareas aprobadas en un mismo día.
  static int _maxPorDia(List<Assignment> aprobadas) {
    if (aprobadas.isEmpty) return 0;
    var max = 0;
    final porDia = <String, int>{};
    for (final a in aprobadas) {
      final f = a.fechaAprobada;
      if (f == null) continue;
      final key = '${f.year}-${f.month}-${f.day}';
      final n = (porDia[key] ?? 0) + 1;
      porDia[key] = n;
      if (n > max) max = n;
    }
    return max;
  }

  /// Meta (valor objetivo) de cada insignia del catálogo, por id.
  static const Map<int, int> metasInsignias = {
    1: 10, // Maestro de limpieza
    2: 10, // Rey de la cocina
    3: 10, // Orden perfecto
    4: 5, // Puntual
    5: 7, // Racha de 7 días
    6: 800, // Experto del hogar (puntos para nivel 5)
    7: 5, // 5 tareas en un día
  };

  /// Progreso actual de cada insignia del catálogo para un integrante.
  /// Devuelve tuplas (insignia, actual, meta, ganada).
  static List<(Badge, int, int, bool)> detalleInsignias({
    required List<Badge> catalogo,
    required int puntos,
    required int racha,
    required List<Assignment> aprobadas,
    required List<Task> tareas,
  }) {
    final c = _contarCategorias(aprobadas: aprobadas, tareas: tareas);
    final diarias = _maxPorDia(aprobadas);
    final valores = <int, int>{
      1: c['limpieza']!,
      2: c['cocina']!,
      3: c['orden']!,
      4: c['puntual']!,
      5: racha,
      6: puntos,
      7: diarias,
    };
    final ganadas = Set<int>.from(insigniasGanadas(
      puntos: puntos,
      racha: racha,
      aprobadas: aprobadas,
      tareas: tareas,
    ));
    return catalogo.map((b) {
      final meta = metasInsignias[b.id] ?? 1;
      final actual = (valores[b.id] ?? 0).clamp(0, meta);
      return (b, actual, meta, ganadas.contains(b.id));
    }).toList();
  }
}
