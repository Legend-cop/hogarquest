import 'dart:async';

import 'peer_info.dart';

/// Stub de sincronización local para la versión web (no usa sockets).
/// En web no hay acceso a dart:io, así que la sincronización P2P simplemente
/// no hace nada. La app sigue funcionando con la sincronización por la nube.
class LocalSyncService {
  static final LocalSyncService instance = LocalSyncService._();

  LocalSyncService._();

  bool get isRunning => false;

  String? get householdCode => null;

  List<PeerInfo> get peersDetectados => const [];

  DateTime? get ultimaSincronizacion => null;

  Stream<void> get onCambio => const Stream.empty();

  Future<void> start(dynamic db) async {}

  Future<void> stop() async {}

  void agregarPeerManual(String ip, [int port = 8765]) {}

  void quitarPeer(String ip) {}

  Future<void> sincronizarAhora() async {}
}
