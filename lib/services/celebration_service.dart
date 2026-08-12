import 'package:audioplayers/audioplayers.dart';

/// Reproduce el sonido de celebración de HogarQuest.
class CelebrationService {
  CelebrationService._();
  static final CelebrationService instance = CelebrationService._();

  final AudioPlayer _player = AudioPlayer();

  static const _success = 'assets/sounds/success.wav';

  bool _habilitado = true;

  /// Enciende/apaga los sonidos (se guarda con el perfil en el futuro).
  bool get habilitado => _habilitado;
  set habilitado(bool v) => _habilitado = v;

  /// Suena y vibra. Seguro de llamar desde cualquier plataforma.
  Future<void> success() async {
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