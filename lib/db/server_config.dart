import 'package:flutter/foundation.dart' show kIsWeb;

/// Configuración del servidor HogarQuest para la app.
///
/// - En **Web** (GitHub Pages) y en **Android/Windows** la app se conecta
///   siempre a la API en la nube (DigitalOcean, vía crédito educación),
///   porque la web y la API viven en orígenes distintos.
class ServerConfig {
  /// URL pública de la API (Azure, vía crédito GitHub Education).
  /// Se pasa en el build con --dart-define=API_BASE_URL=..., de modo que no
  /// hay que editar el código. Por defecto queda un marcador.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://CAMBIA-POR-LA-URL-DEL-DROPLET',
  );

  /// Respaldo por si el build no recibe API_BASE_URL (variable del repo
  /// ausente). Así la app nativa siempre puede hablar con el servidor real
  /// aunque el --dart-define venga vacío.
  static const String _fallbackUrl = 'https://hogarquest-api-uts.azurewebsites.net';

  /// URL que usa la app nativa (Android/Windows) para hablar con la nube.
  /// Si el build no definió API_BASE_URL (o dejó el marcador), usa el respaldo.
  static String get cloudUrl {
    final v = apiBaseUrl.trim();
    if (v.isEmpty || v.contains('CAMBIA-POR-LA-URL')) return _fallbackUrl;
    return v;
  }

  /// Orden en que la app nativa probará las direcciones (solo la nube).
  static List<String> get candidateUrls => [cloudUrl];

  static const String writeToken = 'hq-aCOYOzECZhLg04xREE1a1WlAoRJp3exLGJB63cQB';

  /// URL que la app nativa debe usar (se rellena al encontrar el servidor).
  static String activaUrl = cloudUrl;

  /// Base URL visible para el resto de la app.
  /// Tanto en web como en nativo apunta a la API absoluta en la nube.
  /// En web usamos [cloudUrl] (que ya aplica el respaldo de Azure si la
  /// variable API_BASE_URL está vacía) para no quedar apuntando al marcador
  /// inválido cuando no se configura la variable en el deploy.
  static String get baseUrl => kIsWeb ? cloudUrl : activaUrl;
}
