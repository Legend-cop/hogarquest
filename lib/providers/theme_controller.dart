import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controla el tema claro/oscuro y lo persiste entre sesiones.
class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get esOscuro => _mode == ThemeMode.dark;

  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString('tema') ?? 'light';
    _mode = v == 'dark' ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> setOscuro(bool oscuro) async {
    _mode = oscuro ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tema', oscuro ? 'dark' : 'light');
    notifyListeners();
  }
}
