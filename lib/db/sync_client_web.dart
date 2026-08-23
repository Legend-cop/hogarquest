import 'dart:convert';
import 'dart:html' as html;

import 'server_config.dart';

/// Cliente de sincronización para Web: habla con el servidor Node que
/// guarda la base de datos compartida y notifica cambios vía SSE.
class SyncClient {
  static String get _base => '${ServerConfig.baseUrl}/api';

  Future<Map<String, dynamic>?> fetchDb() async {
    try {
      final req = await html.HttpRequest.request('$_base/db-public', method: 'GET');
      final decoded = jsonDecode(req.responseText!);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> loginServerSide(String usuario, String password) async {
    try {
      final req = await html.HttpRequest.request(
        '$_base/login',
        method: 'POST',
        sendData: jsonEncode({'usuario': usuario, 'password': password}),
        requestHeaders: {'Content-Type': 'application/json'},
      );
      final decoded = jsonDecode(req.responseText!);
      if (decoded is Map && decoded['ok'] == true && decoded['user'] is Map) {
        return Map<String, dynamic>.from(decoded['user']);
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

  Future<void> registrarFcmToken(int userId, String token) => _postJson(
        '/register-token',
        {'userId': userId, 'token': token},
      );

  Future<void> borrarFcmToken(int userId, String token) => _postJson(
        '/register-token',
        {'userId': userId, 'token': token, 'remove': true},
      );

  Future<void> enviarPushFcm(int userId, String titulo, String cuerpo,
      [Map<String, String>? data]) async {
    final payload = <String, dynamic>{
      'userId': userId,
      'title': titulo,
      'body': cuerpo,
    };
    if (data != null) payload['data'] = data;
    await _postJson('/notify', payload);
  }

  Future<void> enviarRecordatorioConfig(int userId, int minutos, int offset) =>
      _postJson('/reminder', {
        'userId': userId,
        'minutos': minutos,
        'offset': offset,
      });

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
