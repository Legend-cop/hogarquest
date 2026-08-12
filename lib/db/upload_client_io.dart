import 'dart:convert';
import 'dart:io';

import 'server_config.dart';
import 'sync_client_io.dart';

/// Sube una imagen de perfil al servidor (Android/Windows).
class UploadClient {
  final SyncClient _sync;

  UploadClient() : _sync = SyncClient();

  /// Devuelve la URL relativa de la foto subida (ej: /fotos/xxx.jpg).
  Future<String?> subirFoto(List<int> bytes, {String mime = 'image/jpeg'}) async {
    final base = await _sync.encontrarBase();
    if (base == null) return null;
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final req = await client.postUrl(Uri.parse('$base/api/upload'));
      req.headers.contentType = ContentType.parse(mime);
      req.headers.set('X-Write-Token', ServerConfig.writeToken);
      req.add(bytes);
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      client.close();
      if (res.statusCode == 200) {
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded['ok'] == true) {
          return decoded['url'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }
}
