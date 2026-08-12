class Redemption {
  final int? id;
  final int usuarioId;
  final int recompensaId;
  final DateTime fecha;

  const Redemption({
    this.id,
    required this.usuarioId,
    required this.recompensaId,
    required this.fecha,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'recompensa_id': recompensaId,
      'fecha': fecha.toIso8601String(),
    };
  }

  factory Redemption.fromMap(Map<String, Object?> map) {
    return Redemption(
      id: map['id'] as int?,
      usuarioId: map['usuario_id'] as int,
      recompensaId: map['recompensa_id'] as int,
      fecha: DateTime.tryParse(map['fecha'] as String) ?? DateTime.now(),
    );
  }
}
