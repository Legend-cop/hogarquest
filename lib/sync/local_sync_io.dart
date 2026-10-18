import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

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
  final Map<String, DateTime> _vecinosAjenos = {};
  final List<String> _localIps = [];
  String? _household;
  String? _ultimaAlerta;
  bool _permisoRedOk = true;
  bool _running = false;
  DateTime? _ultimaSincronizacion;
  final StreamController<void> _onCambio = StreamController<void>.broadcast();

  /// Notifica cambios de estado (detección de pares, sincronización) a la UI.
  Stream<void> get onCambio => _onCambio.stream;

  bool get isRunning => _running;

  /// Código de hogar que acota la sincronización a la misma familia.
  String? get householdCode => _household;

  /// Dispositivos detectados en la red local (misma familia).
  List<PeerInfo> get peersDetectados => _peers.values
      .map((p) => PeerInfo(ip: p.ip, port: p.port, lastSeen: p.lastSeen))
      .toList();

  /// IPs locales de este dispositivo (para comparar subredes).
  List<String> get ipsLocales => List.unmodifiable(_localIps);

  /// Dispositivos HogarQuest detectados en la red con otro código de hogar
  /// (mismo Wi-Fi pero distinta familia: no se sincronizarán con ellos).
  List<String> get vecinosAjenos => List.unmodifiable(_vecinosAjenos.keys);

  /// Última incidencia detectada (código distinto, 403, sin respuesta, ...).
  String? get ultimaAlerta => _ultimaAlerta;

  /// `false` si el permiso de red local fue denegado (Android 17+).
  bool get permisoRedOk => _permisoRedOk;

  /// Borra la alerta visible de la UI.
  void limpiarAlerta() {
    _ultimaAlerta = null;
    _notificar();
  }

  void _fijarAlerta(String texto) {
    if (_ultimaAlerta == texto) return;
    _ultimaAlerta = texto;
    _notificar();
  }

  DateTime? get ultimaSincronizacion => _ultimaSincronizacion;

  void _notificar() {
    if (!_onCambio.isClosed) _onCambio.add(null);
  }

  /// Descubre pares en la misma red y sincroniza con ellos.
  Future<void> start(DatabaseHelper db) async {
    if (_running) return;
    // Android 16+ exige permiso de red local para el beacon UDP.
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final estado = await Permission.accessLocalNetwork.request();
        _permisoRedOk = !estado.isDenied && !estado.isPermanentlyDenied;
        if (!_permisoRedOk) {
          debugPrint('[LocalSync] permiso de red local denegado');
        }
      } catch (e) {
        debugPrint('[LocalSync] permiso de red local: $e');
      }
    }
    _db = db;
    _household = db.householdCode;
    _running = true;
    await _cargarIpsLocales();
    await _iniciarHttp();
    await _iniciarUdp();
    // Beacon periódico para descubrir pares y ronda de sync periódica.
    _beaconTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_running) _enviarBeacon();
    });
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_running) unawaited(_sincronizarConPeers());
    });
    _enviarBeacon();
    unawaited(_sincronizarConPeers());
    debugPrint('[LocalSync] iniciado (hogar: $_household)');
    _notificar();
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
    _vecinosAjenos.clear();
    _ultimaAlerta = null;
  }

  /// Agrega manualmente la IP de otro dispositivo (fallback si el beacon UDP
  /// está bloqueado por el router).
  void agregarPeerManual(String ip, [int port = _tcpPort]) {
    if (ip.isEmpty) return;
    _peers[ip] = _Peer(ip: ip, port: port, lastSeen: DateTime.now());
    _ultimaAlerta = null;
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
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _udpPort,
      );
      socket.broadcastEnabled = true;
      socket.listen(
        (event) {
          if (event == RawSocketEvent.read) {
            final dg = socket.receive();
            if (dg != null) _procesarBeacon(dg);
          }
        },
        // Errores de red del socket (ej. EPERM sin Wi‑Fi o doze) llegan
        // por el stream, no por el try/catch de send(); se tragan aquí
        // para que no se conviertan en ventanita "Error detectado".
        onError: (Object e) =>
            debugPrint('[LocalSync] udp socket: $e'),
      );
      _udp = socket;
      debugPrint('[LocalSync] socket UDP en puerto $_udpPort');
    } catch (_) {
      _udp = null;
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
    final u = _udp;
    if (u == null) return;
    // Sin interfaz de red activa (sin Wi‑Fi, solo datos móviles apagados,
    // doze) el broadcast falla con EPERM; se omite y se reintenta luego.
    if (_localIps.isEmpty) {
      unawaited(_cargarIpsLocales());
      return;
    }
    final msg = jsonEncode({
      'type': 'hq-beacon',
      'household': _household,
      'tcp': _tcpPort,
    });
    final bytes = utf8.encode(msg);
    // Muchos routers/Wi‑Fi filtran un formato de broadcast y dejan pasar el
    // otro: se envía tanto al broadcast global (255.255.255.255) como al de
    // la subred propia (p. ej. 192.168.1.255) para maximizar la detección.
    for (final destino in _destinosBroadcast()) {
      try {
        u.send(bytes, destino, _udpPort);
      } catch (_) {}
    }
  }

  List<InternetAddress> _destinosBroadcast() {
    final destinos = <InternetAddress>[];
    void agregar(String ip) {
      if (ip.isEmpty) return;
      final a = InternetAddress.tryParse(ip);
      if (a != null && !destinos.contains(a)) destinos.add(a);
    }

    agregar('255.255.255.255');
    for (final ip in _localIps) {
      final partes = ip.split('.');
      if (partes.length == 4) agregar('${partes[0]}.${partes[1]}.${partes[2]}.255');
    }
    return destinos;
  }

  void _procesarBeacon(Datagram dg) {
    try {
      final m = jsonDecode(utf8.decode(dg.data));
      if (m is! Map) return;
      if (m['type'] != 'hq-beacon') return;
      final ip = dg.address.address;
      if (_localIps.contains(ip)) return;
      if (m['household'] != _household) {
        // Mismo Wi-Fi pero otro código: se muestra en la UI para poder
        // diagnosticar "no sincronizan" en lugar de ignorarlo en silencio.
        _vecinosAjenos[ip] = DateTime.now();
        _fijarAlerta(
          'Hay un HogarQuest en tu red con otro código de hogar ($ip). '
          'Los dispositivos solo se sincronizan con el mismo código.',
        );
        return;
      }
      final tcp = m['tcp'] as int? ?? _tcpPort;
      _peers[ip] = _Peer(ip: ip, port: tcp, lastSeen: DateTime.now());
      _notificar();
    } catch (_) {}
  }

  Future<void> _sincronizarConPeers() async {
    if (_db == null || _household == null) return;
    final ahora = DateTime.now();
    _peers.removeWhere((_, p) => ahora.difference(p.lastSeen).inSeconds > 25);
    _vecinosAjenos.removeWhere(
      (_, t) => ahora.difference(t).inSeconds > 25,
    );
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
        if (resp.statusCode == 403) {
          await resp.drain();
          _fijarAlerta(
            'El dispositivo ${p.ip} tiene otro código de hogar; no se puede '
            'sincronizar con él.',
          );
          return;
        }
        if (resp.statusCode == 200) {
          final body = await resp.transform(utf8.decoder).join();
          final data = jsonDecode(body);
          await _db!.mezclarDesdePar(data as Map<String, dynamic>);
          _ultimaSincronizacion = DateTime.now();
          _ultimaAlerta = null;
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
      _fijarAlerta(
        'El dispositivo ${p.ip} no responde. Revisa que tenga la app '
        'abierta y conectado a la misma Wi-Fi.',
      );
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
