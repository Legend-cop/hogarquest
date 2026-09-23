import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reproduce el sonido de celebración de HogarQuest.
class CelebrationService {
  CelebrationService._();
  static final CelebrationService instance = CelebrationService._();

  static const _claveSonido = 'hq_sonido_habilitado';

  final AudioPlayer _player = AudioPlayer();

  bool _habilitado = true;
  bool _cargado = false;

  /// Enciende/apaga los sonidos. Se persiste entre sesiones.
  bool get habilitado => _habilitado;

  set habilitado(bool v) {
    _habilitado = v;
    unawaitedPrefs(v);
  }

  /// Carga la preferencia guardada (llamar al arrancar).
  Future<void> cargar() async {
    if (_cargado) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _habilitado = prefs.getBool(_claveSonido) ?? true;
    } catch (_) {
      // Sin preferencias disponibles: se queda el valor por defecto.
    }
    _cargado = true;
  }

  Future<void> unawaitedPrefs(bool v) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_claveSonido, v);
    } catch (_) {}
  }

  /// Suena. Seguro de llamar desde cualquier plataforma.
  Future<void> success() async {
    if (!_cargado) await cargar();
    if (!_habilitado) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/success.wav'));
    } catch (_) {
      // Sin audio disponible (web sin interacción previa, etc.): silencio.
    }
  }

  Future<void> dispose() => _player.dispose();
}
