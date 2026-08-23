import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'server_config.dart';

/// Cliente de sincronización para plataformas nativas (Android/Windows):
/// se conecta al servidor HogarQuest usando HTTP + SSE.
///
/// Prueba las direcciones de [ServerConfig.candidateUrls] en orden y recuerda
/// la primera que responda, así funciona en la nube o en la red local.
class SyncClient {
  bool _listening = false;
  void Function()? _onRemote;
  void Function()? _onReconnect;
  String? _baseActiva;

  Future<String?> encontrarBase() async {
    if (_baseActiva != null) return _baseActiva;
    for (final url in ServerConfig.candidateUrls) {
      try {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 4);
        final req = await client.getUrl(Uri.parse('$url/api/db'));
        final res = await req.close();
        await res.drain();
        client.close();
        if (res.statusCode == 200) {
          _baseActiva = url;
          ServerConfig.activaUrl = url;
          return url;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchDb() async {
    final base = await encontrarBase();
    if (base == null) return null;
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(Uri.parse('$base/api/db'));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      client.close();
      if (res.statusCode == 200 && body.isNotEmpty) {
        final decoded = jsonDecode(body);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> loginServerSide(String usuario, String password) async {
    final base = await encontrarBase();
    if (base == null) return null;
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final req = await client.postUrl(Uri.parse('$base/api/login'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'usuario': usuario, 'password': password}));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      client.close();
      if (res.statusCode == 200 && body.isNotEmpty) {
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded['ok'] == true && decoded['user'] is Map) {
          return Map<String, dynamic>.from(decoded['user']);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> pushDb(Map<String, dynamic> db) async {
    final base = await encontrarBase();
    if (base == null) return;
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final req = await client.postUrl(Uri.parse('$base/api/db'));
      req.headers.contentType = ContentType.json;
      req.headers.set('X-Write-Token', ServerConfig.writeToken);
      req.write(jsonEncode(db));
      final res = await req.close();
      await res.drain();
      client.close();
    } catch (_) {}
  }

  /// Escucha notificaciones del servidor vía SSE y llama a [onRemote]
  /// cada vez que otro cliente cambia datos. Se reconecta automáticamente.
  /// Registra el token FCM de este dispositivo para un usuario.
  Future<void> registrarFcmToken(int userId, String token) => _postJson(
        '/api/register-token',
        {'userId': userId, 'token': token},
      );

  /// Quita el token FCM del usuario (al cerrar sesión).
  Future<void> borrarFcmToken(int userId, String token) => _postJson(
        '/api/register-token',
        {'userId': userId, 'token': token, 'remove': true},
      );

  /// Pide al servidor que envíe un push real al dispositivo del usuario.
  Future<void> enviarPushFcm(int userId, String titulo, String cuerpo,
      [Map<String, String>? data]) async {
    final payload = <String, dynamic>{
      'userId': userId,
      'title': titulo,
      'body': cuerpo,
    };
    if (data != null) payload['data'] = data;
    await _postJson('/api/notify', payload);
  }

  /// Sincroniza la hora del recordatorio diario del usuario con el server.
  Future<void> enviarRecordatorioConfig(int userId, int minutos, int offset) =>
      _postJson('/api/reminder', {
        'userId': userId,
        'minutos': minutos,
        'offset': offset,
      });

  Future<void> _postJson(String path, Map<String, dynamic> body) async {
    final base = await encontrarBase();
    if (base == null) return;
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final req = await client.postUrl(Uri.parse('$base$path'));
      req.headers.contentType = ContentType.json;
      req.headers.set('X-Write-Token', ServerConfig.writeToken);
      req.write(jsonEncode(body));
      final res = await req.close();
      await res.drain();
      client.close();
    } catch (_) {}
  }

  void listen(void Function() onRemote, {void Function()? onReconnect}) {
    _onRemote = onRemote;
    _onReconnect = onReconnect;
    _listening = true;
    _conectarSse();
  }

  Future<void> _conectarSse() async {
    if (!_listening) return;
    final base = await encontrarBase();
    if (base == null) {
      _reconectar();
      return;
    }
    try {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse('$base/api/events'));
      req.headers.set('Accept', 'text/event-stream');
      client.connectionTimeout = const Duration(seconds: 5);

      final res = await req.close();
      if (!_listening) {
        client.close();
        return;
      }
      _onReconnect?.call();
      res.listen(
        (chunk) => _onRemote?.call(),
        onDone: () {
          client.close();
          _reconectar();
        },
        onError: (Object _) {
          client.close();
          _reconectar();
        },
      );
    } catch (_) {
      _reconectar();
    }
  }

  void _reconectar() {
    if (!_listening) return;
    Future.delayed(const Duration(seconds: 2), _conectarSse);
  }
}
