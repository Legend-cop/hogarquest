import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia de visibilidad de la mascota compañera (guarda
/// `hq_mascota_siempre`). Por defecto la mascota es intermitente: aparece
/// y desaparece sola. Con la opción activa se queda siempre visible.
class MascotaService {
  static const _key = 'hq_mascota_siempre';

  /// Notifica en vivo a la navegación cuando cambia la preferencia.
  static final ValueNotifier<bool> siempreVisible = ValueNotifier<bool>(false);

  static Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      siempreVisible.value = prefs.getBool(_key) ?? false;
    } catch (_) {
      // Sin prefs disponible: mantenemos el valor por defecto.
    }
  }

  static Future<void> setSiempreVisible(bool valor) async {
    siempreVisible.value = valor;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, valor);
    } catch (_) {}
  }
}
