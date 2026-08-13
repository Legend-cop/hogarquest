import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/app_provider.dart';

/// Servicio de notificaciones del sistema para plataformas nativas (Android).
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _iniciado = false;

  static const _claveHora = 'hq_recordatorio_hora';
  static const _claveMinutos = 'hq_recordatorio_minutos';
  static const _horaPorDefecto = 8;

  static const _channelAjustes = MethodChannel('hogarquest/ajustes');

  /// Abre los Ajustes de notificaciones de la app en el sistema.
  Future<bool> abrirAjustes() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _channelAjustes.invokeMethod('abrirAjustesNotificaciones');
        return true;
      } catch (_) {}
    }
    return false;
  }

  /// ¿El sistema permite mostrar notificaciones de la app?
  Future<bool> permisoConcedido() async {
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return (await androidImpl?.areNotificationsEnabled()) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Lee la hora configurada del recordatorio del usuario (minutos del día).
  Future<int> horaConfigurada(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final minutos = prefs.getInt('$_claveMinutos$userId');
    if (minutos != null) return minutos;
    // Compatibilidad: datos viejos guardados como hora en punto (0-23).
    final hora = prefs.getInt('$_claveHora$userId');
    return (hora ?? _horaPorDefecto) * 60;
  }

  /// Guarda la hora del recordatorio (minutos del día) y la sincroniza con el
  /// server, que es quien envía el push diario.
  Future<void> guardarHora(
      {required AppProvider app, required int userId, required int minutos}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_claveMinutos$userId', minutos);
    await prefs.setInt('$_claveHora$userId', minutos ~/ 60);
    await sincronizar(app: app, userId: userId);
  }

  /// Inicializa el plugin para mostrar notificaciones inmediatas.
  Future<void> init({AppProvider? app}) async {
    if (_iniciado) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
    );
    _iniciado = true;
  }

  /// Envía la hora configurada del recordatorio y el offset UTC local al
  /// server, para que él programe el push diario.
  Future<void> sincronizar(
      {required AppProvider app, required int userId}) async {
    final minutos = await horaConfigurada(userId);
    final offset = DateTime.now().timeZoneOffset.inMinutes;
    await app.guardarRecordatorioEnServer(
      userId: userId,
      minutos: minutos,
      offset: offset,
    );
  }

  /// Cancela todos los recordatorios programados localmente (versiones viejas).
  Future<void> cancelarRecordatorios() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  /// Solicita permiso para mostrar notificaciones (Android 13+).
  Future<bool> solicitarPermiso() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return (await androidImpl?.requestNotificationsPermission()) ?? true;
  }

  /// Muestra una notificación inmediata (push FCM recibido en primer plano).
  Future<void> mostrarInstantanea(String? titulo, String? cuerpo) async {
    if (kIsWeb) return;
    await init();
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      titulo ?? 'HogarQuest',
      cuerpo,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'hq_push',
          'Notificaciones push',
          channelDescription: 'Avisos en tiempo real de HogarQuest',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
