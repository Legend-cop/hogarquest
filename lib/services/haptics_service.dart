import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Vibración táctil opcional de la app (guarda `hq_haptica`).
/// Se usa al arrastrar avatares, crear tareas rápidas y completar acciones.
class HapticsService {
  static const _key = 'hq_haptica';
  static bool _habilitado = true;

  static bool get habilitado => _habilitado;

  static Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _habilitado = prefs.getBool(_key) ?? true;
    } catch (_) {
      // Sin prefs disponible: mantenemos el valor por defecto.
    }
  }

  static Future<void> setHabilitado(bool valor) async {
    _habilitado = valor;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, valor);
    } catch (_) {}
  }

  static void seleccion() {
    if (_habilitado) HapticFeedback.selectionClick();
  }

  static void ligero() {
    if (_habilitado) HapticFeedback.lightImpact();
  }
}
