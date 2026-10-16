import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Desbloqueo biométrico (huella o rostro) para el panel de administrador.
///
/// Solo está disponible en el APK para Android/iOS; el PIN de administrador
/// sigue siendo el respaldo siempre. En web la opción queda oculta.
class BiometriaService {
  static const _key = 'hq_biometria';

  /// Preferencia activa del usuario (guarda `hq_biometria`).
  static final ValueNotifier<bool> activa = ValueNotifier<bool>(false);

  /// Si el dispositivo soporta biometría con datos registrados.
  static final ValueNotifier<bool> disponible = ValueNotifier<bool>(false);

  static bool get _movil =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> cargar() async {
    if (!_movil) return;
    try {
      final auth = LocalAuthentication();
      final soportado = await auth.isDeviceSupported();
      final puedeChecar = await auth.canCheckBiometrics;
      disponible.value = soportado && puedeChecar;
      if (!disponible.value) {
        activa.value = false;
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      activa.value = prefs.getBool(_key) ?? false;
    } catch (_) {
      disponible.value = false;
      activa.value = false;
    }
  }

  static Future<void> setActiva(bool valor) async {
    final v = valor && disponible.value;
    activa.value = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, v);
    } catch (_) {}
  }

  /// Pide la autenticación biométrica. Devuelve `false` en web, si la
  /// opción está apagada o si el usuario cancela/ falla (luego se usa PIN).
  static Future<bool> autenticar() async {
    if (!_movil || !activa.value) return false;
    try {
      return await LocalAuthentication().authenticate(
        localizedReason: 'Desbloquea el panel de administración',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
