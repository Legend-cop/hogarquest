import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Selecciona una foto de la galería (Android/Windows/iOS).
/// Devuelve (bytes, mime) o null si el usuario cancela.
Future<(Uint8List, String)?> elegirFoto() async {
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
}
