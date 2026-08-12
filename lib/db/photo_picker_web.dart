import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

/// Selecciona una foto usando el selector de archivos del navegador,
/// que funciona en cualquier navegador sin depender del plugin image_picker.
Future<(Uint8List, String)?> elegirFoto() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false;
  input.click();
  final completer = Completer<(Uint8List, String)?>();
  input.onChange.listen((_) {
    final file = input.files?.firstOrNull;
    if (file == null) {
      completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.onError.listen((_) => completer.complete(null));
    reader.onLoadEnd.listen((_) {
      try {
        final bytes = reader.result is Uint8List
            ? reader.result as Uint8List
            : Uint8List.fromList(
                base64.decode(
                  (reader.result as String).split(',').last,
                ),
              );
        final mime = file.type == 'image/png' ? 'image/png' : 'image/jpeg';
        completer.complete((bytes, mime));
      } catch (_) {
        completer.complete(null);
      }
    });
    reader.readAsDataUrl(file);
  });
  return completer.future;
}
