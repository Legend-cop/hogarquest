class Assignment {
  final int? id;
  final int usuarioId;
  final int tareaId;
  final bool completada;
  final bool aprobada;
  final bool castigada;
  final DateTime? fechaCompletada;
  final DateTime? fechaAsignada;
  final DateTime? fechaAprobada;

  const Assignment({
    this.id,
    required this.usuarioId,
    required this.tareaId,
    this.completada = false,
    this.aprobada = false,
    this.castigada = false,
    this.fechaCompletada,
    this.fechaAsignada,
    this.fechaAprobada,
  });

  Assignment copyWith({
    int? id,
    int? usuarioId,
    int? tareaId,
    bool? completada,
    bool? aprobada,
    bool? castigada,
    DateTime? fechaCompletada,
    DateTime? fechaAsignada,
    DateTime? fechaAprobada,
  }) {
    return Assignment(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      tareaId: tareaId ?? this.tareaId,
      completada: completada ?? this.completada,
      aprobada: aprobada ?? this.aprobada,
      castigada: castigada ?? this.castigada,
      fechaCompletada: fechaCompletada ?? this.fechaCompletada,
      fechaAsignada: fechaAsignada ?? this.fechaAsignada,
      fechaAprobada: fechaAprobada ?? this.fechaAprobada,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'tarea_id': tareaId,
      'completada': completada ? 1 : 0,
      'aprobada': aprobada ? 1 : 0,
      'castigada': castigada ? 1 : 0,
      'fecha_completada': fechaCompletada?.toIso8601String(),
      'fecha_asignada': fechaAsignada?.toIso8601String(),
      'fecha_aprobada': fechaAprobada?.toIso8601String(),
    };
  }

  factory Assignment.fromMap(Map<String, Object?> map) {
    return Assignment(
      id: map['id'] as int?,
      usuarioId: map['usuario_id'] as int,
      tareaId: map['tarea_id'] as int,
      completada: (map['completada'] as int? ?? 0) == 1,
      aprobada: (map['aprobada'] as int? ?? 0) == 1,
      castigada: (map['castigada'] as int? ?? 0) == 1,
      fechaCompletada: map['fecha_completada'] != null
          ? DateTime.tryParse(map['fecha_completada'] as String)
          : null,
      fechaAsignada: map['fecha_asignada'] != null
          ? DateTime.tryParse(map['fecha_asignada'] as String)
          : null,
      fechaAprobada: map['fecha_aprobada'] != null
          ? DateTime.tryParse(map['fecha_aprobada'] as String)
          : null,
    );
  }
}
