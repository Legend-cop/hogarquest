class Task {
  final int? id;
  final String titulo;
  final String descripcion;
  final int puntos;
  final String dificultad;
  final DateTime? fechaLimite;
  final String frecuencia;
  final String estado;
  final String dia;

  const Task({
    this.id,
    required this.titulo,
    this.descripcion = '',
    required this.puntos,
    this.dificultad = 'media',
    this.fechaLimite,
    this.frecuencia = 'unica',
    this.estado = 'activa',
    this.dia = '',
  });

  bool get activa => estado == 'activa';

  Task copyWith({
    int? id,
    String? titulo,
    String? descripcion,
    int? puntos,
    String? dificultad,
    DateTime? fechaLimite,
    String? frecuencia,
    String? estado,
    String? dia,
  }) {
    return Task(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      puntos: puntos ?? this.puntos,
      dificultad: dificultad ?? this.dificultad,
      fechaLimite: fechaLimite ?? this.fechaLimite,
      frecuencia: frecuencia ?? this.frecuencia,
      estado: estado ?? this.estado,
      dia: dia ?? this.dia,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'descripcion': descripcion,
      'puntos': puntos,
      'dificultad': dificultad,
      'fecha_limite': fechaLimite?.toIso8601String(),
      'frecuencia': frecuencia,
      'estado': estado,
      'dia': dia,
    };
  }

  factory Task.fromMap(Map<String, Object?> map) {
    return Task(
      id: map['id'] as int?,
      titulo: map['titulo'] as String,
      descripcion: (map['descripcion'] as String?) ?? '',
      puntos: (map['puntos'] as int?) ?? 0,
      dificultad: (map['dificultad'] as String?) ?? 'media',
      fechaLimite: map['fecha_limite'] != null
          ? DateTime.tryParse(map['fecha_limite'] as String)
          : null,
      frecuencia: (map['frecuencia'] as String?) ?? 'unica',
      estado: (map['estado'] as String?) ?? 'activa',
      dia: (map['dia'] as String?) ?? '',
    );
  }
}
