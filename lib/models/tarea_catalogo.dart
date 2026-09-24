/// Entrada del catálogo de tareas: nombre, puntos y metadatos por defecto.
/// Al crear una tarea nueva, si el título coincide con una entrada del
/// catálogo, puntos/categoría/dificultad ya vienen prellenados.
class TareaCatalogo {
  final int? id;
  final String titulo;
  final int puntos;
  final String categoria;
  final String dificultad;

  const TareaCatalogo({
    this.id,
    required this.titulo,
    required this.puntos,
    this.categoria = 'General',
    this.dificultad = 'media',
  });

  TareaCatalogo copyWith({
    int? id,
    String? titulo,
    int? puntos,
    String? categoria,
    String? dificultad,
  }) {
    return TareaCatalogo(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      puntos: puntos ?? this.puntos,
      categoria: categoria ?? this.categoria,
      dificultad: dificultad ?? this.dificultad,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'puntos': puntos,
      'categoria': categoria,
      'dificultad': dificultad,
    };
  }

  factory TareaCatalogo.fromMap(Map<String, Object?> map) {
    return TareaCatalogo(
      id: map['id'] as int?,
      titulo: (map['titulo'] as String?) ?? '',
      puntos: (map['puntos'] as int?) ?? 0,
      categoria: (map['categoria'] as String?) ?? 'General',
      dificultad: (map['dificultad'] as String?) ?? 'media',
    );
  }
}
