import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import 'peer_info.dart';

/// Sincronización P2P local entre dispositivos de la misma familia, sin
/// necesidad de internet. Cualquier dispositivo puede actuar como "hub":
/// cada uno publica un beacon UDP y expone un servidor HTTP con el estado
/// completo de la base; al descubrirse, se fusionan vía LWW (updated_at).
///
/// FASE 2 (pendiente, no implementada aquí por no poder validarse en este
/// entorno): transporte Bluetooth como fallback cuando no hay Wi-Fi
/// compartido. La arquitectura permite añadirlo sin tocar el merge.
class LocalSyncService {
  static final LocalSyncService instance = LocalSyncService._();

  LocalSyncService._();

  static const int _tcpPort = 8765;
  static const int _udpPort = 8766;
  static const String _path = '/hogarquest/sync';

  DatabaseHelper? _db;
  HttpServer? _http;
  RawDatagramSocket? _udp;
  Timer? _beaconTimer;
  Timer? _syncTimer;
  final Map<String, _Peer> _peers = {};
  final List<String> _localIps = [];
  String? _household;
  bool _running = false;
  DateTime? _ultimaSincronizacion;
  final StreamController<void> _onCambio = StreamController<void>.broadcast();

  /// Notifica cambios de estado (detección de pares, sincronización) a la UI.
  Stream<void> get onCambio => _onCambio.stream;

  bool get isRunning => _running;

  /// Código de hogar que acota la sincronización a la misma familia.
  String? get householdCode => _household;

  /// Dispositivos detectados en la red local (misma familia).
  List<PeerInfo> get peersDetectados =>
      _peers.values.map((p) => PeerInfo(ip: p.ip, port: p.port, lastSeen: p.lastSeen)).toList();

  DateTime? get ultimaSincronizacion => _ultimaSincronizacion;

  void _notificar() {
    if (!_onCambio.isClosed) _onCambio.add(null);
  }

