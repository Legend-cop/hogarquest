import 'dart:convert';
import 'dart:html' as html;

import 'server_config.dart';

/// Sube una imagen de perfil al servidor (Web).
class UploadClient {
  /// Devuelve la URL relativa de la foto subida (ej: /fotos/xxx.jpg).
  Future<String?> subirFoto(List<int> bytes, {String mime = 'image/jpeg'}) async {
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
