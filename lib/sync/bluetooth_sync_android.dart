import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:location/location.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

import '../db/database_helper.dart';
import 'bluetooth_peer.dart';

/// Sincronización P2P local sin internet usando Nearby Connections (Google).
///
/// Funciona sobre Bluetooth y Wi-Fi punto a punto. Los dispositivos se anuncian
/// y se descubren usando como nombre el código de hogar, de modo que la
/// sincronización solo ocurre entre dispositivos de la misma familia. Al
/// conectar, cada lado envía una copia completa de la base y la fusiona con la
/// suya (LWW + tombstones) a través de [DatabaseHelper.mezclarDesdePar].
class BluetoothSyncService {
  static final BluetoothSyncService instance = BluetoothSyncService();

  final Nearby _nearby = Nearby();
  DatabaseHelper? _db;

  final ValueNotifier<bool> activo = ValueNotifier(false);
  final ValueNotifier<String> mensaje = ValueNotifier('Inactivo');
  final ValueNotifier<List<BluetoothPeer>> peers = ValueNotifier(const []);
  final ValueNotifier<DateTime?> ultimaSync = ValueNotifier(null);

  bool get disponible => true;

  final Set<String> _conectados = {};
  final Map<String, String> _nombres = {};

  Future<void> start(DatabaseHelper db) async {
    _db = db;
    if (activo.value) return;
    try {
      if (!await _solicitarPermisos()) {
        mensaje.value = 'Permisos de Bluetooth/ubicación denegados';
        return;
      }
      await _activarUbicacion();
      final userName = db.householdCode.isNotEmpty ? db.householdCode : 'HogarQuest';
      await _nearby.startAdvertising(
        userName,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      await _nearby.startDiscovery(
        userName,
        Strategy.P2P_CLUSTER,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
      );
      activo.value = true;
      mensaje.value = 'Buscando dispositivos cercanos…';
    } catch (e) {
      mensaje.value = 'No se pudo iniciar: $e';
      debugPrint('BluetoothSync start: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _nearby.stopAllEndpoints();
      await _nearby.stopAdvertising();
      await _nearby.stopDiscovery();
    } catch (e) {
      debugPrint('BluetoothSync stop: $e');
    }
    _conectados.clear();
    _nombres.clear();
    activo.value = false;
    mensaje.value = 'Inactivo';
    _actualizarPeers();
  }

  /// Reenvía nuestra base a todos los dispositivos conectados.
  Future<void> sincronizarAhora() async {
    for (final id in List<String>.from(_conectados)) {
      _enviarDb(id);
    }
  }

  Future<bool> _solicitarPermisos() async {
    try {
      final estados = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.nearbyWifiDevices,
        Permission.locationWhenInUse,
      ].request();
      return estados.values.every((e) => e.isGranted);
    } catch (e) {
      debugPrint('BluetoothSync permisos: $e');
      return false;
    }
  }

  Future<void> _activarUbicacion() async {
    try {
      final loc = Location();
      if (!await loc.serviceEnabled()) {
        await loc.requestService();
      }
    } catch (e) {
      debugPrint('BluetoothSync ubicacion: $e');
    }
  }

  void _onEndpointFound(String id, String name, String serviceId) {
    _nombres[id] = name;
    _actualizarPeers();
    // Solo nos conectamos con dispositivos del mismo hogar.
    if (name != _db?.householdCode) return;
    try {
      _nearby.requestConnection(
        _db?.householdCode ?? 'HogarQuest',
        id,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
    } catch (e) {
      debugPrint('BluetoothSync requestConnection: $e');
    }
  }

  void _onEndpointLost(String? id) {
    if (id != null) _nombres.remove(id);
    _actualizarPeers();
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    if (info.endpointName != _db?.householdCode) {
      try {
        _nearby.rejectConnection(id);
      } catch (_) {}
      return;
    }
    try {
      _nearby.acceptConnection(
        id,
        onPayLoadRecieved: _onPayloadReceived,
      );
    } catch (e) {
      debugPrint('BluetoothSync acceptConnection: $e');
    }
  }

  void _onConnectionResult(String id, Status status) {
    if (status == Status.CONNECTED) {
      _conectados.add(id);
      mensaje.value = 'Conectado con ${_conectados.length} dispositivo(s)';
      _enviarDb(id);
    } else {
      _conectados.remove(id);
    }
  }

  void _onDisconnected(String id) {
    _conectados.remove(id);
    _actualizarPeers();
  }

  void _onPayloadReceived(String id, Payload payload) {
    if (payload.type != PayloadType.BYTES) return;
    final bytes = payload.bytes;
    if (bytes == null) return;
    try {
      final texto = utf8.decode(bytes);
      final data = jsonDecode(texto);
      if (data is Map && _db != null) {
        unawaited(_db!.mezclarDesdePar(Map<String, dynamic>.from(data)));
        _db!.onRemoteChange?.call();
        ultimaSync.value = DateTime.now();
        mensaje.value = 'Sincronizado con ${_conectados.length} dispositivo(s)';
      }
    } catch (e) {
      debugPrint('BluetoothSync recv: $e');
    }
  }

  void _enviarDb(String endpointId) {
    final db = _db;
    if (db == null) return;
    try {
      final data = db.exportarParaP2P();
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));
      unawaited(_nearby.sendBytesPayload(endpointId, bytes));
    } catch (e) {
      debugPrint('BluetoothSync send: $e');
    }
  }

  void _actualizarPeers() {
    peers.value = _nombres.entries
        .map((e) => BluetoothPeer(id: e.key, nombre: e.value))
        .toList();
  }
}
