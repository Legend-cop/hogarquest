import 'dart:io';

import 'package:path_provider/path_provider.dart';

class PhotoStore {
  static Future<String> guardarLocal(String origen) async {
    final dir = await getApplicationDocumentsDirectory();
    final fotosDir = Directory('${dir.path}/hq_photos');
    if (!await fotosDir.exists()) await fotosDir.create(recursive: true);
    final name = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final dest = File('${fotosDir.path}/$name');
    await File(origen).copy(dest.path);
    return dest.path;
  }

  static bool existe(String? path) =>
      path != null && path.isNotEmpty && File(path).existsSync();

  /// Guarda los [bytes] de una imagen en el almacenamiento local y devuelve
  /// la ruta. Se usa para mostrar la foto sin internet.
  static Future<String> guardarBytes(List<int> bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final fotosDir = Directory('${dir.path}/hq_photos');
    if (!await fotosDir.exists()) await fotosDir.create(recursive: true);
    final name = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final dest = File('${fotosDir.path}/$name');
    await dest.writeAsBytes(bytes);
    return dest.path;
  }
}
