import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Evita invocaciones concurrentes del picker (Android lanza
/// PlatformException(already_active) si se toca dos veces seguidas).
bool _eligiendo = false;

/// Selecciona una foto de la galería (Android/Windows/iOS).
/// Devuelve (bytes, mime) o null si el usuario cancela.
Future<(Uint8List, String)?> elegirFoto() async {
  if (_eligiendo) return null;
  _eligiendo = true;
  try {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      maxHeight: 900,
      imageQuality: 85,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    final mime = picked.name.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';
    return (bytes, mime);
  } on PlatformException catch (e) {
    if (e.code == 'already_active') return null;
    rethrow;
  } finally {
    _eligiendo = false;
  }
}
