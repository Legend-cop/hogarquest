class Reward {
  final int? id;
  final String nombre;
  final String descripcion;
  final int costoPuntos;

  const Reward({
    this.id,
    required this.nombre,
    this.descripcion = '',
    required this.costoPuntos,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'costo_puntos': costoPuntos,
    };
  }

  factory Reward.fromMap(Map<String, Object?> map) {
    return Reward(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      descripcion: (map['descripcion'] as String?) ?? '',
      costoPuntos: (map['costo_puntos'] as int?) ?? 0,
    );
  }
}
