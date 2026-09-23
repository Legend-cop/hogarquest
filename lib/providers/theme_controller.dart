import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controla el tema claro/oscuro/system y lo persiste entre sesiones.
class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get esOscuro => _mode == ThemeMode.dark;
  bool get esSystem => _mode == ThemeMode.system;

  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString('tema') ?? 'light';
    _mode = switch (v) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
    notifyListeners();
  }

  Future<void> setOscuro(bool oscuro) =>
      setModo(oscuro ? ThemeMode.dark : ThemeMode.light);

  Future<void> setModo(ThemeMode modo) async {
    _mode = modo;
    final prefs = await SharedPreferences.getInstance();
    final v = switch (modo) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      _ => 'light',
    };
    await prefs.setString('tema', v);
    notifyListeners();
  }
}
