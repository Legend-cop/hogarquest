/// Información de un dispositivo detectado en la sincronización local.
class PeerInfo {
  final String ip;
  final int port;
  final DateTime lastSeen;

  PeerInfo({required this.ip, required this.port, required this.lastSeen});
}
