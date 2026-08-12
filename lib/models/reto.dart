/// Reto semanal: misión familiar con puntos bonus.
/// El admin lo crea, los integrantes marcan si lo cumplieron y el admin aprueba.
class Reto {
  final int? id;
  final String titulo;
  final String descripcion;
  final int puntos;
  final DateTime fechaInicio; // lunes de la semana del reto
  final List<int> cumplidos; // ids de usuarios que lo cumplieron
  final List<int> aprobados; // ids de usuarios aprobados (reciben puntos)
  final bool finalizado;

  const Reto({
    this.id,
    required this.titulo,
    required this.descripcion,
    required this.puntos,
    required this.fechaInicio,
    this.cumplidos = const [],
    this.aprobados = const [],
    this.finalizado = false,
  });

  bool perteneceASemana(DateTime semana) {
    final a = DateTime(semana.year, semana.month, semana.day);
    final b = DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day);
    final diff = a.difference(b).inDays;
    return diff >= 0 && diff < 7;
  }

  bool get vigente => !finalizado;

  Reto copyWith({
    int? id,
    String? titulo,
    String? descripcion,
    int? puntos,
    DateTime? fechaInicio,
    List<int>? cumplidos,
    List<int>? aprobados,
    bool? finalizado,
  }) {
    return Reto(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      puntos: puntos ?? this.puntos,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      cumplidos: cumplidos ?? this.cumplidos,
      aprobados: aprobados ?? this.aprobados,
      finalizado: finalizado ?? this.finalizado,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'descripcion': descripcion,
      'puntos': puntos,
      'fecha_inicio': fechaInicio.toIso8601String(),
      'cumplidos': cumplidos,
      'aprobados': aprobados,
      'finalizado': finalizado ? 1 : 0,
    };
  }

  factory Reto.fromMap(Map<String, Object?> map) {
    return Reto(
      id: map['id'] as int?,
      titulo: (map['titulo'] as String?) ?? '',
      descripcion: (map['descripcion'] as String?) ?? '',
      puntos: (map['puntos'] as int?) ?? 0,
      fechaInicio: DateTime.tryParse((map['fecha_inicio'] as String?) ?? '') ??
          DateTime.now(),
      cumplidos: (map['cumplidos'] as List?)?.cast<int>() ?? const [],
      aprobados: (map['aprobados'] as List?)?.cast<int>() ?? const [],
      finalizado: (map['finalizado'] as int? ?? 0) == 1,
    );
  }
}