// Sincronización P2P local (Bluetooth/Wi-Fi) sin internet.
// En Android usa Nearby Connections; en otras plataformas (web) se usa un stub
// que no hace nada.
export 'bluetooth_sync_android.dart' if (dart.library.html) 'bluetooth_sync_stub.dart';
export 'bluetooth_peer.dart';
