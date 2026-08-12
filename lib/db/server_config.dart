import 'package:flutter/foundation.dart' show kIsWeb;

/// Configuración del servidor HogarQuest para la app.
///
/// - En **Web** las llamadas usan rutas relativas (`/api/...`), porque el
///   navegador carga la web desde el mismo servidor (nube o local).
/// - En **Android/Windows** la app prueba las direcciones en orden: la nube
///   primero (funciona en cualquier parte) y luego la red local (en casa).
class ServerConfig {
  /// URL pública en la nube (Render/Railway). Pon aquí tu servicio cuando exista.
  static const String cloudUrl = 'https://hogarquest-server.onrender.com';

  /// Dirección local de la PC que corre el servidor en casa.
  static const String localUrl = 'http://192.168.1.14:8080';

  /// Orden en que la app nativa probará las direcciones.
  static const List<String> candidateUrls = [cloudUrl, localUrl];

  static const String writeToken = 'hq-secreto-cambiar-2026';

  /// URL que la app nativa debe usar (se rellena al encontrar el servidor).
  static String activaUrl = candidateUrls.first;

  /// Base URL visible para el resto de la app.
  /// En web devuelve vacío (rutas relativas al servidor actual).
  static String get baseUrl => kIsWeb ? '' : activaUrl;
}
