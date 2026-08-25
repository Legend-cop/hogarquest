/// Sincronización P2P local (misma red, sin internet).
///
/// En nativo usa sockets (dart:io); en web es un stub que no hace nada.
/// Ver lib/sync/local_sync_io.dart para la implementación real.
export 'local_sync_io.dart' if (dart.library.html) 'local_sync_web.dart';
