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

  static const limites = <int, int>{1: 0, 2: 100, 3: 250, 4: 500, 5: 800};

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
    if (nivel <= 0) return niveles[1]!;
    if (nivel <= 5) return niveles[nivel]!;
    return 'Maestro nivel $nivel';
  }

  /// Puntos mínimos y máximos del nivel actual.
  static (int, int) rangoNivel(int nivel) {
    if (nivel <= 1) return (0, 99);
    if (nivel <= 5) {
      final max = nivel < 5 ? limites[nivel + 1]! - 1 : 800;
      return (limites[nivel]!, max);
    }
    final base = 800 + (nivel - 5) * 400;
    return (base, base + 399);
  }

  /// Ligas ordenadas de menor a mayor. Son escalones por PUNTOS acumulados
  /// (no por posición): así la progresión es real y gradual, sin saltos.
  static const List<String> ligas = [
    'Bronce',
    'Plata',
    'Oro',
    'Platino',
    'Zafiro',
    'Esmeralda',
    'Rubí',
    'Amatista',
    'Topacio',
    'Obsidiana',
    'Cristal',
    'Perla',
    'Coral',
    'Ámbar',
    'Jade',
    'Cobalto',
    'Celeste',
    'Estelar',
    'Galáctica',
    'Corona',
  ];

  /// Puntos mínimos para pertenecer a cada liga (misma longitud que [ligas]).
  static const List<int> _umbralesLiga = [
    0,
    100,
    250,
    450,
    700,
    1000,
    1400,
    1900,
    2500,
    3200,
    4000,
    5000,
    6200,
    7600,
    9200,
    11000,
    13000,
    15500,
    18500,
    22000,
  ];

  /// Índice (0-based) de la liga según los puntos acumulados.
  static int indiceLiga(int puntos) {
    var idx = 0;
    for (var i = 0; i < ligas.length; i++) {
      if (puntos >= _umbralesLiga[i]) idx = i;
    }
    return idx;
  }

  /// Liga de un integrante según sus puntos acumulados.
  static String ligaDe(int puntos) => ligas[indiceLiga(puntos)];

  /// Puntos mínimos de la liga en la posición [idx] (0-based).
  static int umbralLiga(int idx) =>
      idx < 0 ? 0 : _umbralesLiga[idx.clamp(0, _umbralesLiga.length - 1)];

  /// Puntos que faltan para subir a la siguiente liga (0 si ya es la última).
  static int puntosParaSiguienteLiga(int puntos) {
    final idx = indiceLiga(puntos);
    if (idx >= ligas.length - 1) return 0;
    final faltan = _umbralesLiga[idx + 1] - puntos;
    return faltan > 0 ? faltan : 0;
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
    final fechas =
        fechasAprobadas
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

  /// Determina qué insignias merece un integrante según el catálogo
  /// editable: cada insignia define su métrica y su meta.
  static List<int> insigniasGanadas({
    required List<Badge> catalogo,
    required int puntos,
    required int racha,
    required List<Assignment> aprobadas,
    required List<Task> tareas,
  }) {
    final c = _contarCategorias(aprobadas: aprobadas, tareas: tareas);
    final diarias = _maxPorDia(aprobadas);
    final ganadas = <int>[];
    for (final b in catalogo) {
      final id = b.id;
      if (id == null) continue;
      final meta = b.meta > 0 ? b.meta : 1;
      final valor = _valorMetrica(
        b.metrica,
        puntos: puntos,
        racha: racha,
        categorias: c,
        diarias: diarias,
        tareasAprobadas: aprobadas.length,
      );
      if (valor >= meta) ganadas.add(id);
    }
    return ganadas..sort();
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

  /// Valor actual de la métrica que mide una insignia.
  static int _valorMetrica(
    String metrica, {
    required int puntos,
    required int racha,
    required Map<String, int> categorias,
    required int diarias,
    required int tareasAprobadas,
  }) {
    return switch (metrica) {
      'limpieza' => categorias['limpieza']!,
      'cocina' => categorias['cocina']!,
      'orden' => categorias['orden']!,
      'puntual' => categorias['puntual']!,
      'racha' => racha,
      'nivel' => nivelPara(puntos),
      'diarias' => diarias,
      _ => tareasAprobadas,
    };
  }

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
    final ganadas = Set<int>.from(
      insigniasGanadas(
        catalogo: catalogo,
        puntos: puntos,
        racha: racha,
        aprobadas: aprobadas,
        tareas: tareas,
      ),
    );
    return catalogo.map((b) {
      final meta = b.meta > 0 ? b.meta : 1;
      final valor = _valorMetrica(
        b.metrica,
        puntos: puntos,
        racha: racha,
        categorias: c,
        diarias: diarias,
        tareasAprobadas: aprobadas.length,
      );
      final actual = valor.clamp(0, meta);
      return (b, actual, meta, b.id != null && ganadas.contains(b.id));
    }).toList();
  }
}
