import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

import '../db/database_helper.dart';
import 'bluetooth_peer.dart';

/// Canal compartido con el código nativo (MainActivity.kt) para acciones que
/// requieren APIs del sistema no expuestas por plugins.
const MethodChannel _channelAjustes = MethodChannel('hogarquest/ajustes');

/// Intenta apagar el Bluetooth del celular. En Android 12+ el sistema bloquea
/// que una app lo haga, por lo que normalmente devuelve `false`.
Future<bool> desactivarBluetooth() async {
  try {
    final ok = await _channelAjustes.invokeMethod<bool>('desactivarBluetooth');
    return ok == true;
  } catch (_) {
    return false;
  }
}

/// Abre los ajustes del sistema donde el usuario puede apagar o encender el
/// Bluetooth (Android 12+ no permite que la app lo haga por sí sola).
Future<void> abrirAjustesBluetooth() async {
  try {
    await _channelAjustes.invokeMethod<void>('abrirAjustesBluetooth');
  } catch (_) {
    // Silencioso: el aviso del sistema sigue siendo la alternativa.
  }
}

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
  final Set<String> _enIntento = {};
  final Map<String, int> _reintentos = {};
  final Map<String, String> _nombres = {};
  final Random _rand = Random();
  bool _descubriendo = false;

  Future<void> start(DatabaseHelper db) async {
    _db = db;
    if (activo.value) return;
    try {
      if (!await _solicitarPermisos()) {
        mensaje.value = 'Permisos de Bluetooth/ubicación denegados';
        return;
      }
      if (!await _activarUbicacion()) return;
      await _nearby.startAdvertising(
        _nombreServicio(),
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      await _iniciarDiscovery();
      activo.value = true;
      mensaje.value = 'Buscando dispositivos cercanos…';
    } catch (e) {
      mensaje.value = 'No se pudo iniciar: $e';
      debugPrint('BluetoothSync start: $e');
    }
  }

  String _nombreServicio() {
    final c = _db?.householdCode;
    return (c != null && c.isNotEmpty) ? c : 'HogarQuest';
  }

  Future<void> _iniciarDiscovery() async {
    await _nearby.startDiscovery(
      _nombreServicio(),
      Strategy.P2P_CLUSTER,
      onEndpointFound: _onEndpointFound,
      onEndpointLost: _onEndpointLost,
    );
    _descubriendo = true;
  }

  Future<void> stop() async {
    try {
      await _nearby.stopAllEndpoints();
      await _nearby.stopAdvertising();
      await _nearby.stopDiscovery();
    } catch (e) {
      debugPrint('BluetoothSync stop: $e');
    }
    _descubriendo = false;
    _conectados.clear();
    _enIntento.clear();
    _reintentos.clear();
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

  /// Nearby Connections necesita la ubicación del sistema encendida para
  /// escanear. Si está apagada se lleva al usuario a los ajustes de ubicación
  /// (no a los de la app) y el servicio no continúa hasta que la active.
  Future<bool> _activarUbicacion() async {
    try {
      final status = await Permission.location.serviceStatus;
      if (status != ServiceStatus.enabled) {
        mensaje.value =
            'Activa la ubicación del celular para poder buscar dispositivos.';
        await _channelAjustes.invokeMethod<void>('abrirAjustesUbicacion');
        return false;
      }
    } catch (e) {
      debugPrint('BluetoothSync ubicacion: $e');
    }
    return true;
  }

  Future<void> _onEndpointFound(String id, String name, String serviceId) async {
    _nombres[id] = name;
    _actualizarPeers();
    // Solo nos conectamos con dispositivos del mismo hogar.
    if (name != _db?.householdCode) return;
    await _conectar(id, name);
  }

  /// Pide la conexión con jitter. Si ambos celulares lo hacen al mismo
  /// tiempo, Nearby falla uno con 8012 (STATUS_ENDPOINT_IO_ERROR), el error
  /// "simultaneous connection clash" documentado por Google; el tiempo
  /// aleatorio hace que uno llegue primero y el otro reciba la conexión
  /// entrante.
  Future<void> _conectar(String id, String nombre) async {
    if (_conectados.contains(id) || _enIntento.contains(id)) return;
    if ((_reintentos[id] ?? 0) >= 3) return;
    _enIntento.add(id);
    try {
      await Future.delayed(Duration(milliseconds: 700 + _rand.nextInt(1600)));
      if (!_nombres.containsKey(id) || _conectados.contains(id)) return;
      await _nearby.requestConnection(
        _nombreServicio(),
        id,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      mensaje.value = 'Conectando con $nombre…';
    } catch (e) {
      debugPrint('BluetoothSync requestConnection: $e');
      if (!_conectados.contains(id)) unawaited(_reintentar(id, nombre));
    } finally {
      _enIntento.remove(id);
    }
  }

  /// Reintento con el remedio documentado por Google para 8012: detener
  /// discovery, esperar 3 s y volver a intentar (máximo 3 veces por endpoint).
  Future<void> _reintentar(String id, String nombre) async {
    final intento = (_reintentos[id] ?? 0) + 1;
    _reintentos[id] = intento;
    if (intento >= 3) {
      mensaje.value =
          'No se pudo conectar con $nombre. Acércate un poco y vuelve a '
          'intentarlo.';
      await _reanudarDiscovery();
      return;
    }
    mensaje.value = 'Reintentando conexión con $nombre (intento $intento de 3)…';
    try {
      await _nearby.stopDiscovery();
      _descubriendo = false;
    } catch (_) {}
    await Future.delayed(const Duration(seconds: 3));
    if (!activo.value || _conectados.contains(id)) return;
    if (!_nombres.containsKey(id)) {
      _reintentos.remove(id);
      await _reanudarDiscovery();
      return;
    }
    await _conectar(id, nombre);
    await _reanudarDiscovery();
  }

  /// Reanuda discovery si quedó detenido y no hay conexiones activas.
  Future<void> _reanudarDiscovery() async {
    if (!activo.value || _conectados.isNotEmpty || _descubriendo) return;
    try {
      await _iniciarDiscovery();
    } catch (e) {
      debugPrint('BluetoothSync reanudar discovery: $e');
    }
  }

  void _onEndpointLost(String? id) {
    if (id != null) {
      _nombres.remove(id);
      _enIntento.remove(id);
      _reintentos.remove(id);
    }
    _actualizarPeers();
  }

  Future<void> _onConnectionInitiated(String id, ConnectionInfo info) async {
    if (info.endpointName != _db?.householdCode) {
      try {
        await _nearby.rejectConnection(id);
      } catch (_) {}
      return;
    }
    // Si mientras esperábamos nuestra petición llegó una conexión entrante
    // del mismo endpoint, se atiende esta (carrera resuelta sin error).
    _enIntento.remove(id);
    try {
      await _nearby.acceptConnection(id, onPayLoadRecieved: _onPayloadReceived);
    } catch (e) {
      debugPrint('BluetoothSync acceptConnection: $e');
    }
  }

  void _onConnectionResult(String id, Status status) {
    _enIntento.remove(id);
    final nombre = _nombres[id] ?? 'el otro celular';
    if (status == Status.CONNECTED) {
      _reintentos.remove(id);
      _conectados.add(id);
      mensaje.value = 'Conectado con ${_conectados.length} dispositivo(s)';
      unawaited(_actualizarDiscovery());
      _enviarDb(id);
    } else {
      _conectados.remove(id);
      if (status == Status.REJECTED) {
        _reintentos.remove(id);
        mensaje.value = '$nombre rechazó la conexión.';
      } else {
        mensaje.value = 'La conexión con $nombre falló.';
        if (_nombres.containsKey(id) && activo.value) {
          unawaited(_reintentar(id, nombre));
        }
      }
      _actualizarPeers();
    }
  }

  void _onDisconnected(String id) {
    _conectados.remove(id);
    _enIntento.remove(id);
    _reintentos.remove(id);
    _actualizarPeers();
    mensaje.value = _conectados.isEmpty
        ? 'Buscando dispositivos cercanos…'
        : 'Conectado con ${_conectados.length} dispositivo(s)';
    unawaited(_actualizarDiscovery());
  }

  /// Google recomienda evitar discovery mientras hay conexiones activas
  /// (compite por ancho de banda y provoca caídas/IO_ERROR). El advertising
  /// sigue corriendo, así que otros celulares aún pueden encontrarnos y
  /// conectarse a nosotros; al quedar sin conexiones se reanuda.
  Future<void> _actualizarDiscovery() async {
    if (!activo.value) return;
    try {
      if (_conectados.isNotEmpty && _descubriendo) {
        await _nearby.stopDiscovery();
        _descubriendo = false;
      } else if (_conectados.isEmpty && !_descubriendo) {
        await _iniciarDiscovery();
      }
    } catch (e) {
      debugPrint('BluetoothSync discovery toggle: $e');
    }
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
      // onError atrapa el error async: sin esto la excepción subiría al
      // handler global y abriría la ventanita "Error detectado".
      unawaited(
        _nearby.sendBytesPayload(endpointId, bytes).then<void>(
          (_) {},
          onError: (Object e) => debugPrint('BluetoothSync send: $e'),
        ),
      );
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
