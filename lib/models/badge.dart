class Badge {
  final int? id;
  final String nombre;
  final String descripcion;
  final String icono;

  const Badge({
    this.id,
    required this.nombre,
    required this.descripcion,
    this.icono = 'emoji_events',
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'icono': icono,
    };
  }

  factory Badge.fromMap(Map<String, Object?> map) {
    return Badge(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      descripcion: (map['descripcion'] as String?) ?? '',
      icono: (map['icono'] as String?) ?? 'emoji_events',
    );
  }
}
