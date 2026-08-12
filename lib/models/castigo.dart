/// Castigo aplicado a un integrante.
/// - `tarea`: quitar puntos por no cumplir la tarea asignada (automático al vencer).
/// - `disciplina`: castigo por portarse mal / desobediencia (del admin, aparte).
class Castigo {
  final int? id;
  final int usuarioId;
  final String motivo;
  final int puntos;
  final String tipo; // 'tarea' | 'disciplina' (también acepta 'vencida'/'manual' antiguos)
  final int? tareaId;
  final DateTime fecha;

  const Castigo({
    this.id,
    required this.usuarioId,
    required this.motivo,
    required this.puntos,
    this.tipo = 'disciplina',
    this.tareaId,
    required this.fecha,
  });

  /// ¿Es castigo de disciplina (portarse mal / desobediencia)?
  bool get esDisciplina => tipo == 'disciplina' || tipo == 'manual';

  /// ¿Es quita de puntos por tarea no cumplida?
  bool get esTarea => tipo == 'tarea' || tipo == 'vencida';

  Castigo copyWith({
    int? id,
    int? usuarioId,
    String? motivo,
    int? puntos,
    String? tipo,
    int? tareaId,
    DateTime? fecha,
  }) {
    return Castigo(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      motivo: motivo ?? this.motivo,
      puntos: puntos ?? this.puntos,
      tipo: tipo ?? this.tipo,
      tareaId: tareaId ?? this.tareaId,
      fecha: fecha ?? this.fecha,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'motivo': motivo,
      'puntos': puntos,
      'tipo': tipo,
      'tarea_id': tareaId,
      'fecha': fecha.toIso8601String(),
    };
  }

  factory Castigo.fromMap(Map<String, Object?> map) {
    return Castigo(
      id: map['id'] as int?,
      usuarioId: map['usuario_id'] as int,
      motivo: (map['motivo'] as String?) ?? '',
      puntos: (map['puntos'] as int?) ?? 0,
      tipo: (map['tipo'] as String?) ?? 'disciplina',
      tareaId: map['tarea_id'] as int?,
      fecha: DateTime.tryParse((map['fecha'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}
