import 'package:flutter/foundation.dart' show kIsWeb;

/// Configuración del servidor HogarQuest para la app.
///
/// - En **Web** las llamadas usan rutas relativas (`/api/...`), porque el
///   navegador carga la web desde el mismo servidor (nube).
/// - En **Android/Windows** la app se conecta siempre a la nube (Render),
///   así las fotos y los datos viven en el mismo sitio que la web.
class ServerConfig {
  /// URL pública en la nube (Render).
  static const String cloudUrl = 'https://hogarquest.onrender.com';

  /// Orden en que la app nativa probará las direcciones (solo la nube).
  static const List<String> candidateUrls = [cloudUrl];

  static const String writeToken = 'hq-aCOYOzECZhLg04xREE1a1WlAoRJp3exLGJB63cQB';

  /// URL que la app nativa debe usar (se rellena al encontrar el servidor).
  static String activaUrl = candidateUrls.first;

  /// Base URL visible para el resto de la app.
  /// En web devuelve vacío (rutas relativas al servidor actual).
  static String get baseUrl => kIsWeb ? '' : activaUrl;
}
