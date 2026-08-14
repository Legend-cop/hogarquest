/// Entrada del catálogo de tareas: nombre y puntos por defecto.
/// Al crear una tarea nueva, si el título coincide con una entrada del
/// catálogo, los puntos ya vienen prellenados (y se pueden editar).
class TareaCatalogo {
  final int? id;
  final String titulo;
  final int puntos;

  const TareaCatalogo({this.id, required this.titulo, required this.puntos});

  TareaCatalogo copyWith({int? id, String? titulo, int? puntos}) {
    return TareaCatalogo(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      puntos: puntos ?? this.puntos,
    );
  }

  Map<String, Object?> toMap() {
    return {'id': id, 'titulo': titulo, 'puntos': puntos};
  }

  factory TareaCatalogo.fromMap(Map<String, Object?> map) {
    return TareaCatalogo(
      id: map['id'] as int?,
      titulo: (map['titulo'] as String?) ?? '',
      puntos: (map['puntos'] as int?) ?? 0,
    );
  }
}