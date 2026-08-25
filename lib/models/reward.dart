class Reward {
  final int? id;
  final String nombre;
  final String descripcion;
  final int costoPuntos;
  final String foto;
  final String fotoLocal;

  const Reward({
    this.id,
    required this.nombre,
    this.descripcion = '',
    required this.costoPuntos,
    this.foto = '',
    this.fotoLocal = '',
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'costo_puntos': costoPuntos,
      'foto': foto,
      'foto_local': fotoLocal,
    };
  }

  factory Reward.fromMap(Map<String, Object?> map) {
    return Reward(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      descripcion: (map['descripcion'] as String?) ?? '',
      costoPuntos: (map['costo_puntos'] as int?) ?? 0,
      foto: (map['foto'] as String?) ?? '',
      fotoLocal: (map['foto_local'] as String?) ?? '',
    );
  }

  Reward copyWith({
    int? id,
    String? nombre,
    String? descripcion,
    int? costoPuntos,
    String? foto,
    String? fotoLocal,
  }) {
    return Reward(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      costoPuntos: costoPuntos ?? this.costoPuntos,
      foto: foto ?? this.foto,
      fotoLocal: fotoLocal ?? this.fotoLocal,
    );
  }
}
