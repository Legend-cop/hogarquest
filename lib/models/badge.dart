/// Métricas que una insignia puede medir. El valor actual se calcula en
/// tiempo real a partir del historial del integrante.
const List<String> metricasInsignia = [
  'limpieza',
  'cocina',
  'orden',
  'puntual',
  'racha',
  'nivel',
  'diarias',
  'tareas',
];

/// Etiqueta legible de cada métrica.
String etiquetaMetrica(String metrica) => switch (metrica) {
  'limpieza' => 'Tareas de limpieza',
  'cocina' => 'Tareas de cocina',
  'orden' => 'Tareas de orden',
  'puntual' => 'Tareas puntuales',
  'racha' => 'Días de racha',
  'nivel' => 'Nivel alcanzado',
  'diarias' => 'Máx. tareas en un día',
  _ => 'Tareas aprobadas',
};

class Badge {
  final int? id;
  final String nombre;
  final String descripcion;
  final String icono;

  /// Valor objetivo que hay que alcanzar para lograrla.
  final int meta;

  /// Métrica que mide (ver [metricasInsignia]).
  final String metrica;

  const Badge({
    this.id,
    required this.nombre,
    required this.descripcion,
    this.icono = 'emoji_events',
    this.meta = 1,
    this.metrica = 'tareas',
  });

  Badge copyWith({
    int? id,
    String? nombre,
    String? descripcion,
    String? icono,
    int? meta,
    String? metrica,
  }) {
    return Badge(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      icono: icono ?? this.icono,
      meta: meta ?? this.meta,
      metrica: metrica ?? this.metrica,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'icono': icono,
      'meta': meta,
      'metrica': metrica,
    };
  }

  factory Badge.fromMap(Map<String, Object?> map) {
    return Badge(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      descripcion: (map['descripcion'] as String?) ?? '',
      icono: (map['icono'] as String?) ?? 'emoji_events',
      meta: (map['meta'] as int?) ?? 1,
      metrica: (map['metrica'] as String?) ?? 'tareas',
    );
  }
}
