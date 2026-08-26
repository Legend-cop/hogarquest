import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'server_config.dart';

/// Cliente de sincronización para plataformas nativas (Android/Windows):
/// se conecta al servidor HogarQuest usando HTTP + SSE.
///
/// Prueba las direcciones de [ServerConfig.candidateUrls] en orden y recuerda
/// la primera que responda, así funciona en la nube o en la red local.
///
/// Todas las llamadas de red tienen un timeout total: si el servidor no
/// responde a tiempo, se asume offline y la app sigue funcionando con la
/// caché local en lugar de congelarse esperando la respuesta.
class SyncClient {
  bool _listening = false;
  bool _conectandoSse = false;
  void Function()? _onRemote;
  void Function()? _onReconnect;
  String? _baseActiva;

  Future<String?> encontrarBase() =>
      _encontrarBase().timeout(const Duration(seconds: 8), onTimeout: () => null);

  Future<String?> _encontrarBase() async {
    if (_baseActiva != null) return _baseActiva;
    const intentos = 2;
    for (int i = 0; i < intentos; i++) {
      for (final url in ServerConfig.candidateUrls) {
        HttpClient? client;
        try {
          client = HttpClient()
            ..connectionTimeout = const Duration(seconds: 8);
          final req = await client.getUrl(Uri.parse('$url/api/db'));
          final res = await req.close();
          await res.drain();
          if (res.statusCode == 200) {
            _baseActiva = url;
            ServerConfig.activaUrl = url;
            return url;
          }
        } catch (_) {
          // Sin respuesta: probamos la siguiente URL.
        } finally {
          client?.close(force: true);
        }
      }
      if (i < intentos - 1) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchDb() =>
      _fetchDb().timeout(const Duration(seconds: 12), onTimeout: () => null);

  Future<Map<String, dynamic>?> _fetchDb() async {
    const intentos = 2;
    for (int i = 0; i < intentos; i++) {
      final base = await encontrarBase();
      if (base == null) {
        if (i < intentos - 1) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }
        return null;
      }
      HttpClient? client;
      try {
        client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 10);
        final req = await client.getUrl(Uri.parse('$base/api/db'));
        final res = await req.close();
        final body = await res.transform(utf8.decoder).join();
        if (res.statusCode == 200 && body.isNotEmpty) {
          final decoded = jsonDecode(body);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // Error de red: se reintentará en la siguiente pasada.
      } finally {
        client?.close(force: true);
      }
      if (i < intentos - 1) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> loginServerSide(String usuario, String password) =>
      _loginServerSide(usuario, password)
          .timeout(const Duration(seconds: 10), onTimeout: () => null);

  Future<Map<String, dynamic>?> _loginServerSide(
      String usuario, String password) async {
    final base = await encontrarBase();
    if (base == null) return null;
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final req = await client.postUrl(Uri.parse('$base/api/login'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'usuario': usuario, 'password': password}));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode == 200 && body.isNotEmpty) {
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded['ok'] == true && decoded['user'] is Map) {
          return Map<String, dynamic>.from(decoded['user']);
        }
      }
    } catch (_) {
      // Error de red: se ignora y se devuelve null.
    } finally {
      client?.close(force: true);
    }
    return null;
  }

  Future<void> pushDb(Map<String, dynamic> db) async {
    try {
      await _pushDb(db).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      // Sin respuesta del servidor: se reintentará al reconectar.
    }
  }

  Future<void> _pushDb(Map<String, dynamic> db) async {
    final base = await encontrarBase();
    if (base == null) return;
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final req = await client.postUrl(Uri.parse('$base/api/db'));
      req.headers.contentType = ContentType.json;
      req.headers.set('X-Write-Token', ServerConfig.writeToken);
      req.write(jsonEncode(db));
      final res = await req.close();
      await res.drain();
    } catch (_) {
      // Error de red: se reintentará al reconectar.
    } finally {
      client?.close(force: true);
    }
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
    try {
      await _postJsonImpl(path, body).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      // Se ignora: la acción se reintentará más tarde.
    }
  }

  Future<void> _postJsonImpl(String path, Map<String, dynamic> body) async {
    final base = await encontrarBase();
    if (base == null) return;
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final req = await client.postUrl(Uri.parse('$base$path'));
      req.headers.contentType = ContentType.json;
      req.headers.set('X-Write-Token', ServerConfig.writeToken);
      req.write(jsonEncode(body));
      final res = await req.close();
      await res.drain();
    } catch (_) {
      // Error de red: se ignora.
    } finally {
      client?.close(force: true);
    }
  }

  void listen(void Function() onRemote, {void Function()? onReconnect}) {
    _onRemote = onRemote;
    _onReconnect = onReconnect;
    _listening = true;
    _conectarSse();
  }

  Future<void> _conectarSse() async {
    if (!_listening || _conectandoSse) return;
    _conectandoSse = true;
    final base = await encontrarBase();
    if (base == null) {
      _conectandoSse = false;
      _reconectarEnBreve(const Duration(seconds: 8));
      return;
    }
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final req = await client
          .getUrl(Uri.parse('$base/api/events'))
          .timeout(const Duration(seconds: 5));
      req.headers.set('Accept', 'text/event-stream');

      final res = await req.close();
      if (!_listening) {
        client.close(force: true);
        _conectandoSse = false;
        return;
      }
      _onReconnect?.call();
      res.listen(
        (chunk) => _onRemote?.call(),
        onDone: () {
          client?.close(force: true);
          _conectandoSse = false;
          _reconectar();
        },
        onError: (Object _) {
          client?.close(force: true);
          _conectandoSse = false;
          _reconectar();
        },
        cancelOnError: true,
      );
    } on TimeoutException {
      client?.close(force: true);
      _conectandoSse = false;
      _reconectarEnBreve(const Duration(seconds: 8));
    } catch (_) {
      client?.close(force: true);
      _conectandoSse = false;
      _reconectar();
    }
  }

  void _reconectar() => _reconectarEnBreve(const Duration(seconds: 2));

  void _reconectarEnBreve(Duration espera) {
    if (!_listening) return;
    Future.delayed(espera, _conectarSse);
  }
}
