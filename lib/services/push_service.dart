import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../services/notification_service_io.dart';

/// Maneja Firebase Cloud Messaging: permisos, token del dispositivo y
/// recepción de mensajes en primer y segundo plano.
///
/// El token se registra en el servidor asociado al usuario que inicia sesión,
/// y el servidor lo usa para enviar push reales a los dispositivos objetivo.
class PushService {
  static final PushService instance = PushService._();
  PushService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Clave VAPID para web (necesaria para obtener el token en navegadores).
  /// De Firebase: Project settings > Cloud Messaging > Web Push certificates.
  static const String _vapidKey =
      'BIyzi4bmLuZX7x6qhgApXiQP1d98mN_dzL1G49LleCQO-bgikLVSiN7EY4_eCASyc4C6QN2JM4iCq2waygvZbMo';

  int? _userId;
  bool _iniciado = false;

  /// Inicializa FCM una sola vez (permisos + listeners). Llámalo al arrancar.
  Future<void> inicializar() async {
    if (_iniciado) return;
    _iniciado = true;

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_enPrimerPlano);
    FirebaseMessaging.onMessageOpenedApp.listen(_alAbrir);

    await _refrescarToken();
    _messaging.onTokenRefresh.listen((_) => _refrescarToken());
  }

  /// Asocia el token del dispositivo al usuario que inicia sesión.
  Future<void> registrarPara(int userId) async {
    _userId = userId;
    await _refrescarToken();
  }

  /// Quita el token del usuario (al cerrar sesión).
  Future<void> desregistrar() async {
    final userId = _userId;
    _userId = null;
    if (userId == null) return;
    final token = await _tokenActual();
    if (token != null) {
      await DatabaseHelper.instance.borrarFcmToken(userId, token);
    }
  }

  Future<String?> _tokenActual() async {
    try {
      if (kIsWeb) {
        return await _messaging.getToken(vapidKey: _vapidKey);
      }
      return await _messaging.getToken();
    } catch (e) {
      // Sin VAPID (web) o sin google-services.json aún: se reintenta luego.
      return null;
    }
  }

  Future<void> _refrescarToken() async {
    final token = await _tokenActual();
    if (token != null && _userId != null) {
      await DatabaseHelper.instance.registrarFcmToken(_userId!, token);
    }
  }

  void _enPrimerPlano(RemoteMessage message) {
    if (!kIsWeb) {
      final n = message.notification;
      NotificationService.instance
          .mostrarInstantanea(n?.title, n?.body ?? message.data['body']);
    }
  }

  void _alAbrir(RemoteMessage message) {
    // La app ya escucha cambios remotos vía SSE; no hace falta navegar.
  }
}

/// Handler de mensajes en segundo plano (Android). Debe ser top-level.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}
