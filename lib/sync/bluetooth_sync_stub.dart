import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import 'bluetooth_peer.dart';

/// Implementación no disponible fuera de Android (Nearby Connections es solo
/// Android). La UI muestra el estado "no disponible".
class BluetoothSyncService {
  static final BluetoothSyncService instance = BluetoothSyncService();

  final ValueNotifier<bool> activo = ValueNotifier(false);
  final ValueNotifier<String> mensaje =
      ValueNotifier('Sincronización Bluetooth no disponible en esta plataforma');
  final ValueNotifier<List<BluetoothPeer>> peers = ValueNotifier(const []);
  final ValueNotifier<DateTime?> ultimaSync = ValueNotifier(null);

  bool get disponible => false;

  Future<void> start(DatabaseHelper db) async {}
  Future<void> stop() async {}
  Future<void> sincronizarAhora() async {}
}
