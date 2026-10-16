// Implementación web de subida de fotos: solo se carga en compilaciones web
// (export condicional en upload_client.dart), por eso usa dart:html.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'server_config.dart';

/// Sube una imagen de perfil al servidor (Web).
class UploadClient {
  /// Devuelve la URL relativa de la foto subida (ej: /fotos/xxx.jpg).
  Future<String?> subirFoto(
    List<int> bytes, {
    String mime = 'image/jpeg',
  }) async {
    try {
      final req = await html.HttpRequest.request(
        '/api/upload',
        method: 'POST',
        sendData: bytes,
        requestHeaders: {
          'Content-Type': mime,
          'X-Write-Token': ServerConfig.writeToken,
        },
      );
      final decoded = jsonDecode(req.responseText!);
      if (decoded is Map && decoded['ok'] == true) {
        return decoded['url'] as String?;
      }
    } catch (_) {}
    return null;
  }
}
