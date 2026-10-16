/// Reto semanal: misión familiar con puntos bonus.
/// El admin lo crea, los integrantes marcan si lo cumplieron y el admin aprueba.
///
/// Tres modos:
/// - `normal`: flujo clásico (marca → aprueba el admin → puntos).
/// - `lluvia`: día aleatorio de la semana; el PRIMERO en marcar gana al
///   instante y el reto se cierra.
/// - `frenesi`: todos tienen un "su tiempo" único; el que no lo cumple a
///   tiempo pierde su slot y cualquier otro niño puede ROBARLO (pago
///   automático al robar).
class Reto {
  static const String modoNormal = 'normal';
  static const String modoLluvia = 'lluvia';
  static const String modoFrenesi = 'frenesi';

  final int? id;
  final String titulo;
  final String descripcion;
  final int puntos;
  final DateTime fechaInicio; // lunes de la semana del reto
  final DateTime?
  fechaFin; // fecha y hora límite (opcional); si no se pone, vence al terminar la semana
  final List<int> cumplidos; // ids de usuarios que lo cumplieron (a tiempo)
  final List<int> aprobados; // ids de usuarios que YA recibieron puntos
  final bool finalizado;

  /// Cómo se juega: `normal`, `lluvia` o `frenesi`.
  final String modo;

  /// Día sorteado de lluvia (solo modo lluvia).
  final DateTime? fechaLluvia;

  /// "Su tiempo" único para todos (solo modo frenesí).
  final DateTime? plazoIndividual;

  /// Ganador de la lluvia (uid); quien cobra al instante.
  final int? ganador;

  /// uid → epoch ms de cada marca. En lluvia decide quién fue primero
  /// aunque dos dispositivos marquen casi a la vez.
  final Map<int, int> marcas;

  /// uid original → uid ladrón (solo frenesí). Cada slot solo se roba una vez.
  final Map<int, int> robados;

  const Reto({
    this.id,
    required this.titulo,
    required this.descripcion,
    required this.puntos,
    required this.fechaInicio,
    this.fechaFin,
    this.cumplidos = const [],
    this.aprobados = const [],
    this.finalizado = false,
    this.modo = modoNormal,
    this.fechaLluvia,
    this.plazoIndividual,
    this.ganador,
    this.marcas = const {},
    this.robados = const {},
  });

  bool get esLluvia => modo == modoLluvia;

  bool get esFrenesi => modo == modoFrenesi;

  bool perteneceASemana(DateTime semana) {
    final a = DateTime(semana.year, semana.month, semana.day);
    final b = DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day);
    final diff = a.difference(b).inDays;
    return diff >= 0 && diff < 7;
  }

  bool get vigente => !finalizado;

  /// True si ya pasó la fecha y hora límite del reto.
  bool vencido(DateTime ahora) {
    final f = fechaFin;
    if (f == null) return false;
    return ahora.isAfter(f);
  }

  /// "Su tiempo" del modo frenesí (plazoIndividual, o el vencimiento del
  /// reto, o el domingo 23:59:59 de su semana como último recurso).
  DateTime get plazoEfectivo {
    final p = plazoIndividual;
    if (p != null) return p;
    final f = fechaFin;
    if (f != null) return f;
    final fin = fechaInicio.add(const Duration(days: 6));
    return DateTime(fechaInicio.year, fechaInicio.month, fin.day, 23, 59, 59);
  }

  /// True si la lluvia está corriendo hoy (mismo día de `fechaLluvia`).
  bool lluviaActiva(DateTime ahora) {
    final d = fechaLluvia;
    if (d == null) return false;
    return d.year == ahora.year && d.month == ahora.month && d.day == ahora.day;
  }

  /// En frenesí: ¿el hijo todavía puede marcar "¡Lo cumplí!"?
  bool puedeMarcarFrenesi(DateTime ahora) =>
      vigente && !ahora.isAfter(plazoEfectivo);

  /// En frenesí: este slot ¿aún está disponible para robar?
  bool slotRobable(int original) =>
      esFrenesi &&
      vigente &&
      original != 0 &&
      !cumplidos.contains(original) &&
      !robados.containsKey(original);

  Reto copyWith({
    int? id,
    String? titulo,
    String? descripcion,
    int? puntos,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    List<int>? cumplidos,
    List<int>? aprobados,
    bool? finalizado,
    String? modo,
    DateTime? fechaLluvia,
    DateTime? plazoIndividual,
    int? ganador,
    Map<int, int>? marcas,
    Map<int, int>? robados,
  }) {
    return Reto(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      puntos: puntos ?? this.puntos,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      cumplidos: cumplidos ?? this.cumplidos,
      aprobados: aprobados ?? this.aprobados,
      finalizado: finalizado ?? this.finalizado,
      modo: modo ?? this.modo,
      fechaLluvia: fechaLluvia ?? this.fechaLluvia,
      plazoIndividual: plazoIndividual ?? this.plazoIndividual,
      ganador: ganador ?? this.ganador,
      marcas: marcas ?? this.marcas,
      robados: robados ?? this.robados,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'descripcion': descripcion,
      'puntos': puntos,
      'fecha_inicio': fechaInicio.toIso8601String(),
      'fecha_fin': fechaFin?.toIso8601String(),
      'cumplidos': cumplidos,
      'aprobados': aprobados,
      'finalizado': finalizado ? 1 : 0,
      'modo': modo,
      'fecha_lluvia': fechaLluvia?.toIso8601String(),
      'plazo_individual': plazoIndividual?.toIso8601String(),
      'ganador': ganador,
      // Map<int,int> se serializa con claves string para ser JSON-safe.
      'marcas': marcas.map((k, v) => MapEntry(k.toString(), v)),
      'robados': robados.map((k, v) => MapEntry(k.toString(), v)),
    };
  }

  static Map<int, int> _intMap(Object? raw) {
    if (raw is Map) {
      final out = <int, int>{};
      raw.forEach((k, v) {
        final i = int.tryParse(k.toString());
        final n = (v is int) ? v : int.tryParse(v.toString());
        if (i != null && n != null) out[i] = n;
      });
      return out;
    }
    return const {};
  }

  factory Reto.fromMap(Map<String, Object?> map) {
    return Reto(
      id: map['id'] as int?,
      titulo: (map['titulo'] as String?) ?? '',
      descripcion: (map['descripcion'] as String?) ?? '',
      puntos: (map['puntos'] as int?) ?? 0,
      fechaInicio:
          DateTime.tryParse((map['fecha_inicio'] as String?) ?? '') ??
          DateTime.now(),
      fechaFin: DateTime.tryParse((map['fecha_fin'] as String?) ?? ''),
      cumplidos: (map['cumplidos'] as List?)?.cast<int>() ?? const [],
      aprobados: (map['aprobados'] as List?)?.cast<int>() ?? const [],
      finalizado: (map['finalizado'] as int? ?? 0) == 1,
      modo: (map['modo'] as String?) ?? modoNormal,
      fechaLluvia: DateTime.tryParse((map['fecha_lluvia'] as String?) ?? ''),
      plazoIndividual: DateTime.tryParse(
        (map['plazo_individual'] as String?) ?? '',
      ),
      ganador: map['ganador'] as int?,
      marcas: _intMap(map['marcas']),
      robados: _intMap(map['robados']),
    );
  }
}
