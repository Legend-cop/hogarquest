import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Utilidades de seguridad de HogarQuest.
class SecurityService {
  /// Calcula el hash SHA-256 de una contraseña con salt único por usuario.
  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt::$password');
    return sha256.convert(bytes).toString();
  }

  /// Genera un salt aleatorio seguro de 16 caracteres hex.
  static String generarSalt() {
    final rng = Random.secure();
    return List.generate(
      8,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  /// Verifica si un mapa de usuario tiene una contraseña en texto plano
  /// (migración antigua) y devuelve true si hay que migrarla.
  ///
  /// Un valor que ya parece un SHA-256 (64 hex) NO se re-hashea: sería un
  /// hash-del-hash y la cuenta quedaría con credenciales inválidas (no se
  /// podría iniciar sesión en ningún dispositivo).
  static bool requiereMigracion(Map map) {
    final pwd = map['password'];
    final salt = map['salt'];
    if (pwd is! String || pwd.isEmpty) return false;
    if (salt != null && salt.isNotEmpty) return false;
    return !esHashSha256(pwd);
  }

  /// true si el texto ya parece un SHA-256 en hexadecimal (64 caracteres).
  static bool esHashSha256(String v) =>
      v.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(v);
}
