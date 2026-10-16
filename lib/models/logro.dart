/// Logro de progreso ("Logros en camino"): meta que el administrador puede
/// crear, editar y borrar. Mide un tipo de avance del integrante con una
/// meta numérica (ej. "Racha legendaria: 30 días"). A diferencia de las
/// insignias, el admin define libremente el nombre y la meta.
class Logro {
  final int? id;
  final String nombre;

  /// Nombre del icono de la colección (ver `insignia3D`).
  final String icono;

  /// Clave de la métrica que mide (ver [tiposLogro]).
  final String tipo;

  /// Valor objetivo que hay que alcanzar.
  final int meta;

  const Logro({
    this.id,
    required this.nombre,
    this.icono = 'emoji_events',
    required this.tipo,
    this.meta = 1,
  });

  Logro copyWith({
    int? id,
    String? nombre,
    String? icono,
    String? tipo,
    int? meta,
  }) {
    return Logro(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      icono: icono ?? this.icono,
      tipo: tipo ?? this.tipo,
      meta: meta ?? this.meta,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'icono': icono,
      'tipo': tipo,
      'meta': meta,
    };
  }

  factory Logro.fromMap(Map<String, Object?> map) {
    return Logro(
      id: map['id'] as int?,
      nombre: (map['nombre'] as String?) ?? 'Logro',
      icono: (map['icono'] as String?) ?? 'emoji_events',
      tipo: (map['tipo'] as String?) ?? 'tareas',
      meta: (map['meta'] as int?) ?? 1,
    );
  }
}

/// Tipos de métrica que puede medir un logro de progreso.
const List<String> tiposLogro = [
  'semana_perfecta',
  'retos',
  'racha',
  'insignias',
  'tareas',
  'puntos',
  'nivel',
  'diarias',
];

/// Nombre legible de cada tipo de logro.
String etiquetaTipoLogro(String tipo) {
  switch (tipo) {
    case 'semana_perfecta':
      return 'Días activos en una semana';
    case 'retos':
      return 'Retos aprobados';
    case 'racha':
      return 'Días seguidos de racha';
    case 'insignias':
      return 'Insignias coleccionadas';
    case 'tareas':
      return 'Tareas aprobadas';
    case 'puntos':
      return 'Puntos XP';
    case 'nivel':
      return 'Nivel alcanzado';
    case 'diarias':
      return 'Tareas en un mismo día';
    default:
      return 'Avance';
  }
}
