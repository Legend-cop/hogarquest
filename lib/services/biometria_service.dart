import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Desbloqueo biométrico (huella o rostro) por usuario.
///
/// Solo está disponible en el APK para Android/iOS; la contraseña (niños)
/// o el PIN (admin) siguen siendo el respaldo siempre. En web la opción
/// queda oculta.
class BiometriaService {
  /// Llave histórica del admin (se migra a la por-usuario en `cargarPara`).
  static const _keyLegacyAdmin = 'hq_biometria';

  static String _keyDe(int userId) => 'hq_biometria_$userId';

  /// Preferencia activa del usuario actual (guarda `hq_biometria_<id>`).
  static final ValueNotifier<bool> activa = ValueNotifier<bool>(false);

  /// Si el dispositivo soporta biometría con datos registrados.
  static final ValueNotifier<bool> disponible = ValueNotifier<bool>(false);

  static bool get _movil =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Detecta si el dispositivo tiene biometría disponible.
  static Future<void> cargar() async {
    if (!_movil) {
      disponible.value = false;
      activa.value = false;
      return;
    }
    try {
      final auth = LocalAuthentication();
      final soportado = await auth.isDeviceSupported();
      final puedeChecar = await auth.canCheckBiometrics;
      disponible.value = soportado && puedeChecar;
    } catch (_) {
      disponible.value = false;
    }
    if (!disponible.value) activa.value = false;
  }

  /// Carga la preferencia del usuario dado (llamar tras iniciar sesión).
  static Future<void> cargarPara(int userId) async {
    if (!disponible.value) {
      activa.value = false;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final propia = prefs.getBool(_keyDe(userId));
      if (propia != null) {
        activa.value = propia;
        return;
      }
      // Migración: la llave global histórica era del admin.
      final legacy = prefs.getBool(_keyLegacyAdmin);
      if (legacy != null && legacy) {
        activa.value = true;
        await prefs.setBool(_keyDe(userId), true);
      } else {
        activa.value = false;
      }
    } catch (_) {
      activa.value = false;
    }
  }

  /// Si el usuario aún no tiene preferencia guardada (para el recordatorio
  /// "¿Quieres usar tu huella la próxima vez?" tras el primer login).
  static Future<bool> sinPreferencia(int userId) async {
    if (!disponible.value) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return !prefs.containsKey(_keyDe(userId));
    } catch (_) {
      return false;
    }
  }

  static Future<void> setActiva(bool valor) async {
    final v = valor && disponible.value;
    activa.value = v;
    // Se guarda con la llave del usuario que fijó la preferencia; el
    // caller (Ajustes) es quien conoce el id.
  }

  static Future<void> setActivaPara(int userId, bool valor) async {
    final v = valor && disponible.value;
    activa.value = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyDe(userId), v);
    } catch (_) {}
  }

  /// Pide la autenticación biométrica. Devuelve `false` en web, si la
  /// opción está apagada o si el usuario cancela/falla (luego se usa la
  /// contraseña o el PIN).
  static Future<bool> autenticar() async {
    if (!_movil || !activa.value) return false;
    try {
      return await LocalAuthentication().authenticate(
        localizedReason: 'Desbloquea HogarQuest',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
