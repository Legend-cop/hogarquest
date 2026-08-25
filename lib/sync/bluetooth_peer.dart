/// Dispositivo detectado/conectado durante la sincronización Bluetooth local.
class BluetoothPeer {
  /// Identificador del endpoint que entrega Nearby Connections.
  final String id;

  /// Nombre del endpoint (en nuestro caso, el código de hogar del dispositivo).
  final String nombre;

  /// Momento en que se vio por última vez.
  final DateTime visto;

  BluetoothPeer({
    required this.id,
    required this.nombre,
    DateTime? visto,
  }) : visto = visto ?? DateTime.now();
}
