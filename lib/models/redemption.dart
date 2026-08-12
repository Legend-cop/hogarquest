class Redemption {
  final int? id;
  final int usuarioId;
  final int recompensaId;
  final DateTime fecha;
  final String estado; // 'pendiente' | 'entregada'

  const Redemption({
    this.id,
    required this.usuarioId,
    required this.recompensaId,
    required this.fecha,
    this.estado = 'pendiente',
  });

  Redemption copyWith({
    int? id,
    int? usuarioId,
    int? recompensaId,
    DateTime? fecha,
    String? estado,
  }) {
    return Redemption(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      recompensaId: recompensaId ?? this.recompensaId,
      fecha: fecha ?? this.fecha,
      estado: estado ?? this.estado,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'recompensa_id': recompensaId,
      'fecha': fecha.toIso8601String(),
      'estado': estado,
    };
  }

  factory Redemption.fromMap(Map<String, Object?> map) {
    return Redemption(
      id: map['id'] as int?,
      usuarioId: map['usuario_id'] as int,
      recompensaId: map['recompensa_id'] as int,
      fecha: DateTime.tryParse(map['fecha'] as String) ?? DateTime.now(),
      estado: (map['estado'] as String?) ?? 'pendiente',
    );
  }
}