  /// Descubre pares en la misma red y sincroniza con ellos.
  Future<void> start(DatabaseHelper db) async {
    if (_running) return;
    _db = db;
    _household = db.householdCode;
    _running = true;
    await _cargarIpsLocales();
    await _iniciarHttp();
    await _iniciarUdp();
    _beaconTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      try {
        _enviarBeacon();
      } catch (_) {}
    });
    _syncTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      try {
        _sincronizarConPeers();
      } catch (_) {}
    });
    _enviarBeacon();
    debugPrint('[LocalSync] iniciado (hogar: $_household)');
  }

  Future<void> stop() async {
    _running = false;
    _beaconTimer?.cancel();
    _syncTimer?.cancel();
    _beaconTimer = null;
    _syncTimer = null;
    await _http?.close(force: true);
    _udp?.close();
    _http = null;
    _udp = null;
    _peers.clear();
  }

  /// Agrega manualmente la IP de otro dispositivo (fallback si el beacon UDP
  /// está bloqueado por el router).
  void agregarPeerManual(String ip, [int port = _tcpPort]) {
    if (ip.isEmpty) return;
    _peers[ip] = _Peer(ip: ip, port: port, lastSeen: DateTime.now());
    _notificar();
    unawaited(_sincronizarConPeer(_peers[ip]!));
  }

  /// Quita un par agregado manualmente o detectado.
  void quitarPeer(String ip) {
    _peers.remove(ip);
    _notificar();
  }

  /// Fuerza una ronda de sincronización inmediata.
  Future<void> sincronizarAhora() async => _sincronizarConPeers();

  Future<void> _cargarIpsLocales() async {
    try {
      final ifaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      _localIps.clear();
      for (final i in ifaces) {
        for (final a in i.addresses) {
          _localIps.add(a.address);
        }
      }
    } catch (e) {
      debugPrint('[LocalSync] no se pudieron leer IPs locales: $e');
    }
  }

  Future<void> _iniciarHttp() async {
    try {
      _http = await HttpServer.bind(InternetAddress.anyIPv4, _tcpPort);
      _http!.listen(_manejarHttp);
      debugPrint('[LocalSync] servidor HTTP en puerto $_tcpPort');
    } catch (e) {
      debugPrint('[LocalSync] no se pudo iniciar HTTP: $e');
    }
  }

  Future<void> _iniciarUdp() async {
    try {
      _udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _udpPort);
      _udp!.broadcastEnabled = true;
      _udp!.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = _udp!.receive();
          if (dg != null) _procesarBeacon(dg);
        }
      });
      debugPrint('[LocalSync] socket UDP en puerto $_udpPort');
    } catch (e) {
      debugPrint('[LocalSync] no se pudo iniciar UDP: $e');
    }
  }

  Future<void> _manejarHttp(HttpRequest req) async {
    if (req.uri.path != _path) {
      req.response.statusCode = 404;
      await req.response.close();
      return;
    }
    final h = req.headers.value('x-household') ?? '';
    if (h != _household) {
      req.response.statusCode = 403;
      await req.response.close();
      return;
    }
    try {
      if (req.method == 'GET') {
        final data = _db!.exportarParaP2P();
        final body = utf8.encode(jsonEncode(data));
        req.response.headers.contentType = ContentType.json;
        req.response.add(body);
      } else if (req.method == 'POST') {
        final body = await utf8.decodeStream(req);
        final data = jsonDecode(body);
        await _db!.mezclarDesdePar(data as Map<String, dynamic>);
        req.response.statusCode = 200;
      } else {
        req.response.statusCode = 405;
      }
    } catch (e) {
      req.response.statusCode = 400;
      debugPrint('[LocalSync] error manejando ${req.method}: $e');
    }
    await req.response.close();
  }

  void _enviarBeacon() {
    if (_udp == null) return;
    final msg = jsonEncode({
      'type': 'hq-beacon',
      'household': _household,
      'tcp': _tcpPort,
    });
    try {
      _udp!.send(utf8.encode(msg), InternetAddress('255.255.255.255'), _udpPort);
    } catch (e) {
      debugPrint('[LocalSync] no se pudo enviar beacon: $e');
    }
  }

  void _procesarBeacon(Datagram dg) {
    try {
      final m = jsonDecode(utf8.decode(dg.data));
      if (m is! Map) return;
      if (m['type'] != 'hq-beacon') return;
      if (m['household'] != _household) return;
      final ip = dg.address.address;
      if (_localIps.contains(ip)) return;
      final tcp = m['tcp'] as int? ?? _tcpPort;
      _peers[ip] = _Peer(ip: ip, port: tcp, lastSeen: DateTime.now());
      _notificar();
    } catch (_) {}
  }

  Future<void> _sincronizarConPeers() async {
    if (_db == null || _household == null) return;
    final ahora = DateTime.now();
    _peers.removeWhere(
        (_, p) => ahora.difference(p.lastSeen).inSeconds > 25);
    final copia = List<_Peer>.from(_peers.values);
    for (final p in copia) {
      await _sincronizarConPeer(p);
    }
  }

  Future<void> _sincronizarConPeer(_Peer p) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      await Future(() async {
        // Tirar del estado del par.
        final req = await client.get(p.ip, p.port, _path);
        req.headers.add('x-household', _household!);
        final resp = await req.close();
        if (resp.statusCode == 200) {
          final body = await resp.transform(utf8.decoder).join();
          final data = jsonDecode(body);
          await _db!.mezclarDesdePar(data as Map<String, dynamic>);
          _ultimaSincronizacion = DateTime.now();
          _notificar();
        }
        // Empujar nuestro estado al par.
        final req2 = await client.post(p.ip, p.port, _path);
        req2.headers.add('x-household', _household!);
        req2.headers.contentType = ContentType.json;
        req2.write(jsonEncode(_db!.exportarParaP2P()));
        final resp2 = await req2.close();
        await resp2.drain();
      }).timeout(const Duration(seconds: 8));
    } catch (e) {
      // El par no está disponible en este momento; se reintenta luego.
      debugPrint('[LocalSync] no se pudo sincronizar con ${p.ip}: $e');
    } finally {
      client.close(force: true);
    }
  }
}

class _Peer {
  _Peer({required this.ip, required this.port, required this.lastSeen});
  final String ip;
  final int port;
  DateTime lastSeen;
}
