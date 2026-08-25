/// Stub de sincronización local para la versión web (no usa sockets).
/// En web no hay acceso a dart:io, así que la sincronización P2P simplemente
/// no hace nada. La app sigue funcionando con la sincronización por la nube.
class LocalSyncService {
  static final LocalSyncService instance = LocalSyncService._();

  LocalSyncService._();

  bool get isRunning => false;

  Future<void> start(dynamic db) async {}

  Future<void> stop() async {}

  void agregarPeerManual(String ip, [int port = 8765]) {}

  Future<void> sincronizarAhora() async {}
}
