import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/user.dart';
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

  /// Guarda la hora del recordatorio (minutos del día) y reprograma.
  Future<void> guardarHora(
      {required AppProvider app, required int userId, required int minutos}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_claveMinutos$userId', minutos);
    await prefs.setInt('$_claveHora$userId', minutos ~/ 60);
    final usuario = await app.buscarUsuario(userId);
    if (usuario != null) {
      await programarRecordatorios(app: app, usuario: usuario);
    }
  }

  /// Inicializa el plugin y programa el recordatorio diario del usuario actual.
  Future<void> init({AppProvider? app}) async {
    if (_iniciado) return;
    tzdata.initializeTimeZones();
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

  /// Programa dos recordatorios diarios del usuario:
  ///  - mañana: tareas pendientes de HOY (para integrantes)
  ///  - tarde:  aprobaciones pendientes (para el admin)
  Future<void> programarRecordatorios(
      {required AppProvider app, required User usuario}) async {
    await init(app: app);
    final id = usuario.id;
    if (id == null) return;

    // Cancelar recordatorios viejos de este usuario antes de reprogramar.
    await cancelarRecordatoriosDe(usuario);

    final zona = tz.local;
    final hoy = tz.TZDateTime.now(zona);
    final minutos = await horaConfigurada(id);
    final hora = minutos ~/ 60;
    final minuto = minutos % 60;
    var horaRecordatorio = tz.TZDateTime(zona, hoy.year, hoy.month, hoy.day,
        hora.clamp(0, 23), minuto.clamp(0, 59));
    if (horaRecordatorio.isBefore(hoy)) {
      horaRecordatorio = horaRecordatorio.add(const Duration(days: 1));
    }

    if (!usuario.esAdmin) {
      // Recordatorio de tareas de HOY para el integrante.
      await _plugin.zonedSchedule(
        id * 100 + 1,
        'HogarQuest: tus tareas de hoy',
        '¡Recuerda completar tus tareas para ganar puntos!',
        horaRecordatorio,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'hq_recordatorios',
            'Recordatorios de tareas',
            channelDescription: 'Recordatorios diarios de tareas del hogar',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } else {
      // Recordatorio de aprobaciones pendientes para el admin.
      await _plugin.zonedSchedule(
        id * 100 + 2,
        'HogarQuest: tareas por revisar',
        'Revisa las tareas completadas de tus hijos.',
        horaRecordatorio,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'hq_aprobaciones',
            'Aprobaciones de tareas',
            channelDescription: 'Avisos de tareas completadas por aprobar',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  /// Cancela los recordatorios de un usuario concreto.
  Future<void> cancelarRecordatoriosDe(User usuario) async {
    final id = usuario.id;
    if (id == null) return;
    await _plugin.cancel(id * 100 + 1);
    await _plugin.cancel(id * 100 + 2);
  }

  /// Cancela todos los recordatorios programados.
  Future<void> cancelarRecordatorios() async {
    await _plugin.cancelAll();
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
