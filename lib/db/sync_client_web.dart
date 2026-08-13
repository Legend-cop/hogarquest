import 'dart:convert';
import 'dart:html' as html;

import 'server_config.dart';

/// Cliente de sincronización para Web: habla con el servidor Node que
/// guarda la base de datos compartida y notifica cambios vía SSE.
class SyncClient {
  static const _base = '/api';

  Future<Map<String, dynamic>?> fetchDb() async {
    try {
      final req = await html.HttpRequest.request('$_base/db', method: 'GET');
      final decoded = jsonDecode(req.responseText!);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  Future<void> pushDb(Map<String, dynamic> db) async {
    try {
      await html.HttpRequest.request(
        '$_base/db',
        method: 'POST',
        sendData: jsonEncode(db),
        requestHeaders: {
          'Content-Type': 'application/json',
          'X-Write-Token': ServerConfig.writeToken,
        },
      );
    } catch (_) {}
  }

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

  Future<void> _postJson(String path, Map<String, dynamic> body) async {
    try {
      await html.HttpRequest.request(
        '$_base$path',
        method: 'POST',
        sendData: jsonEncode(body),
        requestHeaders: {
          'Content-Type': 'application/json',
          'X-Write-Token': ServerConfig.writeToken,
        },
      );
    } catch (_) {}
  }

  void listen(void Function() onRemote, {void Function()? onReconnect}) {
    final es = html.EventSource('$_base/events');
    es.onOpen.listen((_) => onReconnect?.call());
    es.onMessage.listen((_) => onRemote());
  }
}
